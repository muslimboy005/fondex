import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math' as maths;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/payment_model/cod_setting_model.dart';
import 'package:customer/models/payment_model/flutter_wave_model.dart';
import 'package:customer/models/payment_model/mercado_pago_model.dart';
import 'package:customer/models/payment_model/mid_trans.dart';
import 'package:customer/models/payment_model/orange_money.dart';
import 'package:customer/models/payment_model/pay_fast_model.dart';
import 'package:customer/models/payment_model/pay_stack_model.dart';
import 'package:customer/models/payment_model/paypal_model.dart';
import 'package:customer/models/payment_model/paytm_model.dart';
import 'package:customer/models/payment_model/razorpay_model.dart';
import 'package:customer/models/payment_model/stripe_model.dart';
import 'package:customer/models/payment_model/wallet_setting_model.dart';
import 'package:customer/models/payment_model/xendit.dart';
import 'package:customer/models/tax_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vehicle_type.dart';
import 'package:customer/models/wallet_transaction_model.dart';
import 'package:customer/payment/MercadoPagoScreen.dart';
import 'package:customer/payment/PayFastScreen.dart';
import 'package:customer/payment/getPaytmTxtToken.dart';
import 'package:customer/payment/midtrans_screen.dart';
import 'package:customer/payment/orangePayScreen.dart';
import 'package:customer/payment/paystack/pay_stack_screen.dart';
import 'package:customer/payment/paystack/pay_stack_url_model.dart';
import 'package:customer/payment/paystack/paystack_url_genrater.dart';
import 'package:customer/payment/stripe_failed_model.dart';
import 'package:customer/payment/xenditModel.dart';
import 'package:customer/payment/xenditScreen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:flutter_paypal/flutter_paypal.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:location/location.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';
import '../screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import '../themes/app_them_data.dart';

class CabBookingController extends GetxController {
  late GoogleMapController mapController;
  final flutterMap.MapController mapOsmController = flutterMap.MapController();

  final Rx<TextEditingController> sourceTextEditController =
      TextEditingController().obs;
  final Rx<TextEditingController> destinationTextEditController =
      TextEditingController().obs;

  final Rx<TextEditingController> couponCodeTextEditController =
      TextEditingController().obs;

  final Rx<Location> currentLocation = Location().obs;

  final RxSet<Marker> markers = <Marker>{}.obs;
  final RxList<flutterMap.Marker> osmMarker = <flutterMap.Marker>[].obs;
  final RxList<latlong.LatLng> routePoints = <latlong.LatLng>[].obs;

  final Rx<LatLng> currentPosition = LatLng(23.0225, 72.5714).obs;

  final Rx<LatLng> departureLatLong = const LatLng(0.0, 0.0).obs;
  final Rx<LatLng> destinationLatLong = const LatLng(0.0, 0.0).obs;
  final Rx<latlong.LatLng> departureLatLongOsm = latlong.LatLng(0.0, 0.0).obs;
  final Rx<latlong.LatLng> destinationLatLongOsm = latlong.LatLng(0.0, 0.0).obs;

  // 2 bosqichli loading - UI tez ko'rinadi, ma'lumotlar keyin to'ldiriladi
  final RxBool isLoading = true.obs;
  final RxBool isInitialLoading = true.obs; // Kritik ma'lumotlar yuklanmoqda
  final RxBool isDataLoading = false.obs; // Qo'shimcha ma'lumotlar yuklanmoqda

  // Caching uchun flag'lar
  static bool _vehicleTypesCached = false;
  static bool _paymentSettingsCached = false;
  static List<VehicleType>? _cachedVehicleTypes;

  final RxDouble distance = 0.0.obs;
  final RxString duration = ''.obs;

  BitmapDescriptor? departureIcon, destinationIcon, taxiIcon, stopIcon;
  Widget? departureIconOsm, destinationIconOsm, taxiIconOsm, stopIconOsm;

  RxList<TaxModel> taxList = <TaxModel>[].obs;
  RxList<VehicleType> vehicleTypes = <VehicleType>[].obs;
  Rx<VehicleType> selectedVehicleType = VehicleType().obs;

  Rx<UserModel> userModel = UserModel().obs;
  Rx<UserModel> driverModel = UserModel().obs;
  Rx<CabOrderModel> currentOrder = CabOrderModel().obs;

  final RxString selectedPaymentMethod = ''.obs;
  final RxString bottomSheetType = 'location'.obs;

  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;

  bool isOsmMapReady = false;

  Rx<CouponModel> selectedCouponModel = CouponModel().obs;

  // Destination search results
  RxList<Map<String, dynamic>> destinationSearchResults =
      <Map<String, dynamic>>[].obs;
  RxBool isSearchingDestination = false.obs;
  RxString searchError = ''.obs; // Network xatosi uchun

  // Focus node for destination search field
  final FocusNode destinationFocusNode = FocusNode();
  final RxBool isDestinationFocused = false.obs;
  bool focusListenerAdded = false; // Flag to ensure listener is added only once

  // Source search results
  RxList<Map<String, dynamic>> sourceSearchResults =
      <Map<String, dynamic>>[].obs;
  RxBool isSearchingSource = false.obs;
  RxString sourceSearchError = ''.obs;

  // Focus node for source search field
  final FocusNode sourceFocusNode = FocusNode();
  final RxBool isSourceFocused = false.obs;
  bool sourceFocusListenerAdded = false;

  // Map picking mode - xaritada joy tanlash rejimi
  RxBool isMapPickingMode = false.obs;
  RxBool isPickingSource = true.obs; // true = source, false = destination
  Rx<latlong.LatLng> tempPickedLocation = latlong.LatLng(0, 0).obs;
  RxString tempPickedAddress = ''.obs;
  RxBool isLoadingAddress = false.obs;

  @override
  void onInit() {
    super.onInit();
    taxList.value = Constant.taxList;
    initData();
  }

  // Optimizatsiya qilingan initData - parallel loading va lazy loading
  Future<void> initData() async {
    try {
      // 1. Kritik bo'lmagan operatsiyalarni parallel bajarish
      final futures = <Future>[];

      // Icons yuklash - parallel
      futures.add(setIcons());

      // Vehicle types yuklash - parallel (cache'dan olish mumkin bo'lsa)
      if (_vehicleTypesCached && _cachedVehicleTypes != null) {
        vehicleTypes.value = _cachedVehicleTypes!;
        if (vehicleTypes.isNotEmpty) {
          selectedVehicleType.value = vehicleTypes.first;
        }
      } else {
        futures.add(_loadVehicleTypes());
      }

      // Location setup - parallel
      if (Constant.currentLocation != null) {
        if (Constant.selectedMapType == 'osm') {
          departureLatLongOsm.value = latlong.LatLng(
            Constant.currentLocation!.latitude,
            Constant.currentLocation!.longitude,
          );
        } else {
          departureLatLong.value = LatLng(
            Constant.currentLocation!.latitude,
            Constant.currentLocation!.longitude,
          );
        }
        setDepartureMarker(
          Constant.currentLocation!.latitude,
          Constant.currentLocation!.longitude,
        );
      }

      // Barcha parallel operatsiyalarni kutish
      await Future.wait(futures);

      // 2. Initial loading tugadi - UI ko'rinadi
      isInitialLoading.value = false;
      isLoading.value = false;

      // 3. To'lov turlarini yuklash - CabBookingScreen uchun kerak
      await loadPaymentSettingsIfNeeded();

      // 4. Background'da qolgan operatsiyalarni bajarish
      _loadBackgroundData();

      // 5. Reverse geocoding ni background'da bajarish (kutmaslik)
      if (Constant.currentLocation != null) {
        _loadPlaceNameInBackground();
      }

      // 6. Firebase listener'larni ishga tushirish
      _setupFirebaseListeners();

      // 6. Destination check
      if (Constant.selectedMapType == 'osm') {
        if (destinationLatLongOsm.value.latitude != 0.0 &&
            destinationLatLongOsm.value.longitude != 0.0) {
          bottomSheetType.value = 'vehicleSelection';
        }
      } else {
        if (destinationLatLong.value.latitude != 0.0 &&
            destinationLatLong.value.longitude != 0.0) {
          bottomSheetType.value = 'vehicleSelection';
        }
      }
    } catch (e) {
      log("Error in initData: $e");
      isInitialLoading.value = false;
      isLoading.value = false;
    }
  }

  // Vehicle types ni yuklash (cache bilan)
  Future<void> _loadVehicleTypes() async {
    try {
      final vehicleList = await FireStoreUtils.getVehicleType();
      vehicleTypes.value = vehicleList;
      _cachedVehicleTypes = vehicleList;
      _vehicleTypesCached = true;
      if (vehicleTypes.isNotEmpty) {
        selectedVehicleType.value = vehicleTypes.first;
      }
    } catch (e) {
      log("Error loading vehicle types: $e");
    }
  }

  // Background'da qolgan ma'lumotlarni yuklash
  Future<void> _loadBackgroundData() async {
    isDataLoading.value = true;
    try {
      // Payment settings ni lazy load qilish (faqat kerak bo'lganda)
      // Kuponlar ni lazy load qilish (faqat kerak bo'lganda)
      // Bu operatsiyalar keyinroq, kerak bo'lganda yuklanadi
    } catch (e) {
      log("Error in background data loading: $e");
    } finally {
      isDataLoading.value = false;
    }
  }

  // Place name ni background'da yuklash (kutmaslik)
  Future<void> _loadPlaceNameInBackground() async {
    try {
      if (Constant.selectedMapType == 'osm') {
        await searchPlaceNameOSM();
      } else {
        await searchPlaceNameGoogle();
      }
    } catch (e) {
      log("Error loading place name: $e");
    }
  }

  // Firebase listener'larni sozlash
  void _setupFirebaseListeners() {
    // User listener ni keyinroq ishga tushirish
    Future.delayed(const Duration(milliseconds: 500), () {
      _setupUserListener();
    });
  }

