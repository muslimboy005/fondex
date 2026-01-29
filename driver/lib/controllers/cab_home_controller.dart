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
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as location;
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';

class CabHomeController extends GetxController {
  RxBool isLoading = true.obs;
  google_maps.GoogleMapController? mapController;
  RxMap<String, google_maps.Marker> markers =
      <String, google_maps.Marker>{}.obs;
  RxMap<google_maps.PolylineId, google_maps.Polyline> polyLines =
      <google_maps.PolylineId, google_maps.Polyline>{}.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderDocSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _orderQuerySub;

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  @override
  void onClose() {
    _driverSub?.cancel();
    _orderDocSub?.cancel();
    _orderQuerySub?.cancel();
    super.onClose();
  }

  Future<void> getData() async {
    _subscribeDriver();
    isLoading.value = false;
  }

  Rx<CabOrderModel> currentOrder = CabOrderModel().obs;
  Rx<UserModel> driverModel = UserModel().obs;
  Rx<UserModel> ownerModel = UserModel().obs;

  Future<void> acceptOrder() async {
    try {
      await AudioPlayerService.playSound(false);
      ShowToastDialog.showLoader("Please wait".tr);

      driverModel.value.inProgressOrderID ??= [];
      driverModel.value.inProgressOrderID!.add(currentOrder.value.id);
      driverModel.value.orderCabRequestData = null;
      await FireStoreUtils.updateUser(driverModel.value);

      currentOrder.value.status = Constant.driverAccepted;
      currentOrder.value.driverId = driverModel.value.id;
      currentOrder.value.driver = driverModel.value;
      await FireStoreUtils.setCabOrder(currentOrder.value);

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
      ShowToastDialog.showToast("Something went wrong. Please try again.");
    }
  }

  Future<void> rejectOrder() async {
    try {
      await AudioPlayerService.playSound(false);

      // 1️⃣ Immediately update local state (UI)
      currentOrder.value.status = Constant.driverRejected;

      currentOrder.value.rejectedByDrivers ??= [];
      if (!currentOrder.value.rejectedByDrivers!
          .contains(driverModel.value.id)) {
        currentOrder.value.rejectedByDrivers!.add(driverModel.value.id);
      }

      // Immediately update UI so bottom sheet hides right away
      currentOrder.refresh();

      // 2️⃣ Update driver local state right away
      driverModel.value.orderCabRequestData = null;
      driverModel.value.inProgressOrderID = [];
      await FireStoreUtils.updateUser(driverModel.value);

      // 3️⃣ Close bottom sheet immediately (don’t wait for Firestore)
      if (Get.isBottomSheetOpen ?? false) {
        Get.back();
      } else if (Constant.singleOrderReceive == false) {
        Get.back();
      }

      // 4️⃣ Clear map immediately
      await clearMap();

      // 5️⃣ Update Firestore in background (no UI wait)
      unawaited(FireStoreUtils.setCabOrder(currentOrder.value));

      // 6️⃣ Reset local current order after short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        currentOrder.value = CabOrderModel();
      });
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

  Future<void> clearMap() async {
    await AudioPlayerService.playSound(false);
    // Clear Google Maps markers and polylines
    markers.clear();
    polyLines.clear();
    routePoints.clear();
    update();
  }

  Future<void> onRideStatus() async {
    await AudioPlayerService.playSound(false);
    ShowToastDialog.showLoader("Please wait".tr);
    currentOrder.value.status = Constant.orderInTransit;
    await FireStoreUtils.setCabOrder(currentOrder.value);
    ShowToastDialog.closeLoader();
    Get.back();

    // Status o'zgarganda yo'l yangilanishi kerak
    // orderInTransit -> driver dan destination gacha
    print(
        "🚗 [onRideStatus] Status orderInTransit ga o'zgardi, yo'l yangilanmoqda");
    await changeData();
  }

