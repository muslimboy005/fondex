import 'dart:async';
import 'dart:convert';
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
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as location;
import 'package:yandex_mapkit/yandex_mapkit.dart' as yandex;
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';

import '../models/order_model.dart';

class HomeController extends GetxController {
  RxBool isLoading = true.obs;
  flutterMap.MapController osmMapController = flutterMap.MapController();
  yandex.YandexMapController? yandexMapController;
  RxList<flutterMap.Marker> osmMarkers = <flutterMap.Marker>[].obs;
  RxList<yandex.PlacemarkMapObject> yandexPlacemarks =
      <yandex.PlacemarkMapObject>[].obs;
  RxList<yandex.PolylineMapObject> yandexPolylines =
      <yandex.PolylineMapObject>[].obs;

  // Track order subscription to cancel previous ones
  StreamSubscription? _orderSubscription;

  @override
  void onInit() {
    getArgument();
    setIcons();
    getDriver();
    requestLocationPermission();
    super.onInit();
  }

  @override
  void onClose() {
    // Cancel order subscription to prevent memory leaks
    _orderSubscription?.cancel();
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
    await AudioPlayerService.playSound(false);
    ShowToastDialog.showLoader("Please wait".tr);
    driverModel.value.inProgressOrderID ?? [];
    driverModel.value.orderRequestData!.remove(currentOrder.value.id);
    driverModel.value.inProgressOrderID!.add(currentOrder.value.id);

    await FireStoreUtils.updateUser(driverModel.value);

    currentOrder.value.status = Constant.driverAccepted;
    currentOrder.value.driverID = driverModel.value.id;
    currentOrder.value.driver = driverModel.value;

    await FireStoreUtils.setOrder(currentOrder.value);
    print("SendNotification ===========>");
    SendNotification.sendFcmMessage(Constant.driverAcceptedNotification,
        currentOrder.value.author?.fcmToken ?? '', {});
    SendNotification.sendFcmMessage(Constant.driverAcceptedNotification,
        currentOrder.value.vendor?.fcmToken ?? '', {});
    ShowToastDialog.closeLoader();
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
    if (Constant.selectedMapType != 'osm') {
      markers.clear();
      polyLines.clear();
    } else {
      osmMarkers.clear();
      routePoints.clear();
      // osmMapController = flutterMap.MapController();
    }
    update();
  }

  Future<void> getCurrentOrder() async {
    final driver = driverModel.value;
    final currentId = currentOrder.value.id;

    // 1️⃣ Reset if current order is invalid
    if (currentId != null &&
        !(driver.orderRequestData?.contains(currentId) ?? false) &&
        !(driver.inProgressOrderID?.contains(currentId) ?? false)) {
      await _resetCurrentOrder();
      return;
    }

    // 2️⃣ Handle single-order mode
    if (Constant.singleOrderReceive == true) {
      final inProgress = driver.inProgressOrderID;
      final requests = driver.orderRequestData;

      if (inProgress != null && inProgress.isNotEmpty) {
        _listenToOrder(inProgress.first);
        return;
      }

      if (requests != null && requests.isNotEmpty) {
        _listenToOrder(requests.first, checkInRequestData: true);
        return;
      }
    }

    // 3️⃣ Handle fallback (when orderModel has ID)
    final fallbackId = orderModel.value.id;
    if (fallbackId != null) {
      _listenToOrder(fallbackId);
    }
  }

  Future<void> _resetCurrentOrder() async {
    currentOrder.value = OrderModel();
    await clearMap();
    await AudioPlayerService.playSound(false);
    update();
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
    print(
        "currentOrder.value.status :: ${currentOrder.value.id} :: ${currentOrder.value.status} :: ( ${orderModel.value.driver?.vendorID != null} :: ${orderModel.value.status})");

    if (Constant.mapType == "inappmap") {
      if (Constant.selectedMapType == "osm") {
        getOSMPolyline();
      } else {
        getDirections();
      }
    }
    if (currentOrder.value.status == Constant.driverPending) {
      await AudioPlayerService.playSound(true);
    } else {
      await AudioPlayerService.playSound(false);
    }
  }

