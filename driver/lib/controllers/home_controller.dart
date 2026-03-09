import 'dart:async';
import 'dart:developer';

import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;
import 'package:latlong2/latlong.dart' as location;
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:driver/utils/yandex_map_utils.dart';

import '../models/order_model.dart';

class HomeController extends GetxController {
  RxBool isLoading = true.obs;

  // Track order subscription to cancel previous ones
  StreamSubscription? _orderSubscription;
  // Doimiy stream: driver dokumenti (yangi zakazlar orderRequestData da)
  StreamSubscription? _driverSubscription;

  @override
  void onInit() {
    getArgument();
    setIcons();
    listenToDriverAndOrders();
    requestLocationPermission();
    super.onInit();
  }

  @override
  void onClose() {
    _orderSubscription?.cancel();
    _driverSubscription?.cancel();
    super.onClose();
  }

  /// Request location permission and get current location
  Future<void> requestLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("⚠️ Location services are disabled");
        // Request to enable location services
        await Geolocator.openLocationSettings();
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("⚠️ Location permissions are denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("⚠️ Location permissions are permanently denied");
        return;
      }

      // Get current location using Location service (better for LocationData)
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        debugPrint(
            "✅ Location permission granted, getting current location...");

        final locationService = Location();
        try {
          // Get location using Location service
          final locationData = await locationService.getLocation();
          Constant.locationDataFinal = locationData;

          if (locationData.latitude != null && locationData.longitude != null) {
            debugPrint(
                "📍 Got current location: ${locationData.latitude}, ${locationData.longitude}");

            // Update current location in controller
            current.value = location.LatLng(
              locationData.latitude!,
              locationData.longitude!,
            );

            // Update driver model location if needed
            if (driverModel.value.location == null ||
                driverModel.value.location!.latitude == null ||
                driverModel.value.location!.latitude == 0.0) {
              driverModel.value.location = UserLocation(
                latitude: locationData.latitude!,
                longitude: locationData.longitude!,
              );
            }

            // Update markers
            _updateCurrentLocationMarkers();
            update();
          } else {
            debugPrint("⚠️ Location data is null");
          }
        } catch (e) {
          debugPrint("❌ Error getting location from Location service: $e");
          // Fallback to Geolocator
          try {
            Position? position = await Utils.getCurrentLocation();
            if (position != null) {
              debugPrint(
                  "📍 Got current location (fallback): ${position.latitude}, ${position.longitude}");
              current.value =
                  location.LatLng(position.latitude, position.longitude);

              if (driverModel.value.location == null ||
                  driverModel.value.location!.latitude == null ||
                  driverModel.value.location!.latitude == 0.0) {
                driverModel.value.location = UserLocation(
                  latitude: position.latitude,
                  longitude: position.longitude,
                );
              }

              _updateCurrentLocationMarkers();
              update();
            }
          } catch (e2) {
            debugPrint("❌ Error getting location from Geolocator: $e2");
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Error getting location: $e");
    }
  }

