import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/app/wallet_screen/payment_list_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/cab_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/services/call_kit_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/force_update_helper.dart';
import 'package:driver/utils/preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as location;
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';

class CabHomeController extends GetxController {
  static const Duration _driverAcceptTimeout = Duration(minutes: 5);
  RxBool isLoading = true.obs;
  google_maps.GoogleMapController? mapController;
  ym.YandexMapController? yandexMapController;
  RxMap<String, google_maps.Marker> markers =
      <String, google_maps.Marker>{}.obs;
  RxMap<google_maps.PolylineId, google_maps.Polyline> polyLines =
      <google_maps.PolylineId, google_maps.Polyline>{}.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderDocSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _orderQuerySub;

  /// Order id we currently have `_orderDocSub` subscribed to. Used to make
  /// `getCurrentOrder()` / `getOrderByRideId()` idempotent — repeated calls
  /// for the same order id (e.g. from rapid FCM wake-ups) no longer cancel
  /// + re-create the subscription and replay the initial snapshot.
  String? _subscribedOrderId;

  /// Last `(orderId, status)` pair we played the new-order alert tone for.
  /// Prevents `changeData()` from replaying `playSound(true)` on every
  /// driver-doc snapshot / listener re-subscribe for the same pending order.
  String? _lastAlertedOrderId;
  String? _lastAlertedStatus;

  /// Signature of the order-routing fields from the previous driver-doc
  /// snapshot. The driver document churns on every location ping — without
  /// this, every ping replays `getCurrentOrder()` + `changeData()` and (with
  /// the alert memo cleared by an unrelated path) can replay the new-order
  /// tone. We only re-run the chain when one of these fields actually
  /// changes.
  String? _lastDriverRoutingSignature;

  /// Safar davomida har 15–20 sekundda GPS va masofa yangilanishi
  Timer? _trackingTimer;
  location.LatLng? _lastTrackedLatLng;
  double _accumulatedKm = 0.0;