  void getDriver() {
    FireStoreUtils.fireStore
        .collection(CollectionName.users)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen(
      (event) async {
        if (event.exists) {
          driverModel.value = UserModel.fromJson(event.data()!);

          // If driver location is null or 0,0, try to use GPS location from Constant
          if ((driverModel.value.location == null ||
                  driverModel.value.location!.latitude == null ||
                  driverModel.value.location!.latitude == 0.0) &&
              Constant.locationDataFinal != null) {
            // Update driver model with GPS location temporarily for display
            driverModel.value.location = UserLocation(
              latitude: Constant.locationDataFinal!.latitude ?? 0.0,
              longitude: Constant.locationDataFinal!.longitude ?? 0.0,
            );
          }

          _updateCurrentLocationMarkers();
          if (driverModel.value.id != null) {
            isLoading.value = false;
            update();
            changeData();
            getCurrentOrder();
          }
        }
      },
    );
  }

  GoogleMapController? mapController;

  Rx<PolylinePoints> polylinePoints =
      PolylinePoints(apiKey: Constant.mapAPIKey).obs;
  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
  RxMap<String, Marker> markers = <String, Marker>{}.obs;

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;
  BitmapDescriptor? taxiIcon;

  Future<void> setIcons() async {
    if (Constant.selectedMapType == 'google') {
      final Uint8List departure = await Constant()
          .getBytesFromAsset('assets/images/location_black3x.png', 100);
      final Uint8List destination = await Constant()
          .getBytesFromAsset('assets/images/location_orange3x.png', 100);
      final Uint8List driver = await Constant()
          .getBytesFromAsset('assets/images/food_delivery.png', 120);

      departureIcon = BitmapDescriptor.fromBytes(departure);
      destinationIcon = BitmapDescriptor.fromBytes(destination);
      taxiIcon = BitmapDescriptor.fromBytes(driver);
    }
  }

  Future<void> getDirections() async {
    final order = currentOrder.value;
    final driver = driverModel.value;

    // 1️⃣ Safety checks
    if (order.id == null) {
      debugPrint("⚠️ getDirections: Order ID is null");
      return;
    }

    final driverLoc = driver.location;
    if (driverLoc == null) {
      debugPrint("⚠️ getDirections: Driver location is null");
      return;
    }

    // Icons must be loaded before proceeding
    if (taxiIcon == null || destinationIcon == null || departureIcon == null) {
      debugPrint("⚠️ getDirections: One or more map icons are null");
      return;
    }

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
      debugPrint("⚠️ getDirections: Missing origin or destination");
      return;
    }

    // 3️⃣ Fetch polyline route
    final polylineCoordinates = await _fetchPolyline(origin, destination);
    if (polylineCoordinates.isEmpty) {
      debugPrint(
          "⚠️ getDirections: No route found between origin and destination");
    }

    // 4️⃣ Update markers safely - clear all existing markers first
    markers.clear();

    // Restaurant marker (barcha holatlarda ko'rsatiladi)
    if (order.vendor?.latitude != null && order.vendor?.longitude != null) {
      markers['Restaurant'] = Marker(
        markerId: const MarkerId('Restaurant'),
        infoWindow: InfoWindow(title: order.vendor?.title ?? "Restaurant"),
        position: _toLatLng(order.vendor?.latitude, order.vendor?.longitude) ??
            const LatLng(0, 0),
        icon: departureIcon!,
      );
    }