  Rx<OrderModel> orderModel = OrderModel().obs;
  Rx<OrderModel> currentOrder = OrderModel().obs;
  Rx<UserModel> driverModel = UserModel().obs;

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderModel.value = argumentData['orderModel'];
    }
  }

  Future<void> acceptOrder() async {
    log("🟢 [acceptOrder] Boshlandi");
    final orderId = currentOrder.value.id;
    if (orderId == null || orderId.isEmpty) {
      log("❌ [acceptOrder] Order id bo‘sh – qabul qilish bekor qilindi");
      ShowToastDialog.showToast("Order id not found. Please try again.".tr);
      return;
    }
    await AudioPlayerService.playSound(false);
    ShowToastDialog.showLoader("Please wait".tr);
    driverModel.value.inProgressOrderID ??= [];
    driverModel.value.orderRequestData ??= [];
    driverModel.value.orderRequestData!.remove(orderId);
    if (!driverModel.value.inProgressOrderID!.contains(orderId)) {
      driverModel.value.inProgressOrderID!.add(orderId);
    }

    await FireStoreUtils.updateUser(driverModel.value);

    currentOrder.value.status = Constant.driverAccepted;
    currentOrder.value.driverID = driverModel.value.id;
    currentOrder.value.driver = driverModel.value;
    currentOrder.value.id = orderId;

    await FireStoreUtils.setOrder(currentOrder.value);
    log("🟢 [acceptOrder] Firestore yangilandi, status=${currentOrder.value.status}");
    print("SendNotification ===========>");
    SendNotification.sendFcmMessage(Constant.driverAcceptedNotification,
        currentOrder.value.author?.fcmToken ?? '', {});
    SendNotification.sendFcmMessage(Constant.driverAcceptedNotification,
        currentOrder.value.vendor?.fcmToken ?? '', {});
    ShowToastDialog.closeLoader();
    log("🟢 [acceptOrder] changeData() chaqirilmoqda...");
    await changeData();
    log("🟢 [acceptOrder] changeData() tugadi. markers=${markers.length}, polyLines=${polyLines.length}");
  }

  Future<void> rejectOrder() async {
    ShowToastDialog.showLoader("Please wait".tr);
    // 🔊 Stop any ongoing alert sound (if playing)
    await AudioPlayerService.playSound(false);

    final driver = driverModel.value;
    final order = currentOrder.value;

    // 1️⃣ Validate order and driver
    if (order.id == null || driver.id == null) {
      debugPrint("⚠️ No valid order or driver found for rejection.");
      return;
    }

    // 2️⃣ Add driver to rejected list safely
    order.rejectedByDrivers ??= [];
    if (!order.rejectedByDrivers!.contains(driver.id)) {
      order.rejectedByDrivers!.add(driver.id);
    }

    // 3️⃣ Update order status
    order.status = Constant.driverRejected;

    // 4️⃣ Push order update to Firestore
    await FireStoreUtils.setOrder(order);

    // 5️⃣ Clean up driver's order tracking data safely
    driver.orderRequestData?.remove(order.id);
    driver.inProgressOrderID?.remove(order.id);

    // 6️⃣ Update driver info in Firestore
    await FireStoreUtils.updateUser(driver);

    // 7️⃣ Reset order states
    currentOrder.value = OrderModel();
    orderModel.value = OrderModel();

    // 8️⃣ Clear map visuals and UI
    await clearMap();
    update();

    // 9️⃣ If multiple orders allowed, close dialog/screen
    if (Constant.singleOrderReceive == false && Get.isOverlaysOpen) {
      Get.back();
    }
    ShowToastDialog.closeLoader();
    debugPrint("✅ Order ${order.id} rejected by driver ${driver.id}");
  }

  Future<void> clearMap() async {
    await AudioPlayerService.playSound(false);
    markers.clear();
    polyLines.clear();
    update();
  }

  Future<void> getCurrentOrder() async {
    final driver = driverModel.value;
    final currentId = currentOrder.value.id;
    final requests = driver.orderRequestData;
    final inProgress = driver.inProgressOrderID;

    // 1️⃣ Reset if current order is invalid (yo‘q ro‘yxatlarda)
    if (currentId != null &&
        !(requests?.contains(currentId) ?? false) &&
        !(inProgress?.contains(currentId) ?? false)) {
      await _resetCurrentOrder();
      return;
    }

    // 2️⃣ Agar hozir ko‘rsatilayotgan buyurtma hali ham ro‘yxatlarda bo‘lsa, boshqasiga o‘tmaymiz.
    // Driver stream tez-tez yangilanganda (location/accept) eski snapshot kelishi mumkin – dialog yopilmasin.
    if (currentId != null &&
        ((inProgress?.contains(currentId) ?? false) ||
            (requests?.contains(currentId) ?? false))) {
      return;
    }

    // 3️⃣ Avval inProgress (qabul qilingan), keyin orderRequestData (takliflar).
    if (Constant.singleOrderReceive != true) return;
    if (inProgress != null && inProgress.isNotEmpty) {
      final id = inProgress.last;
      if (id != currentId) _listenToOrder(id);
      return;
    }
    if (requests != null && requests.isNotEmpty) {
      final id = requests.last;
      if (id != currentId) {
        _listenToOrder(id, checkInRequestData: true);
      }
      return;
    }

    // 4️⃣ Fallback
    final fallbackId = orderModel.value.id;
    if (fallbackId != null) _listenToOrder(fallbackId);
  }

  Future<void> _resetCurrentOrder() async {
    currentOrder.value = OrderModel();
    await clearMap();
    await AudioPlayerService.playSound(false);
    update();
  }

  /// 🔹 Bildirishnoma orqali kelgan orderId bo‘yicha stream boshlash.
  /// Driver dokumenti yangilanmasa ham buyurtma ko‘rinadi.
  void listenToOrderById(String orderId) {
    if (orderId.isEmpty) return;
    log("🟢 [listenToOrderById] orderId=$orderId – bildirishnoma orqali stream boshlandi");
    _listenToOrder(orderId, checkInRequestData: false);
  }

  /// 🔹 Listen to Firestore order updates for a specific orderId
  void _listenToOrder(String orderId, {bool checkInRequestData = false}) {
    // Cancel previous subscription to avoid memory leaks
    _orderSubscription?.cancel();

    // Use .doc() instead of query to avoid requiring composite index
    // This directly accesses the document by ID, which is more efficient
    _orderSubscription = FireStoreUtils.fireStore
        .collection(CollectionName.vendorOrders)
        .doc(orderId)
        .snapshots()
        .listen((docSnapshot) async {
      // Check if document exists
      if (!docSnapshot.exists) {
        await _handleOrderNotFound();
        return;
      }

      final data = docSnapshot.data();
      if (data == null) {
        await _handleOrderNotFound();
        return;
      }

      final newOrder = OrderModel.fromJson(data);
      // Firestore document id odatda data ichida bo‘lmaydi – asl buyurtma hujjati id sini ishlatamiz,
      // aks holda .doc(null) yangi "nusxa" yaratib, asl buyurtma yangilanmaydi
      newOrder.id = docSnapshot.id;

      // Check status in code instead of query filter
      if (newOrder.status == Constant.orderCancelled ||
          newOrder.status == Constant.driverRejected) {
        await _handleOrderNotFound();
        return;
      }

      if (checkInRequestData &&
          !(driverModel.value.orderRequestData?.contains(newOrder.id) ??
              false)) {
        await _handleOrderNotFound();
        return;
      }

      if (newOrder.rejectedByDrivers!.contains(driverModel.value.id)) {
        await _handleOrderNotFound();
        return;
      }

      currentOrder.value = newOrder;
      log("🟢 [_listenToOrder] Order yangilandi orderId=${newOrder.id} status=${newOrder.status}, changeData() chaqirilmoqda");
      changeData();
      update(); // Update UI to show bottom sheet
    }, onError: (error) {
      // Handle errors gracefully
      debugPrint("❌ Error listening to order $orderId: $error");
      log("Error in _listenToOrder for orderId $orderId: $error");
      // Don't call _handleOrderNotFound on error, as it might be temporary
      // The stream will retry automatically
    });
  }

  Future<void> _handleOrderNotFound() async {
    currentOrder.value = OrderModel();
    await AudioPlayerService.playSound(false);
    update();
  }

  RxBool isChange = false.obs;

  Future<void> changeData() async {
    log("🟡 [changeData] Boshlandi :: orderId=${currentOrder.value.id} status=${currentOrder.value.status} mapType=${Constant.mapType} selectedMapType=${Constant.selectedMapType}");
    print(
        "currentOrder.value.status :: ${currentOrder.value.id} :: ${currentOrder.value.status} :: ( ${orderModel.value.driver?.vendorID != null} :: ${orderModel.value.status})");

    if (Constant.mapType == "inappmap") {
      log("🟡 [changeData] getDirections (Yandex) chaqirilmoqda...");
      await getDirections();
      log("🟡 [changeData] getDirections tugadi");
    } else {
      log("🟡 [changeData] mapType!=inappmap, getDirections chaqirilmoqda...");
      await getDirections();
      log("🟡 [changeData] getDirections tugadi");
    }
    update();
    log("🟡 [changeData] update() chaqirildi");

    if (currentOrder.value.status == Constant.driverPending) {
      await AudioPlayerService.playSound(true);
    } else {
      await AudioPlayerService.playSound(false);
    }
    log("🟡 [changeData] Tugadi");
  }

  /// Doimiy stream: driver dokumentiga eshitadi. Yangi zakaz qo‘shilganda (orderRequestData)
  /// backend yangilaganda stream yangilanadi, getCurrentOrder() yangi zakazni ko‘rsatadi.
  /// Bildirishnoma kelmasa ham yangi zakaz shu orqali chiqadi.
  void listenToDriverAndOrders() {
    _driverSubscription?.cancel();
    _driverSubscription = FireStoreUtils.fireStore
        .collection(CollectionName.users)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen(
      (event) async {
        if (event.exists) {
          driverModel.value = UserModel.fromJson(event.data()!);

          if (Constant.locationDataFinal != null &&
              Constant.locationDataFinal!.latitude != null &&
              Constant.locationDataFinal!.longitude != null) {
            driverModel.value.location = UserLocation(
              latitude: Constant.locationDataFinal!.latitude!,
              longitude: Constant.locationDataFinal!.longitude!,
            );
            debugPrint(
                "📍 getDriver: Updated driverModel.location with GPS: ${driverModel.value.location?.latitude}, ${driverModel.value.location?.longitude}");
          }

          _updateCurrentLocationMarkers();
          if (driverModel.value.id != null) {
            isLoading.value = false;
            update();
            log("🟢 [getDriver] stream yangilandi, changeData() va getCurrentOrder() chaqirilmoqda");
            changeData();
            getCurrentOrder();
          }
        }
      },
    );
  }

  void getDriver() => listenToDriverAndOrders();

  GoogleMapController? mapController;
  ym.YandexMapController? yandexMapController;

  Rx<PolylinePoints> polylinePoints =
      PolylinePoints(apiKey: Constant.mapAPIKey).obs;
  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
  RxMap<String, Marker> markers = <String, Marker>{}.obs;

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;
  BitmapDescriptor? taxiIcon;

  Future<void> setIcons() async {
    final Uint8List departure = await Constant()
        .getBytesFromAsset('assets/images/location_black3x.png', 100);
    final Uint8List destination = await Constant()
        .getBytesFromAsset('assets/images/location_orange3x.png', 100);
    final Uint8List driver = await Constant()
        .getBytesFromAsset('assets/images/food_delivery.png', 110);

    departureIcon = BitmapDescriptor.fromBytes(departure);
    destinationIcon = BitmapDescriptor.fromBytes(destination);
    taxiIcon = BitmapDescriptor.fromBytes(driver);
  }

  Future<void> getDirections() async {
    log("🔵 [getDirections] Boshlandi");
    final order = currentOrder.value;
    final driver = driverModel.value;

    // 1️⃣ Safety checks
    if (order.id == null) {
      log("⚠️ [getDirections] Order ID null, chiqilmoqda");
      debugPrint("⚠️ getDirections: Order ID is null");
      return;
    }
    log("🔵 [getDirections] orderId=${order.id} status=${order.status} vendorLat=${order.vendor?.latitude} vendorLng=${order.vendor?.longitude}");

    // ✅ Mavjud lokatsiyadan darhol foydalanish (getLocation() bloklamaslik uchun)
    // Yangi GPS keyinroq backgroundda yangilanishi mumkin
    if (Constant.locationDataFinal == null ||
        Constant.locationDataFinal!.latitude == null ||
        Constant.locationDataFinal!.longitude == null) {
      try {
        final locationService = Location();
        final freshLocation = await locationService.getLocation().timeout(
              const Duration(seconds: 2),
              onTimeout: () => throw TimeoutException('getLocation 2s'),
            );
        if (freshLocation.latitude != null && freshLocation.longitude != null) {
          Constant.locationDataFinal = freshLocation;
          log("🔵 [getDirections] Fresh GPS olindi: ${freshLocation.latitude}, ${freshLocation.longitude}");
        }
      } catch (e) {
        log("🔵 [getDirections] Fresh GPS olinnadi, mavjuddan foydalanamiz: $e");
      }
    }

    // ✅ Use current GPS location if available, otherwise fallback to driver.location
    UserLocation? driverLoc;
    if (Constant.locationDataFinal != null &&
        Constant.locationDataFinal!.latitude != null &&
        Constant.locationDataFinal!.longitude != null) {
      // Use current GPS location (most accurate)
      driverLoc = UserLocation(
        latitude: Constant.locationDataFinal!.latitude!,
        longitude: Constant.locationDataFinal!.longitude!,
      );
      debugPrint(
          "📍 getDirections: Using current GPS location: ${driverLoc.latitude}, ${driverLoc.longitude}");
    } else {
      // Fallback to driver.location from Firestore
      driverLoc = driver.location;
      debugPrint(
          "📍 getDirections: Using driver.location from Firestore: ${driverLoc?.latitude}, ${driverLoc?.longitude}");
    }

    if (driverLoc == null) {
      log("⚠️ [getDirections] Driver location null, chiqilmoqda");
      debugPrint("⚠️ getDirections: Driver location is null");
      return;
    }
    log("🔵 [getDirections] driverLoc: ${driverLoc.latitude}, ${driverLoc.longitude}");

    // 2️⃣ Get start and end coordinates based on order status
    LatLng? origin;
    LatLng? destination;

    switch (order.status) {
      // Driver dan Restaurant gacha (yangilangan order qabul qilingan)
      case Constant.driverPending:
      case Constant.driverAccepted:
        origin = LatLng(driverLoc.latitude ?? 0.0, driverLoc.longitude ?? 0.0);
        destination =
            _toLatLng(order.vendor?.latitude, order.vendor?.longitude);
        break;

      // Driver dan Restaurant gacha (order olib ketilmoqda)
      case Constant.orderShipped:
        origin = LatLng(driverLoc.latitude ?? 0.0, driverLoc.longitude ?? 0.0);
        destination =
            _toLatLng(order.vendor?.latitude, order.vendor?.longitude);
        break;

      // Restaurant dan Mijozgacha (yetkazilmoqda)
      case Constant.orderInTransit:
        origin = _toLatLng(order.vendor?.latitude, order.vendor?.longitude);
        destination = _toLatLng(
          order.address?.location?.latitude,
          order.address?.location?.longitude,
        );
        break;

      default:
        debugPrint("⚠️ getDirections: Unknown order status ${order.status}");
        return;
    }

    if (origin == null || destination == null) {
      log("⚠️ [getDirections] origin yoki destination null, chiqilmoqda");
      debugPrint("⚠️ getDirections: Missing origin or destination");
      return;
    }
    log("🔵 [getDirections] origin=$origin destination=$destination");

    // 3️⃣ Fetch polyline route
    log("🔵 [getDirections] _fetchPolyline chaqirilmoqda...");
    final polylineCoordinates = await _fetchPolyline(origin, destination);
    log("🔵 [getDirections] polyline nuqtalar soni: ${polylineCoordinates.length}");
    if (polylineCoordinates.isEmpty) {
      debugPrint(
          "⚠️ getDirections: No route found between origin and destination");
    }

    // 4️⃣ Update markers safely - clear all existing markers first
    markers.clear();

    // Restaurant marker — yashil (barcha holatlarda)
    if (order.vendor?.latitude != null && order.vendor?.longitude != null) {
      markers['Restaurant'] = Marker(
        markerId: const MarkerId('Restaurant'),
        infoWindow: InfoWindow(title: order.vendor?.title ?? "Restaurant"),
        position: _toLatLng(order.vendor?.latitude, order.vendor?.longitude) ??
            const LatLng(0, 0),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
    }

    // Mijoz marker — qizil (orderInTransit holatida ko'rsatiladi)
    if (order.status == Constant.orderInTransit &&
        order.address?.location?.latitude != null &&
        order.address?.location?.longitude != null) {
      markers['Customer'] = Marker(
        markerId: const MarkerId('Customer'),
        infoWindow: InfoWindow(title: order.author?.firstName ?? "Customer"),
        position: _toLatLng(
              order.address?.location?.latitude,
              order.address?.location?.longitude,
            ) ??
            const LatLng(0, 0),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
    }

    // Kurier/haydovchi marker — qizil
    // Double-check that we're using the most current GPS location
    LatLng driverMarkerPosition;
    if (Constant.locationDataFinal != null &&
        Constant.locationDataFinal!.latitude != null &&
        Constant.locationDataFinal!.longitude != null) {
      driverMarkerPosition = LatLng(
        Constant.locationDataFinal!.latitude!,
        Constant.locationDataFinal!.longitude!,
      );
      debugPrint(
          "📍 getDirections: Driver marker using GPS: ${driverMarkerPosition.latitude}, ${driverMarkerPosition.longitude}");
    } else {
      driverMarkerPosition = LatLng(
        driverLoc.latitude ?? 0.0,
        driverLoc.longitude ?? 0.0,
      );
      debugPrint(
          "📍 getDirections: Driver marker using driverLoc (fallback): ${driverMarkerPosition.latitude}, ${driverMarkerPosition.longitude}");
    }

    markers['Driver'] = Marker(
      markerId: const MarkerId('Driver'),
      infoWindow: const InfoWindow(title: "Driver"),
      position: driverMarkerPosition,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      rotation: double.tryParse(driver.rotation.toString()) ?? 0,
      anchor: const Offset(0.5, 0.5),
      flat: true,
    );

    // 5️⃣ Draw polyline
    addPolyLine(polylineCoordinates);
    markers.refresh();
    polyLines.refresh();
    update();
    log("🔵 [getDirections] Tugadi: markers=${markers.length} polyLines=${polyLines.length}");
  }

  /// Helper: safely convert to LatLng if valid
  LatLng? _toLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  /// Helper: fetch polyline safely
  Future<List<LatLng>> _fetchPolyline(LatLng origin, LatLng destination) async {
    try {
      final result = await polylinePoints.value.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isEmpty) return [];

      return result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    } catch (e, st) {
      debugPrint("❌ getDirections _fetchPolyline error: $e\n$st");
      return [];
    }
  }

  void addPolyLine(List<LatLng> polylineCoordinates) {
    log("🟣 [addPolyLine] polyline nuqtalar=${polylineCoordinates.length}");
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: AppThemeData.primary300,
      points: polylineCoordinates,
      width: 8,
      geodesic: true,
    );
    polyLines[id] = polyline;
    log("🟣 [addPolyLine] polyLines.length=${polyLines.length}, update() chaqirilmoqda");
    update();

    // ✅ Use current GPS location for camera if available, otherwise use polyline start
    LatLng cameraTarget;
    if (Constant.locationDataFinal != null &&
        Constant.locationDataFinal!.latitude != null &&
        Constant.locationDataFinal!.longitude != null) {
      cameraTarget = LatLng(
        Constant.locationDataFinal!.latitude!,
        Constant.locationDataFinal!.longitude!,
      );
      debugPrint(
          "📍 addPolyLine: Camera using current GPS location: ${cameraTarget.latitude}, ${cameraTarget.longitude}");
    } else if (polylineCoordinates.isNotEmpty) {
      cameraTarget = polylineCoordinates.first;
      debugPrint(
          "📍 addPolyLine: Camera using polyline start: ${cameraTarget.latitude}, ${cameraTarget.longitude}");
    } else {
      // Fallback to current.value if available
      cameraTarget = LatLng(current.value.latitude, current.value.longitude);
      debugPrint(
          "📍 addPolyLine: Camera using current.value: ${cameraTarget.latitude}, ${cameraTarget.longitude}");
    }

    updateCameraLocation(cameraTarget, mapController);
  }

  Future<void> updateCameraLocation(
    LatLng source,
    GoogleMapController? mapController,
  ) async {
    if (Constant.isYandexMap) {
      if (yandexMapController == null) return;
      await yandexMapController!.moveCamera(
        ym.CameraUpdate.newCameraPosition(
          ym.CameraPosition(
            target: yandexPointFromLatLng(source),
            zoom: currentOrder.value.id == null ||
                    currentOrder.value.status == Constant.driverPending
                ? 16
                : 20,
          ),
        ),
      );
      return;
    }
    if (mapController == null) return;
    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: source,
          zoom: currentOrder.value.id == null ||
                  currentOrder.value.status == Constant.driverPending
              ? 16
              : 20,
          bearing: double.parse(driverModel.value.rotation.toString()),
        ),
      ),
    );
  }

  void animateToSource() {
    double lat = 0.0;
    double lng = 0.0;

    // ✅ ALWAYS prioritize current GPS location over Firestore location
    if (Constant.locationDataFinal != null &&
        Constant.locationDataFinal!.latitude != null &&
        Constant.locationDataFinal!.longitude != null) {
      // Use current GPS location (most accurate)
      lat = Constant.locationDataFinal!.latitude!;
      lng = Constant.locationDataFinal!.longitude!;
      debugPrint("📍 animateToSource: Using current GPS location: $lat, $lng");
    } else {
      // Fallback to driverModel.location from Firestore
      final loc = driverModel.value.location;
      if (loc != null) {
        // Use string parsing to avoid nullable-toDouble issues and handle numbers/strings.
        lat = double.tryParse('${loc.latitude}') ?? 0.0;
        lng = double.tryParse('${loc.longitude}') ?? 0.0;
      }
    }

    // If location is invalid (0,0), use default location (Tashkent)
    if (lat == 0.0 && lng == 0.0) {
      lat = 41.3111;
      lng = 69.2797;
      debugPrint(
          "📍 animateToSource: Using default location (Tashkent): $lat, $lng");
    }

    _updateCurrentLocationMarkers();
    try {
      if (yandexMapController != null && (lat != 0.0 || lng != 0.0)) {
        yandexMapController!.moveCamera(
          ym.CameraUpdate.newCameraPosition(
            ym.CameraPosition(
              target: ym.Point(latitude: lat, longitude: lng),
              zoom: 16,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Yandex map move error: $e");
    }
  }

  void _updateCurrentLocationMarkers() async {
    try {
      // ✅ ALWAYS prioritize current GPS location over Firestore location
      LatLng latLng;

      if (Constant.locationDataFinal != null &&
          Constant.locationDataFinal!.latitude != null &&
          Constant.locationDataFinal!.longitude != null) {
        // Use current GPS location (most accurate and up-to-date)
        latLng = LatLng(
          Constant.locationDataFinal!.latitude!,
          Constant.locationDataFinal!.longitude!,
        );
        debugPrint(
            "📍 _updateCurrentLocationMarkers: Using current GPS location: ${latLng.latitude}, ${latLng.longitude}");
      } else {
        // Fallback to driverModel.location from Firestore
        final loc = driverModel.value.location;
        latLng = _safeLatLngFromLocation(loc);
        debugPrint(
            "📍 _updateCurrentLocationMarkers: Using driverModel.location (fallback): ${latLng.latitude}, ${latLng.longitude}");
      }

      // If still 0,0, use default location (Tashkent)
      if (latLng.latitude == 0.0 && latLng.longitude == 0.0) {
        latLng = const LatLng(41.3111, 69.2797);
        debugPrint(
            "📍 Using default location (Tashkent): ${latLng.latitude}, ${latLng.longitude}");
      }

      // Update reactive current location
      current.value = location.LatLng(latLng.latitude, latLng.longitude);
      debugPrint(
          "📍 Final current.value = ${current.value.latitude}, ${current.value.longitude}");

      // --- Yandex Map Section ---
      try {
        // Skip if icons are not loaded yet
        {
          // Remove old driver marker
          markers.remove("Driver");

          // Kurier marker — qizil
          markers["Driver"] = Marker(
            markerId: const MarkerId("Driver"),
            infoWindow: const InfoWindow(title: "Driver"),
            position: LatLng(current.value.latitude, current.value.longitude),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            rotation: _safeRotation(),
            anchor: const Offset(0.5, 0.5),
            flat: true,
          );

          // Animate camera to current driver location
          if (Constant.isYandexMap) {
            if (yandexMapController != null &&
                !(current.value.latitude == 0.0 &&
                    current.value.longitude == 0.0)) {
              await yandexMapController!.moveCamera(
                ym.CameraUpdate.newCameraPosition(
                  ym.CameraPosition(
                    target: ym.Point(
                      latitude: current.value.latitude,
                      longitude: current.value.longitude,
                    ),
                    zoom: 16,
                  ),
                ),
              );
            }
          } else {
            if (mapController != null &&
                !(current.value.latitude == 0.0 &&
                    current.value.longitude == 0.0)) {
              mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target:
                        LatLng(current.value.latitude, current.value.longitude),
                    zoom: 16,
                    bearing: _safeRotation(),
                  ),
                ),
              );
            }
          }
        }
      } catch (e) {
        print("Google map update ignored (controller not ready): $e");
      }

      // --- GOOGLE MAP Section ---
      // Google Maps markers are updated via getDirections() method

      update();
    } catch (e) {
      print("_updateCurrentLocationMarkers error: $e");
    }
  }

  double _safeRotation() {
    return double.tryParse(driverModel.value.rotation.toString()) ?? 0.0;
  }

  LatLng _safeLatLngFromLocation(dynamic loc) {
    final lat = (loc?.latitude is num) ? loc.latitude.toDouble() : 0.0;
    final lng = (loc?.longitude is num) ? loc.longitude.toDouble() : 0.0;
    return LatLng(lat, lng);
  }

  Rx<location.LatLng> source = location.LatLng(0.0, 0.0).obs; // Start (unset)
  Rx<location.LatLng> current =
      location.LatLng(0.0, 0.0).obs; // Moving marker (unset)
  Rx<location.LatLng> destination =
      location.LatLng(0.0, 0.0).obs; // Destination (unset)

  /// Open Yandex Maps directly with directions
  Future<void> showMapSelectionDialog() async {
    final order = currentOrder.value;

    // Get origin (driver current location)
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
      // Going to restaurant (vendor)
      destLat = (order.vendor?.latitude as num?)?.toDouble() ?? 0.0;
      destLng = (order.vendor?.longitude as num?)?.toDouble() ?? 0.0;
    } else if (order.status == Constant.orderInTransit) {
      // Going to customer (address)
      destLat = (order.address?.location?.latitude as num?)?.toDouble() ?? 0.0;
      destLng = (order.address?.location?.longitude as num?)?.toDouble() ?? 0.0;
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
      debugPrint("Error opening Yandex Maps: $e");
      ShowToastDialog.showToast("Error opening Yandex Maps".tr);
    }
  }
}