  // User listener ni sozlash
  void _setupUserListener() {
    FireStoreUtils.fireStore
        .collection(CollectionName.users)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen((userSnapshot) async {
          if (!userSnapshot.exists) return;

          userModel.value = UserModel.fromJson(userSnapshot.data()!);

          if (userModel.value.inProgressOrderID != null &&
              userModel.value.inProgressOrderID!.isNotEmpty) {
            String? validRideId;

            for (String id in userModel.value.inProgressOrderID!) {
              final rideDoc =
                  await FireStoreUtils.fireStore
                      .collection(CollectionName.rides)
                      .doc(id)
                      .get();

              if (rideDoc.exists &&
                  (rideDoc.data()?['rideType'] ?? '')
                          .toString()
                          .toLowerCase() ==
                      "ride") {
                validRideId = userModel.value.inProgressOrderID!.first!;
                break;
              }
            }

            if (validRideId != null) {
              _setupOrderListener(validRideId);
            }
          } else {
            bottomSheetType.value = 'location';
            if (Constant.currentLocation != null) {
              if (Constant.selectedMapType == 'osm') {
                departureLatLongOsm.value = latlong.LatLng(
                  Constant.currentLocation!.latitude,
                  Constant.currentLocation!.longitude,
                );
                _loadPlaceNameInBackground();
              } else {
                departureLatLong.value = LatLng(
                  Constant.currentLocation!.latitude,
                  Constant.currentLocation!.longitude,
                );
                _loadPlaceNameInBackground();
              }
              setDepartureMarker(
                Constant.currentLocation!.latitude,
                Constant.currentLocation!.longitude,
              );
            }
          }
        });
  }

  // Order listener ni sozlash
  void _setupOrderListener(String validRideId) {
    FireStoreUtils.fireStore
        .collection(CollectionName.rides)
        .doc(validRideId)
        .snapshots()
        .listen((rideSnapshot) async {
          if (!rideSnapshot.exists) return;

          final rideData = rideSnapshot.data()!;
          currentOrder.value = CabOrderModel.fromJson(rideData);
          final status = currentOrder.value.status;

          if (status == Constant.driverAccepted ||
              status == Constant.orderInTransit) {
            _setupDriverListener(currentOrder.value.driverId);
          }

          print("Current Ride Status: $status");
          if (status == Constant.orderPlaced ||
              status == Constant.driverPending ||
              status == Constant.driverRejected ||
              (status == Constant.orderAccepted &&
                  currentOrder.value.driverId == null)) {
            bottomSheetType.value = 'waitingForDriver';
          } else if (status == Constant.driverAccepted ||
              status == Constant.orderInTransit) {
            bottomSheetType.value = 'driverDetails';
            sourceTextEditController.value.text =
                currentOrder.value.sourceLocationName ?? '';
            destinationTextEditController.value.text =
                currentOrder.value.destinationLocationName ?? '';
            selectedPaymentMethod.value =
                currentOrder.value.paymentMethod ?? '';
            calculateTotalAmountAfterAccept();
          } else if (status == Constant.orderCompleted) {
            userModel.value.inProgressOrderID!.remove(validRideId);
            await FireStoreUtils.updateUser(userModel.value);
            bottomSheetType.value = 'location';
            Get.back();
          }
        });
  }

  // Driver listener ni sozlash
  void _setupDriverListener(String? driverId) {
    if (driverId == null || driverId.isEmpty) return;

    FireStoreUtils.fireStore
        .collection(CollectionName.users)
        .doc(driverId)
        .snapshots()
        .listen((event) async {
          if (event.exists && event.data() != null) {
            UserModel driverModel0 = UserModel.fromJson(
              event.data()!,
            );
            driverModel.value = driverModel0;
            await updateDriverRoute(driverModel0);
          }
        });
  }

  RxList<CouponModel> cabCouponList = <CouponModel>[].obs;
  bool _couponsLoaded = false; // Lazy loading uchun flag

  // Lazy loading - kuponlar faqat kerak bo'lganda yuklanadi
  Future<void> loadCouponsIfNeeded() async {
    if (_couponsLoaded || cabCouponList.isNotEmpty) return;
    
    try {
      isDataLoading.value = true;
      final coupons = await FireStoreUtils.getCabCoupon();
      cabCouponList.value = coupons;
      _couponsLoaded = true;
    } catch (e) {
      log("Error loading coupons: $e");
    } finally {
      isDataLoading.value = false;
    }
  }

  // Lazy loading - payment settings faqat kerak bo'lganda yuklanadi
  bool _paymentSettingsLoaded = false;
  
  Future<void> loadPaymentSettingsIfNeeded() async {
    if (_paymentSettingsLoaded) {
      return; // Allaqachon yuklangan
    }
    
    try {
      isDataLoading.value = true;
      await getPaymentSettings();
      _paymentSettingsLoaded = true;
      _paymentSettingsCached = true;
    } catch (e) {
      log("Error loading payment settings: $e");
    } finally {
      isDataLoading.value = false;
    }
  }

  Future<void> updateDriverRoute(UserModel driverModel) async {
    try {
      final order = currentOrder.value;

      final driverLat = driverModel.location!.latitude ?? 0.0;
      final driverLng = driverModel.location!.longitude ?? 0.0;

      if (driverLat == 0.0 || driverLng == 0.0) return;

      // Get pickup and destination
      final pickupLat = order.sourceLocation?.latitude ?? 0.0;
      final pickupLng = order.sourceLocation?.longitude ?? 0.0;
      final destLat = order.destinationLocation?.latitude ?? 0.0;
      final destLng = order.destinationLocation?.longitude ?? 0.0;

      if (Constant.selectedMapType == 'osm') {
        /// For OpenStreetMap
        routePoints.clear();

        if (order.status == Constant.driverAccepted) {
          // DRIVER → PICKUP
          await fetchRouteWithWaypoints([
            latlong.LatLng(driverLat, driverLng),
            latlong.LatLng(pickupLat, pickupLng),
          ]);
        } else if (order.status == Constant.orderInTransit) {
          // PICKUP → DESTINATION
          await fetchRouteWithWaypoints([
            latlong.LatLng(driverLat, driverLng),
            latlong.LatLng(destLat, destLng),
          ]);
        }
        updateRouteMarkers(driverModel);
      } else {
        /// For Google Maps
        if (order.status == Constant.driverAccepted) {
          await fetchGoogleRouteBetween(
            LatLng(driverLat, driverLng),
            LatLng(pickupLat, pickupLng),
          );
        } else if (order.status == Constant.orderInTransit) {
          await fetchGoogleRouteBetween(
            LatLng(driverLat, driverLng),
            LatLng(destLat, destLng),
          );
        }
        updateRouteMarkers(driverModel);
      }
    } catch (e) {
      print("Error in updateDriverRoute: $e");
    }
  }

  Future<void> updateRouteMarkers(UserModel driverModel) async {
    try {
      final order = currentOrder.value;
      if (order.driver == null || driverModel.location == null) return;

      final driverLat = driverModel.location!.latitude ?? 0.0;
      final driverLng = driverModel.location!.longitude ?? 0.0;
      final pickupLat = order.sourceLocation?.latitude ?? 0.0;
      final pickupLng = order.sourceLocation?.longitude ?? 0.0;
      final destLat = order.destinationLocation?.latitude ?? 0.0;
      final destLng = order.destinationLocation?.longitude ?? 0.0;

      markers.clear();
      osmMarker.clear();

      final departureBytes = await Constant().getBytesFromAsset(
        'assets/images/location_black3x.png',
        50,
      );
      final destinationBytes = await Constant().getBytesFromAsset(
        'assets/images/location_orange3x.png',
        50,
      );
      final driverBytesRaw =
          (Constant.sectionConstantModel?.markerIcon?.isNotEmpty ?? false)
              ? await Constant().getBytesFromUrl(
                Constant.sectionConstantModel!.markerIcon!,
                width: 120,
              )
              : await Constant().getBytesFromAsset(
                'assets/images/ic_cab.png',
                50,
              );

      departureIcon = BitmapDescriptor.fromBytes(departureBytes);
      destinationIcon = BitmapDescriptor.fromBytes(destinationBytes);
      taxiIcon = BitmapDescriptor.fromBytes(driverBytesRaw);

      if (Constant.selectedMapType == 'osm') {
        if (order.status == Constant.driverAccepted) {
          osmMarker.addAll([
            flutterMap.Marker(
              point: latlong.LatLng(pickupLat, pickupLng),
              width: 40,
              height: 40,
              child: Image.asset(
                'assets/images/location_black3x.png',
                width: 40,
              ),
            ),
            flutterMap.Marker(
              point: latlong.LatLng(driverLat, driverLng),
              width: 45,
              height: 45,
              rotate: true,
              child: CachedNetworkImage(
                width: 50,
                height: 50,
                imageUrl: Constant.sectionConstantModel!.markerIcon.toString(),
                placeholder: (context, url) => Constant.loader(),
                errorWidget:
                    (context, url, error) => SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
              ),
            ),
          ]);
        } else if (order.status == Constant.orderInTransit) {
          osmMarker.addAll([
            flutterMap.Marker(
              point: latlong.LatLng(destLat, destLng),
              width: 40,
              height: 40,
              child: Image.asset(
                'assets/images/location_orange3x.png',
                width: 40,
              ),
            ),
            flutterMap.Marker(
              point: latlong.LatLng(driverLat, driverLng),
              width: 45,
              height: 45,
              rotate: true,
              child: CachedNetworkImage(
                width: 50,
                height: 50,
                imageUrl: Constant.sectionConstantModel!.markerIcon.toString(),
                placeholder: (context, url) => Constant.loader(),
                errorWidget:
                    (context, url, error) => SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
              ),
            ),
          ]);
        }
      } else {
        if (order.status == Constant.driverAccepted) {
          markers.addAll([
            Marker(
              markerId: const MarkerId("pickup"),
              position: LatLng(pickupLat, pickupLng),
              infoWindow: InfoWindow(title: "Pickup Location".tr),
              icon:
                  departureIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
            ),
            Marker(
              markerId: const MarkerId("driver"),
              position: LatLng(driverLat, driverLng),
              infoWindow: InfoWindow(title: "Driver at Pickup".tr),
              icon: taxiIcon ?? BitmapDescriptor.defaultMarker,
            ),
          ]);
        } else if (order.status == Constant.orderInTransit) {
          markers.addAll([
            Marker(
              markerId: const MarkerId("destination"),
              position: LatLng(destLat, destLng),
              infoWindow: InfoWindow(title: "Destination Location".tr),
              icon:
                  destinationIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
            ),
            Marker(
              markerId: const MarkerId("driver"),
              position: LatLng(driverLat, driverLng),
              infoWindow: InfoWindow(title: "Driver Location".tr),
              icon: taxiIcon ?? BitmapDescriptor.defaultMarker,
            ),
          ]);
        }
      }

      update();
    } catch (e) {
      print("❌ Error in updateRouteMarkers: $e");
    }
  }