    // Mijoz marker (orderInTransit holatida ko'rsatiladi)
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
        icon: destinationIcon!,
      );
    }

    markers['Driver'] = Marker(
      markerId: const MarkerId('Driver'),
      infoWindow: const InfoWindow(title: "Driver"),
      position: LatLng(
        driverLoc.latitude ?? 0.0, // ✅ safe fallback
        driverLoc.longitude ?? 0.0, // ✅ safe fallback
      ),
      icon: taxiIcon!,
      rotation: double.tryParse(driver.rotation.toString()) ?? 0,
    );

    // 5️⃣ Draw polyline
    addPolyLine(polylineCoordinates);
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
    // mapOsmController.clearAllRoads();
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: AppThemeData.primary300,
      points: polylineCoordinates,
      width: 8,
      geodesic: true,
    );
    polyLines[id] = polyline;
    update();
    updateCameraLocation(polylineCoordinates.first, mapController);
  }

  Future<void> updateCameraLocation(
    LatLng source,
    GoogleMapController? mapController,
  ) async {
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
    final loc = driverModel.value.location;
    if (loc != null) {
      // Use string parsing to avoid nullable-toDouble issues and handle numbers/strings.
      lat = double.tryParse('${loc.latitude}') ?? 0.0;
      lng = double.tryParse('${loc.longitude}') ?? 0.0;
    }

    // If location is invalid (0,0), use default location (Tashkent)
    if (lat == 0.0 && lng == 0.0) {
      lat = 41.3111;
      lng = 69.2797;
    }

    _updateCurrentLocationMarkers();
    try {
      osmMapController.move(location.LatLng(lat, lng), 16);
    } catch (e) {
      debugPrint("OSM map move error: $e");
    }
  }

  void _updateCurrentLocationMarkers() async {
    try {
      final loc = driverModel.value.location;
      var latLng = _safeLatLngFromLocation(loc);

      debugPrint(
          "📍 _updateCurrentLocationMarkers: driverModel.location = ${loc?.latitude}, ${loc?.longitude}");
      debugPrint(
          "📍 Constant.locationDataFinal = ${Constant.locationDataFinal?.latitude}, ${Constant.locationDataFinal?.longitude}");

      // If location is 0,0, try to get from Constant.locationDataFinal (GPS)
      if (latLng.latitude == 0.0 && latLng.longitude == 0.0) {
        if (Constant.locationDataFinal != null) {
          latLng = LatLng(
            Constant.locationDataFinal!.latitude ?? 0.0,
            Constant.locationDataFinal!.longitude ?? 0.0,
          );
          debugPrint(
              "📍 Using GPS location from Constant.locationDataFinal: ${latLng.latitude}, ${latLng.longitude}");
        }
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

      // --- OSM Section ---
      try {
        setOsmMapMarker();

        if (latLng.latitude != 0.0 || latLng.longitude != 0.0) {
          osmMapController.move(
              location.LatLng(latLng.latitude, latLng.longitude), 16);
        }
      } catch (e) {
        print("OSM map move ignored (controller not ready): $e");
      }

      // --- GOOGLE MAP Section ---
      try {
        // Skip if icons are not loaded yet
        if (taxiIcon != null) {
          // Remove old driver marker
          markers.remove("Driver");

          // Create new Google Marker
          markers["Driver"] = Marker(
            markerId: const MarkerId("Driver"),
            infoWindow: const InfoWindow(title: "Driver"),
            position: LatLng(current.value.latitude, current.value.longitude),
            icon: taxiIcon!,
            rotation: _safeRotation(),
            anchor: const Offset(0.5, 0.5),
            flat: true,
          );

          // Animate camera to current driver location
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
      } catch (e) {
        print("Google map update ignored (controller not ready): $e");
      }

      // --- YANDEX MAP Section ---
      if (Constant.selectedMapType == "yandex") {
        updateYandexMarkers();
      }

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

  Rx<location.LatLng> source =
      location.LatLng(21.1702, 72.8311).obs; // Start (e.g., Surat)
  Rx<location.LatLng> current =
      location.LatLng(21.1800, 72.8400).obs; // Moving marker
  Rx<location.LatLng> destination =
      location.LatLng(21.2000, 72.8600).obs; // Destination

  /// Update Yandex Map markers
  Future<void> updateYandexMarkers() async {
    try {
      final placemarks = <yandex.PlacemarkMapObject>[];

      // Driver marker
      if (!(current.value.latitude == 0.0 && current.value.longitude == 0.0)) {
        try {
          final driverIcon = yandex.BitmapDescriptor.fromAssetImage(
            'assets/images/food_delivery.png',
          );
          placemarks.add(
            yandex.PlacemarkMapObject(
              mapId: const yandex.MapObjectId('driver'),
              point: yandex.Point(
                latitude: current.value.latitude,
                longitude: current.value.longitude,
              ),
              opacity: 1.0, // Opacity yo'q - to'liq ko'rinadi
              icon: yandex.PlacemarkIcon.single(
                yandex.PlacemarkIconStyle(
                  image: driverIcon,
                  scale: 1.5,
                  rotationType: yandex.RotationType.rotate,
                ),
              ),
            ),
          );
          log("✅ Driver marker yaratildi: ${current.value.latitude}, ${current.value.longitude}");
        } catch (e) {
          log("❌ Driver marker yaratishda xatolik: $e");
        }
      }

      // Source marker (pickup)
      if (!(source.value.latitude == 0.0 && source.value.longitude == 0.0)) {
        try {
          final sourceIcon = yandex.BitmapDescriptor.fromAssetImage(
            'assets/images/location_black3x.png',
          );
          placemarks.add(
            yandex.PlacemarkMapObject(
              mapId: const yandex.MapObjectId('source'),
              point: yandex.Point(
                latitude: source.value.latitude,
                longitude: source.value.longitude,
              ),
              opacity: 1.0, // Opacity yo'q - to'liq ko'rinadi
              icon: yandex.PlacemarkIcon.single(
                yandex.PlacemarkIconStyle(
                  image: sourceIcon,
                  scale: 1.0,
                ),
              ),
            ),
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
          final destIcon = yandex.BitmapDescriptor.fromAssetImage(
            'assets/images/location_orange3x.png',
          );
          placemarks.add(
            yandex.PlacemarkMapObject(
              mapId: const yandex.MapObjectId('destination'),
              point: yandex.Point(
                latitude: destination.value.latitude,
                longitude: destination.value.longitude,
              ),
              opacity: 1.0, // Opacity yo'q - to'liq ko'rinadi
              icon: yandex.PlacemarkIcon.single(
                yandex.PlacemarkIconStyle(
                  image: destIcon,
                  scale: 1.0,
                ),
              ),
            ),
          );
          log("✅ Destination marker yaratildi: ${destination.value.latitude}, ${destination.value.longitude}");
        } catch (e) {
          log("❌ Destination marker yaratishda xatolik: $e");
        }
      }

      log("📍 [updateYandexMarkers] Jami ${placemarks.length} ta marker yaratildi");
      yandexPlacemarks.value = placemarks;
      log("📍 [updateYandexMarkers] yandexPlacemarks.value = ${yandexPlacemarks.length} ta marker");

      // Update Yandex map camera if controller is ready
      if (yandexMapController != null &&
          !(current.value.latitude == 0.0 && current.value.longitude == 0.0)) {
        yandexMapController!.moveCamera(
          yandex.CameraUpdate.newCameraPosition(
            yandex.CameraPosition(
              target: yandex.Point(
                latitude: current.value.latitude,
                longitude: current.value.longitude,
              ),
              zoom: 16,
            ),
          ),
          animation: const yandex.MapAnimation(
            type: yandex.MapAnimationType.smooth,
            duration: 1.0,
          ),
        );
      }
    } catch (e) {
      debugPrint("Yandex map markers update error: $e");
    }
  }

  void setOsmMapMarker() {
    final markers = <flutterMap.Marker>[];
    final order = currentOrder.value;

    // Driver marker - always show if location is valid
    if (!(current.value.latitude == 0.0 && current.value.longitude == 0.0)) {
      debugPrint(
          "📍 Creating driver marker at: ${current.value.latitude}, ${current.value.longitude}");
      markers.add(
        flutterMap.Marker(
          point: current.value,
          width: 45,
          height: 45,
          rotate: true,
          child: Image.asset('assets/images/food_delivery.png'),
        ),
      );
    } else {
      debugPrint("⚠️ Driver location is 0,0 - marker not created");
    }

    // Restaurant marker - show in all states if vendor location is valid
    if (order.vendor?.latitude != null && order.vendor?.longitude != null) {
      final restaurantLat = order.vendor!.latitude ?? 0.0;
      final restaurantLng = order.vendor!.longitude ?? 0.0;
      if (!(restaurantLat == 0.0 && restaurantLng == 0.0)) {
        markers.add(
          flutterMap.Marker(
            point: location.LatLng(restaurantLat, restaurantLng),
            width: 40,
            height: 40,
            child: Image.asset('assets/images/location_black3x.png'),
          ),
        );
        debugPrint("📍 Restaurant marker at: $restaurantLat, $restaurantLng");
      }
    }

    // Destination marker (Restaurant yoki Customer) - only show if valid and not 0,0
    if (!(destination.value.latitude == 0.0 &&
        destination.value.longitude == 0.0)) {
      markers.add(
        flutterMap.Marker(
          point: destination.value,
          width: 40,
          height: 40,
          child: Image.asset('assets/images/location_orange3x.png'),
        ),
      );
      debugPrint(
          "📍 Destination marker at: ${destination.value.latitude}, ${destination.value.longitude}");
    }

    // Source marker - only show if valid and not 0,0 (legacy support)
    if (!(source.value.latitude == 0.0 && source.value.longitude == 0.0)) {
      markers.add(
        flutterMap.Marker(
          point: source.value,
          width: 40,
          height: 40,
          child: Image.asset('assets/images/location_black3x.png'),
        ),
      );
    }

    osmMarkers.value = markers;
  }

  void getOSMPolyline() async {
    try {
      if (currentOrder.value.id != null) {
        final order = currentOrder.value;
        final driverLoc = driverModel.value.location;

        if (driverLoc == null) {
          print("⚠️ getOSMPolyline: Driver location is null");
          return;
        }

        print(
            "📍 getOSMPolyline: Order Status = ${order.status}, OrderId = ${order.id}");

        // Driver dan Restaurant gacha (driverPending, driverAccepted, orderShipped)
        if (order.status == Constant.driverPending ||
            order.status == Constant.driverAccepted ||
            order.status == Constant.orderShipped) {
          if (order.vendor?.latitude != null &&
              order.vendor?.longitude != null) {
            current.value = location.LatLng(
              driverLoc.latitude ?? 0.0,
              driverLoc.longitude ?? 0.0,
            );
            destination.value = location.LatLng(
              order.vendor!.latitude ?? 0.0,
              order.vendor!.longitude ?? 0.0,
            );
            print(
                "📍 Driver → Restaurant: ${current.value} → ${destination.value}");
            animateToSource();
            fetchRoute(current.value, destination.value).then((value) {
              setOsmMapMarker();
            });
          }
        }
        // Restaurant dan Mijozgacha (orderInTransit)
        else if (order.status == Constant.orderInTransit) {
          if (order.vendor?.latitude != null &&
              order.vendor?.longitude != null &&
              order.address?.location?.latitude != null &&
              order.address?.location?.longitude != null) {
            // Restaurant dan boshlaymiz (driver hozirgi joyi)
            current.value = location.LatLng(
              driverLoc.latitude ?? 0.0,
              driverLoc.longitude ?? 0.0,
            );
            // Mijoz manzili
            destination.value = location.LatLng(
              order.address!.location!.latitude ?? 0.0,
              order.address!.location!.longitude ?? 0.0,
            );
            print(
                "📍 Restaurant → Customer: ${current.value} → ${destination.value}");
            setOsmMapMarker();
            fetchRoute(current.value, destination.value).then((value) {
              setOsmMapMarker();
            });
            animateToSource();
          }
        } else {
          print("⚠️ getOSMPolyline: Unknown order status ${order.status}");
        }
      }
    } catch (e) {
      print('❌ getOSMPolyline Error: $e');
    }
  }

  RxList<location.LatLng> routePoints = <location.LatLng>[].obs;

  Future<void> fetchRoute(
      location.LatLng source, location.LatLng destination) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${source.longitude},${source.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final geometry = decoded['routes'][0]['geometry']['coordinates'];

      routePoints.clear();
      for (var coord in geometry) {
        final lon = coord[0];
        final lat = coord[1];
        routePoints.add(location.LatLng(lat, lon));
      }
    } else {
      print("Failed to get route: ${response.body}");
    }
  }
}