  Future<void> completeRide() async {
    try {
      ShowToastDialog.showLoader("Please wait".tr);
      await updateCabWalletAmount(currentOrder.value);

      await FireStoreUtils.getFirestOrderOrNOtCabService(currentOrder.value)
          .then((value) async {
        if (value == true) {
          await FireStoreUtils.updateReferralAmountCabService(
              currentOrder.value);
        }
      });

      currentOrder.value.status = Constant.orderCompleted;
      driverModel.value.inProgressOrderID = [];
      driverModel.value.orderCabRequestData = null;
      await FireStoreUtils.setCabOrder(currentOrder.value);
      await FireStoreUtils.updateUser(driverModel.value);

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
      await _orderDocSub?.cancel();
      await _orderQuerySub?.cancel();

      final inProgress = driverModel.value.inProgressOrderID;
      print("📦 [getCurrentOrder] inProgressOrderID: $inProgress");

      if (inProgress != null && inProgress.isNotEmpty) {
        final String id = inProgress.first.toString();
        print("📦 [getCurrentOrder] inProgress order topildi, ID: $id");
        _orderDocSub = FireStoreUtils.fireStore
            .collection(CollectionName.ridesBooking)
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
          print(
              "📦 [getCurrentOrder] orderCabRequestData dan order topildi, ID: $id");
          _orderDocSub = FireStoreUtils.fireStore
              .collection(CollectionName.ridesBooking)
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

      // Fallback: Query for pending orders that might be assigned to this driver
      // This helps when notification arrives before driver document is updated
      print("📦 [getCurrentOrder] Fallback query chaqirilmoqda...");
      await _queryPendingOrdersForDriver();

      // Only clear if we still don't have an order after fallback query
      print(
          "📦 [getCurrentOrder] currentOrder.value.id: ${currentOrder.value.id}");
      if (currentOrder.value.id == null) {
        print("📦 [getCurrentOrder] Order topilmadi, clearMap chaqirilmoqda");
        currentOrder.value = CabOrderModel();
        await clearMap();
        await AudioPlayerService.playSound(false);
        update();
      } else {
        print(
            "📦 [getCurrentOrder] Order topildi: ${currentOrder.value.id}, status: ${currentOrder.value.status}");
      }
    } catch (e) {
      print("📦 [getCurrentOrder] Xatolik: $e");
      log("getCurrentOrder() error: $e");
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

      // Only query for very recent orders (last 1 minute) to avoid picking up old orders
      final oneMinuteAgo = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 1)));
      print("🔍 [_queryPendingOrdersForDriver] oneMinuteAgo: $oneMinuteAgo");

      final sectionId = driverModel.value.sectionId;
      print("🔍 [_queryPendingOrdersForDriver] sectionId: $sectionId");

      // Build query - use simpler query to avoid index requirements
      // Query by status and createdAt, filter sectionId in memory if needed
      Query<Map<String, dynamic>> query = FireStoreUtils.fireStore
          .collection(CollectionName.ridesBooking)
          .where('status', isEqualTo: Constant.driverPending)
          .where('createdAt', isGreaterThanOrEqualTo: oneMinuteAgo)
          .orderBy('createdAt', descending: true)
          .limit(5);

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

          // This might be the order for this driver
          print(
              "🔍 [_queryPendingOrdersForDriver] Potensial order topildi: ${order.id}");
          log("Found potential pending order: ${order.id}, sectionId: ${order.sectionId}");
          // Listen to this order document
          final id = order.id;
          if (id != null && id.isNotEmpty) {
            print(
                "🔍 [_queryPendingOrdersForDriver] Order document listener o'rnatilmoqda: $id");
            await _orderDocSub?.cancel();
            _orderDocSub = FireStoreUtils.fireStore
                .collection(CollectionName.ridesBooking)
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
            .collection(CollectionName.ridesBooking)
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
          await _orderDocSub?.cancel();
          _orderDocSub = docRef
              .snapshots()
              .listen((snap) => _handleOrderDoc(snap, rideId));
          return;
        }

        // Agar document ID orqali topilmasa, 'id' field orqali qidiramiz
        print(
            "🚀 [getOrderByRideId] Document ID orqali topilmadi, 'id' field orqali qidiryapmiz");
        final querySnapshot = await FireStoreUtils.fireStore
            .collection(CollectionName.ridesBooking)
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
          await _orderDocSub?.cancel();
          _orderDocSub = FireStoreUtils.fireStore
              .collection(CollectionName.ridesBooking)
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