  Future<void> fetchGoogleRouteBetween(
    LatLng originPoint,
    LatLng destPoint,
  ) async {
    final origin = '${originPoint.latitude},${originPoint.longitude}';
    final destination = '${destPoint.latitude},${destPoint.longitude}';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$destination'
      '&mode=driving&key=${Constant.mapAPIKey}',
    );

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final route = data['routes'][0];
        final encodedPolyline = route['overview_polyline']['points'];
        final decodedPoints = PolylinePoints.decodePolyline(encodedPolyline);
        final coordinates =
            decodedPoints.map((e) => LatLng(e.latitude, e.longitude)).toList();

        addPolyLine(coordinates);

        // Distance + duration update
        final leg = route['legs'][0];
        final totalDistance = leg['distance']['value'] / 1000.0;
        final totalDuration = leg['duration']['value'] / 60.0;

        distance.value = totalDistance;
        duration.value = '${totalDuration.toStringAsFixed(0)} min';
      } else {
        print('Google Directions API error: ${data['status']}');
      }
    } catch (e) {
      print("Error fetching driver route: $e");
    }
  }

  void calculateTotalAmountAfterAccept() {
    taxAmount = 0.0.obs;
    discount = 0.0.obs;
    subTotal.value = double.parse(currentOrder.value.subTotal.toString());
    discount.value = double.parse(currentOrder.value.discount ?? '0.0');

    if (currentOrder.value.taxSetting != null) {
      for (var element in currentOrder.value.taxSetting!) {
        taxAmount.value =
            (taxAmount.value +
                Constant.calculateTax(
                  amount: (subTotal.value - discount.value).toString(),
                  taxModel: element,
                ));
      }
    }

    totalAmount.value = (subTotal.value - discount.value) + taxAmount.value;
    update();
  }

  void calculateTotalAmount() {
    subTotal = 0.0.obs;
    taxAmount = 0.0.obs;
    discount = 0.0.obs;
    totalAmount = 0.0.obs;
    subTotal.value = getAmount(selectedVehicleType.value);

    if (selectedCouponModel.value.id != null) {
      discount.value = Constant.calculateDiscount(
        amount: subTotal.value.toString(),
        offerModel: selectedCouponModel.value,
      );
    }

    for (var element in Constant.taxList) {
      taxAmount.value =
          (taxAmount.value +
              Constant.calculateTax(
                amount: (subTotal.value - discount.value).toString(),
                taxModel: element,
              ));
    }

    totalAmount.value = (subTotal.value - discount.value) + taxAmount.value;
    update();
  }

  Future<void> completeOrder() async {
    // Wallet bilan to'lov tanlangan bo'lsa, balansni tekshirish
    if (selectedPaymentMethod.value == PaymentGateway.wallet.name) {
      // User ma'lumotlarini yangilash - eng so'nggi balansni olish
      final updatedUser = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
      if (updatedUser != null) {
        userModel.value = updatedUser;
      }
      
      num walletAmount = userModel.value.walletAmount ?? 0;
      num orderTotal = totalAmount.value;

      if (walletAmount < orderTotal || walletAmount <= 0) {
        // Qizil snackbar ko'rsatish
        Get.snackbar(
          "Error".tr,
          "Insufficient wallet balance".tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          icon: const Icon(Icons.error, color: Colors.white),
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
        );
        return; // Zakaz berilmaydi
      }
    }
    
    if (selectedPaymentMethod.value == PaymentGateway.cod.name) {
      currentOrder.value.paymentMethod = selectedPaymentMethod.value;
      await FireStoreUtils.cabOrderPlace(currentOrder.value).then((value) {
        ShowToastDialog.showToast("Payment method changed".tr);
        Get.back();
        Get.back();
      });
    } else {
      currentOrder.value.paymentStatus = true;
      currentOrder.value.paymentMethod = selectedPaymentMethod.value;
      userModel.value.inProgressOrderID ??= [];
      userModel.value.inProgressOrderID!.clear();
      await FireStoreUtils.updateUser(userModel.value);

      if (selectedPaymentMethod.value == PaymentGateway.wallet.name) {
        // Yana bir bor tekshirish - xavfsizlik uchun
        final updatedUser = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
        if (updatedUser != null) {
          userModel.value = updatedUser;
        }
        
        num walletAmount = userModel.value.walletAmount ?? 0;
        num orderTotal = totalAmount.value;

        if (walletAmount < orderTotal || walletAmount <= 0) {
          Get.snackbar(
            "Error".tr,
            "Insufficient wallet balance".tr,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            icon: const Icon(Icons.error, color: Colors.white),
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
          );
          return;
        }
        
        WalletTransactionModel transactionModel = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: double.parse(totalAmount.toString()),
          date: Timestamp.now(),
          paymentMethod: PaymentGateway.wallet.name,
          transactionUser: "customer",
          userId: FireStoreUtils.getCurrentUid(),
          isTopup: false,
          orderId: currentOrder.value.id,
          note: "Cab Amount debited",
          paymentStatus: "success",
          serviceType: Constant.parcelServiceType,
        );

        await FireStoreUtils.setWalletTransaction(transactionModel).then((
          value,
        ) async {
          if (value == true) {
            await FireStoreUtils.updateUserWallet(
              amount: "-${totalAmount.value.toString()}",
              userId: FireStoreUtils.getCurrentUid(),
            );
          }
        });
      }

      await FireStoreUtils.cabOrderPlace(currentOrder.value).then((value) {
        ShowToastDialog.showToast("Payment successfully".tr);
        Get.back();
      });
    }
  }

  Future<void> placeOrder() async {
    // Wallet bilan to'lov tanlangan bo'lsa, balansni tekshirish
    if (selectedPaymentMethod.value == PaymentGateway.wallet.name) {
      num walletAmount = userModel.value.walletAmount ?? 0;
      num orderTotal = totalAmount.value;

      if (walletAmount < orderTotal) {
        // Qizil snackbar ko'rsatish
        Get.snackbar(
          "Error".tr,
          "Insufficient wallet balance".tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,

          icon: const Icon(Icons.error, color: Colors.white),
          duration: const Duration(seconds: 3),

          margin: const EdgeInsets.all(16),
        );
        return; // Zakaz berilmaydi
      }
    }

    DestinationLocation sourceLocation = DestinationLocation(
      latitude:
          Constant.selectedMapType == 'osm'
              ? departureLatLongOsm.value.latitude
              : departureLatLong.value.latitude,
      longitude:
          Constant.selectedMapType == 'osm'
              ? departureLatLongOsm.value.longitude
              : departureLatLong.value.longitude,
    );

    DestinationLocation destinationLocation = DestinationLocation(
      latitude:
          Constant.selectedMapType == 'osm'
              ? destinationLatLongOsm.value.latitude
              : destinationLatLong.value.latitude,
      longitude:
          Constant.selectedMapType == 'osm'
              ? destinationLatLongOsm.value.longitude
              : destinationLatLong.value.longitude,
    );

    CabOrderModel orderModel = CabOrderModel();
    orderModel.id = const Uuid().v4();
    orderModel.distance = distance.value.toString();
    orderModel.duration = duration.value;
    orderModel.vehicleId = selectedVehicleType.value.id;
    orderModel.vehicleType = selectedVehicleType.value;
    orderModel.authorID = FireStoreUtils.getCurrentUid();
    orderModel.sourceLocationName = sourceTextEditController.value.text;
    orderModel.destinationLocationName =
        destinationTextEditController.value.text;

    orderModel.sourceLocation = sourceLocation;
    orderModel.destinationLocation = destinationLocation;
    orderModel.author = userModel.value;
    orderModel.subTotal = subTotal.value.toString();
    orderModel.discount = discount.value.toString();
    orderModel.couponCode = selectedCouponModel.value.code;
    orderModel.couponId = selectedCouponModel.value.id;

    orderModel.taxSetting = Constant.taxList;
    orderModel.adminCommissionType =
        Constant.sectionConstantModel!.adminCommision != null &&
                Constant.sectionConstantModel!.adminCommision!.isEnabled == true
            ? Constant.sectionConstantModel!.adminCommision!.commissionType
                .toString()
            : null;
    orderModel.adminCommission =
        Constant.sectionConstantModel!.adminCommision != null &&
                Constant.sectionConstantModel!.adminCommision!.isEnabled == true
            ? Constant.sectionConstantModel!.adminCommision!.amount.toString()
            : null;
    orderModel.couponCode = couponCodeTextEditController.value.text;
    orderModel.paymentMethod = selectedPaymentMethod.value;
    orderModel.paymentStatus = false;
    orderModel.triggerDelevery = Timestamp.now();
    orderModel.tipAmount = "0.0";
    orderModel.scheduleReturnDateTime = Timestamp.now();
    orderModel.rideType = 'ride';
    orderModel.roundTrip = false;
    orderModel.sectionId = Constant.sectionConstantModel!.id;
    orderModel.createdAt = Timestamp.now();
    orderModel.otpCode =
        (maths.Random().nextInt(9000) + 1000)
            .toString(); // Generate a 4-digit OTP
    orderModel.status = Constant.orderPlaced;
    orderModel.scheduleDateTime = Timestamp.now();
    log("Order Model : ${orderModel.toJson()}");

    await FireStoreUtils.cabOrderPlace(orderModel);

    userModel.value.inProgressOrderID!.add(orderModel.id);
    await FireStoreUtils.updateUser(userModel.value);

    bottomSheetType.value = 'waitingForDriver';
  }

  double getAmount(VehicleType vehicleType) {
    final double currentDistance = distance.value;
    if (currentDistance <=
        (vehicleType.minimum_delivery_charges_within_km ?? 0)) {
      return double.tryParse(vehicleType.minimum_delivery_charges.toString()) ??
          0.0;
    } else {
      return (vehicleType.delivery_charges_per_km ?? 0.0) * currentDistance;
    }
  }

  void setDepartureMarker(double lat, double long) {
    if (Constant.selectedMapType == 'osm') {
      _setOsmMarker(lat, long, isDeparture: true);
    } else {
      _setGoogleMarker(lat, long, isDeparture: true);
    }
  }

  void setDestinationMarker(double lat, double lng) {
    if (Constant.selectedMapType == 'osm') {
      _setOsmMarker(lat, lng, isDeparture: false);
    } else {
      _setGoogleMarker(lat, lng, isDeparture: false);
    }
  }

  void setStopMarker(double lat, double lng, int index) {
    if (Constant.selectedMapType == 'osm') {
      // Add new stop marker without clearing
      osmMarker.add(
        flutterMap.Marker(
          point: latlong.LatLng(lat, lng),
          width: 40,
          height: 40,
          child: stopIconOsm!,
        ),
      );

      getDirections(isStopMarker: true);
    } else {
      final markerId = MarkerId('Stop $index');

      markers.removeWhere((marker) => marker.markerId == markerId);
      markers.add(
        Marker(
          markerId: markerId,
          infoWindow: InfoWindow(
            title: '${'Stop'.tr} ${String.fromCharCode(index + 65)}',
          ),
          position: LatLng(lat, lng),
          icon: stopIcon!,
        ),
      );

      getDirections();
    }
  }

  void _setOsmMarker(double lat, double lng, {required bool isDeparture}) {
    if (isDeparture) {
      departureLatLongOsm.value = latlong.LatLng(lat, lng);
    } else {
      destinationLatLongOsm.value = latlong.LatLng(lat, lng);
    }
    
    // Ikkala lokatsiya ham bo'lsa, yo'l chizish
    if (departureLatLongOsm.value.latitude != 0 &&
        departureLatLongOsm.value.longitude != 0 &&
        destinationLatLongOsm.value.latitude != 0 &&
        destinationLatLongOsm.value.longitude != 0) {
      getDirections();
      animateToSource(lat, lng);
    } else {
      // Faqat bitta lokatsiya bo'lsa, marker qo'shish
      final marker = flutterMap.Marker(
        point: latlong.LatLng(lat, lng),
        width: 40,
        height: 40,
        child: isDeparture ? departureIconOsm! : destinationIconOsm!,
      );
      // Eski marker'ni olib tashlash
      if (isDeparture) {
        osmMarker.removeWhere((m) => m.point == departureLatLongOsm.value);
      } else {
        osmMarker.removeWhere((m) => m.point == destinationLatLongOsm.value);
      }
      osmMarker.add(marker);
    }
  }

  void _setGoogleMarker(double lat, double lng, {required bool isDeparture}) {
    final LatLng pos = LatLng(lat, lng);
    final markerId = MarkerId(isDeparture ? 'Departure' : 'Destination');
    final icon = isDeparture ? departureIcon! : destinationIcon!;
    final title = isDeparture ? 'Departure'.tr : 'Destination'.tr;

    if (isDeparture) {
      departureLatLong.value = pos;
    } else {
      destinationLatLong.value = pos;
    }

    // Remove only the matching departure/destination marker
    markers.removeWhere((marker) => marker.markerId == markerId);

    // Add new marker
    markers.add(
      Marker(
        markerId: markerId,
        position: pos,
        icon: icon,
        infoWindow: InfoWindow(title: title),
      ),
    );

    // Ikkala lokatsiya ham bo'lsa, yo'l chizish
    if (departureLatLong.value.latitude != 0 &&
        departureLatLong.value.longitude != 0 &&
        destinationLatLong.value.latitude != 0 &&
        destinationLatLong.value.longitude != 0) {
      getDirections();
    } else {
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 14),
        ),
      );
    }
  }

  Future<void> getDirections({bool isStopMarker = false}) async {
    if (Constant.selectedMapType == 'osm') {
      final wayPoints = <latlong.LatLng>[];

      // Only add valid source
      if (departureLatLongOsm.value.latitude != 0.0 &&
          departureLatLongOsm.value.longitude != 0.0) {
        wayPoints.add(departureLatLongOsm.value);
      }

      // Only add valid destination
      if (destinationLatLongOsm.value.latitude != 0.0 &&
          destinationLatLongOsm.value.longitude != 0.0) {
        wayPoints.add(destinationLatLongOsm.value);
      }

      if (!isStopMarker) osmMarker.clear();

      // Add source marker
      if (departureLatLongOsm.value.latitude != 0.0 &&
          departureLatLongOsm.value.longitude != 0.0) {
        osmMarker.add(
          flutterMap.Marker(
            point: departureLatLongOsm.value,
            width: 40,
            height: 40,
            child: departureIconOsm!,
          ),
        );
      }

      // Add destination marker
      if (destinationLatLongOsm.value.latitude != 0.0 &&
          destinationLatLongOsm.value.longitude != 0.0) {
        osmMarker.add(
          flutterMap.Marker(
            point: destinationLatLongOsm.value,
            width: 40,
            height: 40,
            child: destinationIconOsm!,
          ),
        );
      }

      if (wayPoints.length >= 2) {
        await fetchRouteWithWaypoints(wayPoints);
      }
    } else {
      // Google Maps path
      fetchGoogleRouteWithWaypoints();
    }
  }

  Future<void> fetchGoogleRouteWithWaypoints() async {
    if (departureLatLong.value.latitude == 0.0 ||
        destinationLatLong.value.latitude == 0.0)
      return;

    final origin =
        '${departureLatLong.value.latitude},${departureLatLong.value.longitude}';
    final destination =
        '${destinationLatLong.value.latitude},${destinationLatLong.value.longitude}';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$destination'
      '&mode=driving&key=${Constant.mapAPIKey}',
    );

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);
      log("=======>$data");
      if (data['status'] == 'OK') {
        final route = data['routes'][0];
        final legs = route['legs'] as List;

        // Polyline
        final encodedPolyline = route['overview_polyline']['points'];
        final decodedPoints = PolylinePoints.decodePolyline(encodedPolyline);
        final coordinates =
            decodedPoints.map((e) => LatLng(e.latitude, e.longitude)).toList();

        addPolyLine(coordinates);

        // Distance & Duration
        num totalDistance = 0;
        num totalDuration = 0;
        for (var leg in legs) {
          totalDistance += leg['distance']['value']!; // meters
          totalDuration += leg['duration']['value']!; // seconds
        }

        // Convert distance to KM or Miles
        if (Constant.distanceType.toLowerCase() == "KM".toLowerCase()) {
          distance.value = totalDistance / 1000.0;
        } else {
          distance.value = totalDistance / 1609.34;
        }

        // Format duration
        final hours = totalDuration ~/ 3600;
        final minutes = ((totalDuration % 3600) / 60).round();
        duration.value = '${hours}h ${minutes}m';
      } else {
        print('Google Directions API Error: ${data['status']}');
      }
    } catch (e) {
      print("Google route fetch error: $e");
    }
  }

  Future<void> fetchRouteWithWaypoints(List<latlong.LatLng> points) async {
    final coordinates = points
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final geometry =
            decoded['routes'][0]['geometry']['coordinates'] as List;
        final dist = decoded['routes'][0]['distance'];
        final dur = decoded['routes'][0]['duration'];

        routePoints.clear();
        routePoints.addAll(
          geometry.map((coord) => latlong.LatLng(coord[1], coord[0])),
        );

        if (Constant.distanceType.toLowerCase() == "KM".toLowerCase()) {
          distance.value = dist / 1000.00;
        } else {
          distance.value = dist / 1609.34;
        }

        final hours = dur ~/ 3600;
        final minutes = ((dur % 3600) / 60).round();
        duration.value = '${hours}h ${minutes}m';

        // Zoom to fit polyline after drawing
        zoomToPolylineOSM();
      } else {
        print("Failed to get route: ${response.body}");
      }
    } catch (e) {
      print("Route fetch error: $e");
    }
  }

  void zoomToPolylineOSM() {
    if (routePoints.isEmpty) return;
    // LatLngBounds requires at least two points
    final bounds = flutterMap.LatLngBounds(
      routePoints.first,
      routePoints.first,
    );
    for (final point in routePoints) {
      bounds.extend(point);
    }
    final center = bounds.center;
    // Calculate zoom level to fit all points
    double zoom = getBoundsZoomLevel(bounds);
    mapOsmController.move(center, zoom);
  }

  double getBoundsZoomLevel(flutterMap.LatLngBounds bounds) {
    // Simple heuristic: zoom out for larger bounds
    final latDiff =
        (bounds.northEast.latitude - bounds.southWest.latitude).abs();
    final lngDiff =
        (bounds.northEast.longitude - bounds.southWest.longitude).abs();
    double maxDiff = math.max(latDiff, lngDiff);
    if (maxDiff < 0.005) return 18.0;
    if (maxDiff < 0.01) return 16.0;
    if (maxDiff < 0.05) return 14.0;
    if (maxDiff < 0.1) return 12.0;
    if (maxDiff < 0.5) return 10.0;
    return 8.0;
  }

  void addPolyLine(List<LatLng> points) {
    final id = const PolylineId("poly");
    final polyline = Polyline(
      polylineId: id,
      color: AppThemeData.primary300,
      points: points,
      width: 6,
      geodesic: true,
    );
    polyLines[id] = polyline;

    if (points.length >= 2) {
      // Zoom to fit all polyline points
      updateCameraLocationToFitPolyline(points, mapController);
    }
  }

  Future<void> updateCameraLocationToFitPolyline(
    List<LatLng> points,
    GoogleMapController? mapController,
  ) async {
    if (mapController == null || points.isEmpty) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    final cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 50);
    await checkCameraLocation(cameraUpdate, mapController);
  }

  Future<void> animateToSource(double lat, double long) async {
    final hasBothCoords =
        departureLatLongOsm.value.latitude != 0.0 &&
        destinationLatLongOsm.value.latitude != 0.0;

    if (hasBothCoords) {
      await calculateZoomLevel(
        source: departureLatLongOsm.value,
        destination: destinationLatLongOsm.value,
      );
    } else {
      mapOsmController.move(latlong.LatLng(lat, long), 10);
    }
  }

  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;

  Future<void> calculateZoomLevel({
    required latlong.LatLng source,
    required latlong.LatLng destination,
    double paddingFraction = 0.001,
  }) async {
    final bounds = flutterMap.LatLngBounds.fromPoints([source, destination]);
    final screenSize = Size(Get.width, Get.height * 0.5);
    const double worldDimension = 256.0;
    const double maxZoom = 10.0;

    double latToRad(double lat) =>
        math.log(
          (1 + math.sin(lat * math.pi / 180)) /
              (1 - math.sin(lat * math.pi / 180)),
        ) /
        2;

    double computeZoom(double screenPx, double worldPx, double fraction) =>
        math.log(screenPx / worldPx / fraction) / math.ln2;

    final north = bounds.northEast.latitude;
    final south = bounds.southWest.latitude;
    final east = bounds.northEast.longitude;
    final west = bounds.southWest.longitude;

    final latDelta = (north - south).abs();
    final lngDelta = (east - west).abs();

    final center = bounds.center;

    if (latDelta < 1e-6 || lngDelta < 1e-6) {
      mapOsmController.move(center, maxZoom);
    } else {
      final latFraction = (latToRad(north) - latToRad(south)) / math.pi;
      final lngFraction = ((east - west + 360) % 360) / 360;

      final latZoom = computeZoom(
        screenSize.height,
        worldDimension,
        latFraction + paddingFraction,
      );
      final lngZoom = computeZoom(
        screenSize.width,
        worldDimension,
        lngFraction + paddingFraction,
      );

      final zoomLevel = math.min(latZoom, lngZoom).clamp(0.0, maxZoom);
      mapOsmController.move(center, zoomLevel);
    }
  }

  Future<void> updateCameraLocation(
    LatLng source,
    LatLng destination,
    GoogleMapController? mapController,
  ) async {
    if (mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(source.latitude, destination.latitude),
        math.min(source.longitude, destination.longitude),
      ),
      northeast: LatLng(
        math.max(source.latitude, destination.latitude),
        math.max(source.longitude, destination.longitude),
      ),
    );

    final cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 90);
    await checkCameraLocation(cameraUpdate, mapController);
  }

  Future<void> checkCameraLocation(
    CameraUpdate cameraUpdate,
    GoogleMapController mapController,
  ) async {
    await mapController.animateCamera(cameraUpdate);
    final l1 = await mapController.getVisibleRegion();
    final l2 = await mapController.getVisibleRegion();

    if (l1.southwest.latitude == -90 || l2.southwest.latitude == -90) {
      await checkCameraLocation(cameraUpdate, mapController);
    }
  }

  Future<void> setIcons() async {
    try {
      if (Constant.selectedMapType == 'osm') {
        departureIconOsm = Image.asset(
          "assets/icons/pickup.png",
          width: 30,
          height: 30,
        );
        destinationIconOsm = Image.asset(
          "assets/icons/dropoff.png",
          width: 30,
          height: 30,
        );
        taxiIconOsm = Image.asset(
          "assets/icons/ic_taxi.png",
          width: 30,
          height: 30,
        );
        stopIconOsm = Image.asset(
          "assets/icons/location.png",
          width: 26,
          height: 26,
        );
      } else {
        const config = ImageConfiguration(size: Size(48, 48));
        departureIcon = await BitmapDescriptor.fromAssetImage(
          config,
          "assets/icons/pickup.png",
        );
        destinationIcon = await BitmapDescriptor.fromAssetImage(
          config,
          "assets/icons/dropoff.png",
        );
        taxiIcon = await BitmapDescriptor.fromAssetImage(
          config,
          "assets/icons/ic_taxi.png",
        );
        stopIcon = await BitmapDescriptor.fromAssetImage(
          config,
          "assets/icons/location.png",
        );
      }
    } catch (e) {
      print('Error loading icons: $e');
    }
  }

  void clearMapDataIfLocationsRemoved() {
    final isSourceEmpty =
        departureLatLongOsm.value.latitude == 0.0 &&
        departureLatLongOsm.value.longitude == 0.0;
    final isDestinationEmpty =
        destinationLatLongOsm.value.latitude == 0.0 &&
        destinationLatLongOsm.value.longitude == 0.0;

    if (isSourceEmpty || isDestinationEmpty) {
      // Clear polylines
      polyLines.clear();

      // Clear OSM markers (if using OSM)
      osmMarker.clear();

      // Clear Google markers (if using Google Maps)
      markers.clear();

      // Clear route points (optional)
      routePoints.clear();

      // Reset distance and duration values
      distance.value = 0.0;
      duration.value = '';
    }
  }

  void removeSource() {
    // Clear departure location and related data
    departureLatLongOsm.value = latlong.LatLng(0.0, 0.0);
    departureLatLong.value = const LatLng(0.0, 0.0);
    sourceTextEditController.value.clear();

    // Remove marker
    if (Constant.selectedMapType == 'osm') {
      osmMarker.removeWhere(
        (marker) => marker.point == departureLatLongOsm.value,
      );
    } else {
      markers.removeWhere((marker) => marker.markerId.value == 'Departure');
    }

    // Clear polylines and route info if needed
    clearMapDataIfLocationsRemoved();
    update();
  }

  void removeDestination() {
    destinationLatLongOsm.value = latlong.LatLng(0.0, 0.0);
    destinationLatLong.value = const LatLng(0.0, 0.0);
    destinationTextEditController.value.clear();

    if (Constant.selectedMapType == 'osm') {
      osmMarker.removeWhere(
        (marker) => marker.point == destinationLatLongOsm.value,
      );
    } else {
      markers.removeWhere((marker) => marker.markerId.value == 'Destination');
    }

    clearMapDataIfLocationsRemoved();
    update();
  }

  Future<void> searchPlaceNameOSM() async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${departureLatLongOsm.value.latitude}&lon=${departureLatLongOsm.value.longitude}&format=json',
      );

      final response = await http
          .get(
            url,
            headers: {
              'User-Agent':
                  'FlutterMapApp/1.0 (menil.siddhiinfosoft@gmail.com)',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        log("response.body :: ${response.body}");
        Map<String, dynamic> data = json.decode(response.body);
        sourceTextEditController.value.text = data['display_name'] ?? '';
      }
    } catch (e) {
      log("OSM Reverse Geocode Error: $e");
      // Error bo'lsa ham davom etadi
    }
  }

  Future<void> searchPlaceNameGoogle() async {
    final lat = departureLatLong.value.latitude;
    final lng = departureLatLong.value.longitude;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${Constant.mapAPIKey}',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final formattedAddress = results[0]['formatted_address'];
          sourceTextEditController.value.text = formattedAddress;
        }
      } else {
        log("Google API Error: ${data['status']}");
      }
    } else {
      log("HTTP Error: ${response.statusCode}");
    }
  }

  // Xaritada tanlangan joydan manzil olish
  Future<void> getAddressFromPickedLocation(double lat, double lng) async {
    isLoadingAddress.value = true;
    tempPickedLocation.value = latlong.LatLng(lat, lng);

    try {
      if (Constant.selectedMapType == 'osm') {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
        );

        final response = await http
            .get(
              url,
              headers: {
                'User-Agent': 'FlutterMapApp/1.0 (menil.siddhiinfosoft@gmail.com)',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          Map<String, dynamic> data = json.decode(response.body);
          tempPickedAddress.value = data['display_name'] ?? '';
        }
      } else {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${Constant.mapAPIKey}',
        );

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            final results = data['results'] as List;
            if (results.isNotEmpty) {
              tempPickedAddress.value = results[0]['formatted_address'] ?? '';
            }
          }
        }
      }
    } catch (e) {
      log("Get Address Error: $e");
      tempPickedAddress.value = 'Manzil topilmadi';
    } finally {
      isLoadingAddress.value = false;
    }
  }

  // Tanlangan joyni tasdiqlash
  void confirmPickedLocation() {
    if (tempPickedLocation.value.latitude == 0) return;

    final lat = tempPickedLocation.value.latitude;
    final lng = tempPickedLocation.value.longitude;
    final address = tempPickedAddress.value;

    if (!Constant.checkZoneCheck(lat, lng)) {
      ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
      return;
    }

    if (isPickingSource.value) {
      sourceTextEditController.value.text = address;
      setDepartureMarker(lat, lng);
    } else {
      destinationTextEditController.value.text = address;
      setDestinationMarker(lat, lng);
    }

    // Reset map picking mode
    isMapPickingMode.value = false;
    tempPickedLocation.value = latlong.LatLng(0, 0);
    tempPickedAddress.value = '';
  }

  // Map picking rejimini bekor qilish
  void cancelMapPicking() {
    isMapPickingMode.value = false;
    tempPickedLocation.value = latlong.LatLng(0, 0);
    tempPickedAddress.value = '';
  }

  // Search destination places for OSM
  Future<void> searchDestinationOSM(String query) async {
    // Minimum uzunlikni 4 ga oshirish - Nominatim rate limit'ni oldini olish uchun
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || trimmedQuery.length < 4) {
      destinationSearchResults.clear();
      searchError.value = '';
      return;
    }

    isSearchingDestination.value = true;
    searchError.value = ''; // Error'ni tozalash

    try {
      // URL encoding qo'shish
      final encodedQuery = Uri.encodeComponent(trimmedQuery);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&addressdetails=1&limit=10',
      );

      final response = await http
          .get(
            url,
            headers: {
              'User-Agent':
                  'FlutterMapApp/1.0 (menil.siddhiinfosoft@gmail.com)',
            },
          )
          .timeout(
            const Duration(seconds: 15), // Timeout'ni 15 soniyaga oshirish
            onTimeout: () {
              throw TimeoutException('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isEmpty) {
          destinationSearchResults.clear();
          searchError.value = ''; // Natija topilmadi - error emas
        } else {
          destinationSearchResults.value =
              data.map((item) {
                return {
                  'name': item['display_name'] ?? '',
                  'lat': double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0,
                  'lon': double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0,
                  'address': item['display_name'] ?? '',
                };
              }).toList();
          searchError.value = ''; // Muvaffaqiyatli - error yo'q
        }
      } else {
        destinationSearchResults.clear();
        // HTTP error'ni faqat log qilish, foydalanuvchiga ko'rsatmaslik
        log("OSM Search HTTP Error: ${response.statusCode} - ${response.body}");
        searchError.value = ''; // Error'ni ko'rsatmaslik
      }
    } on SocketException catch (e) {
      log("OSM Search Network Error: $e");
      destinationSearchResults.clear();
      // SocketException - haqiqatan ham internet yo'q bo'lishi mumkin
      // Lekin ba'zida server muammosi ham bo'lishi mumkin
      // Shuning uchun error'ni ko'rsatmaslik yaxshiroq
      searchError.value = '';
    } on TimeoutException catch (e) {
      log("OSM Search Timeout Error: $e");
      destinationSearchResults.clear();
      // Timeout - server sekin javob bergan yoki internet sekin
      // Error'ni ko'rsatmaslik
      searchError.value = '';
    } catch (e) {
      log("OSM Search Error: $e");
      destinationSearchResults.clear();
      // Barcha boshqa error'larni ham ko'rsatmaslik
      // Faqat log qilish
      searchError.value = '';
    } finally {
      isSearchingDestination.value = false;
    }
  }

  // Search destination places for Google Maps
  Future<void> searchDestinationGoogle(String query) async {
    // Minimum uzunlikni 4 ga oshirish - so'rovlar sonini kamaytirish uchun
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || trimmedQuery.length < 4) {
      destinationSearchResults.clear();
      searchError.value = '';
      return;
    }

    isSearchingDestination.value = true;
    searchError.value = ''; // Error'ni tozalash

    try {
      // URL encoding qo'shish
      final encodedQuery = Uri.encodeComponent(trimmedQuery);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$encodedQuery&key=${Constant.mapAPIKey}&language=en',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 15), // Timeout'ni 15 soniyaga oshirish
            onTimeout: () {
              throw TimeoutException('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          if (predictions.isEmpty) {
            destinationSearchResults.clear();
            searchError.value = ''; // Natija topilmadi - error emas
          } else {
            destinationSearchResults.value =
                predictions
                    .map(
                      (item) => {
                        'name': item['description'] ?? '',
                        'place_id': item['place_id'] ?? '',
                        'address': item['description'] ?? '',
                      },
                    )
                    .toList();
            searchError.value = ''; // Muvaffaqiyatli - error yo'q
          }
        } else {
          destinationSearchResults.clear();
          // API error'ni faqat log qilish
          log("Google Search API Error: ${data['status']}");
          searchError.value = ''; // Error'ni ko'rsatmaslik
        }
      } else {
        destinationSearchResults.clear();
        log(
          "Google Search HTTP Error: ${response.statusCode} - ${response.body}",
        );
        searchError.value = ''; // Error'ni ko'rsatmaslik
      }
    } on SocketException catch (e) {
      log("Google Search Network Error: $e");
      destinationSearchResults.clear();
      searchError.value = ''; // Error'ni ko'rsatmaslik
    } on TimeoutException catch (e) {
      log("Google Search Timeout Error: $e");
      destinationSearchResults.clear();
      searchError.value = ''; // Error'ni ko'rsatmaslik
    } catch (e) {
      log("Google Search Error: $e");
      destinationSearchResults.clear();
      searchError.value = ''; // Error'ni ko'rsatmaslik
    } finally {
      isSearchingDestination.value = false;
    }
  }

  // Get place details from Google place_id
  Future<Map<String, dynamic>?> getPlaceDetailsGoogle(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=${Constant.mapAPIKey}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          return {
            'name': result['name'] ?? '',
            'address': result['formatted_address'] ?? '',
            'lat': result['geometry']['location']['lat'],
            'lng': result['geometry']['location']['lng'],
          };
        }
      }
    } catch (e) {
      log("Get Place Details Error: $e");
    }
    return null;
  }

  // Search source places for OSM
  Future<void> searchSourceOSM(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || trimmedQuery.length < 4) {
      sourceSearchResults.clear();
      sourceSearchError.value = '';
      return;
    }

    isSearchingSource.value = true;
    sourceSearchError.value = '';

    try {
      final encodedQuery = Uri.encodeComponent(trimmedQuery);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&addressdetails=1&limit=10',
      );

      final response = await http
          .get(
            url,
            headers: {
              'User-Agent':
                  'FlutterMapApp/1.0 (menil.siddhiinfosoft@gmail.com)',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isEmpty) {
          sourceSearchResults.clear();
          sourceSearchError.value = '';
        } else {
          sourceSearchResults.value =
              data.map((item) {
                return {
                  'name': item['display_name'] ?? '',
                  'lat': double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0,
                  'lon': double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0,
                  'address': item['display_name'] ?? '',
                };
              }).toList();
          sourceSearchError.value = '';
        }
      } else {
        sourceSearchResults.clear();
        log("OSM Source Search HTTP Error: ${response.statusCode} - ${response.body}");
        sourceSearchError.value = '';
      }
    } on SocketException catch (e) {
      log("OSM Source Search Network Error: $e");
      sourceSearchResults.clear();
      sourceSearchError.value = '';
    } on TimeoutException catch (e) {
      log("OSM Source Search Timeout Error: $e");
      sourceSearchResults.clear();
      sourceSearchError.value = '';
    } catch (e) {
      log("OSM Source Search Error: $e");
      sourceSearchResults.clear();
      sourceSearchError.value = '';
    } finally {
      isSearchingSource.value = false;
    }
  }

  // Search source places for Google Maps
  Future<void> searchSourceGoogle(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || trimmedQuery.length < 4) {
      sourceSearchResults.clear();
      sourceSearchError.value = '';
      return;
    }

    isSearchingSource.value = true;
    sourceSearchError.value = '';

    try {
      final encodedQuery = Uri.encodeComponent(trimmedQuery);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$encodedQuery&key=${Constant.mapAPIKey}&language=en',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          if (predictions.isEmpty) {
            sourceSearchResults.clear();
            sourceSearchError.value = '';
          } else {
            sourceSearchResults.value =
                predictions
                    .map(
                      (item) => {
                        'name': item['description'] ?? '',
                        'place_id': item['place_id'] ?? '',
                        'address': item['description'] ?? '',
                      },
                    )
                    .toList();
            sourceSearchError.value = '';
          }
        } else {
          sourceSearchResults.clear();
          log("Google Source Search API Error: ${data['status']}");
          sourceSearchError.value = '';
        }
      } else {
        sourceSearchResults.clear();
        log(
          "Google Source Search HTTP Error: ${response.statusCode} - ${response.body}",
        );
        sourceSearchError.value = '';
      }
    } on SocketException catch (e) {
      log("Google Source Search Network Error: $e");
      sourceSearchResults.clear();
      sourceSearchError.value = '';
    } on TimeoutException catch (e) {
      log("Google Source Search Timeout Error: $e");
      sourceSearchResults.clear();
      sourceSearchError.value = '';
    } catch (e) {
      log("Google Source Search Error: $e");
      sourceSearchResults.clear();
      sourceSearchError.value = '';
    } finally {
      isSearchingSource.value = false;
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  Rx<WalletSettingModel> walletSettingModel = WalletSettingModel().obs;
  Rx<CodSettingModel> cashOnDeliverySettingModel = CodSettingModel().obs;
  Rx<PayFastModel> payFastModel = PayFastModel().obs;
  Rx<MercadoPagoModel> mercadoPagoModel = MercadoPagoModel().obs;
  Rx<PayPalModel> payPalModel = PayPalModel().obs;
  Rx<StripeModel> stripeModel = StripeModel().obs;
  Rx<FlutterWaveModel> flutterWaveModel = FlutterWaveModel().obs;
  Rx<PayStackModel> payStackModel = PayStackModel().obs;
  Rx<PaytmModel> paytmModel = PaytmModel().obs;
  Rx<RazorPayModel> razorPayModel = RazorPayModel().obs;

  Rx<MidTrans> midTransModel = MidTrans().obs;
  Rx<OrangeMoney> orangeMoneyModel = OrangeMoney().obs;
  Rx<Xendit> xenditModel = Xendit().obs;

  Future<void> getPaymentSettings() async {
    // Agar allaqachon yuklangan bo'lsa, qayta yuklamaslik
    if (_paymentSettingsCached && _paymentSettingsLoaded) return;
    
    await FireStoreUtils.getPaymentSettingsData().then((value) {
      stripeModel.value = StripeModel.fromJson(
        jsonDecode(Preferences.getString(Preferences.stripeSettings)),
      );
      payPalModel.value = PayPalModel.fromJson(
        jsonDecode(Preferences.getString(Preferences.paypalSettings)),
      );
      payStackModel.value = PayStackModel.fromJson(
        jsonDecode(Preferences.getString(Preferences.payStack)),
      );
      mercadoPagoModel.value = MercadoPagoModel.fromJson(
        jsonDecode(Preferences.getString(Preferences.mercadoPago)),
      );
      flutterWaveModel.value = FlutterWaveModel.fromJson(
        jsonDecode(Preferences.getString(Preferences.flutterWave)),
      );
      paytmModel.value = PaytmModel.fromJson(
        jsonDecode(Preferences.getString(Preferences.paytmSettings)),
      );
      payFastModel.value = PayFastModel.fromJson(
        jsonDecode(Preferences.getString(Preferences.payFastSettings)),
      );
      razorPayModel.value = RazorPayModel.fromJson(
        jsonDecode(Preferences.getString(Preferences.razorpaySettings)),
      );
      midTransModel.value = MidTrans.fromJson(
        jsonDecode(Preferences.getString(Preferences.midTransSettings)),
      );
      orangeMoneyModel.value = OrangeMoney.fromJson(
        jsonDecode(Preferences.getString(Preferences.orangeMoneySettings)),
      );
      xenditModel.value = Xendit.fromJson(
        jsonDecode(Preferences.getString(Preferences.xenditSettings)),
      );
      walletSettingModel.value = WalletSettingModel.fromJson(
        jsonDecode(Preferences.getString(Preferences.walletSettings)),
      );
      cashOnDeliverySettingModel.value = CodSettingModel.fromJson(
        jsonDecode(Preferences.getString(Preferences.codSettings)),
      );

      if (walletSettingModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.wallet.name;
      } else if (cashOnDeliverySettingModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.cod.name;
      } else if (stripeModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.stripe.name;
      } else if (payPalModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.paypal.name;
      } else if (payStackModel.value.isEnable == true) {
        selectedPaymentMethod.value = PaymentGateway.payStack.name;
      } else if (mercadoPagoModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.mercadoPago.name;
      } else if (flutterWaveModel.value.isEnable == true) {
        selectedPaymentMethod.value = PaymentGateway.flutterWave.name;
      } else if (payFastModel.value.isEnable == true) {
        selectedPaymentMethod.value = PaymentGateway.payFast.name;
      } else if (razorPayModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.razorpay.name;
      } else if (midTransModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.midTrans.name;
      } else if (orangeMoneyModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.orangeMoney.name;
      } else if (xenditModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.xendit.name;
      }
      Stripe.publishableKey = stripeModel.value.clientpublishableKey.toString();
      Stripe.merchantIdentifier = 'eMart Customer';
      Stripe.instance.applySettings();
      setRef();

      razorPay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccess);
      razorPay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWaller);
      razorPay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentError);
    });
  }

  // Strip
  Future<void> stripeMakePayment({required String amount}) async {
    log(double.parse(amount).toStringAsFixed(0));
    try {
      Map<String, dynamic>? paymentIntentData = await createStripeIntent(
        amount: amount,
      );
      log("stripe Responce====>$paymentIntentData");
      if (paymentIntentData!.containsKey("error")) {
        Get.back();
        ShowToastDialog.showToast(
          "Something went wrong, please contact admin.".tr,
        );
      } else {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentIntentData['client_secret'],
            allowsDelayedPaymentMethods: false,
            googlePay: const PaymentSheetGooglePay(
              merchantCountryCode: 'US',
              testEnv: true,
              currencyCode: "USD",
            ),
            customFlow: true,
            style: ThemeMode.system,
            appearance: PaymentSheetAppearance(
              colors: PaymentSheetAppearanceColors(
                primary: AppThemeData.primary300,
              ),
            ),
            merchantDisplayName: 'GoRide',
          ),
        );
        displayStripePaymentSheet(amount: amount);
      }
    } catch (e, s) {
      log("$e \n$s");
      ShowToastDialog.showToast("exception:$e \n$s");
    }
  }

  Future<void> displayStripePaymentSheet({required String amount}) async {
    try {
      await Stripe.instance.presentPaymentSheet().then((value) {
        ShowToastDialog.showToast("Payment successfully".tr);
        completeOrder();
      });
    } on StripeException catch (e) {
      var lo1 = jsonEncode(e);
      var lo2 = jsonDecode(lo1);
      StripePayFailedModel lom = StripePayFailedModel.fromJson(lo2);
      ShowToastDialog.showToast(lom.error.message);
    } catch (e) {
      ShowToastDialog.showToast(e.toString());
    }
  }

  Future createStripeIntent({required String amount}) async {
    try {
      Map<String, dynamic> body = {
        'amount': ((double.parse(amount) * 100).round()).toString(),
        'currency': "USD",
        'payment_method_types[]': 'card',
        "description": "Strip Payment",
        "shipping[name]": userModel.value.fullName(),
        "shipping[address][line1]": "510 Townsend St",
        "shipping[address][postal_code]": "98140",
        "shipping[address][city]": "San Francisco",
        "shipping[address][state]": "CA",
        "shipping[address][country]": "US",
      };
      var stripeSecret = stripeModel.value.stripeSecret;
      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        body: body,
        headers: {
          'Authorization': 'Bearer $stripeSecret',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      log(e.toString());
    }
  }

  //mercadoo
  Future<Null> mercadoPagoMakePayment({
    required BuildContext context,
    required String amount,
  }) async {
    final headers = {
      'Authorization': 'Bearer ${mercadoPagoModel.value.accessToken}',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      "items": [
        {
          "title": "Test",
          "description": "Test Payment",
          "quantity": 1,
          "currency_id": "BRL", // or your preferred currency
          "unit_price": double.parse(amount),
        },
      ],
      "payer": {"email": userModel.value.email},
      "back_urls": {
        "failure": "${Constant.globalUrl}payment/failure",
        "pending": "${Constant.globalUrl}payment/pending",
        "success": "${Constant.globalUrl}payment/success",
      },
      "auto_return": "approved",
      // Automatically return after payment is approved
    });

    final response = await http.post(
      Uri.parse("https://api.mercadopago.com/checkout/preferences"),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      Get.to(MercadoPagoScreen(initialURl: data['init_point']))!.then((value) {
        if (value) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          completeOrder();
        } else {
          ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
        }
      });
    } else {
      print('Error creating preference: ${response.body}');
      return null;
    }
  }

  //Paypal
  void paypalPaymentSheet(String amount, context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (BuildContext context) => UsePaypal(
              sandboxMode: payPalModel.value.isLive == true ? false : true,
              clientId: payPalModel.value.paypalClient ?? '',
              secretKey: payPalModel.value.paypalSecret ?? '',
              returnURL: "com.parkme://paypalpay",
              cancelURL: "com.parkme://paypalpay",
              transactions: [
                {
                  "amount": {
                    "total": amount,
                    "currency": "USD",
                    "details": {"subtotal": amount},
                  },
                },
              ],
              note: "Contact us for any questions on your order.",
              onSuccess: (Map params) async {
                completeOrder();
                ShowToastDialog.showToast("Payment Successful!!".tr);
              },
              onError: (error) {
                Get.back();
                ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
              },
              onCancel: (params) {
                Get.back();
                ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
              },
            ),
      ),
    );
  }

  ///PayStack Payment Method
  Future<void> payStackPayment(String totalAmount) async {
    await PayStackURLGen.payStackURLGen(
      amount: (double.parse(totalAmount) * 100).toString(),
      currency: "ZAR",
      secretKey: payStackModel.value.secretKey.toString(),
      userModel: userModel.value,
    ).then((value) async {
      if (value != null) {
        PayStackUrlModel payStackModel0 = value;
        Get.to(
          PayStackScreen(
            secretKey: payStackModel.value.secretKey.toString(),
            callBackUrl: payStackModel.value.callbackURL.toString(),
            initialURl: payStackModel0.data.authorizationUrl,
            amount: totalAmount,
            reference: payStackModel0.data.reference,
          ),
        )!.then((value) {
          if (value) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            completeOrder();
          } else {
            ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
          }
        });
      } else {
        ShowToastDialog.showToast(
          "Something went wrong, please contact admin.".tr,
        );
      }
    });
  }

  //flutter wave Payment Method
  Future<Null> flutterWaveInitiatePayment({
    required BuildContext context,
    required String amount,
  }) async {
    final url = Uri.parse('https://api.flutterwave.com/v3/payments');
    final headers = {
      'Authorization': 'Bearer ${flutterWaveModel.value.secretKey}',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      "tx_ref": _ref,
      "amount": amount,
      "currency": "NGN",
      "redirect_url": "${Constant.globalUrl}payment/success",
      "payment_options": "ussd, card, barter, payattitude",
      "customer": {
        "email": userModel.value.email.toString(),
        "phonenumber": userModel.value.phoneNumber, // Add a real phone number
        "name": userModel.value.fullName(), // Add a real customer name
      },
      "customizations": {
        "title": "Payment for Services",
        "description": "Payment for XYZ services",
      },
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      Get.to(MercadoPagoScreen(initialURl: data['data']['link']))!.then((
        value,
      ) {
        if (value) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          completeOrder();
        } else {
          ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
        }
      });
    } else {
      print('Payment initialization failed: ${response.body}');
      return null;
    }
  }

  String? _ref;

  void setRef() {
    maths.Random numRef = maths.Random();
    int year = DateTime.now().year;
    int refNumber = numRef.nextInt(20000);
    if (Platform.isAndroid) {
      _ref = "AndroidRef$year$refNumber";
    } else if (Platform.isIOS) {
      _ref = "IOSRef$year$refNumber";
    }
  }

  // payFast
  void payFastPayment({required BuildContext context, required String amount}) {
    PayStackURLGen.getPayHTML(
      payFastSettingData: payFastModel.value,
      amount: amount.toString(),
      userModel: userModel.value,
    ).then((String? value) async {
      bool isDone = await Get.to(
        PayFastScreen(htmlData: value!, payFastSettingData: payFastModel.value),
      );
      if (isDone) {
        Get.back();
        ShowToastDialog.showToast("Payment successfully".tr);
        completeOrder();
      } else {
        Get.back();
        ShowToastDialog.showToast("Payment Failed".tr);
      }
    });
  }

  ///Paytm payment function
  Future<void> getPaytmCheckSum(context, {required double amount}) async {
    // final String orderId = DateTime.now().millisecondsSinceEpoch.toString();
    // String getChecksum = "${Constant.globalUrl}payments/getpaytmchecksum";
    //
    // final response = await http.post(
    //   Uri.parse(getChecksum),
    //   headers: {},
    //   body: {"mid": paytmModel.value.paytmMID.toString(), "order_id": orderId, "key_secret": paytmModel.value.pAYTMMERCHANTKEY.toString()},
    // );
    //
    // final data = jsonDecode(response.body);
    // await verifyCheckSum(checkSum: data["code"], amount: amount, orderId: orderId).then((value) {
    //   initiatePayment(amount: amount, orderId: orderId).then((value) {
    //     String callback = "";
    //     if (paytmModel.value.isSandboxEnabled == true) {
    //       callback = "${callback}https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    //     } else {
    //       callback = "${callback}https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    //     }
    //
    //     GetPaymentTxtTokenModel result = value;
    //     startTransaction(context, txnTokenBy: result.body.txnToken, orderId: orderId, amount: amount, callBackURL: callback, isStaging: paytmModel.value.isSandboxEnabled);
    //   });
    // });
  }

  Future<void> startTransaction(
    context, {
    required String txnTokenBy,
    required orderId,
    required double amount,
    required callBackURL,
    required isStaging,
  }) async {
    // try {
    //   var response = AllInOneSdk.startTransaction(
    //     paytmModel.value.paytmMID.toString(),
    //     orderId,
    //     amount.toString(),
    //     txnTokenBy,
    //     callBackURL,
    //     isStaging,
    //     true,
    //     true,
    //   );
    //
    //   response.then((value) {
    //     if (value!["RESPMSG"] == "Txn Success") {
    //       print("txt done!!");
    //       ShowToastDialog.showToast("Payment Successful!!");
    //       completeOrder();
    //     }
    //   }).catchError((onError) {
    //     if (onError is PlatformException) {
    //       Get.back();
    //
    //       ShowToastDialog.showToast(onError.message.toString());
    //     } else {
    //       log("======>>2");
    //       Get.back();
    //       ShowToastDialog.showToast(onError.message.toString());
    //     }
    //   });
    // } catch (err) {
    //   Get.back();
    //   ShowToastDialog.showToast(err.toString());
    // }
  }

  Future verifyCheckSum({
    required String checkSum,
    required double amount,
    required orderId,
  }) async {
    String getChecksum = "${Constant.globalUrl}payments/validatechecksum";
    final response = await http.post(
      Uri.parse(getChecksum),
      headers: {},
      body: {
        "mid": paytmModel.value.paytmMID.toString(),
        "order_id": orderId,
        "key_secret": paytmModel.value.pAYTMMERCHANTKEY.toString(),
        "checksum_value": checkSum,
      },
    );
    final data = jsonDecode(response.body);
    return data['status'];
  }

  Future<GetPaymentTxtTokenModel> initiatePayment({
    required double amount,
    required orderId,
  }) async {
    String initiateURL = "${Constant.globalUrl}payments/initiatepaytmpayment";
    String callback = "";
    if (paytmModel.value.isSandboxEnabled == true) {
      callback =
          "${callback}https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    } else {
      callback =
          "${callback}https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    }
    final response = await http.post(
      Uri.parse(initiateURL),
      headers: {},
      body: {
        "mid": paytmModel.value.paytmMID,
        "order_id": orderId,
        "key_secret": paytmModel.value.pAYTMMERCHANTKEY,
        "amount": amount.toString(),
        "currency": "INR",
        "callback_url": callback,
        "custId": FireStoreUtils.getCurrentUid(),
        "issandbox": paytmModel.value.isSandboxEnabled == true ? "1" : "2",
      },
    );
    log(response.body);
    final data = jsonDecode(response.body);
    if (data["body"]["txnToken"] == null ||
        data["body"]["txnToken"].toString().isEmpty) {
      Get.back();
      ShowToastDialog.showToast(
        "something went wrong, please contact admin.".tr,
      );
    }
    return GetPaymentTxtTokenModel.fromJson(data);
  }

  ///RazorPay payment function
  final Razorpay razorPay = Razorpay();

  void openCheckout({required amount, required orderId}) async {
    var options = {
      'key': razorPayModel.value.razorpayKey,
      'amount': amount * 100,
      'name': 'GoRide',
      'order_id': orderId,
      "currency": "INR",
      'description': 'wallet Topup',
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
      'prefill': {
        'contact': userModel.value.phoneNumber,
        'email': userModel.value.email,
      },
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      razorPay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void handlePaymentSuccess(PaymentSuccessResponse response) {
    Get.back();
    ShowToastDialog.showToast("Payment Successful!!".tr);
    completeOrder();
  }

  void handleExternalWaller(ExternalWalletResponse response) {
    Get.back();
    ShowToastDialog.showToast("Payment Processing!! via".tr);
  }

  void handlePaymentError(PaymentFailureResponse response) {
    Get.back();
    ShowToastDialog.showToast("Payment Failed!!".tr);
  }

  bool isCurrentDateInRange(DateTime startDate, DateTime endDate) {
    final currentDate = DateTime.now();
    return currentDate.isAfter(startDate) && currentDate.isBefore(endDate);
  }

  //Midtrans payment
  Future<void> midtransMakePayment({
    required String amount,
    required BuildContext context,
  }) async {
    await createPaymentLink(amount: amount).then((url) {
      ShowToastDialog.closeLoader();
      if (url != '') {
        Get.to(() => MidtransScreen(initialURl: url))!.then((value) {
          if (value == true) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            completeOrder();
          } else {
            ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
          }
        });
      }
    });
  }

  Future<String> createPaymentLink({required var amount}) async {
    var ordersId = const Uuid().v1();
    final url = Uri.parse(
      midTransModel.value.isSandbox!
          ? 'https://api.sandbox.midtrans.com/v1/payment-links'
          : 'https://api.midtrans.com/v1/payment-links',
    );

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': generateBasicAuthHeader(
          midTransModel.value.serverKey!,
        ),
      },
      body: jsonEncode({
        'transaction_details': {
          'order_id': ordersId,
          'gross_amount': double.parse(amount.toString()).toInt(),
        },
        'usage_limit': 2,
        "callbacks": {
          "finish": "https://www.google.com?merchant_order_id=$ordersId",
        },
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      return responseData['payment_url'];
    } else {
      ShowToastDialog.showToast(
        "something went wrong, please contact admin.".tr,
      );
      return '';
    }
  }

  String generateBasicAuthHeader(String apiKey) {
    String credentials = '$apiKey:';
    String base64Encoded = base64Encode(utf8.encode(credentials));
    return 'Basic $base64Encoded';
  }

  //Orangepay payment
  static String accessToken = '';
  static String payToken = '';
  static String orderId = '';
  static String amount = '';

  Future<void> orangeMakePayment({
    required String amount,
    required BuildContext context,
  }) async {
    reset();
    var id = const Uuid().v4();
    var paymentURL = await fetchToken(
      context: context,
      orderId: id,
      amount: amount,
      currency: 'USD',
    );
    ShowToastDialog.closeLoader();
    if (paymentURL.toString() != '') {
      Get.to(
        () => OrangeMoneyScreen(
          initialURl: paymentURL,
          accessToken: accessToken,
          amount: amount,
          orangePay: orangeMoneyModel.value,
          orderId: orderId,
          payToken: payToken,
        ),
      )!.then((value) {
        if (value == true) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          completeOrder();
          ();
        }
      });
    } else {
      ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
    }
  }

  Future fetchToken({
    required String orderId,
    required String currency,
    required BuildContext context,
    required String amount,
  }) async {
    String apiUrl = 'https://api.orange.com/oauth/v3/token';
    Map<String, String> requestBody = {'grant_type': 'client_credentials'};

    var response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Authorization': "Basic ${orangeMoneyModel.value.auth!}",
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: requestBody,
    );

    // Handle the response

    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.body);

      accessToken = responseData['access_token'];
      // ignore: use_build_context_synchronously
      return await webpayment(
        context: context,
        amountData: amount,
        currency: currency,
        orderIdData: orderId,
      );
    } else {
      ShowToastDialog.showToast(
        "Something went wrong, please contact admin.".tr,
      );
      return '';
    }
  }

  Future webpayment({
    required String orderIdData,
    required BuildContext context,
    required String currency,
    required String amountData,
  }) async {
    orderId = orderIdData;
    amount = amountData;
    String apiUrl =
        orangeMoneyModel.value.isSandbox! == true
            ? 'https://api.orange.com/orange-money-webpay/dev/v1/webpayment'
            : 'https://api.orange.com/orange-money-webpay/cm/v1/webpayment';
    Map<String, String> requestBody = {
      "merchant_key": orangeMoneyModel.value.merchantKey ?? '',
      "currency": orangeMoneyModel.value.isSandbox == true ? "OUV" : currency,
      "order_id": orderId,
      "amount": amount,
      "reference": 'Y-Note Test',
      "lang": "en",
      "return_url": orangeMoneyModel.value.returnUrl!.toString(),
      "cancel_url": orangeMoneyModel.value.cancelUrl!.toString(),
      "notif_url": orangeMoneyModel.value.notifUrl!.toString(),
    };

    var response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(requestBody),
    );

    // Handle the response
    if (response.statusCode == 201) {
      Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData['message'] == 'OK') {
        payToken = responseData['pay_token'];
        return responseData['payment_url'];
      } else {
        return '';
      }
    } else {
      ShowToastDialog.showToast(
        "Something went wrong, please contact admin.".tr,
      );
      return '';
    }
  }

  static void reset() {
    accessToken = '';
    payToken = '';
    orderId = '';
    amount = '';
  }

  //XenditPayment
  Future<void> xenditPayment(context, amount) async {
    await createXenditInvoice(amount: amount).then((model) {
      ShowToastDialog.closeLoader();
      if (model.id != null) {
        Get.to(
          () => XenditScreen(
            initialURl: model.invoiceUrl ?? '',
            transId: model.id ?? '',
            apiKey: xenditModel.value.apiKey!.toString(),
          ),
        )!.then((value) {
          if (value == true) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            completeOrder();
            ();
          } else {
            ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
          }
        });
      }
    });
  }

  Future<XenditModel> createXenditInvoice({required var amount}) async {
    const url = 'https://api.xendit.co/v2/invoices';
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': generateBasicAuthHeader(
        xenditModel.value.apiKey!.toString(),
      ),
      // 'Cookie': '__cf_bm=yERkrx3xDITyFGiou0bbKY1bi7xEwovHNwxV1vCNbVc-1724155511-1.0.1.1-jekyYQmPCwY6vIJ524K0V6_CEw6O.dAwOmQnHtwmaXO_MfTrdnmZMka0KZvjukQgXu5B.K_6FJm47SGOPeWviQ',
    };

    final body = jsonEncode({
      'external_id': const Uuid().v1(),
      'amount': amount,
      'payer_email': 'customer@domain.com',
      'description': 'Test - VA Successful invoice payment',
      'currency': 'IDR', //IDR, PHP, THB, VND, MYR
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        XenditModel model = XenditModel.fromJson(jsonDecode(response.body));
        return model;
      } else {
        return XenditModel();
      }
    } catch (e) {
      return XenditModel();
    }
  }
}