  /// Aktiv zakaz bo‘lmaganda yangi pending orderlarni tekshirish (yana zakaz handle qilish)
  Timer? _pendingOrderPollTimer;

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    ForceUpdateHelper.checkAndShowIfNeeded();
    _consumePendingCallkitRide();
  }

  /// On cold start: if the driver tapped Accept on a CallKit prompt for a cab
  /// ride while the app was terminated, [Preferences.pendingRideId] holds the
  /// ride id. Pull the order so the acceptance bottom sheet renders.
  Future<void> _consumePendingCallkitRide() async {
    final pendingType = Preferences.getString(Preferences.pendingOrderType);
    if (pendingType.isNotEmpty && pendingType != 'cab') return;
    final rideId = Preferences.getString(Preferences.pendingRideId);
    if (rideId.isEmpty) return;
    await Preferences.clearKeyData(Preferences.pendingRideId);
    await Preferences.clearKeyData(Preferences.pendingOrderType);
    await getOrderByRideId(rideId);
  }

  @override
  void onClose() {
    _stopTrackingTimer();
    _pendingOrderPollTimer?.cancel();
    _pendingOrderPollTimer = null;
    _driverSub?.cancel();
    _orderDocSub?.cancel();
    _orderQuerySub?.cancel();
    _subscribedOrderId = null;
    _lastAlertedOrderId = null;
    _lastAlertedStatus = null;
    _lastDriverRoutingSignature = null;
    super.onClose();
  }

  void _stopTrackingTimer() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  void _startPendingOrderPoll() {
    _pendingOrderPollTimer?.cancel();
    _pendingOrderPollTimer =
        Timer.periodic(const Duration(seconds: 15), (_) async {
      if (currentOrder.value.id != null && currentOrder.value.id!.isNotEmpty) {
        return;
      }
      if (driverModel.value.inProgressOrderID != null &&
          driverModel.value.inProgressOrderID!.isNotEmpty) {
        return;
      }
      if (driverModel.value.orderCabRequestData != null) return;
      // Oflayn haydovchiga yangi zakaz ko'rsatilmaydi (polling ham ishlamaydi)
      if (driverModel.value.isActive != true) return;
      await _queryPendingOrdersForDriver();
      if (currentOrder.value.id != null && currentOrder.value.id!.isNotEmpty) {
        _pendingOrderPollTimer?.cancel();
        _pendingOrderPollTimer = null;
        update();
      }
    });
  }

  void _stopPendingOrderPoll() {
    _pendingOrderPollTimer?.cancel();
    _pendingOrderPollTimer = null;
  }

  Future<void> getData() async {
    _subscribeDriver();
    isLoading.value = false;
    // Recover a ride that was in progress when the app was killed
    // (e.g. by the OS while the driver was navigating in Yandex).
    unawaited(_restoreInFlightRideIfAny());
  }

  Rx<CabOrderModel> currentOrder = CabOrderModel().obs;
  Rx<UserModel> driverModel = UserModel().obs;
  Rx<UserModel> ownerModel = UserModel().obs;

  bool _isFinalStatus(String? status) {
    return status == Constant.orderCompleted ||
        status == Constant.orderCancelled ||
        status == Constant.orderRejected;
  }

  bool _isPendingAcceptanceStatus(String? status) {
    return status == Constant.orderPlaced ||
        status == Constant.driverPending ||
        status == Constant.driverRejected ||
        status == Constant.orderAccepted;
  }

  bool _canAcceptCurrentOrder() {
    final order = currentOrder.value;
    final status = order.status;
    if (!_isPendingAcceptanceStatus(status)) return false;
    if (_isFinalStatus(status)) return false;
    final assignedDriver = order.driverId?.trim() ?? '';
    final myDriverId = driverModel.value.id?.trim() ?? '';
    if (assignedDriver.isNotEmpty && myDriverId.isNotEmpty && assignedDriver != myDriverId) {
      return false;
    }
    return order.id != null && order.id!.isNotEmpty;
  }

  bool _canRejectCurrentOrder() {
    final order = currentOrder.value;
    final status = order.status;
    if (!_isPendingAcceptanceStatus(status)) return false;
    if (_isFinalStatus(status)) return false;
    return order.id != null && order.id!.isNotEmpty;
  }

  bool _canStartTrip() {
    final status = currentOrder.value.status;
    return status == Constant.driverAccepted || status == Constant.orderShipped;
  }

  bool _canReachDestination() {
    return currentOrder.value.status == Constant.orderInTransit;
  }

  bool _canCompleteRide() {
    return currentOrder.value.status == Constant.orderInTransit;
  }

  /// Server-only read of the cab order's current status. Returns null on any
  /// failure or when the order doesn't exist. Used to avoid races where the
  /// driver acts on a stale local cache (e.g. customer cancelled while the
  /// driver was about to accept).
  Future<String?> _fetchOrderStatusFromServer(String? orderId) async {
    if (orderId == null || orderId.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('cab_booking_orders')
          .doc(orderId)
          .get(const GetOptions(source: Source.server));
      if (!snap.exists) return null;
      return (snap.data()?['status'] ?? '').toString();
    } catch (e) {
      log('[Cab] _fetchOrderStatusFromServer failed: $e');
      return null;
    }
  }

  bool _isAllowedTransition(String? from, String? to) {
    if (to == null || to.isEmpty) return true;
    if (from == null || from.isEmpty) return true;
    if (from == to) return true;
    if (_isFinalStatus(from)) return false;

    switch (from) {
      case Constant.orderPlaced:
      case Constant.driverPending:
      case Constant.driverRejected:
      case Constant.orderAccepted:
        return to == Constant.orderPlaced ||
            to == Constant.driverPending ||
            to == Constant.driverRejected ||
            to == Constant.driverAccepted ||
            to == Constant.orderShipped ||
            to == Constant.orderInTransit ||
            to == Constant.orderCancelled ||
            to == Constant.orderRejected;
      case Constant.driverAccepted:
        return to == Constant.orderShipped ||
            to == Constant.orderInTransit ||
            to == Constant.orderCancelled ||
            to == Constant.orderRejected ||
            to == Constant.orderCompleted;
      case Constant.orderShipped:
        return to == Constant.orderInTransit ||
            to == Constant.orderCancelled ||
            to == Constant.orderRejected ||
            to == Constant.orderCompleted;
      case Constant.orderInTransit:
        return to == Constant.orderCompleted ||
            to == Constant.orderCancelled;
      default:
        return true;
    }
  }

  Future<void> acceptOrder() async {
    try {
      if (!_canAcceptCurrentOrder()) {
        ShowToastDialog.showToast("Zakaz holati qabul qilish uchun yaroqsiz".tr);
        return;
      }

      // Race-condition guard: refetch the order from the server before
      // accepting. If the customer cancelled or another driver claimed it
      // in the meantime, bail out cleanly.
      final freshStatus = await _fetchOrderStatusFromServer(currentOrder.value.id);
      if (freshStatus != null &&
          freshStatus != Constant.orderPlaced &&
          freshStatus != Constant.driverPending &&
          freshStatus != Constant.driverRejected) {
        ShowToastDialog.showToast(
          "Buyurtma allaqachon $freshStatus holatida. Yangilash...".tr,
        );
        return;
      }

      await AudioPlayerService.stopAll();
      unawaited(CallKitService.endCall(currentOrder.value.id ?? ''));
      unawaited(CallKitService.endAll());
      ShowToastDialog.showLoader("Please wait".tr);

      driverModel.value.inProgressOrderID ??= [];
      driverModel.value.inProgressOrderID!.add(currentOrder.value.id);
      driverModel.value.orderCabRequestData = null;
      await FireStoreUtils.updateUser(driverModel.value);

      currentOrder.value.status = Constant.driverAccepted;
      currentOrder.value.driverId = driverModel.value.id;
      currentOrder.value.driver = driverModel.value;
      currentOrder.value.acceptedAt = Timestamp.now();
      await FireStoreUtils.setCabOrder(currentOrder.value);

      // Persist active ride id so a crash/Yandex round-trip can resume.
      if (currentOrder.value.id != null) {
        await Preferences.setString(
          Preferences.lastActiveRideId,
          currentOrder.value.id!,
        );
      }

      ShowToastDialog.closeLoader();

      await SendNotification.sendFcmMessage(Constant.driverAcceptedNotification,
          currentOrder.value.author?.fcmToken ?? "", {});

      // Order qabul qilinganda status o'zgardi, yo'l yangilanishi kerak
      // driverAccepted -> driver dan pickup (source) gacha
      print(
          "✅ [acceptOrder] Order qabul qilindi, status driverAccepted, yo'l yangilanmoqda");
      await changeData();
    } catch (e, s) {
      ShowToastDialog.closeLoader();
      debugPrint("Error in acceptOrder: $e");
      debugPrintStack(stackTrace: s);
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
    }
  }

  Future<void> rejectOrder() async {
    try {
      if (!_canRejectCurrentOrder()) {
        ShowToastDialog.showToast("Zakaz holati rad etish uchun yaroqsiz".tr);
        return;
      }
      await AudioPlayerService.stopAll();
      unawaited(CallKitService.endCall(currentOrder.value.id ?? ''));
      unawaited(CallKitService.endAll());

      final orderId = currentOrder.value.id;
      final myDriverId = driverModel.value.id;

      // Server-side check: if another driver has already moved the order past
      // acceptance (e.g. accepted it), do NOT downgrade `status` globally —
      // that would clobber the accepted ride and kick the customer back to
      // the "searching for driver" screen. Only record this driver in
      // `rejectedByDrivers` in that case. Mirror of the delivery flow guard
      // in home_controller.dart rejectOrder.
      bool safeToDowngradeStatus = true;
      if (orderId != null && orderId.isNotEmpty) {
        try {
          final serverSnap = await FirebaseFirestore.instance
              .collection(CollectionName.cabBookingOrders)
              .doc(orderId)
              .get(const GetOptions(source: Source.server));
          if (serverSnap.exists) {
            final data = serverSnap.data() ?? const <String, dynamic>{};
            final serverStatus = (data['status'] ?? '').toString();
            final serverDriverId = (data['driverId'] ?? '').toString().trim();
            final stillPending = serverStatus == Constant.orderPlaced ||
                serverStatus == Constant.driverPending ||
                serverStatus == Constant.driverRejected;
            final myId = myDriverId?.trim() ?? '';
            final assignedToOther = serverDriverId.isNotEmpty &&
                myId.isNotEmpty &&
                serverDriverId != myId;
            safeToDowngradeStatus = stillPending && !assignedToOther;
          }
        } catch (e) {
          // Network failure: be conservative and do NOT downgrade global
          // status — preserve any acceptance that may already exist on the
          // server.
          safeToDowngradeStatus = false;
          log('rejectOrder: server status fetch failed, preserving global status: $e');
        }
      }

      // 1️⃣ Immediately update local state (UI) — only flip local status if
      // it's safe to downgrade the global one; otherwise the order is already
      // accepted and we just leave it.
      if (safeToDowngradeStatus) {
        currentOrder.value.status = Constant.driverRejected;
      }

      currentOrder.value.rejectedByDrivers ??= [];
      if (myDriverId != null &&
          !currentOrder.value.rejectedByDrivers!.contains(myDriverId)) {
        currentOrder.value.rejectedByDrivers!.add(myDriverId);
      }

      // Immediately update UI so bottom sheet hides right away
      currentOrder.refresh();

      // 2️⃣ Update driver local state right away
      driverModel.value.orderCabRequestData = null;
      driverModel.value.inProgressOrderID = [];
      await FireStoreUtils.updateUser(driverModel.value);

      // 3️⃣ Close bottom sheet immediately (don't wait for Firestore)
      if (Get.isBottomSheetOpen ?? false) {
        Get.back();
      } else if (Constant.singleOrderReceive == false) {
        Get.back();
      }

      // 4️⃣ Clear map immediately
      await clearMap();

      // 5️⃣ Granular Firestore write so we don't accidentally overwrite
      // `driverId`/`driver`/`acceptedAt` set by the accepting driver via a
      // stale full-document merge.
      if (orderId != null && orderId.isNotEmpty && myDriverId != null) {
        final Map<String, dynamic> rejectPayload = {
          'rejectedByDrivers': FieldValue.arrayUnion([myDriverId]),
        };
        if (safeToDowngradeStatus) {
          rejectPayload['status'] = Constant.driverRejected;
        }
        unawaited(FirebaseFirestore.instance
            .collection(CollectionName.cabBookingOrders)
            .doc(orderId)
            .set(rejectPayload, SetOptions(merge: true)));
      }

      // 6️⃣ Reset local current order after short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        currentOrder.value = CabOrderModel();
      });

      // The driver rejected this ride — clear any persisted resume pointer.
      await Preferences.clearKeyData(Preferences.lastActiveRideId);
      await Preferences.clearKeyData(Preferences.lastAccumulatedKm);
    } catch (e, s) {
      print("rejectOrder() error: $e\n$s");
    }
  }

  bool get shouldShowOrderSheet {
    final status = currentOrder.value.status;
    final orderId = currentOrder.value.id;

    // Faqat quyidagi statuslarda "complete ride" bottom sheet ko'rsatiladi:
    // - driverAccepted: Order qabul qilingan, pickup ga borilmoqda
    // - orderShipped: Pickup ga yetib kelindi
    // - orderInTransit: Destination ga borilmoqda
    final allowedStatuses = [
      Constant.driverAccepted,
      Constant.orderShipped,
      Constant.orderInTransit
    ];

    final result = orderId != null && allowedStatuses.contains(status);
    print(
        "🎯 [shouldShowOrderSheet] orderId: $orderId, status: $status, result: $result");
    return result;
  }

  /// Faqat jo'nash joyi bilan berilgan zakaz (manzil user tomonidan kiritilmagan)
  bool get isSinglePointOrder {
    final order = currentOrder.value;
    // Masofa 0 yoki bo'sh – bitta nuqta (faqat jo'nash joyi)
    final dist = double.tryParse(order.distance ?? '') ?? -1.0;
    if (dist >= 0 && dist < 0.001) return true;
    final src = order.sourceLocation;
    final dest = order.destinationLocation;
    if (dest == null) return true;
    final destName = (order.destinationLocationName ?? '').trim();
    final srcName = (order.sourceLocationName ?? '').trim();
    if (destName.isEmpty || destName == srcName) return true;
    if (src == null) return true;
    const eps = 1e-4;
    final slat = (src.latitude is num) ? (src.latitude as num).toDouble() : 0.0;
    final slng =
        (src.longitude is num) ? (src.longitude as num).toDouble() : 0.0;
    final dlat =
        (dest.latitude is num) ? (dest.latitude as num).toDouble() : 0.0;
    final dlng =
        (dest.longitude is num) ? (dest.longitude as num).toDouble() : 0.0;
    return (slat - dlat).abs() < eps && (slng - dlng).abs() < eps;
  }

  Future<void> clearMap() async {
    await AudioPlayerService.playSound(false);
    // Clear Google Maps markers and polylines
    markers.clear();
    polyLines.clear();
    routePoints.clear();
    update();
  }

  /// Driver pickup nuqtasiga yetib kelganini bildiradi. Customer tomonida
  /// "Haydovchi yetib keldi" state'ini ko'rsatish uchun shu order doc'ga
  /// `status = Constant.orderShipped` yoziladi.
  Future<void> markArrivedAtPickup() async {
    if (currentOrder.value.status != Constant.driverAccepted) {
      ShowToastDialog.showToast(
        "Avval mijozni qabul qiling".tr,
      );
      return;
    }
    final orderId = currentOrder.value.id;
    if (orderId == null || orderId.isEmpty) return;

    ShowToastDialog.showLoader("Please wait".tr);
    try {
      currentOrder.value.status = Constant.orderShipped;
      await FireStoreUtils.setCabOrder(currentOrder.value);
      log("📍 [markArrivedAtPickup] orderShipped yozildi: $orderId");
      update();
      await changeData();
    } catch (e, s) {
      debugPrint("markArrivedAtPickup error: $e");
      debugPrintStack(stackTrace: s);
      ShowToastDialog.showToast(
        "Holatni yangilashda xatolik. Qaytadan urinib ko'ring.".tr,
      );
    } finally {
      ShowToastDialog.closeLoader();
    }
  }

  Future<void> onRideStatus() async {
    if (!_canStartTrip()) {
      ShowToastDialog.showToast("Safarni boshlash uchun noto'g'ri holat".tr);
      return;
    }
    await AudioPlayerService.playSound(false);
    ShowToastDialog.showLoader("Please wait".tr);

    final orderId = currentOrder.value.id;
    if (orderId == null || orderId.isEmpty) {
      ShowToastDialog.closeLoader();
      return;
    }

    double lat = 0.0, lng = 0.0;
    if (Constant.locationDataFinal != null &&
        Constant.locationDataFinal!.latitude != null &&
        Constant.locationDataFinal!.longitude != null) {
      lat = Constant.locationDataFinal!.latitude!;
      lng = Constant.locationDataFinal!.longitude!;
    } else {
      try {
        final loc = await Location().getLocation();
        lat = loc.latitude ?? 0.0;
        lng = loc.longitude ?? 0.0;
      } catch (_) {}
    }
    if (lat == 0.0 && lng == 0.0) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Location not available".tr);
      return;
    }

    await FireStoreUtils.updateCabOrderStartTrip(
      orderId: orderId,
      startLocation: {'latitude': lat, 'longitude': lng},
    );

    currentOrder.value.status = Constant.orderInTransit;
    currentOrder.value.startLocation =
        DestinationLocation(latitude: lat, longitude: lng);
    currentOrder.value.accumulatedDistance = 0.0;
    currentOrder.value.isTracking = true;
    currentOrder.value.finalFare = null;
    currentOrder.value.finalDistance = null;
    currentOrder.value.extraKm = null;
    currentOrder.value.extraCharge = null;
    _lastTrackedLatLng = location.LatLng(lat, lng);
    _accumulatedKm = 0.0;
    _startTrackingTimer();

    // Firestore va UI bir xil holatda qolishi uchun to'liq order yozamiz (bitta nuqtada "Mijozni olish" qayt chiqishining oldini olish)
    await FireStoreUtils.setCabOrder(currentOrder.value);

    ShowToastDialog.closeLoader();
    Get.back();
    log("🚗 [onRideStatus] Safar boshlandi, finalFare tozalandi – Manzilga yetib keldik tugmasi ko'rinadi");
    update();
    await changeData();
  }

  void _startTrackingTimer() {
    _stopTrackingTimer();
    _trackingTimer =
        Timer.periodic(const Duration(seconds: 12), (_) => _onTrackingTick());
    log("📍 [Cab] Tracking timer started, interval 12s");
  }

  Future<void> _onTrackingTick() async {
    final orderId = currentOrder.value.id;
    if (orderId == null ||
        orderId.isEmpty ||
        currentOrder.value.isTracking != true) {
      _stopTrackingTimer();
      return;
    }
    // Manzilga yetib keldik bosilgandan keyin narx hisoblashdan to'xtatamiz
    if (currentOrder.value.finalFare != null) {
      _stopTrackingTimer();
      return;
    }

    double lat = 0.0, lng = 0.0;
    if (Constant.locationDataFinal != null &&
        Constant.locationDataFinal!.latitude != null &&
        Constant.locationDataFinal!.longitude != null) {
      lat = Constant.locationDataFinal!.latitude!;
      lng = Constant.locationDataFinal!.longitude!;
    } else {
      try {
        final loc = await Location().getLocation();
        lat = loc.latitude ?? 0.0;
        lng = loc.longitude ?? 0.0;
      } catch (_) {
        return;
      }
    }
    if (lat == 0.0 && lng == 0.0) return;

    final current = location.LatLng(lat, lng);
    if (_lastTrackedLatLng != null) {
      final segmentM = Geolocator.distanceBetween(
        _lastTrackedLatLng!.latitude,
        _lastTrackedLatLng!.longitude,
        lat,
        lng,
      );
      _accumulatedKm += segmentM / 1000.0;
    }
    _lastTrackedLatLng = current;

    final order = currentOrder.value;
    double? currentFare;
    double? extraKm;
    double? extraCharge;
    if (isSinglePointOrder) {
      final includedKm = _safeKmOrFare(
        order.cabIncludedKm,
        order.vehicleType?.minimum_delivery_charges_within_km,
        0.0,
      );
      final extraKmFare = _safeKmOrFare(
        order.cabExtraKmFare,
        order.vehicleType?.delivery_charges_per_km,
        0.0,
      );
      extraKm = _accumulatedKm > includedKm ? _accumulatedKm - includedKm : 0.0;
      extraCharge = extraKm * extraKmFare;
      final minFare =
          _safeKmOrFare(null, order.vehicleType?.minimum_delivery_charges, 0.0);
      // Bitta nuqtada: narx = chaqiruv narxi + yurgan yo'l to'lovi (yaxlitlangan)
      currentFare = minFare + Constant.roundUpToNearest500(extraCharge);
      log(
        "📍 [Cab] Tick metered orderId=$orderId km=${_accumulatedKm.toStringAsFixed(3)} fare=$currentFare extraKm=$extraKm",
      );
    } else {
      // Ikki nuqtali safarda narx fixed: faqat masofa/lokatsiya track qilinadi.
      log(
        "📍 [Cab] Tick fixed orderId=$orderId km=${_accumulatedKm.toStringAsFixed(3)}",
      );
    }

    Map<String, dynamic>? driverMap;
    if (order.driver != null) {
      driverMap = order.driver!.toJson();
      driverMap['currentLocation'] = {'latitude': lat, 'longitude': lng};
    }

    await FireStoreUtils.updateCabOrderTracking(
      orderId: orderId,
      accumulatedDistance: _accumulatedKm,
      lat: lat,
      lng: lng,
      driverWithCurrentLocation: driverMap,
      subTotal: currentFare,
      extraKm: extraKm,
      extraCharge: extraCharge,
    );
    // Driver heartbeat — lets the customer app render a "driver online"
    // indicator and is useful for stuck-ride detection on the server.
    unawaited(
      FirebaseFirestore.instance
          .collection('cab_booking_orders')
          .doc(orderId)
          .set({'driverActiveAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true))
          .catchError((e) {
        log('[Cab] heartbeat failed: $e');
      }),
    );
    // Persist accumulated km in case the driver app is killed mid-ride.
    unawaited(
      Preferences.setDouble(Preferences.lastAccumulatedKm, _accumulatedKm),
    );
    currentOrder.value.accumulatedDistance = _accumulatedKm;
    if (currentFare != null) {
      currentOrder.value.subTotal = currentFare.toString();
    }
    currentOrder.value.lastLocation =
        DestinationLocation(latitude: lat, longitude: lng);
    update();
  }

  /// vehicle_type da NaN bo'lsa ham xavfsiz: Comfort va boshqa typelar uchun
  static double _safeKmOrFare(double? fromOrder, num? fromVehicle, double def) {
    if (fromOrder != null && !fromOrder.isNaN && !fromOrder.isInfinite) {
      return fromOrder;
    }
    if (fromVehicle != null) {
      final d = fromVehicle.toDouble();
      if (!d.isNaN && !d.isInfinite) return d;
    }
    return def;
  }

  /// UI da "Tekin yurish" km (NaN bo'lmasligi uchun)
  double get displayIncludedKm => _safeKmOrFare(
        currentOrder.value.cabIncludedKm,
        currentOrder.value.vehicleType?.minimum_delivery_charges_within_km,
        0.0,
      );

  /// Zakaz summasi kamida minimum_delivery_charges (1 so'm xato ko'rinishini oldini olish)
  double get minimumCabFare => _safeKmOrFare(
        null,
        currentOrder.value.vehicleType?.minimum_delivery_charges,
        0.0,
      );

  /// UI: Chaqiruv narxi (minimum tarif)
  double get displayCallOutFee => minimumCabFare;

  /// UI: Yurgan yo'l to'lovi (yaxlitlangan). finalFare bo'lsa finalFare - chaqiruv, aks holda joriy extraCharge yaxlitlangan
  double get displayDistanceFareRounded {
    final minF = minimumCabFare;
    final ff = currentOrder.value.finalFare;
    if (ff != null) {
      final distancePart = ff - minF;
      return distancePart > 0
          ? Constant.roundUpToNearest500(distancePart)
          : 0.0;
    }
    final extraCh = currentOrder.value.extraCharge ?? 0.0;
    return Constant.roundUpToNearest500(extraCh);
  }

  /// UI: Mijoz to'lovi (umumiy). finalFare bo'lsa shu; bitta nuqtada har doim chaqiruv + yurgan to'lovi
  double get displayCustomerTotal {
    final ff = currentOrder.value.finalFare;
    if (ff != null) return ff;
    // Bitta nuqtada: joriy ko'rsatish = chaqiruv narxi + yurgan yo'l to'lovi (order.subTotal eski booking dan bo'lishi mumkin)
    if (isSinglePointOrder) {
      return displayCallOutFee + displayDistanceFareRounded;
    }
    final st = double.tryParse(currentOrder.value.subTotal ?? '0') ?? 0.0;
    final minF = minimumCabFare;
    return st < minF ? minF : st;
  }

  /// Bir nuqtali zakazda: "Manzilga yetib keldik" – faqat summa yangilanadi, mijoz to‘lovi ko‘rinadi
  Future<bool> markReachedDestination() async {
    try {
      if (!_canReachDestination()) {
        ShowToastDialog.showToast("Manzilga yetish holati noto'g'ri".tr);
        return false;
      }
      final order = currentOrder.value;
      if (order.id == null || order.id!.isEmpty) {
        log("⚠️ [Cab] markReachedDestination: orderId empty");
        return false;
      }

      final totalDistance = order.accumulatedDistance ?? _accumulatedKm;
      final baseSubTotal = double.tryParse(order.subTotal ?? '0') ?? 0.0;
      final minFare =
          _safeKmOrFare(null, order.vehicleType?.minimum_delivery_charges, 0.0);
      double extraKm;
      double extraCharge;
      // Bitta nuqtada: finalFare = chaqiruv narxi + yurgan yo'l to'lovi (yaxlitlangan), ikki nuqtada fixed fare.
      double finalFare;
      if (isSinglePointOrder) {
        final includedKm = _safeKmOrFare(
          order.cabIncludedKm,
          order.vehicleType?.minimum_delivery_charges_within_km,
          0.0,
        );
        final extraKmFare = _safeKmOrFare(
          order.cabExtraKmFare,
          order.vehicleType?.delivery_charges_per_km,
          0.0,
        );
        extraKm =
            totalDistance > includedKm ? totalDistance - includedKm : 0.0;
        extraCharge = extraKm * extraKmFare;
        finalFare = minFare + Constant.roundUpToNearest500(extraCharge);
      } else {
        finalFare = baseSubTotal < minFare ? minFare : baseSubTotal;
        extraKm = 0.0;
        extraCharge = 0.0;
      }

      log("📍 [Cab] markReachedDestination orderId=${order.id} totalKm=$totalDistance finalFare=$finalFare extraKm=$extraKm");

      final ok = await FireStoreUtils.updateCabOrderReachedDestination(
        orderId: order.id!,
        finalDistance: totalDistance,
        finalFare: finalFare,
        extraKm: extraKm,
        extraCharge: extraCharge,
      );
      if (!ok) {
        log("⚠️ [Cab] markReachedDestination Firestore update failed");
        return false;
      }

      order.finalDistance = totalDistance;
      order.finalFare = finalFare;
      order.extraKm = extraKm;
      order.extraCharge = extraCharge;
      order.subTotal = finalFare.toString();
      _stopTrackingTimer();
      update();

      final token = order.author?.fcmToken?.trim();
      if (token != null && token.isNotEmpty) {
        await SendNotification.sendOneNotification(
          token: token,
          title: "Manzilga yetib kelingan".tr,
          body: "Hozir to'lov qilish".tr,
          payload: {
            'type': 'cab_reached_destination',
            'rideId': order.id ?? ''
          },
        );
        log("📍 [Cab] Sent FCM to customer: Hozir to'lov qilish");
      }
      return true;
    } catch (e) {
      log("Error in markReachedDestination(): $e");
      return false;
    }
  }

  Future<void> completeRide() async {
    try {
      if (!_canCompleteRide()) {
        ShowToastDialog.showToast("Safarni yakunlash uchun noto'g'ri holat".tr);
        return;
      }
      _stopTrackingTimer();

      ShowToastDialog.showLoader("Please wait".tr);

      final order = currentOrder.value;
      final totalDistance = order.accumulatedDistance ?? _accumulatedKm;

      double finalFare;
      double extraKm;
      double extraCharge;

      final minFare =
          _safeKmOrFare(null, order.vehicleType?.minimum_delivery_charges, 0.0);
      if (order.finalFare != null && order.finalDistance != null) {
        finalFare = order.finalFare!;
        extraKm = order.extraKm ?? 0.0;
        extraCharge = order.extraCharge ?? 0.0;
      } else {
        if (isSinglePointOrder) {
          final includedKm = _safeKmOrFare(
            order.cabIncludedKm,
            order.vehicleType?.minimum_delivery_charges_within_km,
            0.0,
          );
          final extraKmFare = _safeKmOrFare(
            order.cabExtraKmFare,
            order.vehicleType?.delivery_charges_per_km,
            0.0,
          );
          extraKm = totalDistance > includedKm ? totalDistance - includedKm : 0.0;
          extraCharge = extraKm * extraKmFare;
          finalFare = minFare + Constant.roundUpToNearest500(extraCharge);
        } else {
          final subTotal = double.tryParse(order.subTotal ?? '0') ?? 0.0;
          finalFare = subTotal < minFare ? minFare : subTotal;
          extraKm = 0.0;
          extraCharge = 0.0;
        }
      }

      if (order.id != null && order.id!.isNotEmpty) {
        await FireStoreUtils.updateCabOrderEndTrip(
          orderId: order.id!,
          finalDistance: totalDistance,
          finalFare: finalFare,
          extraKm: extraKm,
          extraCharge: extraCharge,
        );
      }

      order.finalDistance = totalDistance;
      order.finalFare = finalFare;
      order.extraKm = extraKm;
      order.extraCharge = extraCharge;
      order.subTotal = finalFare.toString();
      order.status = Constant.orderCompleted;

      await updateCabWalletAmount(order);

      await FireStoreUtils.getFirestOrderOrNOtCabService(order)
          .then((value) async {
        if (value == true) {
          await FireStoreUtils.updateReferralAmountCabService(order);
        }
      });

      driverModel.value.inProgressOrderID = [];
      driverModel.value.orderCabRequestData = null;
      await FireStoreUtils.setCabOrder(order);
      await FireStoreUtils.updateUser(driverModel.value);

      currentOrder.value = CabOrderModel();
      await clearMap();
      source.value = location.LatLng(0.0, 0.0);
      destination.value = location.LatLng(0.0, 0.0);
      await updateGoogleMarkers();
      _startPendingOrderPoll();
      // Ride is finished — drop the persisted resume pointer.
      await Preferences.clearKeyData(Preferences.lastActiveRideId);
      await Preferences.clearKeyData(Preferences.lastAccumulatedKm);
      update();

      ShowToastDialog.closeLoader();
    } catch (e) {
      ShowToastDialog.closeLoader();
      log("Error in completeRide(): $e");
    }
  }

  Future<void> updateCabWalletAmount(CabOrderModel orderModel) async {
    try {
      double totalTax = 0.0;
      double discount = 0.0;
      double subTotal = 0.0;
      double adminComm = 0.0;
      double totalAmount = 0.0;

      subTotal = double.tryParse(orderModel.subTotal ?? '0.0') ?? 0.0;
      discount = double.tryParse(orderModel.discount ?? '0.0') ?? 0.0;

      if (orderModel.taxSetting != null) {
        for (var element in orderModel.taxSetting!) {
          totalTax += Constant.calculateTax(
              amount: subTotal.toString(), taxModel: element);
        }
      }

      if ((orderModel.adminCommission ?? '').isNotEmpty) {
        adminComm = Constant.calculateAdminCommission(
            amount: (subTotal - discount).toString(),
            adminCommissionType: orderModel.adminCommissionType.toString(),
            adminCommission: orderModel.adminCommission ?? '0');
      }
      totalAmount = (subTotal + totalTax) - discount;

      final ownerId = orderModel.driver?.ownerId;
      final userIdForWallet = (ownerId != null && ownerId.isNotEmpty)
          ? ownerId
          : FireStoreUtils.getCurrentUid();

      if (orderModel.paymentMethod.toString() != PaymentGateway.cod.name) {
        WalletTransactionModel transactionModel = WalletTransactionModel(
            id: Constant.getUuid(),
            amount: totalAmount,
            date: Timestamp.now(),
            paymentMethod: orderModel.paymentMethod ?? '',
            transactionUser: "driver",
            userId: userIdForWallet,
            isTopup: true,
            orderId: orderModel.id,
            note: "Booking amount credited",
            paymentStatus: "success");

        final setTx =
            await FireStoreUtils.setWalletTransaction(transactionModel);
        if (setTx == true) {
          await FireStoreUtils.updateUserWallet(
              amount: totalAmount.toString(), userId: userIdForWallet);
        }
      }

      WalletTransactionModel adminTx = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: adminComm,
          date: Timestamp.now(),
          paymentMethod: orderModel.paymentMethod ?? '',
          transactionUser: "driver",
          userId: userIdForWallet,
          isTopup: false,
          orderId: orderModel.id,
          note: "Admin commission deducted",
          paymentStatus: "success");

      final setAdmin = await FireStoreUtils.setWalletTransaction(adminTx);
      if (setAdmin == true) {
        await FireStoreUtils.updateUserWallet(
            amount: "-${adminComm.toString()}", userId: userIdForWallet);
      }
    } catch (e) {
      log("Error in updateCabWalletAmount(): $e");
    }
  }

  Future<void> getCurrentOrder() async {
    try {
      print("📦 [getCurrentOrder] getCurrentOrder chaqirildi");

      final inProgress = driverModel.value.inProgressOrderID;
      print("📦 [getCurrentOrder] inProgressOrderID: $inProgress");

      if (inProgress != null && inProgress.isNotEmpty) {
        _stopPendingOrderPoll();
        final String id = inProgress.first.toString();
        // Idempotency: if we're already subscribed to this order doc, do not
        // cancel + re-create the subscription. Re-subscribing replays the
        // initial snapshot which retriggers `_handleOrderDoc` →
        // `changeData()` → alert tone for the same order.
        if (_subscribedOrderId == id && _orderDocSub != null) {
          print("📦 [getCurrentOrder] already subscribed to $id, skip");
          return;
        }
        await _orderDocSub?.cancel();
        await _orderQuerySub?.cancel();
        print("📦 [getCurrentOrder] inProgress order topildi, ID: $id");
        _subscribedOrderId = id;
        _orderDocSub = FireStoreUtils.fireStore
            .collection(CollectionName.cabBookingOrders)
            .doc(id)
            .snapshots()
            .listen((docSnap) => _handleOrderDoc(docSnap, id));
        return;
      }

      final pendingRequest = driverModel.value.orderCabRequestData;
      print("📦 [getCurrentOrder] orderCabRequestData: ${pendingRequest?.id}");
      print(
          "📦 [getCurrentOrder] orderCabRequestData status: ${pendingRequest?.status}");

      if (pendingRequest != null) {
        final id = pendingRequest.id?.toString();
        if (id != null && id.isNotEmpty) {
          _stopPendingOrderPoll();
          if (_subscribedOrderId == id && _orderDocSub != null) {
            print(
                "📦 [getCurrentOrder] already subscribed to pending $id, skip");
            return;
          }
          await _orderDocSub?.cancel();
          await _orderQuerySub?.cancel();
          print(
              "📦 [getCurrentOrder] orderCabRequestData dan order topildi, ID: $id");
          _subscribedOrderId = id;
          _orderDocSub = FireStoreUtils.fireStore
              .collection(CollectionName.cabBookingOrders)
              .doc(id)
              .snapshots()
              .listen((docSnap) => _handleOrderDoc(docSnap, id));
          return;
        } else {
          print("📦 [getCurrentOrder] orderCabRequestData.id null yoki bo'sh");
        }
      } else {
        print("📦 [getCurrentOrder] orderCabRequestData null");
      }

      // Fallback 1: Haydovchiga biriktirilgan aktiv orderlarni tekshirish
      await _queryActiveAssignedOrderForDriver();
      if (currentOrder.value.id != null && currentOrder.value.id!.isNotEmpty) {
        _stopPendingOrderPoll();
        print(
            "📦 [getCurrentOrder] Assigned active order topildi: ${currentOrder.value.id}, status: ${currentOrder.value.status}");
        return;
      }

      // Fallback: Query for pending orders that might be assigned to this driver
      // This helps when notification arrives before driver document is updated
      print("📦 [getCurrentOrder] Fallback query chaqirilmoqda...");
      await _queryPendingOrdersForDriver();

      // Only clear if we still don't have an order after fallback query
      print(
          "📦 [getCurrentOrder] currentOrder.value.id: ${currentOrder.value.id}");
      if (currentOrder.value.id == null || currentOrder.value.id!.isEmpty) {
        print(
            "📦 [getCurrentOrder] Order topilmadi, clearMap va pending poll boshlandi");
        _subscribedOrderId = null;
        await _orderDocSub?.cancel();
        await _orderQuerySub?.cancel();
        _orderDocSub = null;
        _orderQuerySub = null;
        _lastAlertedOrderId = null;
        _lastAlertedStatus = null;
        currentOrder.value = CabOrderModel();
        await clearMap();
        await AudioPlayerService.playSound(false);
        _startPendingOrderPoll();
        update();
      } else {
        _stopPendingOrderPoll();
        print(
            "📦 [getCurrentOrder] Order topildi: ${currentOrder.value.id}, status: ${currentOrder.value.status}");
      }
    } catch (e) {
      print("📦 [getCurrentOrder] Xatolik: $e");
      log("getCurrentOrder() error: $e");
    }
  }

  Future<void> _queryActiveAssignedOrderForDriver() async {
    try {
      final driverId = driverModel.value.id?.toString().trim() ?? '';
      if (driverId.isEmpty) return;

      final querySnapshot = await FireStoreUtils.fireStore
          .collection(CollectionName.cabBookingOrders)
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: [
        Constant.driverAccepted,
        Constant.orderShipped,
        Constant.orderInTransit,
      ]).limit(10).get();

      if (querySnapshot.docs.isEmpty) return;

      final sortedDocs = [...querySnapshot.docs]..sort((a, b) {
          final aCreated = (a.data()['createdAt'] as Timestamp?);
          final bCreated = (b.data()['createdAt'] as Timestamp?);
          final aMs = aCreated?.millisecondsSinceEpoch ?? 0;
          final bMs = bCreated?.millisecondsSinceEpoch ?? 0;
          return bMs.compareTo(aMs);
        });
      final doc = sortedDocs.first;
      final order = CabOrderModel.fromJson(doc.data());
      final id = order.id?.toString().trim() ?? doc.id;
      if (id.isEmpty) return;

      if (_subscribedOrderId == id && _orderDocSub != null) return;
      await _orderDocSub?.cancel();
      _subscribedOrderId = id;
      _orderDocSub = FireStoreUtils.fireStore
          .collection(CollectionName.cabBookingOrders)
          .doc(doc.id)
          .snapshots()
          .listen((docSnap) => _handleOrderDoc(docSnap, id));
    } catch (e) {
      print("🔍 [_queryActiveAssignedOrderForDriver] Xatolik: $e");
      log("_queryActiveAssignedOrderForDriver() error: $e");
    }
  }

  Future<void> _queryPendingOrdersForDriver() async {
    try {
      print("🔍 [_queryPendingOrdersForDriver] Fallback query boshlandi");
      final driverId = driverModel.value.id;
      print("🔍 [_queryPendingOrdersForDriver] driverId: $driverId");

      if (driverId == null || driverId.isEmpty) {
        print(
            "🔍 [_queryPendingOrdersForDriver] driverId null yoki bo'sh, return");
        return;
      }

      // Faqat 5 daqiqa ichidagi pending zakazlar ko'rsatiladi.
      final recentOrdersSince = Timestamp.fromDate(
          DateTime.now().subtract(_driverAcceptTimeout));
      print(
          "🔍 [_queryPendingOrdersForDriver] recentOrdersSince: $recentOrdersSince");

      final sectionId = driverModel.value.sectionId;
      print("🔍 [_queryPendingOrdersForDriver] sectionId: $sectionId");

      // Build query - use simpler query to avoid index requirements
      // Query by status and createdAt, filter sectionId in memory if needed
      Query<Map<String, dynamic>> query = FireStoreUtils.fireStore
          .collection(CollectionName.cabBookingOrders)
          .where('status', isEqualTo: Constant.driverPending)
          .where('createdAt', isGreaterThanOrEqualTo: recentOrdersSince)
          .orderBy('createdAt', descending: true)
          .limit(10);

      print("🔍 [_queryPendingOrdersForDriver] Query yuborilmoqda...");
      final querySnapshot = await query.get();
      print(
          "🔍 [_queryPendingOrdersForDriver] Query natijasi: ${querySnapshot.docs.length} ta order");

      if (querySnapshot.docs.isNotEmpty) {
        // Check each order to see if it might be for this driver
        for (var doc in querySnapshot.docs) {
          final orderData = doc.data();
          final order = CabOrderModel.fromJson(orderData);
          print(
              "🔍 [_queryPendingOrdersForDriver] Order topildi: ${order.id}, status: ${order.status}, sectionId: ${order.sectionId}");

          if (_isPendingDriverAcceptance(order) && _isOrderExpired(order)) {
            print(
                "🔍 [_queryPendingOrdersForDriver] Order eskirgan (>5 min), o'tkazib yuborilmoqda");
            continue;
          }

          // Check if driver hasn't rejected this order
          final rejectedBy = order.rejectedByDrivers ?? [];
          if (rejectedBy.contains(driverId)) {
            print(
                "🔍 [_queryPendingOrdersForDriver] Order rad etilgan, o'tkazib yuborilmoqda");
            continue; // Skip rejected orders
          }

          // Check if order matches driver's section (if driver has one)
          if (sectionId != null && sectionId.isNotEmpty) {
            if (order.sectionId != sectionId) {
              print(
                  "🔍 [_queryPendingOrdersForDriver] Order sectionId mos kelmaydi, o'tkazib yuborilmoqda");
              continue; // Skip orders from different sections
            }
          }

          // Faqat haydovchining mashina turiga (vehicleId) mos zakazlarni ko'rsatish (masalan Comfort)
          final orderVid = order.vehicleId?.toString().trim() ?? '';
          final driverVid = driverModel.value.vehicleId?.toString().trim() ?? '';
          if (orderVid.isNotEmpty && driverVid.isNotEmpty && orderVid != driverVid) {
            print(
                "🔍 [_queryPendingOrdersForDriver] Order vehicleId ($orderVid) haydovchi vehicleId ($driverVid) ga mos kelmaydi, o'tkazib yuborilmoqda");
            continue;
          }

          // This might be the order for this driver
          print(
              "🔍 [_queryPendingOrdersForDriver] Potensial order topildi: ${order.id}");
          log("Found potential pending order: ${order.id}, sectionId: ${order.sectionId}");
          // Listen to this order document
          final id = order.id;
          if (id != null && id.isNotEmpty) {
            if (_subscribedOrderId == id && _orderDocSub != null) return;
            print(
                "🔍 [_queryPendingOrdersForDriver] Order document listener o'rnatilmoqda: $id");
            await _orderDocSub?.cancel();
            _subscribedOrderId = id;
            _orderDocSub = FireStoreUtils.fireStore
                .collection(CollectionName.cabBookingOrders)
                .doc(id)
                .snapshots()
                .listen((docSnap) => _handleOrderDoc(docSnap, id));
            return;
          }
        }
        print(
            "🔍 [_queryPendingOrdersForDriver] Hech qanday mos order topilmadi");
      } else {
        print("🔍 [_queryPendingOrdersForDriver] Query natijasi bo'sh");
      }
    } catch (e) {
      print("🔍 [_queryPendingOrdersForDriver] Xatolik: $e");
      log("_queryPendingOrdersForDriver() error: $e");
      // If query fails (e.g., missing index), silently continue
      // The driver document stream will eventually update and trigger getCurrentOrder()
    }
  }

  /// Notification dan kelgan rideId orqali order ni to'g'ridan-to'g'ri o'qib olish
  /// Retry logic bilan Firestore UNAVAILABLE xatolarini handle qiladi
  Future<void> getOrderByRideId(String rideId, {int maxRetries = 5}) async {
    if (rideId.isEmpty) {
      print("🚀 [getOrderByRideId] rideId bo'sh");
      return;
    }

    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        attempt++;
        print(
            "🚀 [getOrderByRideId] rideId: $rideId, attempt: $attempt/$maxRetries");

        // Avval document ID sifatida sinab ko'ramiz
        final docRef = FireStoreUtils.fireStore
            .collection(CollectionName.cabBookingOrders)
            .doc(rideId);

        final docSnap = await docRef.get().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException("Firestore get() timeout");
          },
        );

        if (docSnap.exists && docSnap.data() != null) {
          print("🚀 [getOrderByRideId] Document topildi (doc ID orqali)");
          final order = CabOrderModel.fromJson(docSnap.data()!);
          print(
              "🚀 [getOrderByRideId] Order ID: ${order.id}, status: ${order.status}");

          // Agar order topilsa, listener o'rnatamiz
          if (_subscribedOrderId == rideId && _orderDocSub != null) {
            print("🚀 [getOrderByRideId] already subscribed to $rideId, skip");
            return;
          }
          await _orderDocSub?.cancel();
          _subscribedOrderId = rideId;
          _orderDocSub = docRef
              .snapshots()
              .listen((snap) => _handleOrderDoc(snap, rideId));
          return;
        }

        // Agar document ID orqali topilmasa, 'id' field orqali qidiramiz
        print(
            "🚀 [getOrderByRideId] Document ID orqali topilmadi, 'id' field orqali qidiryapmiz");
        final querySnapshot = await FireStoreUtils.fireStore
            .collection(CollectionName.cabBookingOrders)
            .where('id', isEqualTo: rideId)
            .limit(1)
            .get()
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException("Firestore query() timeout");
          },
        );

        if (querySnapshot.docs.isNotEmpty) {
          print("🚀 [getOrderByRideId] Query orqali order topildi");
          final doc = querySnapshot.docs.first;
          final order = CabOrderModel.fromJson(doc.data());
          print(
              "🚀 [getOrderByRideId] Order ID: ${order.id}, status: ${order.status}");

          // Listener o'rnatamiz
          final docId = doc.id;
          if (_subscribedOrderId == docId && _orderDocSub != null) return;
          await _orderDocSub?.cancel();
          _subscribedOrderId = docId;
          _orderDocSub = FireStoreUtils.fireStore
              .collection(CollectionName.cabBookingOrders)
              .doc(docId)
              .snapshots()
              .listen((snap) => _handleOrderDoc(snap, docId));
          return;
        } else {
          print("🚀 [getOrderByRideId] Order topilmadi, rideId: $rideId");
          // Agar order topilmasa, retry qilmaymiz
          return;
        }
      } catch (e) {
        final errorStr = e.toString();
        final isUnavailable = errorStr.contains('unavailable') ||
            errorStr.contains('UNAVAILABLE') ||
            errorStr.contains('UNAUTHENTICATED');

        print(
            "🚀 [getOrderByRideId] Xatolik (attempt $attempt/$maxRetries): $e");
        log("getOrderByRideId() error (attempt $attempt/$maxRetries): $e");

        if (isUnavailable && attempt < maxRetries) {
          // Exponential backoff: 1s, 2s, 4s, 8s, 16s
          final delaySeconds = 1 << (attempt - 1);
          print(
              "🚀 [getOrderByRideId] Retry $attempt/$maxRetries dan keyin $delaySeconds sekund kutamiz...");
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        } else {
          // Agar retry limit yoki boshqa xatolik bo'lsa, to'xtatamiz
          print("🚀 [getOrderByRideId] Retry tugadi yoki boshqa xatolik");
          log("getOrderByRideId() failed after $attempt attempts: $e");
          return;
        }
      }
    }
  }

  bool _isOrderAssignedToAnotherDriver(CabOrderModel order) {
    final assignedDriverId = order.driverId?.toString().trim() ?? '';
    if (assignedDriverId.isEmpty) return false;
    final currentDriverId =
        (driverModel.value.id?.toString().trim().isNotEmpty == true)
            ? driverModel.value.id!.toString().trim()
            : FireStoreUtils.getCurrentUid();
    return currentDriverId.isNotEmpty && assignedDriverId != currentDriverId;
  }

  Future<void> _releaseStaleOrderIfAssignedToAnotherDriver(
    CabOrderModel order,
  ) async {
    if (!_isOrderAssignedToAnotherDriver(order)) return;

    final orderId = order.id?.toString() ?? '';
    print(
      "📄 [staleOrder] Order boshqa haydovchiga biriktirilgan. orderId=$orderId, driverId=${order.driverId}",
    );

    driverModel.value.orderCabRequestData = null;
    driverModel.value.inProgressOrderID ??= [];
    if (orderId.isNotEmpty) {
      driverModel.value.inProgressOrderID!
          .removeWhere((e) => e.toString() == orderId);
    }
    await FireStoreUtils.updateUser(driverModel.value);

    currentOrder.value = CabOrderModel();
    await clearMap();
    _startPendingOrderPoll();
    update();
  }

  Future<void> _handleOrderDoc(
      DocumentSnapshot<Map<String, dynamic>> docSnap, String id) async {
    try {
      print("📄 [_handleOrderDoc] Order document yangilandi, ID: $id");
      print("📄 [_handleOrderDoc] docSnap.exists: ${docSnap.exists}");

      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null) {
          final previousStatus = currentOrder.value.status;
          final nextStatus = data['status']?.toString();
          if (!_isAllowedTransition(previousStatus, nextStatus)) {
            print(
                "📄 [_handleOrderDoc] Noto'g'ri transition e'tiborsiz qoldirildi: $previousStatus -> $nextStatus");
            return;
          }
          currentOrder.value = CabOrderModel.fromJson(data);
          await _releaseStaleOrderIfAssignedToAnotherDriver(currentOrder.value);
          if (currentOrder.value.id == null || currentOrder.value.id!.isEmpty) {
            return;
          }
          if (_isPendingDriverAcceptance(currentOrder.value) &&
              _isOrderExpired(currentOrder.value)) {
            print(
                "📄 [_handleOrderDoc] Pending order eskirgan (>5 min), ko'rsatilmaydi");
            currentOrder.value = CabOrderModel();
            await clearMap();
            source.value = location.LatLng(0.0, 0.0);
            destination.value = location.LatLng(0.0, 0.0);
            await updateGoogleMarkers();
            _startPendingOrderPoll();
            update();
            return;
          }
          // Zakaz faqat haydovchi mashina turiga (vehicleId) mos bo'lsa ko'rsatiladi (masalan Comfort)
          final orderVid = currentOrder.value.vehicleId?.toString().trim() ?? '';
          final driverVid = driverModel.value.vehicleId?.toString().trim() ?? '';
          if (orderVid.isNotEmpty && driverVid.isNotEmpty && orderVid != driverVid) {
            print("📄 [_handleOrderDoc] Order vehicleId ($orderVid) haydovchiga mos emas ($driverVid), o'tkazib yuborilmoqda");
            currentOrder.value = CabOrderModel();
            _startPendingOrderPoll();
            update();
            return;
          }
          print("📄 [_handleOrderDoc] currentOrder yangilandi");
          print("📄 [_handleOrderDoc] Order ID: ${currentOrder.value.id}");
          print(
              "📄 [_handleOrderDoc] Order status: ${currentOrder.value.status}");
          print(
              "📄 [_handleOrderDoc] shouldShowOrderSheet: $shouldShowOrderSheet");

          _stopPendingOrderPoll();
          await changeData();
          if (currentOrder.value.status == Constant.orderCompleted) {
            print("📄 [_handleOrderDoc] Order completed, tozalash");
            _stopTrackingTimer();
            driverModel.value.inProgressOrderID = [];
            await FireStoreUtils.updateUser(driverModel.value);
            _subscribedOrderId = null;
            _lastAlertedOrderId = null;
            _lastAlertedStatus = null;
            currentOrder.value = CabOrderModel();
            await clearMap();
            source.value = location.LatLng(0.0, 0.0);
            destination.value = location.LatLng(0.0, 0.0);
            await updateGoogleMarkers();
            _startPendingOrderPoll();
            await AudioPlayerService.playSound(false);
            update();
            return;
          } else if (currentOrder.value.status == Constant.orderRejected ||
              currentOrder.value.status == Constant.orderCancelled) {
            print("📄 [_handleOrderDoc] Order rejected/cancelled, tozalash");
            // Customer atkaz qilganda va driver allaqachon qabul qilgan bo'lsa
            // qisqa ogohlantirish ovozi chalar
            final wasCancelledByCustomer =
                currentOrder.value.status == Constant.orderCancelled &&
                currentOrder.value.driverId == driverModel.value.id;
            driverModel.value.inProgressOrderID = [];
            driverModel.value.orderCabRequestData = null;
            await FireStoreUtils.updateUser(driverModel.value);
            _subscribedOrderId = null;
            _lastAlertedOrderId = null;
            _lastAlertedStatus = null;
            currentOrder.value = CabOrderModel();
            await clearMap();
            source.value = location.LatLng(0.0, 0.0);
            destination.value = location.LatLng(0.0, 0.0);
            await updateGoogleMarkers();
            _startPendingOrderPoll();
            await AudioPlayerService.playSound(false);
            if (wasCancelledByCustomer) {
              unawaited(AudioPlayerService.playCancellationSound());
            }
            update();
            return;
          }
          print(
              "📄 [_handleOrderDoc] Order yangilandi, update() chaqirilmoqda");
          update();
          return;
        } else {
          print("📄 [_handleOrderDoc] data null");
        }
      } else {
        print("📄 [_handleOrderDoc] Document mavjud emas, query fallback");
      }
      _orderQuerySub = FireStoreUtils.fireStore
          .collection(CollectionName.cabBookingOrders)
          .where('id', isEqualTo: id)
          .limit(1)
          .snapshots()
          .listen((qSnap) => _handleOrderQuery(qSnap));
    } catch (e) {
      print("📄 [_handleOrderDoc] Xatolik: $e");
      log("Error listening to order doc: $e");
    }
  }

  Future<void> _handleOrderQuery(
      QuerySnapshot<Map<String, dynamic>> qSnap) async {
    try {
      if (qSnap.docs.isNotEmpty) {
        final doc = qSnap.docs.first;
        final data = doc.data();
        final previousStatus = currentOrder.value.status;
        final nextStatus = data['status']?.toString();
        if (!_isAllowedTransition(previousStatus, nextStatus)) {
          print(
              "📄 [_handleOrderQuery] Noto'g'ri transition e'tiborsiz qoldirildi: $previousStatus -> $nextStatus");
          return;
        }
        currentOrder.value = CabOrderModel.fromJson(data);
        await _releaseStaleOrderIfAssignedToAnotherDriver(currentOrder.value);
        if (currentOrder.value.id == null || currentOrder.value.id!.isEmpty) {
          return;
        }
        if (_isPendingDriverAcceptance(currentOrder.value) &&
            _isOrderExpired(currentOrder.value)) {
          currentOrder.value = CabOrderModel();
          await clearMap();
          source.value = location.LatLng(0.0, 0.0);
          destination.value = location.LatLng(0.0, 0.0);
          await updateGoogleMarkers();
          _startPendingOrderPoll();
          update();
          return;
        }
        final orderVid = currentOrder.value.vehicleId?.toString().trim() ?? '';
        final driverVid = driverModel.value.vehicleId?.toString().trim() ?? '';
        if (orderVid.isNotEmpty && driverVid.isNotEmpty && orderVid != driverVid) {
          currentOrder.value = CabOrderModel();
          _startPendingOrderPoll();
          update();
          return;
        }
        await changeData();
        if (currentOrder.value.status == Constant.orderCompleted) {
          driverModel.value.inProgressOrderID = [];
          await FireStoreUtils.updateUser(driverModel.value);
          currentOrder.value = CabOrderModel();
          await clearMap();
          source.value = location.LatLng(0.0, 0.0);
          destination.value = location.LatLng(0.0, 0.0);
          await updateGoogleMarkers();
          _startPendingOrderPoll();
          await AudioPlayerService.playSound(false);
          update();
          return;
        }
        update();
        return;
      } else {
        currentOrder.value = CabOrderModel();
        await AudioPlayerService.playSound(false);
        update();
      }
    } catch (e) {
      log("Error parsing order from query fallback: $e");
    }
  }

  RxBool isChange = false.obs;

  bool _isPendingDriverAcceptance(CabOrderModel order) {
    final status = order.status;
    return status == Constant.orderPlaced ||
        status == Constant.driverPending ||
        status == Constant.driverRejected ||
        (status == Constant.orderAccepted &&
            (order.driverId == null || order.driverId!.isEmpty));
  }

  bool _isOrderExpired(CabOrderModel order) {
    final createdAt = order.createdAt;
    if (createdAt == null) return false;
    final elapsed = DateTime.now().difference(createdAt.toDate());
    return elapsed >= _driverAcceptTimeout;
  }

  Future<void> changeData() async {
    print("🔄 [changeData] changeData chaqirildi");
    print("🔄 [changeData] currentOrder.id: ${currentOrder.value.id}");
    print("🔄 [changeData] currentOrder.status: ${currentOrder.value.status}");
    print("🔄 [changeData] yandex/osrm polyline chizilmoqda");
    await getOSMPolyline();

    // pending_driver_acceptance yoki driverPending statuslarida sound play
    final orderId = currentOrder.value.id;
    final status = currentOrder.value.status;
    // Agar haydovchi orderni qabul qilgan bo'lsa (inProgressOrderID da bor),
    // status hali driverPending ko'rinib qolgan bo'lsa ham ovoz ochilmasin.
    final alreadyAccepted = orderId != null &&
        orderId.isNotEmpty &&
        (driverModel.value.inProgressOrderID?.contains(orderId) ?? false);
    final isPendingStatus = !alreadyAccepted &&
        (status == Constant.driverPending ||
            status == "pending_driver_acceptance");

    if (isPendingStatus) {
      // Idempotency: only play the new-order alert once per (orderId, status)
      // pair. Repeated `changeData()` invocations triggered by driver-doc
      // location pings, listener re-subscribes, or FCM wake-ups must NOT
      // replay the tone for an order the driver has already been alerted
      // about.
      final alreadyAlerted = _lastAlertedOrderId == orderId &&
          _lastAlertedStatus == status &&
          orderId != null &&
          orderId.isNotEmpty;
      if (!alreadyAlerted) {
        print("🔄 [changeData] pending status ($status), sound play");
        _lastAlertedOrderId = orderId;
        _lastAlertedStatus = status;
        await AudioPlayerService.playSound(true);
      } else {
        print(
            "🔄 [changeData] pending status ($status) — already alerted for $orderId, skipping sound");
      }
    } else {
      // Order moved out of the pending window — clear the alert memo so the
      // next pending order is allowed to play its tone.
      _lastAlertedOrderId = null;
      _lastAlertedStatus = null;
      await AudioPlayerService.playSound(false);
    }

    // Update markers after route is drawn
    await updateGoogleMarkers();

    print("🔄 [changeData] changeData tugadi");
  }

  Future<void> _subscribeDriver() async {
    log("👤 [_subscribeDriver] Driver subscription boshlandi");

    _driverSub = FireStoreUtils.fireStore
        .collection(CollectionName.users)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen((event) => _onDriverSnapshot(event));

    if (Constant.userModel != null &&
        Constant.userModel!.ownerId != null &&
        Constant.userModel!.ownerId!.isNotEmpty) {
      log("👤 [_subscribeDriver] Owner subscription boshlandi: ${Constant.userModel!.ownerId}");
      FireStoreUtils.fireStore
          .collection(CollectionName.users)
          .doc(Constant.userModel!.ownerId)
          .snapshots()
          .listen(
        (event) async {
          if (event.exists) {
            ownerModel.value = UserModel.fromJson(event.data()!);
          }
        },
      );
    } else {
      log("👤 [_subscribeDriver] Owner ID yo'q yoki null");
    }
  }

  /// String fingerprint of the driver-doc fields that actually drive order
  /// routing. Used by `_onDriverSnapshot` to skip the `getCurrentOrder()` +
  /// `changeData()` chain when only irrelevant fields (e.g. live `location`)
  /// changed.
  String _computeDriverRoutingSignature() {
    final m = driverModel.value;
    final pending = m.orderCabRequestData?.id?.toString() ?? '';
    final inProgress = (m.inProgressOrderID ?? const [])
        .map((e) => e.toString())
        .toList()
      ..sort();
    final active = (m.isActive == true).toString();
    final section = m.sectionId?.toString() ?? '';
    final vehicle = m.vehicleId?.toString() ?? '';
    return '$pending|${inProgress.join(",")}|$active|$section|$vehicle';
  }

  Future<void> _onDriverSnapshot(
      DocumentSnapshot<Map<String, dynamic>> event) async {
    try {
      print("👤 [_onDriverSnapshot] Driver document yangilandi");
      print("👤 [_onDriverSnapshot] event.exists: ${event.exists}");

      if (event.exists && event.data() != null) {
        driverModel.value = UserModel.fromJson(event.data()!);
        print("👤 [_onDriverSnapshot] driverModel yangilandi");
        print(
            "👤 [_onDriverSnapshot] orderCabRequestData: ${driverModel.value.orderCabRequestData?.id}");
        print(
            "👤 [_onDriverSnapshot] orderCabRequestData status: ${driverModel.value.orderCabRequestData?.status}");
        print(
            "👤 [_onDriverSnapshot] inProgressOrderID: ${driverModel.value.inProgressOrderID}");

        _updateCurrentLocationMarkers();
        if (driverModel.value.id != null) {
          // Oflayn bo'lsa yangi zakaz ko'rsatilmaydi (orderCabRequestData va poll natijalari e'tiborsiz)
          if (driverModel.value.isActive != true &&
              (currentOrder.value.id == null || currentOrder.value.id!.isEmpty)) {
            _lastDriverRoutingSignature = _computeDriverRoutingSignature();
            currentOrder.value = CabOrderModel();
            update();
            return;
          }

          // Driver document churns on every location ping (and on every
          // `ordercabRequestAt: Timestamp.now()` dispatch write). Compute a
          // signature of the fields that actually matter for order routing
          // — only re-run the heavy chain when one of them changes.
          // Location-only updates still flow through `_updateCurrentLocationMarkers()`
          // above so the marker keeps moving.
          final newSignature = _computeDriverRoutingSignature();
          if (_lastDriverRoutingSignature != null &&
              _lastDriverRoutingSignature == newSignature) {
            print(
                "👤 [_onDriverSnapshot] routing signature unchanged, skip chain");
            update();
            return;
          }
          _lastDriverRoutingSignature = newSignature;

          print("👤 [_onDriverSnapshot] getCurrentOrder chaqirilmoqda");
          await getCurrentOrder();
          await changeData();
          if (driverModel.value.sectionId != null &&
              driverModel.value.sectionId!.isNotEmpty) {
            await FireStoreUtils.getSectionBySectionId(
                    driverModel.value.sectionId!)
                .then((sectionValue) {
              if (sectionValue != null) {
                Constant.sectionModel = sectionValue;
              }
            });
          }
          print("👤 [_onDriverSnapshot] update() chaqirilmoqda");
          update();
        } else {
          print("👤 [_onDriverSnapshot] driverModel.value.id null");
        }
      } else {
        print("👤 [_onDriverSnapshot] event.exists false yoki data null");
      }
    } catch (e) {
      print("👤 [_onDriverSnapshot] Xatolik: $e");
      log("getDriver() listener error: $e");
    }
  }

  void _updateCurrentLocationMarkers() async {
    try {
      // ✅ Try to get fresh GPS location first
      try {
        final locationService = Location();
        final freshLocation = await locationService.getLocation();
        if (freshLocation.latitude != null && freshLocation.longitude != null) {
          Constant.locationDataFinal = freshLocation;
          log("📍 _updateCurrentLocationMarkers: Got fresh GPS location: ${freshLocation.latitude}, ${freshLocation.longitude}");
        }
      } catch (e) {
        log("📍 _updateCurrentLocationMarkers: Could not get fresh GPS location: $e");
        // Continue with existing location
      }

      // ✅ ALWAYS prioritize current GPS location over Firestore location
      location.LatLng latLng;

      if (Constant.locationDataFinal != null &&
          Constant.locationDataFinal!.latitude != null &&
          Constant.locationDataFinal!.longitude != null) {
        // Use current GPS location (most accurate and up-to-date)
        latLng = location.LatLng(
          Constant.locationDataFinal!.latitude!,
          Constant.locationDataFinal!.longitude!,
        );
        log("📍 _updateCurrentLocationMarkers: Using current GPS location: ${latLng.latitude}, ${latLng.longitude}");
      } else {
        // Fallback to driverModel.location from Firestore
        final loc = driverModel.value.location;
        latLng = _safeLatLngFromLocation(loc);
        log("📍 _updateCurrentLocationMarkers: Using driverModel.location (fallback): ${latLng.latitude}, ${latLng.longitude}");
      }

      // If still 0,0, use default location (Tashkent)
      if (latLng.latitude == 0.0 && latLng.longitude == 0.0) {
        latLng = const location.LatLng(41.3111, 69.2797);
        log("📍 _updateCurrentLocationMarkers: Using default location (Tashkent): ${latLng.latitude}, ${latLng.longitude}");
      }

      // Update reactive current location
      current.value = location.LatLng(latLng.latitude, latLng.longitude);

      // --- GOOGLE MAP Section ---
      updateGoogleMarkers();

      // Only update if location actually changed to prevent flickering
      final previousLat = current.value.latitude;
      final previousLng = current.value.longitude;

      if ((previousLat - latLng.latitude).abs() > 0.0001 ||
          (previousLng - latLng.longitude).abs() > 0.0001) {
        update();
      }

      log('_updateCurrentLocationMarkers: lat=${latLng.latitude}, lng=${latLng.longitude}, '
          'markers=${markers.length}');
    } catch (e) {
      log("_updateCurrentLocationMarkers error: $e");
    }
  }

  Rx<PolylinePoints> polylinePoints =
      PolylinePoints(apiKey: Constant.mapAPIKey).obs;

  google_maps.BitmapDescriptor? driverIcon;
  google_maps.BitmapDescriptor? sourceIcon;
  google_maps.BitmapDescriptor? destinationIcon;

  /// Marker icon size scale (0.22 = kichik hajm)
  static const double _markerSizeScale = 0.22;

  Future<void> _loadIcons() async {
    try {
      final int driverW = (50 * _markerSizeScale).round().clamp(8, 200);
      final int pinW = (100 * _markerSizeScale).round().clamp(8, 200);
      final Uint8List driverBytes = await Constant()
          .getBytesFromAsset('assets/images/ic_cab.png', driverW);
      final Uint8List sourceBytes = await Constant()
          .getBytesFromAsset('assets/images/location_black3x.png', pinW);
      final Uint8List destBytes = await Constant()
          .getBytesFromAsset('assets/images/location_orange3x.png', pinW);

      driverIcon = google_maps.BitmapDescriptor.fromBytes(driverBytes);
      sourceIcon = google_maps.BitmapDescriptor.fromBytes(sourceBytes);
      destinationIcon = google_maps.BitmapDescriptor.fromBytes(destBytes);
    } catch (e) {
      log("Error loading icons: $e");
    }
  }

  /// Update Google Maps markers
  Future<void> updateGoogleMarkers() async {
    try {
      if (driverIcon == null || sourceIcon == null || destinationIcon == null) {
        await _loadIcons();
      }

      markers.clear();

      // ✅ Driver marker - ALWAYS use current GPS location if available
      google_maps.LatLng driverMarkerPosition;
      if (Constant.locationDataFinal != null &&
          Constant.locationDataFinal!.latitude != null &&
          Constant.locationDataFinal!.longitude != null) {
        // Use current GPS location (most accurate)
        driverMarkerPosition = google_maps.LatLng(
          Constant.locationDataFinal!.latitude!,
          Constant.locationDataFinal!.longitude!,
        );
        log("📍 updateGoogleMarkers: Driver marker using GPS: ${driverMarkerPosition.latitude}, ${driverMarkerPosition.longitude}");
      } else if (!(current.value.latitude == 0.0 &&
          current.value.longitude == 0.0)) {
        // Fallback to current.value
        driverMarkerPosition = google_maps.LatLng(
          current.value.latitude,
          current.value.longitude,
        );
        log("📍 updateGoogleMarkers: Driver marker using current.value: ${driverMarkerPosition.latitude}, ${driverMarkerPosition.longitude}");
      } else {
        // Skip if no valid location
        log("⚠️ updateGoogleMarkers: No valid driver location, skipping marker");
        return;
      }

      // Create driver marker
      try {
        markers['driver'] = google_maps.Marker(
          markerId: const google_maps.MarkerId('driver'),
          position: driverMarkerPosition,
          icon: driverIcon ?? google_maps.BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
          flat: true,
        );
        log("✅ Driver marker yaratildi: ${driverMarkerPosition.latitude}, ${driverMarkerPosition.longitude}");
      } catch (e) {
        log("❌ Driver marker yaratishda xatolik: $e");
      }

      // Source marker (pickup)
      if (!(source.value.latitude == 0.0 && source.value.longitude == 0.0)) {
        try {
          markers['source'] = google_maps.Marker(
            markerId: const google_maps.MarkerId('source'),
            position: google_maps.LatLng(
              source.value.latitude,
              source.value.longitude,
            ),
            icon: sourceIcon ?? google_maps.BitmapDescriptor.defaultMarker,
          );
          log("✅ Source marker yaratildi: ${source.value.latitude}, ${source.value.longitude}");
        } catch (e) {
          log("❌ Source marker yaratishda xatolik: $e");
        }
      }

      // Destination marker (dropoff)
      if (!(destination.value.latitude == 0.0 &&
          destination.value.longitude == 0.0)) {
        try {
          markers['destination'] = google_maps.Marker(
            markerId: const google_maps.MarkerId('destination'),
            position: google_maps.LatLng(
              destination.value.latitude,
              destination.value.longitude,
            ),
            icon: destinationIcon ?? google_maps.BitmapDescriptor.defaultMarker,
          );
          log("✅ Destination marker yaratildi: ${destination.value.latitude}, ${destination.value.longitude}");
        } catch (e) {
          log("❌ Destination marker yaratishda xatolik: $e");
        }
      }

      log("📍 [updateGoogleMarkers] Jami ${markers.length} ta marker yaratildi");

      // Update Google map camera if controller is ready
      // ✅ Use GPS location for camera if available
      google_maps.LatLng cameraTarget = driverMarkerPosition;
      if (Constant.isYandexMap) {
        if (yandexMapController != null &&
            !(cameraTarget.latitude == 0.0 && cameraTarget.longitude == 0.0)) {
          await yandexMapController!.moveCamera(
            ym.CameraUpdate.newCameraPosition(
              ym.CameraPosition(
                target: ym.Point(
                  latitude: cameraTarget.latitude,
                  longitude: cameraTarget.longitude,
                ),
                zoom: 16,
              ),
            ),
          );
        }
      } else {
        if (mapController != null &&
            !(cameraTarget.latitude == 0.0 && cameraTarget.longitude == 0.0)) {
          mapController!.animateCamera(
            google_maps.CameraUpdate.newCameraPosition(
              google_maps.CameraPosition(
                target: cameraTarget,
                zoom: 16,
              ),
            ),
          );
        }
      }
      update();
    } catch (e, stackTrace) {
      log("❌ Google map markers update error: $e");
      log("Stack trace: $stackTrace");
    }
  }

  // BitmapDescriptor? departureIcon;
  // BitmapDescriptor? destinationIcon;
  // BitmapDescriptor? taxiIcon;

  // Future<void> setIcons() async {
  //   try {
  //     if (Constant.selectedMapType == 'google') {
  //       final Uint8List departure = await Constant().getBytesFromAsset('assets/images/location_black3x.png', 100);
  //       final Uint8List destination = await Constant().getBytesFromAsset('assets/images/location_orange3x.png', 100);
  //       final Uint8List driver = Constant.sectionModel!.markerIcon == null || Constant.sectionModel!.markerIcon!.isEmpty
  //           ? await Constant().getBytesFromAsset('assets/images/ic_cab.png', 50)
  //           : await Constant().getBytesFromUrl(Constant.sectionModel!.markerIcon.toString(), width: 120);
  //
  //       departureIcon = BitmapDescriptor.fromBytes(departure);
  //       destinationIcon = BitmapDescriptor.fromBytes(destination);
  //       taxiIcon = BitmapDescriptor.fromBytes(driver);
  //     }
  //   } catch (e) {
  //     log("setIcons error: $e");
  //   }
  // }

  location.LatLng _safeLatLngFromLocation(dynamic loc) {
    final lat = (loc?.latitude is num) ? loc.latitude.toDouble() : 0.0;
    final lng = (loc?.longitude is num) ? loc.longitude.toDouble() : 0.0;
    return location.LatLng(lat, lng);
  }

  // _safeRotation() removed - not used with Google Maps
  // double _safeRotation() {
  //   return double.tryParse(driverModel.value.rotation.toString()) ?? 0.0;
  // }

  Future<void> getGooglePolyline() async {
    try {
      if (currentOrder.value.id == null) return;

      final driverLatLng = _safeLatLngFromLocation(driverModel.value.location);

      // Check order status
      // pending_driver_acceptance yoki driverPending statuslarida faqat source -> destination chiziladi
      final status = currentOrder.value.status;
      final isPendingStatus = status == Constant.driverPending ||
          status == "pending_driver_acceptance";

      if (!isPendingStatus) {
        // Case 1: Driver Accepted or Order Shipped → Driver → Pickup
        if (currentOrder.value.status == Constant.driverAccepted ||
            currentOrder.value.status == Constant.orderShipped) {
          final sourceLatLng =
              _safeLatLngFromLocation(currentOrder.value.sourceLocation);

          log("📍 [getGooglePolyline] driverAccepted status: driver=${driverLatLng.latitude},${driverLatLng.longitude} -> source=${sourceLatLng.latitude},${sourceLatLng.longitude}");

          await _drawGoogleRoute(
            origin: driverLatLng,
            destination: sourceLatLng,
            addDriver: true,
            addSource: true,
            addDestination: false,
          );

          animateToSource();
        }

        // Case 2: Order In Transit → Driver → Destination
        else if (currentOrder.value.status == Constant.orderInTransit) {
          final destLatLng =
              _safeLatLngFromLocation(currentOrder.value.destinationLocation);

          await _drawGoogleRoute(
            origin: driverLatLng,
            destination: destLatLng,
            addDriver: true,
            addSource: false,
            addDestination: true,
          );

          animateToSource();
        }
      }

      // Case 3: Before driver assigned → Source → Destination
      else {
        final sourceLatLng =
            _safeLatLngFromLocation(currentOrder.value.sourceLocation);
        final destLatLng =
            _safeLatLngFromLocation(currentOrder.value.destinationLocation);

        await _drawGoogleRoute(
          origin: sourceLatLng,
          destination: destLatLng,
          addDriver: false,
          addSource: true,
          addDestination: true,
        );

        animateToSource();
      }
    } catch (e, s) {
      log('getGooglePolyline() error: $e');
      debugPrintStack(stackTrace: s);
    }
  }

  Future<void> _drawGoogleRoute({
    required location.LatLng origin,
    required location.LatLng destination,
    bool addDriver = true,
    bool addSource = true,
    bool addDestination = true,
  }) async {
    try {
      if ((origin.latitude == 0.0 && origin.longitude == 0.0) ||
          (destination.latitude == 0.0 && destination.longitude == 0.0)) {
        return;
      }

      // Get route points from Google Directions API
      final result = await polylinePoints.value.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isEmpty) {
        log('Google route not found');
        return;
      }

      final List<location.LatLng> polylineCoordinates = result.points
          .map((p) => location.LatLng(p.latitude, p.longitude))
          .toList();

      // Draw polyline
      addPolyLine(polylineCoordinates);

      // --- Update Google Maps reactive variables ---
      // Update current location (driver)
      if (addDriver) {
        current.value = origin;
      }
      // Update source location (pickup)
      if (addSource) {
        final sourceLatLng =
            _safeLatLngFromLocation(currentOrder.value.sourceLocation);
        if (sourceLatLng.latitude != 0.0 || sourceLatLng.longitude != 0.0) {
          source.value = sourceLatLng;
        }
      }
      // Update destination location (dropoff)
      if (addDestination) {
        final destLatLng =
            _safeLatLngFromLocation(currentOrder.value.destinationLocation);
        if (destLatLng.latitude != 0.0 || destLatLng.longitude != 0.0) {
          this.destination.value = destLatLng;
        }
      }
      // Google Maps uchun markerlarni yangilash
      await updateGoogleMarkers();
    } catch (e, s) {
      log('_drawGoogleRoute error: $e');
      debugPrintStack(stackTrace: s);
    }
  }

  void addPolyLine(List<location.LatLng> polylineCoordinates) {
    if (polylineCoordinates.isEmpty) {
      // nothing to draw, but ensure markers updated
      update();
      return;
    }

    // Convert to Google Maps polyline
    final googlePoints = polylineCoordinates
        .map((point) => google_maps.LatLng(
              point.latitude,
              point.longitude,
            ))
        .toList();

    final polylineId = const google_maps.PolylineId('route');
    polyLines[polylineId] = google_maps.Polyline(
      polylineId: polylineId,
      points: googlePoints,
      color: AppThemeData.primary300,
      width: 8,
      geodesic: true,
    );

    update();
    // Update camera to first point
    if (polylineCoordinates.isNotEmpty) {
      final firstPoint = polylineCoordinates.first;
      if (Constant.isYandexMap) {
        if (yandexMapController == null) return;
        yandexMapController!.moveCamera(
          ym.CameraUpdate.newCameraPosition(
            ym.CameraPosition(
              target: ym.Point(
                latitude: firstPoint.latitude,
                longitude: firstPoint.longitude,
              ),
              zoom: currentOrder.value.id == null ||
                      currentOrder.value.status == Constant.driverPending
                  ? 16
                  : 20,
            ),
          ),
        );
      } else if (mapController != null) {
        mapController!.animateCamera(
          google_maps.CameraUpdate.newCameraPosition(
            google_maps.CameraPosition(
              target: google_maps.LatLng(
                firstPoint.latitude,
                firstPoint.longitude,
              ),
              zoom: currentOrder.value.id == null ||
                      currentOrder.value.status == Constant.driverPending
                  ? 16
                  : 20,
            ),
          ),
        );
      }
    }
  }

  void animateToSource() {
    double lat = 0.0;
    double lng = 0.0;
    final loc = driverModel.value.location;
    if (loc != null) {
      // Use string parsing to avoid nullable-toDouble issues and handle numbers/strings.
      lat = double.tryParse('${loc.latitude}') ?? 0.0;
      lng = double.tryParse('${loc.longitude}') ?? 0.0;
    }
    _updateCurrentLocationMarkers();
    // Move map camera to current location
    if (Constant.isYandexMap) {
      if (yandexMapController != null && lat != 0.0 && lng != 0.0) {
        yandexMapController!.moveCamera(
          ym.CameraUpdate.newCameraPosition(
            ym.CameraPosition(
              target: ym.Point(latitude: lat, longitude: lng),
              zoom: 16,
            ),
          ),
        );
      }
    } else {
      if (mapController != null && lat != 0.0 && lng != 0.0) {
        mapController!.animateCamera(
          google_maps.CameraUpdate.newCameraPosition(
            google_maps.CameraPosition(
              target: google_maps.LatLng(lat, lng),
              zoom: 16,
            ),
          ),
        );
      }
    }
  }

  Rx<location.LatLng> source = location.LatLng(0.0, 0.0).obs; // Start (unset)
  Rx<location.LatLng> current =
      location.LatLng(0.0, 0.0).obs; // Moving marker (unset)
  Rx<location.LatLng> destination =
      location.LatLng(0.0, 0.0).obs; // Destination (unset)

  void setOsmMapMarker() {
    // OSM markers are now handled by Google Maps via updateGoogleMarkers()
    updateGoogleMarkers();
  }

  Future<void> getOSMPolyline() async {
    try {
      if (currentOrder.value.id == null) return;

      // pending_driver_acceptance yoki driverPending statuslarida faqat source -> destination chiziladi
      final status = currentOrder.value.status;
      final isPendingStatus = status == Constant.driverPending ||
          status == "pending_driver_acceptance";

      if (!isPendingStatus) {
        if (currentOrder.value.status == Constant.driverAccepted ||
            currentOrder.value.status == Constant.orderShipped) {
          final lat =
              (driverModel.value.location?.latitude as num?)?.toDouble() ?? 0.0;
          final lng =
              (driverModel.value.location?.longitude as num?)?.toDouble() ??
                  0.0;
          current.value = location.LatLng(lat, lng);
          source.value = location.LatLng(
            currentOrder.value.sourceLocation?.latitude ?? 0.0,
            currentOrder.value.sourceLocation?.longitude ?? 0.0,
          );
          animateToSource();
          await fetchRoute(current.value, source.value);

          // Google Maps uchun polyline chizish
          if (Constant.mapType == "inappmap") {
            if (routePoints.isNotEmpty) {
              addPolyLine(routePoints.toList());
            }
          }

          setOsmMapMarker();
        } else if (currentOrder.value.status == Constant.orderInTransit) {
          final lat =
              (driverModel.value.location?.latitude as num?)?.toDouble() ?? 0.0;
          final lng =
              (driverModel.value.location?.longitude as num?)?.toDouble() ??
                  0.0;
          current.value = location.LatLng(lat, lng);
          destination.value = location.LatLng(
            currentOrder.value.destinationLocation?.latitude ?? 0.0,
            currentOrder.value.destinationLocation?.longitude ?? 0.0,
          );
          await fetchRoute(current.value, destination.value);

          // Google Maps uchun polyline chizish
          if (Constant.mapType == "inappmap") {
            if (routePoints.isNotEmpty) {
              addPolyLine(routePoints.toList());
            }
          }

          setOsmMapMarker();
          animateToSource();
        }
      } else {
        current.value = location.LatLng(
            currentOrder.value.sourceLocation?.latitude ?? 0.0,
            currentOrder.value.sourceLocation?.longitude ?? 0.0);
        destination.value = location.LatLng(
            currentOrder.value.destinationLocation?.latitude ?? 0.0,
            currentOrder.value.destinationLocation?.longitude ?? 0.0);
        await fetchRoute(current.value, destination.value);

        // Google Maps uchun polyline chizish
        if (Constant.mapType == "inappmap") {
          if (routePoints.isNotEmpty) {
            addPolyLine(routePoints.toList());
          }
        }

        setOsmMapMarker();
        animateToSource();
      }
    } catch (e) {
      log('getOSMPolyline error: $e');
    }
  }

  RxList<location.LatLng> routePoints = <location.LatLng>[].obs;

  Future<void> fetchRoute(
      location.LatLng source, location.LatLng destination) async {
    try {
      // ensure valid coords
      final bothZero = source.latitude == 0.0 &&
          source.longitude == 0.0 &&
          destination.latitude == 0.0 &&
          destination.longitude == 0.0;
      if (bothZero) {
        routePoints.clear();
        return;
      }

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${source.longitude},${source.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded != null &&
            decoded['routes'] != null &&
            decoded['routes'] is List &&
            (decoded['routes'] as List).isNotEmpty &&
            decoded['routes'][0]['geometry'] != null) {
          final geometry = decoded['routes'][0]['geometry']['coordinates'];
          routePoints.clear();
          for (var coord in geometry) {
            if (coord is List && coord.length >= 2) {
              final lon = coord[0];
              final lat = coord[1];
              if (lat is num && lon is num) {
                routePoints
                    .add(location.LatLng(lat.toDouble(), lon.toDouble()));
              }
            }
          }
          return;
        }
        routePoints.clear();
      } else {
        log("Failed to get route: ${response.statusCode} ${response.body}");
        routePoints.clear();
      }
    } catch (e) {
      log("fetchRoute error: $e");
      routePoints.clear();
    }
  }

  /// Open Yandex Maps directly with directions
  Future<void> showMapSelectionDialog() async {
    final order = currentOrder.value;

    // Get origin (driver current location or source)
    double originLat = 0.0;
    double originLng = 0.0;

    if (Constant.locationDataFinal != null &&
        Constant.locationDataFinal!.latitude != null &&
        Constant.locationDataFinal!.longitude != null) {
      originLat = Constant.locationDataFinal!.latitude!;
      originLng = Constant.locationDataFinal!.longitude!;
    } else if (driverModel.value.location != null) {
      originLat =
          (driverModel.value.location!.latitude as num?)?.toDouble() ?? 0.0;
      originLng =
          (driverModel.value.location!.longitude as num?)?.toDouble() ?? 0.0;
    }

    // Get destination based on order status
    double destLat = 0.0;
    double destLng = 0.0;

    if (order.status == Constant.driverAccepted ||
        order.status == Constant.orderShipped) {
      // Going to pickup (source)
      destLat = (order.sourceLocation?.latitude as num?)?.toDouble() ?? 0.0;
      destLng = (order.sourceLocation?.longitude as num?)?.toDouble() ?? 0.0;
    } else if (order.status == Constant.orderInTransit) {
      // Going to dropoff (destination)
      destLat =
          (order.destinationLocation?.latitude as num?)?.toDouble() ?? 0.0;
      destLng =
          (order.destinationLocation?.longitude as num?)?.toDouble() ?? 0.0;
    }

    if (originLat == 0.0 ||
        originLng == 0.0 ||
        destLat == 0.0 ||
        destLng == 0.0) {
      ShowToastDialog.showToast("Location information is not available".tr);
      return;
    }

    // Open Yandex Maps directly
    _openYandexMaps(originLat, originLng, destLat, destLng);
  }

  /// Open Yandex Maps with directions
  Future<void> _openYandexMaps(double originLat, double originLng,
      double destLat, double destLng) async {
    // Persist the active ride so the controller can rehydrate if the OS
    // kills the driver app while the user is in Yandex Navigator.
    final orderId = currentOrder.value.id;
    if (orderId != null && orderId.isNotEmpty) {
      await Preferences.setString(Preferences.lastActiveRideId, orderId);
      await Preferences.setDouble(Preferences.lastAccumulatedKm, _accumulatedKm);
    }

    final url = Uri.parse(
      'https://yandex.com/maps/?rtext=$originLat,$originLng~$destLat,$destLng&rtt=auto',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ShowToastDialog.showToast("Could not open Yandex Maps".tr);
      }
    } catch (e) {
      log("Error opening Yandex Maps: $e");
      ShowToastDialog.showToast("Error opening Yandex Maps".tr);
    }
  }

  /// Called on cold start to recover an in-progress ride that was active
  /// when the app was killed (e.g. by the OS while the driver was using
  /// Yandex Navigator). Repopulates `currentOrder` from Firestore and
  /// resumes the tracking loop if the ride is still active.
  Future<void> _restoreInFlightRideIfAny() async {
    final rideId = Preferences.getString(Preferences.lastActiveRideId);
    if (rideId.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('cab_booking_orders')
          .doc(rideId)
          .get(const GetOptions(source: Source.server));
      if (!snap.exists) {
        await Preferences.clearKeyData(Preferences.lastActiveRideId);
        await Preferences.clearKeyData(Preferences.lastAccumulatedKm);
        return;
      }
      final order = CabOrderModel.fromJson(snap.data()!);
      if (_isFinalStatus(order.status)) {
        await Preferences.clearKeyData(Preferences.lastActiveRideId);
        await Preferences.clearKeyData(Preferences.lastAccumulatedKm);
        return;
      }
      currentOrder.value = order;
      _accumulatedKm =
          Preferences.getDouble(Preferences.lastAccumulatedKm, defaultValue: 0);
      if (order.status == Constant.orderInTransit && order.isTracking == true) {
        _startTrackingTimer();
      }
      log('[Cab] Restored in-flight ride $rideId status=${order.status} km=$_accumulatedKm');
    } catch (e) {
      log('[Cab] _restoreInFlightRideIfAny failed: $e');
    }
  }
}