  Future<void> _handleOrderDoc(
      DocumentSnapshot<Map<String, dynamic>> docSnap, String id) async {
    try {
      print("📄 [_handleOrderDoc] Order document yangilandi, ID: $id");
      print("📄 [_handleOrderDoc] docSnap.exists: ${docSnap.exists}");

      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null) {
          currentOrder.value = CabOrderModel.fromJson(data);
          print("📄 [_handleOrderDoc] currentOrder yangilandi");
          print("📄 [_handleOrderDoc] Order ID: ${currentOrder.value.id}");
          print(
              "📄 [_handleOrderDoc] Order status: ${currentOrder.value.status}");
          print(
              "📄 [_handleOrderDoc] shouldShowOrderSheet: $shouldShowOrderSheet");

          await changeData();
          if (currentOrder.value.status == Constant.orderCompleted) {
            print("📄 [_handleOrderDoc] Order completed, tozalash");
            driverModel.value.inProgressOrderID = [];
            await FireStoreUtils.updateUser(driverModel.value);
            currentOrder.value = CabOrderModel();
            await clearMap();
            await AudioPlayerService.playSound(false);
            update();
            return;
          } else if (currentOrder.value.status == Constant.orderRejected ||
              currentOrder.value.status == Constant.orderCancelled) {
            print("📄 [_handleOrderDoc] Order rejected/cancelled, tozalash");
            driverModel.value.inProgressOrderID = [];
            driverModel.value.orderCabRequestData = null;
            await FireStoreUtils.updateUser(driverModel.value);
            currentOrder.value = CabOrderModel();
            await clearMap();
            await AudioPlayerService.playSound(false);
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
          .collection(CollectionName.ridesBooking)
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
        currentOrder.value = CabOrderModel.fromJson(data);
        await changeData();
        if (currentOrder.value.status == Constant.orderCompleted) {
          driverModel.value.inProgressOrderID = [];
          await FireStoreUtils.updateUser(driverModel.value);
          currentOrder.value = CabOrderModel();
          await clearMap();
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

  Future<void> changeData() async {
    print("🔄 [changeData] changeData chaqirildi");
    print("🔄 [changeData] currentOrder.id: ${currentOrder.value.id}");
    print("🔄 [changeData] currentOrder.status: ${currentOrder.value.status}");
    print("🔄 [changeData] selectedMapType: ${Constant.selectedMapType}");

    // Order status bo'yicha yo'l chizish
    if (Constant.mapType == "inappmap") {
      if (Constant.selectedMapType == "osm") {
        print("🔄 [changeData] OSM polyline chizilmoqda");
        await getOSMPolyline();
      } else {
        // Google Maps uchun
        print("🔄 [changeData] Google Maps polyline chizilmoqda");
        await getGooglePolyline();
      }
    } else {
      // Google Maps uchun ham
      print("🔄 [changeData] Google Maps polyline chizilmoqda");
      await getGooglePolyline();
    }

    // pending_driver_acceptance yoki driverPending statuslarida sound play
    final status = currentOrder.value.status;
    final isPendingStatus = status == Constant.driverPending ||
        status == "pending_driver_acceptance";

    if (isPendingStatus) {
      print("🔄 [changeData] pending status ($status), sound play");
      await AudioPlayerService.playSound(true);
    } else {
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

  Future<void> _loadIcons() async {
    try {
      final Uint8List driverBytes =
          await Constant().getBytesFromAsset('assets/images/ic_cab.png', 50);
      final Uint8List sourceBytes = await Constant()
          .getBytesFromAsset('assets/images/location_black3x.png', 100);
      final Uint8List destBytes = await Constant()
          .getBytesFromAsset('assets/images/location_orange3x.png', 100);

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
    if (polylineCoordinates.isNotEmpty && mapController != null) {
      final firstPoint = polylineCoordinates.first;
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
    // Move Google map camera to current location
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

  Rx<location.LatLng> source =
      location.LatLng(21.1702, 72.8311).obs; // Start (e.g., Surat)
  Rx<location.LatLng> current =
      location.LatLng(21.1800, 72.8400).obs; // Moving marker
  Rx<location.LatLng> destination =
      location.LatLng(21.2000, 72.8600).obs; // Destination

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

  /// Open Google Maps with directions
  Future<void> _openGoogleMaps(double originLat, double originLng,
      double destLat, double destLng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ShowToastDialog.showToast("Could not open Google Maps".tr);
      }
    } catch (e) {
      log("Error opening Google Maps: $e");
      ShowToastDialog.showToast("Error opening Google Maps".tr);
    }
  }

  /// Open Yandex Maps with directions
  Future<void> _openYandexMaps(double originLat, double originLng,
      double destLat, double destLng) async {
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
}
