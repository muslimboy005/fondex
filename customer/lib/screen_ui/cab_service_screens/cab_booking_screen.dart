import 'dart:async';
import 'dart:io';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/tax_model.dart';
import 'package:customer/models/vehicle_type.dart';
import 'package:customer/payment/createRazorPayOrderModel.dart';
import 'package:customer/payment/rozorpayConroller.dart';
import 'package:customer/screen_ui/cab_service_screens/cab_coupon_code_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/chat_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_border.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/utils/utils.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;
import 'package:customer/utils/yandex_map_utils.dart';
import '../../constant/constant.dart';
import '../../controllers/cab_booking_controller.dart';
import '../../controllers/cab_dashboard_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/user_model.dart';
import '../../service/fire_store_utils.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/show_toast_dialog.dart';
import '../../themes/text_field_widget.dart';
import '../../widget/osm_map/map_picker_page.dart';
import '../../widget/place_picker/location_picker_screen.dart';
import '../../widget/place_picker/selected_location_model.dart';
import 'package:location/location.dart';

class CabBookingScreen extends StatelessWidget {
  const CabBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: CabBookingController(),
      builder: (controller) {
        return Scaffold(
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Stack(
                    children: [
                      Constant.isOsmMap
                          ? flutterMap.FlutterMap(
                            mapController: controller.mapOsmController,
                            options: flutterMap.MapOptions(
                              initialCenter:
                                  Constant.currentLocation != null
                                      ? latlong.LatLng(
                                        Constant.currentLocation!.latitude,
                                        Constant.currentLocation!.longitude,
                                      )
                                      : controller.currentOrder.value.id != null
                                      ? latlong.LatLng(
                                        double.parse(
                                          controller
                                              .currentOrder
                                              .value
                                              .sourceLocation!
                                              .latitude
                                              .toString(),
                                        ),
                                        double.parse(
                                          controller
                                              .currentOrder
                                              .value
                                              .sourceLocation!
                                              .longitude
                                              .toString(),
                                        ),
                                      )
                                      : latlong.LatLng(
                                        41.4219057,
                                        -102.0840772,
                                      ),
                              initialZoom: 10,
                            ),
                            children: [
                              flutterMap.TileLayer(
                                urlTemplate:
                                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    Platform.isAndroid
                                        ? "com.emart.customer"
                                        : "com.emart.customer.ios",
                              ),
                              flutterMap.MarkerLayer(
                                markers: controller.osmMarker,
                              ),
                              if (controller.routePoints.isNotEmpty)
                                flutterMap.PolylineLayer(
                                  polylines: [
                                    flutterMap.Polyline(
                                      points: controller.routePoints,
                                      strokeWidth: 5.0,
                                      color: Colors.blue,
                                    ),
                                  ],
                                ),
                            ],
                          )
                          : Constant.isYandexMap
                              ? ym.YandexMap(
                                onMapCreated:
                                    (ym.YandexMapController mapController) async {
                                  controller.yandexMapController =
                                      mapController;
                                  await mapController.toggleUserLayer(
                                    visible: true,
                                  );
                                  await mapController.moveCamera(
                                    ym.CameraUpdate.newCameraPosition(
                                      ym.CameraPosition(
                                        target: ym.Point(
                                          latitude: controller
                                              .currentPosition
                                              .value
                                              .latitude,
                                          longitude: controller
                                              .currentPosition
                                              .value
                                              .longitude,
                                        ),
                                        zoom: 14,
                                      ),
                                    ),
                                  );
                                  if (Constant.currentLocation != null) {
                                    controller.setDepartureMarker(
                                      Constant.currentLocation!.latitude,
                                      Constant.currentLocation!.longitude,
                                    );
                                    controller.searchPlaceNameGoogle();
                                  }
                                },
                                mapObjects: yandexMapObjectsFromGoogle(
                                  markers: controller.markers.toSet(),
                                  polylines: controller.polyLines.values,
                                ),
                              )
                              : GoogleMap(
                                onMapCreated: (googleMapController) {
                                  controller.mapController =
                                      googleMapController;

                                  if (Constant.currentLocation != null) {
                                    controller.setDepartureMarker(
                                      Constant.currentLocation!.latitude,
                                      Constant.currentLocation!.longitude,
                                    );
                                    controller.searchPlaceNameGoogle();
                                  }
                                },
                                initialCameraPosition: CameraPosition(
                                  target: controller.currentPosition.value,
                                  zoom: 14,
                                ),
                                myLocationEnabled: true,
                                zoomControlsEnabled: true,
                                zoomGesturesEnabled: true,
                                polylines: Set<Polyline>.of(
                                  controller.polyLines.values,
                                ),
                                markers:
                                    controller.markers
                                        .toSet(), // reactive marker set
                              ),

                      Positioned(
                        top: 50,
                        left: Constant.isRtl ? null : 20,
                        right: Constant.isRtl ? 20 : null,
                        child: InkWell(
                          onTap: () {
                            if (controller.bottomSheetType.value ==
                                "vehicleSelection") {
                              // Vehicle selection'dan back bosilganda cab home screen'ga qaytish
                              // State'ni tozalash - search results va focus holatini
                              controller.destinationSearchResults.clear();
                              controller.isSearchingDestination.value = false;
                              controller.searchError.value = '';
                              Get.back();
                            } else if (controller.bottomSheetType.value ==
                                "location") {
                              // Location bottom sheet'dan back bosilganda vehicle selection'ga qaytish
                              controller.bottomSheetType.value =
                                  "vehicleSelection";
                            } else if (controller.bottomSheetType.value ==
                                "payment") {
                              controller.bottomSheetType.value =
                                  "vehicleSelection";
                            } else if (controller.bottomSheetType.value ==
                                "conformRide") {
                              controller.bottomSheetType.value = "payment";
                            } else if (controller.bottomSheetType.value ==
                                    "waitingDriver" ||
                                controller.bottomSheetType.value ==
                                    "driverDetails") {
                              Get.back(result: true);
                            } else {
                              Get.back();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? AppThemeData.greyDark50
                                      : AppThemeData.grey50,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Center(
                                child: Icon(
                                  Icons.arrow_back_ios_new,
                                  color:
                                      isDark
                                          ? AppThemeData.grey50
                                          : AppThemeData.greyDark50,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      controller.bottomSheetType.value == "location"
                          ? vehicleSelection(context, controller, isDark)
                          : controller.bottomSheetType.value ==
                              "vehicleSelection"
                          ? vehicleSelection(context, controller, isDark)
                          : controller.bottomSheetType.value == "payment"
                          ? paymentBottomSheet(context, controller, isDark)
                          : controller.bottomSheetType.value == "conformRide"
                          ? conformBottomSheet(context, isDark)
                          : controller.bottomSheetType.value ==
                              "waitingForDriver"
                          ? waitingDialog(context, controller, isDark)
                          : controller.bottomSheetType.value == "driverDetails"
                          ? driverDialog(context, controller, isDark)
                          : SizedBox(),
                    ],
                  ),
        );
      },
    );
  }

  Widget searchLocationBottomSheet(
    BuildContext context,
    CabBookingController controller,
    bool isDark,
  ) {
    final RxString selectedServiceType = 'ride'.obs; // 'ride' or 'intercity'
    final FocusNode destinationFocusNode = FocusNode();
    final RxBool isDestinationFocused = false.obs;
    final DraggableScrollableController sheetController =
        DraggableScrollableController();
    Timer? searchDebounce;

    destinationFocusNode.addListener(() {
      isDestinationFocused.value = destinationFocusNode.hasFocus;
      // Klaviatura ochilganda bottom sheet ni 0.8 ga o'zgartirish
      if (destinationFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (sheetController.isAttached) {
            sheetController.animateTo(
              0.80,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        // Klaviatura yopilganda bottom sheet ni 0.4 ga qaytarish
        Future.delayed(const Duration(milliseconds: 300), () {
          if (sheetController.isAttached) {
            sheetController.animateTo(
              0.40,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    // Destination field ga listener qo'shish - search uchun (debounce bilan)
    controller.destinationTextEditController.value.addListener(() {
      searchDebounce?.cancel();
      final query = controller.destinationTextEditController.value.text;
      if (query.isNotEmpty && query.length >= 3) {
        searchDebounce = Timer(const Duration(milliseconds: 500), () {
          if (Constant.selectedMapType == 'osm') {
            controller.searchDestinationOSM(query);
          } else {
            controller.searchDestinationGoogle(query);
          }
        });
      } else {
        controller.destinationSearchResults.clear();
      }
    });

    return Positioned.fill(
      child: DraggableScrollableSheet(
        controller: sheetController,
        initialChildSize: 0.40,
        minChildSize: 0.40,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppThemeData.grey700 : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(35),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppThemeData.grey400,
                    ),
                    height: 4,
                    width: 33,
                  ),
                  const SizedBox(height: 16),
                  // Service Type Selection
                  Obx(
                    () => Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              selectedServiceType.value = 'ride';
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    selectedServiceType.value == 'ride'
                                        ? AppThemeData.warning50
                                        : (isDark
                                            ? AppThemeData.grey600
                                            : AppThemeData.grey100),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    "assets/icons/ic_ride.svg",
                                    height: 24,
                                    width: 24,
                                    colorFilter: ColorFilter.mode(
                                      selectedServiceType.value == 'ride'
                                          ? AppThemeData.taxiBooking500
                                          : (isDark
                                              ? AppThemeData.grey400
                                              : AppThemeData.grey600),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "City rides, 24x7 availability".tr,
                                    style: AppThemeData.semiBoldTextStyle(
                                      fontSize: 14,
                                      color:
                                          selectedServiceType.value == 'ride'
                                              ? AppThemeData.taxiBooking500
                                              : (isDark
                                                  ? AppThemeData.grey400
                                                  : AppThemeData.grey600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              selectedServiceType.value = 'intercity';
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    selectedServiceType.value == 'intercity'
                                        ? AppThemeData.carRent50
                                        : (isDark
                                            ? AppThemeData.grey600
                                            : AppThemeData.grey100),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    "assets/icons/ic_intercity.svg",
                                    height: 24,
                                    width: 24,
                                    colorFilter: ColorFilter.mode(
                                      selectedServiceType.value == 'intercity'
                                          ? AppThemeData.carRent500
                                          : (isDark
                                              ? AppThemeData.grey400
                                              : AppThemeData.grey600),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      "Intercity/Outstation".tr,
                                      style: AppThemeData.semiBoldTextStyle(
                                        fontSize: 12,
                                        color:
                                            selectedServiceType.value ==
                                                    'intercity'
                                                ? AppThemeData.carRent500
                                                : (isDark
                                                    ? AppThemeData.grey400
                                                    : AppThemeData.grey600),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Origin Location
                  InkWell(
                    onTap: () async {
                      if (Constant.selectedMapType == 'osm') {
                        final result = await Get.to(() => MapPickerPage());
                        if (result != null) {
                          controller.sourceTextEditController.value.text = '';
                          final firstPlace = result;
                          if (Constant.checkZoneCheck(
                                firstPlace.coordinates.latitude,
                                firstPlace.coordinates.longitude,
                              ) ==
                              true) {
                            final lat = firstPlace.coordinates.latitude;
                            final lng = firstPlace.coordinates.longitude;
                            final address = firstPlace.address;
                            controller.sourceTextEditController.value.text =
                                address.toString();
                            controller.setDepartureMarker(lat, lng);
                          } else {
                            ShowToastDialog.showToast(
                              "Service is unavailable at the selected address."
                                  .tr,
                            );
                          }
                        }
                      } else {
                        Get.to(LocationPickerScreen())!.then((value) async {
                          if (value != null) {
                            SelectedLocationModel selectedLocationModel = value;
                            if (Constant.checkZoneCheck(
                                  selectedLocationModel.latLng!.latitude,
                                  selectedLocationModel.latLng!.longitude,
                                ) ==
                                true) {
                              controller
                                  .sourceTextEditController
                                  .value
                                  .text = Utils.formatAddress(
                                selectedLocation: selectedLocationModel,
                              );
                              controller.setDepartureMarker(
                                selectedLocationModel.latLng!.latitude,
                                selectedLocationModel.latLng!.longitude,
                              );
                            } else {
                              ShowToastDialog.showToast(
                                "Service is unavailable at the selected address."
                                    .tr,
                              );
                            }
                          }
                        });
                      }
                    },
                    child: TextFieldWidget(
                      controller: controller.sourceTextEditController.value,
                      hintText:
                          Constant.selectedLocation.getFullAddress().isNotEmpty
                              ? Constant.selectedLocation.getFullAddress()
                              : "Pickup Location".tr,
                      enable: false,
                      prefix: Padding(
                        padding: const EdgeInsets.only(left: 10, right: 10),
                        child: Image.asset(
                          "assets/icons/pickup.png",
                          height: 22,
                          width: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Destination Location
                  GestureDetector(
                    onTap: () {
                      destinationFocusNode.requestFocus();
                    },
                    child: TextFieldWidget(
                      controller:
                          controller.destinationTextEditController.value,
                      hintText: "→ Qayerga boramiz?".tr,
                      enable: true,
                      focusNode: destinationFocusNode,
                      onchange: (value) {
                        searchDebounce?.cancel();
                        if (value.isNotEmpty && value.length >= 3) {
                          searchDebounce = Timer(
                            const Duration(milliseconds: 500),
                            () {
                              if (Constant.selectedMapType == 'osm') {
                                controller.searchDestinationOSM(value);
                              } else {
                                controller.searchDestinationGoogle(value);
                              }
                            },
                          );
                        } else {
                          controller.destinationSearchResults.clear();
                        }
                      },
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 10, right: 10),
                        child: Icon(Icons.arrow_forward, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Suggested Destinations
                  Obx(
                    () =>
                        isDestinationFocused.value
                            ? Expanded(
                              child:
                                  controller.isSearchingDestination.value
                                      ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                      : controller
                                          .destinationSearchResults
                                          .isEmpty
                                      ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: Text(
                                            controller
                                                        .destinationTextEditController
                                                        .value
                                                        .text
                                                        .length <
                                                    3
                                                ? "Kamida 3 ta belgi kiriting"
                                                    .tr
                                                : "No results found".tr,
                                            style: AppThemeData.mediumTextStyle(
                                              fontSize: 14,
                                              color:
                                                  isDark
                                                      ? AppThemeData.greyDark700
                                                      : AppThemeData.grey700,
                                            ),
                                          ),
                                        ),
                                      )
                                      : ListView(
                                        controller: scrollController,
                                        children:
                                            controller.destinationSearchResults.map((
                                              result,
                                            ) {
                                              return _buildSuggestedDestination(
                                                result['name'] ?? '',
                                                '',
                                                result['address'] ?? '',
                                                () async {
                                                  if (Constant
                                                          .selectedMapType ==
                                                      'osm') {
                                                    final lat =
                                                        result['lat'] as double;
                                                    final lng =
                                                        result['lon'] as double;
                                                    controller
                                                            .destinationTextEditController
                                                            .value
                                                            .text =
                                                        result['address'] ?? '';
                                                    controller
                                                        .setDestinationMarker(
                                                          lat,
                                                          lng,
                                                        );
                                                  } else {
                                                    final placeId =
                                                        result['place_id']
                                                            as String?;
                                                    if (placeId != null) {
                                                      final details =
                                                          await controller
                                                              .getPlaceDetailsGoogle(
                                                                placeId,
                                                              );
                                                      if (details != null) {
                                                        controller
                                                                .destinationTextEditController
                                                                .value
                                                                .text =
                                                            details['address'] ??
                                                            '';
                                                        controller
                                                            .setDestinationMarker(
                                                              details['lat']
                                                                  as double,
                                                              details['lng']
                                                                  as double,
                                                            );
                                                      }
                                                    }
                                                  }
                                                  destinationFocusNode
                                                      .unfocus();
                                                  isDestinationFocused.value =
                                                      false;
                                                },
                                                isDark,
                                              );
                                            }).toList(),
                                      ),
                            )
                            : const SizedBox(),
                  ),
                  const SizedBox(height: 16),
                  RoundedButtonFill(
                    title: "Continue".tr,
                    onPress: () {
                      if (controller
                          .sourceTextEditController
                          .value
                          .text
                          .isEmpty) {
                        ShowToastDialog.showToast(
                          "Please select source location".tr,
                        );
                      } else if (controller
                          .destinationTextEditController
                          .value
                          .text
                          .isEmpty) {
                        ShowToastDialog.showToast(
                          "Please select destination location".tr,
                        );
                      } else {
                        controller.bottomSheetType.value = "vehicleSelection";
                      }
                    },
                    color: AppThemeData.primary300,
                    textColor: AppThemeData.grey900,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestedDestination(
    String title,
    String distance,
    String address,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppThemeData.grey600 : AppThemeData.grey50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: AppThemeData.primary300, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppThemeData.semiBoldTextStyle(
                      fontSize: 14,
                      color:
                          isDark
                              ? AppThemeData.greyDark900
                              : AppThemeData.grey900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (distance.isNotEmpty) ...[
                        Text(
                          distance,
                          style: AppThemeData.mediumTextStyle(
                            fontSize: 12,
                            color:
                                isDark
                                    ? AppThemeData.greyDark700
                                    : AppThemeData.grey700,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          address,
                          style: AppThemeData.mediumTextStyle(
                            fontSize: 12,
                            color:
                                isDark
                                    ? AppThemeData.greyDark700
                                    : AppThemeData.grey700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700,
            ),
          ],
        ),
      ),
    );
  }

  Widget vehicleSelection(
    BuildContext context,
    CabBookingController controller,
    bool isDark,
  ) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.38,
        minChildSize: 0.38,
        maxChildSize: 0.38,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppThemeData.grey700 : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppThemeData.grey400,
                        ),
                        height: 4,
                        width: 36,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Destination va joriy lokatsiya ko'rsatish
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark ? AppThemeData.grey600 : AppThemeData.grey50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Source (joriy joy - pickup location)
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.circle,
                                    color: Colors.white,
                                    size: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Obx(
                                  () => Text(
                                    controller
                                            .sourceTextEditController
                                            .value
                                            .text
                                            .isNotEmpty
                                        ? controller
                                            .sourceTextEditController
                                            .value
                                            .text
                                        : "Joriy manzil".tr,
                                    style: AppThemeData.mediumTextStyle(
                                      fontSize: 13,
                                      color:
                                          isDark
                                              ? AppThemeData.grey100
                                              : AppThemeData.grey900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Destination (boradigan joy - dropoff location)
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppThemeData.taxiBooking500,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.circle,
                                    color: Colors.white,
                                    size: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Obx(
                                  () => Text(
                                    controller
                                            .destinationTextEditController
                                            .value
                                            .text
                                            .isNotEmpty
                                        ? controller
                                            .destinationTextEditController
                                            .value
                                            .text
                                        : "Boradigan manzil".tr,
                                    style: AppThemeData.mediumTextStyle(
                                      fontSize: 13,
                                      color:
                                          isDark
                                              ? AppThemeData.grey300
                                              : AppThemeData.grey600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Vehicle type horizontal scroll - responsive
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: controller.vehicleTypes.length,
                        itemBuilder: (context, index) {
                          VehicleType vehicleType =
                              controller.vehicleTypes[index];

                          return Obx(() {
                            bool isSelected =
                                controller.selectedVehicleType.value.id ==
                                vehicleType.id;
                            return GestureDetector(
                              onTap: () {
                                controller.selectedVehicleType.value =
                                    vehicleType;
                              },
                              child: Container(
                                width: 115,
                                margin: EdgeInsets.only(
                                  right:
                                      index < controller.vehicleTypes.length - 1
                                          ? 12
                                          : 0,
                                ),
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? const Color(0xFFFF6839)
                                          : (isDark
                                              ? AppThemeData.grey600
                                              : AppThemeData.grey50),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? const Color(0xFFFF6839)
                                            : (isDark
                                                ? AppThemeData.grey500
                                                : AppThemeData.grey200),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // Vehicle image - positioned at bottom right, overflowing (orqada)
                                    Positioned(
                                      right: -45,
                                      bottom: -25,
                                      child: Image.network(
                                        vehicleType.vehicleIcon ?? "",
                                        height: 110,
                                        width: 150,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    // Text content - ustda, rasmning ustida
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.only(
                                          left: 12,
                                          top: 12,
                                          right: 8,
                                          bottom: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Vehicle name
                                            Text(
                                              vehicleType.name ?? "Ekonom",
                                              style:
                                                  AppThemeData.semiBoldTextStyle(
                                                    fontSize: 15,
                                                    color:
                                                        isSelected
                                                            ? Colors.white
                                                            : (isDark
                                                                ? AppThemeData
                                                                    .grey100
                                                                : AppThemeData
                                                                    .grey900),
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            // Price
                                            Text(
                                              " ${Constant.amountShow(amount: controller.getAmount(vehicleType).toString())}",
                                              style:
                                                  AppThemeData.mediumTextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        isSelected
                                                            ? Colors.white
                                                            : (isDark
                                                                ? AppThemeData
                                                                    .grey300
                                                                : AppThemeData
                                                                    .grey600),
                                                  ),
                                            ),
                                            // Duration
                                            Text(
                                              "(${controller.duration.value})",
                                              style:
                                                  AppThemeData.regularTextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        isSelected
                                                            ? Colors.white
                                                            : (isDark
                                                                ? AppThemeData
                                                                    .grey400
                                                                : AppThemeData
                                                                    .grey500),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Payment method and order button row
                    Row(
                      children: [
                        // Payment method button
                        Obx(
                          () => GestureDetector(
                            onTap: () async {
                              await controller.loadPaymentSettingsIfNeeded();
                              if (context.mounted) {
                                _showPaymentMethodPicker(
                                  context,
                                  controller,
                                  isDark,
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? AppThemeData.grey600
                                        : AppThemeData.grey100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getPaymentIcon(
                                      controller.selectedPaymentMethod.value,
                                    ),
                                    size: 18,
                                    color:
                                        isDark
                                            ? AppThemeData.grey200
                                            : AppThemeData.grey700,
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 18,
                                    color:
                                        isDark
                                            ? AppThemeData.grey300
                                            : AppThemeData.grey600,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Order button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (controller.selectedVehicleType.value.id !=
                                  null) {
                                controller.calculateTotalAmount();
                                // To'g'ridan to'g'ri buyurtma berish
                                controller.placeOrder();
                              } else {
                                ShowToastDialog.showToast(
                                  "Please select a vehicle type first.".tr,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6839),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              "Buyurtma berish".tr,
                              style: AppThemeData.semiBoldTextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getPaymentIcon(String paymentMethod) {
    switch (paymentMethod) {
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'cod':
        return Icons.money;
      case 'stripe':
        return Icons.credit_card;
      case 'paypal':
        return Icons.payment;
      default:
        return Icons.money;
    }
  }

  void _showPaymentMethodPicker(
    BuildContext context,
    CabBookingController controller,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppThemeData.grey700 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final hasCod =
            controller.cashOnDeliverySettingModel.value.isEnabled == true;
        final hasWallet = controller.walletSettingModel.value.isEnabled == true;
        final hasStripe = controller.stripeModel.value.isEnabled == true;
        final hasPaypal = controller.payPalModel.value.isEnabled == true;
        final hasPayStack = controller.payStackModel.value.isEnable == true;
        final hasMercado = controller.mercadoPagoModel.value.isEnabled == true;
        final hasFlutterWave =
            controller.flutterWaveModel.value.isEnable == true;
        final hasPayFast = controller.payFastModel.value.isEnable == true;
        final hasRazorpay = controller.razorPayModel.value.isEnabled == true;
        final hasMidTrans = controller.midTransModel.value.enable == true;
        final hasOrange = controller.orangeMoneyModel.value.enable == true;
        final hasXendit = controller.xenditModel.value.enable == true;
        final hasPayme =
            controller.paymeModel.value.isEnabled == true ||
            controller.paymeModel.value.enable == true;
        final hasAny =
            hasCod ||
            hasWallet ||
            hasStripe ||
            hasPaypal ||
            hasPayStack ||
            hasMercado ||
            hasFlutterWave ||
            hasPayFast ||
            hasRazorpay ||
            hasMidTrans ||
            hasOrange ||
            hasXendit ||
            hasPayme;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "To'lov usulini tanlang".tr,
                style: AppThemeData.boldTextStyle(
                  fontSize: 18,
                  color: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
                ),
              ),
              const SizedBox(height: 16),
              if (hasCod || !hasAny)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'cod',
                  'Naqd pul',
                  Icons.money,
                ),
              if (hasWallet)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'wallet',
                  'Hamyon',
                  Icons.account_balance_wallet,
                ),
              if (hasStripe)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'stripe',
                  'Karta',
                  Icons.credit_card,
                ),
              if (hasPaypal)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'paypal',
                  'PayPal',
                  Icons.payment,
                ),
              if (hasPayStack)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'payStack',
                  'PayStack',
                  Icons.payment,
                ),
              if (hasMercado)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'mercadoPago',
                  'MercadoPago',
                  Icons.payment,
                ),
              if (hasFlutterWave)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'flutterWave',
                  'FlutterWave',
                  Icons.payment,
                ),
              if (hasPayFast)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'payFast',
                  'PayFast',
                  Icons.payment,
                ),
              if (hasRazorpay)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'razorpay',
                  'RazorPay',
                  Icons.payment,
                ),
              if (hasMidTrans)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'midTrans',
                  'MidTrans',
                  Icons.payment,
                ),
              if (hasOrange)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'orangeMoney',
                  'OrangeMoney',
                  Icons.payment,
                ),
              if (hasXendit)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'xendit',
                  'Xendit',
                  Icons.payment,
                ),
              if (hasPayme)
                _buildPaymentOption(
                  context,
                  controller,
                  isDark,
                  'payme',
                  'Payme',
                  Icons.payment,
                ),
              if (!hasAny)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    "Boshqa to'lov usullarini admin sozlamalarida yoqing.".tr,
                    style: AppThemeData.regularTextStyle(
                      fontSize: 12,
                      color:
                          isDark ? AppThemeData.grey400 : AppThemeData.grey600,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentOption(
    BuildContext context,
    CabBookingController controller,
    bool isDark,
    String value,
    String label,
    IconData icon,
  ) {
    return Obx(
      () => ListTile(
        leading: Icon(
          icon,
          color:
              controller.selectedPaymentMethod.value == value
                  ? const Color(0xFFFF6839)
                  : (isDark ? AppThemeData.grey300 : AppThemeData.grey600),
        ),
        title: Text(
          label,
          style: AppThemeData.mediumTextStyle(
            fontSize: 16,
            color: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
          ),
        ),
        trailing:
            controller.selectedPaymentMethod.value == value
                ? Icon(Icons.check_circle, color: const Color(0xFFFF6839))
                : null,
        onTap: () {
          controller.selectedPaymentMethod.value = value;
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget paymentBottomSheet(
    BuildContext context,
    CabBookingController controller,
    bool isDark,
  ) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.70,
        minChildSize: 0.30,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? AppThemeData.grey700 : Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select Payment Method".tr,
                      style: AppThemeData.mediumTextStyle(
                        fontSize: 18,
                        color:
                            isDark
                                ? AppThemeData.greyDark900
                                : AppThemeData.grey900,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Get.back();
                      },
                      child: Icon(
                        Icons.close,
                        color:
                            isDark
                                ? AppThemeData.greyDark900
                                : AppThemeData.grey900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    controller: scrollController,
                    children: [
                      Text(
                        "Preferred Payment".tr,
                        textAlign: TextAlign.start,
                        style: AppThemeData.boldTextStyle(
                          fontSize: 15,
                          color:
                              isDark
                                  ? AppThemeData.greyDark500
                                  : AppThemeData.grey500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (controller.walletSettingModel.value.isEnabled ==
                              true ||
                          controller
                                  .cashOnDeliverySettingModel
                                  .value
                                  .isEnabled ==
                              true)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color:
                                isDark
                                    ? AppThemeData.greyDark100
                                    : AppThemeData.grey50,
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppThemeData.greyDark200
                                      : AppThemeData.grey200,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Visibility(
                                  visible:
                                      controller
                                          .walletSettingModel
                                          .value
                                          .isEnabled ==
                                      true,
                                  child: cardDecoration(
                                    controller,
                                    PaymentGateway.wallet,
                                    isDark,
                                    "assets/images/ic_wallet.png",
                                  ),
                                ),
                                Visibility(
                                  visible:
                                      controller
                                          .cashOnDeliverySettingModel
                                          .value
                                          .isEnabled ==
                                      true,
                                  child: cardDecoration(
                                    controller,
                                    PaymentGateway.cod,
                                    isDark,
                                    "assets/images/ic_cash.png",
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (controller.walletSettingModel.value.isEnabled ==
                              true ||
                          controller
                                  .cashOnDeliverySettingModel
                                  .value
                                  .isEnabled ==
                              true)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            Text(
                              "Other Payment Options".tr,
                              textAlign: TextAlign.start,
                              style: AppThemeData.boldTextStyle(
                                fontSize: 15,
                                color:
                                    isDark
                                        ? AppThemeData.greyDark500
                                        : AppThemeData.grey500,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color:
                              isDark
                                  ? AppThemeData.greyDark100
                                  : AppThemeData.grey50,
                          border: Border.all(
                            color:
                                isDark
                                    ? AppThemeData.greyDark200
                                    : AppThemeData.grey200,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Visibility(
                                visible:
                                    controller.stripeModel.value.isEnabled ==
                                    true,
                                child: cardDecoration(
                                  controller,
                                  PaymentGateway.stripe,
                                  isDark,
                                  "assets/images/stripe.png",
                                ),
                              ),
                              Visibility(
                                visible:
                                    controller.payPalModel.value.isEnabled ==
                                    true,
                                child: cardDecoration(
                                  controller,
                                  PaymentGateway.paypal,
                                  isDark,
                                  "assets/images/paypal.png",
                                ),
                              ),
                              Visibility(
                                visible:
                                    controller.payStackModel.value.isEnable ==
                                    true,
                                child: cardDecoration(
                                  controller,
                                  PaymentGateway.payStack,
                                  isDark,
                                  "assets/images/paystack.png",
                                ),
                              ),
                              Visibility(
                                visible:
                                    controller
                                        .mercadoPagoModel
                                        .value
                                        .isEnabled ==
                                    true,
                                child: cardDecoration(
                                  controller,
                                  PaymentGateway.mercadoPago,
                                  isDark,
                                  "assets/images/mercado-pago.png",
                                ),
                              ),
                              Visibility(
                                visible:
                                    controller
                                        .flutterWaveModel
                                        .value
                                        .isEnable ==
                                    true,
                                child: cardDecoration(
                                  controller,
                                  PaymentGateway.flutterWave,
                                  isDark,
                                  "assets/images/flutterwave_logo.png",
                                ),
                              ),
                              Visibility(
                                visible:
                                    controller.payFastModel.value.isEnable ==
                                    true,
                                child: cardDecoration(
                                  controller,
                                  PaymentGateway.payFast,
                                  isDark,
                                  "assets/images/payfast.png",
                                ),
                              ),
                              Visibility(
                                visible:
                                    controller.razorPayModel.value.isEnabled ==
                                    true,
                                child: cardDecoration(
                                  controller,
                                  PaymentGateway.razorpay,
                                  isDark,
                                  "assets/images/razorpay.png",
                                ),
                              ),
                              Visibility(
                                visible:
                                    controller.midTransModel.value.enable ==
                                    true,
                                child: cardDecoration(
                                  controller,
                                  PaymentGateway.midTrans,
                                  isDark,
                                  "assets/images/midtrans.png",
                                ),
                              ),
                              Visibility(
                                visible:
                                    controller.orangeMoneyModel.value.enable ==
                                    true,
                                child: cardDecoration(
                                  controller,
                                  PaymentGateway.orangeMoney,
                                  isDark,
                                  "assets/images/orange_money.png",
                                ),
                              ),
                              Visibility(
                                visible:
                                    controller.xenditModel.value.enable == true,
                                child: cardDecoration(
                                  controller,
                                  PaymentGateway.xendit,
                                  isDark,
                                  "assets/images/xendit.png",
                                ),
                              ),
                              Visibility(
                                visible:
                                    controller.paymeModel.value.isEnabled ==
                                        true ||
                                    controller.paymeModel.value.enable == true,
                                child: cardDecoration(
                                  controller,
                                  PaymentGateway.payme,
                                  isDark,
                                  "assets/images/payme.png",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
                RoundedButtonFill(
                  title: "Continue".tr,
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey900,
                  onPress: () async {
                    if (controller.selectedPaymentMethod.value.isEmpty) {
                      ShowToastDialog.showToast(
                        "Please select a payment method".tr,
                      );
                      return;
                    }
                    if (controller.selectedPaymentMethod.value == "wallet") {
                      num walletAmount =
                          controller.userModel.value.walletAmount ?? 0;
                      num totalAmount = controller.totalAmount.value;
                      if (walletAmount < totalAmount) {
                        // Qizil snackbar ko'rsatish
                        Get.snackbar(
                          "Error".tr,
                          "Insufficient wallet balance".tr,
                          snackPosition: SnackPosition.TOP,
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 3),
                          margin: const EdgeInsets.all(16),
                        );
                        return;
                      }
                    }
                    if (controller.currentOrder.value.id != null) {
                      controller.bottomSheetType.value = "driverDetails";
                    } else {
                      controller.bottomSheetType.value = "conformRide";
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget conformBottomSheet(BuildContext context, bool isDark) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return GetX(
            init: CabBookingController(),
            builder: (controller) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppThemeData.grey700 : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15.0,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppThemeData.grey400,
                        ),
                        height: 4,
                        width: 33,
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          children: [
                            const SizedBox(height: 10),
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? Colors.transparent
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Pickup Location
                                      InkWell(
                                        onTap: () async {
                                          if (Constant.selectedMapType ==
                                              'osm') {
                                            final result = await Get.to(
                                              () => MapPickerPage(),
                                            );
                                            if (result != null) {
                                              controller
                                                  .sourceTextEditController
                                                  .value
                                                  .text = '';
                                              final firstPlace = result;
                                              final lat =
                                                  firstPlace
                                                      .coordinates
                                                      .latitude;
                                              final lng =
                                                  firstPlace
                                                      .coordinates
                                                      .longitude;
                                              final address =
                                                  firstPlace.address;
                                              controller
                                                  .sourceTextEditController
                                                  .value
                                                  .text = address.toString();
                                              controller.setDepartureMarker(
                                                lat,
                                                lng,
                                              );
                                            }
                                          } else {
                                            Get.to(
                                              LocationPickerScreen(),
                                            )!.then((value) async {
                                              if (value != null) {
                                                SelectedLocationModel
                                                selectedLocationModel = value;

                                                controller
                                                    .sourceTextEditController
                                                    .value
                                                    .text = Utils.formatAddress(
                                                  selectedLocation:
                                                      selectedLocationModel,
                                                );
                                                controller.setDepartureMarker(
                                                  selectedLocationModel
                                                      .latLng!
                                                      .latitude,
                                                  selectedLocationModel
                                                      .latLng!
                                                      .longitude,
                                                );
                                              }
                                            });
                                          }
                                        },
                                        child: TextFieldWidget(
                                          controller:
                                              controller
                                                  .sourceTextEditController
                                                  .value,
                                          hintText: "Pickup Location".tr,
                                          enable: false,
                                          prefix: const Padding(
                                            padding: EdgeInsets.only(
                                              left: 10,
                                              right: 10,
                                            ),
                                            child: Icon(
                                              Icons.stop_circle_outlined,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      // Destination Location
                                      InkWell(
                                        onTap: () async {
                                          if (Constant.selectedMapType ==
                                              'osm') {
                                            final result = await Get.to(
                                              () => MapPickerPage(),
                                            );
                                            if (result != null) {
                                              controller
                                                  .destinationTextEditController
                                                  .value
                                                  .text = '';
                                              final firstPlace = result;
                                              final lat =
                                                  firstPlace
                                                      .coordinates
                                                      .latitude;
                                              final lng =
                                                  firstPlace
                                                      .coordinates
                                                      .longitude;
                                              final address =
                                                  firstPlace.address;
                                              controller
                                                  .destinationTextEditController
                                                  .value
                                                  .text = address.toString();
                                              controller.setDestinationMarker(
                                                lat,
                                                lng,
                                              );
                                            }
                                          } else {
                                            Get.to(
                                              LocationPickerScreen(),
                                            )!.then((value) async {
                                              if (value != null) {
                                                SelectedLocationModel
                                                selectedLocationModel = value;

                                                controller
                                                    .destinationTextEditController
                                                    .value
                                                    .text = Utils.formatAddress(
                                                  selectedLocation:
                                                      selectedLocationModel,
                                                );
                                                controller.setDestinationMarker(
                                                  selectedLocationModel
                                                      .latLng!
                                                      .latitude,
                                                  selectedLocationModel
                                                      .latLng!
                                                      .longitude,
                                                );
                                              }
                                            });
                                          }
                                        },
                                        child: TextFieldWidget(
                                          controller:
                                              controller
                                                  .destinationTextEditController
                                                  .value,
                                          // backgroundColor: AppThemeData.grey50,
                                          // borderColor: AppThemeData.grey50,
                                          hintText: "Destination Location".tr,
                                          enable: false,
                                          prefix: const Padding(
                                            padding: EdgeInsets.only(
                                              left: 10,
                                              right: 10,
                                            ),
                                            child: Icon(
                                              Icons.radio_button_checked,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  left: 10,
                                  top: 33,
                                  child: DottedBorder(
                                    options: CustomPathDottedBorderOptions(
                                      color: Colors.grey.shade400,
                                      strokeWidth: 2,
                                      dashPattern: [4, 4],
                                      customPath:
                                          (size) =>
                                              Path()
                                                ..moveTo(size.width / 2, 0)
                                                ..lineTo(
                                                  size.width / 2,
                                                  size.height,
                                                ),
                                    ),
                                    child: const SizedBox(
                                      width: 20,
                                      height: 40,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Promo code".tr,
                                    style: AppThemeData.boldTextStyle(
                                      fontSize: 16,
                                      color:
                                          isDark
                                              ? AppThemeData.greyDark900
                                              : AppThemeData.grey900,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Get.to(CabCouponCodeScreen())!.then((
                                      value,
                                    ) {
                                      if (value != null) {
                                        controller
                                            .couponCodeTextEditController
                                            .value
                                            .text = value.code ?? '';
                                        double couponAmount =
                                            Constant.calculateDiscount(
                                              amount:
                                                  controller.subTotal.value
                                                      .toString(),
                                              offerModel: value,
                                            );
                                        if (couponAmount <
                                            controller.subTotal.value) {
                                          controller.selectedCouponModel.value =
                                              value;
                                          controller.calculateTotalAmount();
                                        } else {
                                          ShowToastDialog.showToast(
                                            "This offer not eligible for this booking"
                                                .tr,
                                          );
                                        }
                                      }
                                    });
                                  },
                                  child: Text(
                                    "View All".tr,
                                    style: AppThemeData.boldTextStyle(
                                      decoration: TextDecoration.underline,
                                      fontSize: 14,
                                      color:
                                          isDark
                                              ? AppThemeData.primary300
                                              : AppThemeData.primary300,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: Responsive.width(100, context),
                                height: Responsive.height(6, context),
                                color: AppThemeData.carRent50,
                                child: DottedBorder(
                                  options: RectDottedBorderOptions(
                                    dashPattern: [10, 5],
                                    strokeWidth: 1,
                                    padding: EdgeInsets.all(0),
                                    color: AppThemeData.carRent400,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        SvgPicture.asset(
                                          "assets/icons/ic_coupon.svg",
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            child: TextFormField(
                                              controller:
                                                  controller
                                                      .couponCodeTextEditController
                                                      .value,
                                              style:
                                                  AppThemeData.semiBoldTextStyle(
                                                    color:
                                                        AppThemeData
                                                            .parcelService500,
                                                    fontSize: 16,
                                                  ),
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                hintText:
                                                    'Write coupon Code'.tr,
                                                contentPadding: EdgeInsets.only(
                                                  bottom: 10,
                                                ),
                                                hintStyle:
                                                    AppThemeData.semiBoldTextStyle(
                                                      color:
                                                          AppThemeData
                                                              .parcelService500,
                                                      fontSize: 16,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        RoundedButtonFill(
                                          title: "Redeem now".tr,
                                          width: 27,
                                          borderRadius: 10,
                                          fontSizes: 14,
                                          onPress: () async {
                                            if (controller
                                                .couponCodeTextEditController
                                                .value
                                                .text
                                                .trim()
                                                .isEmpty) {
                                              ShowToastDialog.showToast(
                                                "Please enter a coupon code".tr,
                                              );
                                              return;
                                            }

                                            List matchedCoupons =
                                                controller.cabCouponList
                                                    .where(
                                                      (element) =>
                                                          element.code!
                                                              .toLowerCase()
                                                              .trim() ==
                                                          controller
                                                              .couponCodeTextEditController
                                                              .value
                                                              .text
                                                              .toLowerCase()
                                                              .trim(),
                                                    )
                                                    .toList();

                                            if (matchedCoupons.isNotEmpty) {
                                              CouponModel couponModel =
                                                  matchedCoupons.first;

                                              if (couponModel.expiresAt !=
                                                      null &&
                                                  couponModel.expiresAt!
                                                      .toDate()
                                                      .isAfter(
                                                        DateTime.now(),
                                                      )) {
                                                double couponAmount =
                                                    Constant.calculateDiscount(
                                                      amount:
                                                          controller
                                                              .subTotal
                                                              .value
                                                              .toString(),
                                                      offerModel: couponModel,
                                                    );

                                                if (couponAmount <
                                                    controller.subTotal.value) {
                                                  controller
                                                      .selectedCouponModel
                                                      .value = couponModel;
                                                  controller.discount.value =
                                                      couponAmount;
                                                  controller
                                                      .calculateTotalAmount();
                                                  ShowToastDialog.showToast(
                                                    "Coupon applied successfully"
                                                        .tr,
                                                  );
                                                  controller.update();
                                                } else {
                                                  ShowToastDialog.showToast(
                                                    "This offer not eligible for this booking"
                                                        .tr,
                                                  );
                                                }
                                              } else {
                                                ShowToastDialog.showToast(
                                                  "This coupon code has been expired"
                                                      .tr,
                                                );
                                              }
                                            } else {
                                              ShowToastDialog.showToast(
                                                "Invalid coupon code".tr,
                                              );
                                            }
                                          },
                                          color: AppThemeData.parcelService300,
                                          textColor: AppThemeData.grey50,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color:
                                    isDark
                                        ? AppThemeData.greyDark50
                                        : AppThemeData.grey50,
                                border: Border.all(
                                  color:
                                      isDark
                                          ? AppThemeData.greyDark200
                                          : AppThemeData.grey200,
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Order Summary".tr,
                                    style: AppThemeData.boldTextStyle(
                                      fontSize: 14,
                                      color:
                                          isDark
                                              ? AppThemeData.greyDark500
                                              : AppThemeData.grey500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Subtotal".tr,
                                          style: AppThemeData.mediumTextStyle(
                                            fontSize: 16,
                                            color:
                                                isDark
                                                    ? AppThemeData.greyDark800
                                                    : AppThemeData.grey800,
                                          ),
                                        ),
                                        Text(
                                          Constant.amountShow(
                                            amount:
                                                controller.subTotal.value
                                                    .toString(),
                                          ),
                                          style: AppThemeData.semiBoldTextStyle(
                                            fontSize: 16,
                                            color:
                                                isDark
                                                    ? AppThemeData.greyDark900
                                                    : AppThemeData.grey900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              "Discount".tr,
                                              style:
                                                  AppThemeData.mediumTextStyle(
                                                    fontSize: 16,
                                                    color:
                                                        isDark
                                                            ? AppThemeData
                                                                .greyDark900
                                                            : AppThemeData
                                                                .grey900,
                                                  ),
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              controller
                                                          .selectedCouponModel
                                                          .value
                                                          .id ==
                                                      null
                                                  ? ""
                                                  : "(${controller.selectedCouponModel.value.code})",
                                              style:
                                                  AppThemeData.mediumTextStyle(
                                                    fontSize: 16,
                                                    color:
                                                        AppThemeData.primary300,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          Constant.amountShow(
                                            amount:
                                                controller.discount.value
                                                    .toString(),
                                          ),
                                          style: AppThemeData.semiBoldTextStyle(
                                            fontSize: 16,
                                            color: AppThemeData.danger300,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Tax List
                                  ListView.builder(
                                    itemCount: Constant.taxList.length,
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    itemBuilder: (context, index) {
                                      TaxModel taxModel =
                                          Constant.taxList[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 5,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${taxModel.title} (${taxModel.tax} ${taxModel.type == "Fixed" ? Constant.currencyData!.code : "%"})'
                                                    .tr,
                                                textAlign: TextAlign.start,
                                                style:
                                                    AppThemeData.mediumTextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          isDark
                                                              ? AppThemeData
                                                                  .greyDark800
                                                              : AppThemeData
                                                                  .grey800,
                                                    ),
                                              ),
                                            ),
                                            Text(
                                              Constant.amountShow(
                                                amount:
                                                    Constant.calculateTax(
                                                      amount:
                                                          (controller
                                                                      .subTotal
                                                                      .value -
                                                                  controller
                                                                      .discount
                                                                      .value)
                                                              .toString(),
                                                      taxModel: taxModel,
                                                    ).toString(),
                                              ).tr,
                                              textAlign: TextAlign.start,
                                              style:
                                                  AppThemeData.semiBoldTextStyle(
                                                    fontSize: 16,
                                                    color:
                                                        isDark
                                                            ? AppThemeData
                                                                .greyDark900
                                                            : AppThemeData
                                                                .grey900,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const Divider(),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Order Total".tr,
                                          style: AppThemeData.mediumTextStyle(
                                            fontSize: 16,
                                            color:
                                                isDark
                                                    ? AppThemeData.greyDark900
                                                    : AppThemeData.grey900,
                                          ),
                                        ),
                                        Text(
                                          Constant.amountShow(
                                            amount:
                                                controller.totalAmount.value
                                                    .toString(),
                                          ),
                                          style: AppThemeData.semiBoldTextStyle(
                                            fontSize: 16,
                                            color:
                                                isDark
                                                    ? AppThemeData.greyDark900
                                                    : AppThemeData.grey900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color:
                                    isDark
                                        ? AppThemeData.greyDark50
                                        : AppThemeData.grey50,
                                border: Border.all(
                                  color:
                                      isDark
                                          ? AppThemeData.greyDark200
                                          : AppThemeData.grey200,
                                ),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  controller.selectedPaymentMethod.value == ''
                                      ? cardDecorationScreen(
                                        controller,
                                        PaymentGateway.wallet,
                                        isDark,
                                        "",
                                      )
                                      : controller
                                              .selectedPaymentMethod
                                              .value ==
                                          PaymentGateway.wallet.name
                                      ? cardDecorationScreen(
                                        controller,
                                        PaymentGateway.wallet,
                                        isDark,
                                        "assets/images/ic_wallet.png",
                                      )
                                      : controller
                                              .selectedPaymentMethod
                                              .value ==
                                          PaymentGateway.cod.name
                                      ? cardDecorationScreen(
                                        controller,
                                        PaymentGateway.cod,
                                        isDark,
                                        "assets/images/ic_cash.png",
                                      )
                                      : controller
                                              .selectedPaymentMethod
                                              .value ==
                                          PaymentGateway.stripe.name
                                      ? cardDecorationScreen(
                                        controller,
                                        PaymentGateway.stripe,
                                        isDark,
                                        "assets/images/stripe.png",
                                      )
                                      : controller
                                              .selectedPaymentMethod
                                              .value ==
                                          PaymentGateway.paypal.name
                                      ? cardDecorationScreen(
                                        controller,
                                        PaymentGateway.paypal,
                                        isDark,
                                        "assets/images/paypal.png",
                                      )
                                      : controller
                                              .selectedPaymentMethod
                                              .value ==
                                          PaymentGateway.payStack.name
                                      ? cardDecorationScreen(
                                        controller,
                                        PaymentGateway.payStack,
                                        isDark,
                                        "assets/images/paystack.png",
                                      )
                                      : controller
                                              .selectedPaymentMethod
                                              .value ==
                                          PaymentGateway.mercadoPago.name
                                      ? cardDecorationScreen(
                                        controller,
                                        PaymentGateway.mercadoPago,
                                        isDark,
                                        "assets/images/mercado-pago.png",
                                      )
                                      : controller
                                              .selectedPaymentMethod
                                              .value ==
                                          PaymentGateway.flutterWave.name
                                      ? cardDecorationScreen(
                                        controller,
                                        PaymentGateway.flutterWave,
                                        isDark,
                                        "assets/images/flutterwave_logo.png",
                                      )
                                      : controller
                                              .selectedPaymentMethod
                                              .value ==
                                          PaymentGateway.payFast.name
                                      ? cardDecorationScreen(
                                        controller,
                                        PaymentGateway.payFast,
                                        isDark,
                                        "assets/images/payfast.png",
                                      )
                                      : controller
                                              .selectedPaymentMethod
                                              .value ==
                                          PaymentGateway.midTrans.name
                                      ? cardDecorationScreen(
                                        controller,
                                        PaymentGateway.midTrans,
                                        isDark,
                                        "assets/images/midtrans.png",
                                      )
                                      : controller
                                              .selectedPaymentMethod
                                              .value ==
                                          PaymentGateway.orangeMoney.name
                                      ? cardDecorationScreen(
                                        controller,
                                        PaymentGateway.orangeMoney,
                                        isDark,
                                        "assets/images/orange_money.png",
                                      )
                                      : controller
                                              .selectedPaymentMethod
                                              .value ==
                                          PaymentGateway.xendit.name
                                      ? cardDecorationScreen(
                                        controller,
                                        PaymentGateway.xendit,
                                        isDark,
                                        "assets/images/xendit.png",
                                      )
                                      : cardDecorationScreen(
                                        controller,
                                        PaymentGateway.razorpay,
                                        isDark,
                                        "assets/images/razorpay.png",
                                      ),
                                  SizedBox(width: 22),
                                  Text(
                                    controller.selectedPaymentMethod.value.tr,
                                    textAlign: TextAlign.start,
                                    style: AppThemeData.boldTextStyle(
                                      fontSize: 16,
                                      color:
                                          isDark
                                              ? AppThemeData.greyDark900
                                              : AppThemeData.grey900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      RoundedButtonFill(
                        title: "Confirm Booking".tr,
                        onPress: () async {
                          // Wallet balansini tekshirish
                          if (controller.selectedPaymentMethod.value ==
                              "wallet") {
                            num walletAmount =
                                controller.userModel.value.walletAmount ?? 0;
                            num totalAmount = controller.totalAmount.value;
                            if (walletAmount < totalAmount) {
                              // Qizil snackbar ko'rsatish
                              Get.snackbar(
                                "Error".tr,
                                "Insufficient wallet balance".tr,
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 3),
                                margin: const EdgeInsets.all(16),
                              );
                              return;
                            }
                          }
                          controller.placeOrder();
                        },
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey900,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget waitingDialog(
    BuildContext context,
    CabBookingController controller,
    bool isDark,
  ) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.4,
        maxChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15.0,
                vertical: 10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppThemeData.grey400,
                    ),
                    height: 4,
                    width: 33,
                  ),
                  SizedBox(height: 30),
                  Text(
                    "Waiting for driver....".tr,
                    style: AppThemeData.mediumTextStyle(
                      fontSize: 18,
                      color: AppThemeData.grey900,
                    ),
                  ),
                  Image.asset('assets/loader.gif', width: 250),
                  RoundedButtonFill(
                    title: "Cancel Ride".tr,
                    color: AppThemeData.danger300,
                    textColor: AppThemeData.surface,
                    onPress: () async {
                      try {
                        controller.currentOrder.update((order) {
                          if (order != null) {
                            order.status = Constant.orderRejected;
                          }
                        });

                        if (controller.currentOrder.value.id != null) {
                          await FireStoreUtils.updateCabOrder(
                            controller.currentOrder.value,
                          );
                        }

                        controller.bottomSheetType.value = "";
                        controller.polyLines.clear();
                        controller.markers.clear();
                        controller.osmMarker.clear();
                        controller.routePoints.clear();
                        controller.sourceTextEditController.value.clear();
                        controller.destinationTextEditController.value.clear();
                        controller.departureLatLong.value = const LatLng(
                          0.0,
                          0.0,
                        );
                        controller.destinationLatLong.value = const LatLng(
                          0.0,
                          0.0,
                        );
                        controller.departureLatLongOsm.value = latlong.LatLng(
                          0.0,
                          0.0,
                        );
                        controller.destinationLatLongOsm.value = latlong.LatLng(
                          0.0,
                          0.0,
                        );
                        // Search state'ni tozalash - cab home screen'da search ishlashi uchun
                        controller.destinationSearchResults.clear();
                        controller.isSearchingDestination.value = false;
                        controller.searchError.value = '';
                        controller.isDestinationFocused.value = false;
                        controller.destinationFocusNode.unfocus();
                        // Listener flag'ni reset qilish - qayta listener qo'shish uchun
                        controller.focusListenerAdded = false;

                        // 4. Reset user's in-progress order
                        if (Constant.userModel != null) {
                          Constant.userModel!.inProgressOrderID = null;
                          await FireStoreUtils.updateUser(Constant.userModel!);
                        }
                        ShowToastDialog.showToast(
                          "Ride cancelled successfully".tr,
                        );
                        Get.back(result: true);
                        CabDashboardController cabDashboardController = Get.put(
                          CabDashboardController(),
                        );
                        cabDashboardController.selectedIndex.value = 0;
                      } catch (e) {
                        ShowToastDialog.showToast("Failed to cancel ride".tr);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget driverDialog(
    BuildContext context,
    CabBookingController controller,
    bool isDark,
  ) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppThemeData.grey700 : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15.0,
                vertical: 10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppThemeData.grey400,
                    ),
                    height: 4,
                    width: 33,
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        const SizedBox(height: 10),
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color:
                                    isDark ? Colors.transparent : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      // if (Constant.selectedMapType == 'osm') {
                                      //   final result = await Get.to(() => MapPickerPage());
                                      //   if (result != null) {
                                      //     controller.sourceTextEditController.value.text = '';
                                      //     final firstPlace = result;
                                      //     final lat = firstPlace.coordinates.latitude;
                                      //     final lng = firstPlace.coordinates.longitude;
                                      //     final address = firstPlace.address;
                                      //     controller.sourceTextEditController.value.text = address.toString();
                                      //     controller.setDepartureMarker(lat, lng);
                                      //   }
                                      // } else {
                                      //   Get.to(LocationPickerScreen())!.then((value) async {
                                      //     if (value != null) {
                                      //       SelectedLocationModel selectedLocationModel = value;
                                      //
                                      //       controller.sourceTextEditController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                      //       controller.setDepartureMarker(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                                      //     }
                                      //   });
                                      // }
                                    },
                                    child: TextFieldWidget(
                                      controller:
                                          controller
                                              .sourceTextEditController
                                              .value,
                                      hintText: "Pickup Location".tr,
                                      enable: false,
                                      readOnly: true,
                                      prefix: const Padding(
                                        padding: EdgeInsets.only(
                                          left: 10,
                                          right: 10,
                                        ),
                                        child: Icon(
                                          Icons.stop_circle_outlined,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () async {
                                      // if (Constant.selectedMapType == 'osm') {
                                      //   final result = await Get.to(() => MapPickerPage());
                                      //   if (result != null) {
                                      //     controller.destinationTextEditController.value.text = '';
                                      //     final firstPlace = result;
                                      //     final lat = firstPlace.coordinates.latitude;
                                      //     final lng = firstPlace.coordinates.longitude;
                                      //     final address = firstPlace.address;
                                      //     controller.destinationTextEditController.value.text = address.toString();
                                      //     controller.setDestinationMarker(lat, lng);
                                      //   }
                                      // } else {
                                      //   Get.to(LocationPickerScreen())!.then((value) async {
                                      //     if (value != null) {
                                      //       SelectedLocationModel selectedLocationModel = value;
                                      //
                                      //       controller.destinationTextEditController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                      //       controller.setDestinationMarker(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                                      //     }
                                      //   });
                                      // }
                                    },
                                    child: TextFieldWidget(
                                      controller:
                                          controller
                                              .destinationTextEditController
                                              .value,
                                      // backgroundColor: AppThemeData.grey50,
                                      // borderColor: AppThemeData.grey50,
                                      hintText: "Destination Location".tr,
                                      enable: false,
                                      readOnly: true,
                                      prefix: const Padding(
                                        padding: EdgeInsets.only(
                                          left: 10,
                                          right: 10,
                                        ),
                                        child: Icon(
                                          Icons.radio_button_checked,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 10,
                              top: 33,
                              child: DottedBorder(
                                options: CustomPathDottedBorderOptions(
                                  color: Colors.grey.shade400,
                                  strokeWidth: 2,
                                  dashPattern: [4, 4],
                                  customPath:
                                      (size) =>
                                          Path()
                                            ..moveTo(size.width / 2, 0)
                                            ..lineTo(
                                              size.width / 2,
                                              size.height,
                                            ),
                                ),
                                child: const SizedBox(width: 20, height: 40),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Constant.isEnableOTPTripStart == true
                            ? Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Otp :".tr,
                                    style: AppThemeData.mediumTextStyle(
                                      fontSize: 16,
                                      color:
                                          isDark
                                              ? AppThemeData.greyDark800
                                              : AppThemeData.grey800,
                                    ),
                                  ),
                                  Text(
                                    controller.currentOrder.value.otpCode ?? '',
                                    style: AppThemeData.semiBoldTextStyle(
                                      fontSize: 16,
                                      color:
                                          isDark
                                              ? AppThemeData.greyDark900
                                              : AppThemeData.grey900,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : SizedBox.shrink(),

                        if (Constant.isEnableOTPTripStart == true)
                          SizedBox(height: 14),

                        controller.currentOrder.value.driver != null
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadiusGeometry.circular(
                                    10,
                                  ),
                                  child: NetworkImageWidget(
                                    imageUrl:
                                        controller
                                            .currentOrder
                                            .value
                                            .driver
                                            ?.profilePictureURL ??
                                        '',
                                    height: 70,
                                    width: 70,
                                    borderRadius: 35,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        controller.currentOrder.value.driver
                                                ?.fullName() ??
                                            '',
                                        style: AppThemeData.boldTextStyle(
                                          color:
                                              isDark
                                                  ? AppThemeData.greyDark900
                                                  : AppThemeData.grey900,
                                          fontSize: 18,
                                        ),
                                      ),
                                      Text(
                                        "${controller.currentOrder.value.driver?.vehicleType ?? ''} | ${controller.currentOrder.value.driver?.carMakes.toString()}",
                                        style: TextStyle(
                                          fontFamily: AppThemeData.medium,
                                          color:
                                              isDark
                                                  ? AppThemeData.greyDark700
                                                  : AppThemeData.grey700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        controller
                                                .currentOrder
                                                .value
                                                .driver
                                                ?.carNumber ??
                                            '',
                                        style: AppThemeData.boldTextStyle(
                                          color:
                                              isDark
                                                  ? AppThemeData.greyDark700
                                                  : AppThemeData.grey700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    RoundedButtonBorder(
                                      title:
                                          controller
                                              .driverModel
                                              .value
                                              .averageRating
                                              .toStringAsFixed(1) ??
                                          '',
                                      width: 20,
                                      height: 3.5,
                                      radius: 10,
                                      isRight: false,
                                      isCenter: true,
                                      textColor: AppThemeData.warning400,
                                      borderColor: AppThemeData.warning400,
                                      color: AppThemeData.warning50,
                                      icon: SvgPicture.asset(
                                        "assets/icons/ic_start.svg",
                                      ),
                                      onPress: () {},
                                    ),
                                    SizedBox(height: 10),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            Constant.makePhoneCall(
                                              controller
                                                  .currentOrder
                                                  .value
                                                  .driver!
                                                  .phoneNumber
                                                  .toString(),
                                            );
                                          },
                                          child: Container(
                                            width: 38,
                                            height: 38,
                                            decoration: ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(
                                                  width: 1,
                                                  color:
                                                      isDark
                                                          ? AppThemeData.grey200
                                                          : AppThemeData
                                                              .grey200,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(120),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: SvgPicture.asset(
                                                "assets/icons/ic_phone_call.svg",
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        InkWell(
                                          onTap: () async {
                                            ShowToastDialog.showLoader(
                                              "Please wait...".tr,
                                            );

                                            UserModel? customer =
                                                await FireStoreUtils.getUserProfile(
                                                  controller
                                                          .currentOrder
                                                          .value
                                                          .authorID ??
                                                      '',
                                                );
                                            UserModel? driverUser =
                                                await FireStoreUtils.getUserProfile(
                                                  controller
                                                          .currentOrder
                                                          .value
                                                          .driverId ??
                                                      '',
                                                );

                                            ShowToastDialog.closeLoader();

                                            Get.to(
                                              const ChatScreen(),
                                              arguments: {
                                                "customerName":
                                                    customer?.fullName(),
                                                "restaurantName":
                                                    driverUser?.fullName(),
                                                "orderId":
                                                    controller
                                                        .currentOrder
                                                        .value
                                                        .id,
                                                "restaurantId": driverUser?.id,
                                                "customerId": customer?.id,
                                                "customerProfileImage":
                                                    customer?.profilePictureURL,
                                                "restaurantProfileImage":
                                                    driverUser
                                                        ?.profilePictureURL,
                                                "token": driverUser?.fcmToken,
                                                "chatType": "Driver",
                                              },
                                            );
                                          },
                                          child: Container(
                                            width: 42,
                                            height: 42,
                                            decoration: ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(
                                                  width: 1,
                                                  color:
                                                      isDark
                                                          ? AppThemeData.grey200
                                                          : AppThemeData
                                                              .grey200,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(120),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: SvgPicture.asset(
                                                "assets/icons/ic_wechat.svg",
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            )
                            : SizedBox(),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color:
                                isDark
                                    ? AppThemeData.greyDark50
                                    : AppThemeData.grey50,
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppThemeData.greyDark200
                                      : AppThemeData.grey200,
                            ),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: InkWell(
                            onTap: () {
                              controller.bottomSheetType.value = 'payment';
                            },
                            child: Row(
                              children: [
                                controller.selectedPaymentMethod.value ==
                                        PaymentGateway.wallet.name
                                    ? cardDecorationScreen(
                                      controller,
                                      PaymentGateway.wallet,
                                      isDark,
                                      "assets/images/ic_wallet.png",
                                    )
                                    : controller.selectedPaymentMethod.value ==
                                        PaymentGateway.cod.name
                                    ? cardDecorationScreen(
                                      controller,
                                      PaymentGateway.cod,
                                      isDark,
                                      "assets/images/ic_cash.png",
                                    )
                                    : controller.selectedPaymentMethod.value ==
                                        PaymentGateway.stripe.name
                                    ? cardDecorationScreen(
                                      controller,
                                      PaymentGateway.stripe,
                                      isDark,
                                      "assets/images/stripe.png",
                                    )
                                    : controller.selectedPaymentMethod.value ==
                                        PaymentGateway.paypal.name
                                    ? cardDecorationScreen(
                                      controller,
                                      PaymentGateway.paypal,
                                      isDark,
                                      "assets/images/paypal.png",
                                    )
                                    : controller.selectedPaymentMethod.value ==
                                        PaymentGateway.payStack.name
                                    ? cardDecorationScreen(
                                      controller,
                                      PaymentGateway.payStack,
                                      isDark,
                                      "assets/images/paystack.png",
                                    )
                                    : controller.selectedPaymentMethod.value ==
                                        PaymentGateway.mercadoPago.name
                                    ? cardDecorationScreen(
                                      controller,
                                      PaymentGateway.mercadoPago,
                                      isDark,
                                      "assets/images/mercado-pago.png",
                                    )
                                    : controller.selectedPaymentMethod.value ==
                                        PaymentGateway.flutterWave.name
                                    ? cardDecorationScreen(
                                      controller,
                                      PaymentGateway.flutterWave,
                                      isDark,
                                      "assets/images/flutterwave_logo.png",
                                    )
                                    : controller.selectedPaymentMethod.value ==
                                        PaymentGateway.payFast.name
                                    ? cardDecorationScreen(
                                      controller,
                                      PaymentGateway.payFast,
                                      isDark,
                                      "assets/images/payfast.png",
                                    )
                                    : controller.selectedPaymentMethod.value ==
                                        PaymentGateway.midTrans.name
                                    ? cardDecorationScreen(
                                      controller,
                                      PaymentGateway.midTrans,
                                      isDark,
                                      "assets/images/midtrans.png",
                                    )
                                    : controller.selectedPaymentMethod.value ==
                                        PaymentGateway.orangeMoney.name
                                    ? cardDecorationScreen(
                                      controller,
                                      PaymentGateway.orangeMoney,
                                      isDark,
                                      "assets/images/orange_money.png",
                                    )
                                    : controller.selectedPaymentMethod.value ==
                                        PaymentGateway.xendit.name
                                    ? cardDecorationScreen(
                                      controller,
                                      PaymentGateway.xendit,
                                      isDark,
                                      "assets/images/xendit.png",
                                    )
                                    : cardDecorationScreen(
                                      controller,
                                      PaymentGateway.razorpay,
                                      isDark,
                                      "assets/images/razorpay.png",
                                    ),
                                SizedBox(width: 22),
                                Expanded(
                                  child: Text(
                                    controller.selectedPaymentMethod.value.tr,
                                    textAlign: TextAlign.start,
                                    style: AppThemeData.boldTextStyle(
                                      fontSize: 16,
                                      color:
                                          isDark
                                              ? AppThemeData.greyDark900
                                              : AppThemeData.grey900,
                                    ),
                                  ),
                                ),
                                Text(
                                  "Change".tr,
                                  textAlign: TextAlign.start,
                                  style: AppThemeData.boldTextStyle(
                                    fontSize: 16,
                                    color:
                                        isDark
                                            ? AppThemeData.primary300
                                            : AppThemeData.primary300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color:
                                isDark
                                    ? AppThemeData.greyDark50
                                    : AppThemeData.grey50,
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppThemeData.greyDark200
                                      : AppThemeData.grey200,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Order Summary".tr,
                                style: AppThemeData.boldTextStyle(
                                  fontSize: 14,
                                  color:
                                      isDark
                                          ? AppThemeData.greyDark500
                                          : AppThemeData.grey500,
                                ),
                              ),
                              const SizedBox(height: 8),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Subtotal".tr,
                                      style: AppThemeData.mediumTextStyle(
                                        fontSize: 16,
                                        color:
                                            isDark
                                                ? AppThemeData.greyDark800
                                                : AppThemeData.grey800,
                                      ),
                                    ),
                                    Text(
                                      Constant.amountShow(
                                        amount:
                                            controller.subTotal.value
                                                .toString(),
                                      ),
                                      style: AppThemeData.semiBoldTextStyle(
                                        fontSize: 16,
                                        color:
                                            isDark
                                                ? AppThemeData.greyDark900
                                                : AppThemeData.grey900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Discount".tr,
                                      style: AppThemeData.mediumTextStyle(
                                        fontSize: 16,
                                        color:
                                            isDark
                                                ? AppThemeData.greyDark900
                                                : AppThemeData.grey900,
                                      ),
                                    ),
                                    Text(
                                      Constant.amountShow(
                                        amount:
                                            controller.discount.value
                                                .toString(),
                                      ),
                                      style: AppThemeData.semiBoldTextStyle(
                                        fontSize: 16,
                                        color: AppThemeData.danger300,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Tax List
                              ListView.builder(
                                itemCount: Constant.taxList.length,
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemBuilder: (context, index) {
                                  TaxModel taxModel = Constant.taxList[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${taxModel.title} (${taxModel.tax} ${taxModel.type == "Fixed" ? Constant.currencyData!.code : "%"})'
                                                .tr,
                                            textAlign: TextAlign.start,
                                            style: AppThemeData.mediumTextStyle(
                                              fontSize: 14,
                                              color:
                                                  isDark
                                                      ? AppThemeData.greyDark800
                                                      : AppThemeData.grey800,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          Constant.amountShow(
                                            amount:
                                                Constant.calculateTax(
                                                  amount:
                                                      (controller
                                                                  .subTotal
                                                                  .value -
                                                              controller
                                                                  .discount
                                                                  .value)
                                                          .toString(),
                                                  taxModel: taxModel,
                                                ).toString(),
                                          ).tr,
                                          textAlign: TextAlign.start,
                                          style: AppThemeData.semiBoldTextStyle(
                                            fontSize: 16,
                                            color:
                                                isDark
                                                    ? AppThemeData.greyDark900
                                                    : AppThemeData.grey900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const Divider(),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Order Total".tr,
                                      style: AppThemeData.mediumTextStyle(
                                        fontSize: 16,
                                        color:
                                            isDark
                                                ? AppThemeData.greyDark900
                                                : AppThemeData.grey900,
                                      ),
                                    ),
                                    Text(
                                      Constant.amountShow(
                                        amount:
                                            controller.totalAmount.value
                                                .toString(),
                                      ),
                                      style: AppThemeData.semiBoldTextStyle(
                                        fontSize: 16,
                                        color:
                                            isDark
                                                ? AppThemeData.greyDark900
                                                : AppThemeData.grey900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),

                  Obx(() {
                    if (controller.currentOrder.value.status ==
                        Constant.orderInTransit) {
                      return Column(
                        children: [
                          RoundedButtonFill(
                            title: "SOS".tr,
                            color: Colors.red.withOpacity(0.50),
                            textColor: AppThemeData.grey50,
                            isCenter: true,
                            icon: const Icon(Icons.call, color: Colors.white),
                            onPress: () async {
                              ShowToastDialog.showLoader("Please wait...".tr);

                              LocationData location =
                                  await controller.currentLocation.value
                                      .getLocation();

                              await FireStoreUtils.getSOS(
                                controller.currentOrder.value.id ?? '',
                              ).then((value) async {
                                if (value == false) {
                                  await FireStoreUtils.setSos(
                                    controller.currentOrder.value.id ?? '',
                                    UserLocation(
                                      latitude: location.latitude!,
                                      longitude: location.longitude!,
                                    ),
                                  ).then((_) {
                                    ShowToastDialog.closeLoader();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Your SOS request has been submitted to admin"
                                              .tr,
                                        ),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  });
                                } else {
                                  ShowToastDialog.closeLoader();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Your SOS request is already submitted"
                                            .tr,
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),
                  Obx(() {
                    if (controller.currentOrder.value.status ==
                            Constant.orderInTransit &&
                        controller.currentOrder.value.paymentStatus == false) {
                      return RoundedButtonFill(
                        title: "Pay Now".tr,
                        onPress: () async {
                          if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.stripe.name) {
                            controller.stripeMakePayment(
                              amount: controller.totalAmount.value.toString(),
                            );
                          } else if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.paypal.name) {
                            controller.paypalPaymentSheet(
                              controller.totalAmount.value.toString(),
                              context,
                            );
                          } else if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.payStack.name) {
                            controller.payStackPayment(
                              controller.totalAmount.value.toString(),
                            );
                          } else if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.mercadoPago.name) {
                            controller.mercadoPagoMakePayment(
                              context: context,
                              amount: controller.totalAmount.value.toString(),
                            );
                          } else if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.flutterWave.name) {
                            controller.flutterWaveInitiatePayment(
                              context: context,
                              amount: controller.totalAmount.value.toString(),
                            );
                          } else if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.payFast.name) {
                            controller.payFastPayment(
                              context: context,
                              amount: controller.totalAmount.value.toString(),
                            );
                          } else if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.cod.name) {
                            controller.completeOrder();
                          } else if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.wallet.name) {
                            if (Constant.userModel!.walletAmount == null ||
                                Constant.userModel!.walletAmount! <
                                    controller.totalAmount.value) {
                              ShowToastDialog.showToast(
                                "You do not have sufficient wallet balance".tr,
                              );
                            } else {
                              controller.completeOrder();
                            }
                          } else if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.midTrans.name) {
                            controller.midtransMakePayment(
                              context: context,
                              amount: controller.totalAmount.value.toString(),
                            );
                          } else if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.orangeMoney.name) {
                            controller.orangeMakePayment(
                              context: context,
                              amount: controller.totalAmount.value.toString(),
                            );
                          } else if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.xendit.name) {
                            controller.xenditPayment(
                              context,
                              controller.totalAmount.value.toString(),
                            );
                          } else if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.razorpay.name) {
                            RazorPayController()
                                .createOrderRazorPay(
                                  amount: double.parse(
                                    controller.totalAmount.value.toString(),
                                  ),
                                  razorpayModel: controller.razorPayModel.value,
                                )
                                .then((value) {
                                  if (value == null) {
                                    Get.back();
                                    ShowToastDialog.showToast(
                                      "Something went wrong, please contact admin."
                                          .tr,
                                    );
                                  } else {
                                    CreateRazorPayOrderModel result = value;
                                    controller.openCheckout(
                                      amount:
                                          controller.totalAmount.value
                                              .toString(),
                                      orderId: result.id,
                                    );
                                  }
                                });
                          } else if (controller.selectedPaymentMethod.value ==
                              PaymentGateway.payme.name) {
                            controller.paymeMakePayment(
                              context: context,
                              amount: controller.totalAmount.value.toString(),
                            );
                          } else {
                            ShowToastDialog.showToast(
                              "Please select payment method".tr,
                            );
                          }
                        },
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey900,
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Padding cardDecorationScreen(
    CabBookingController controller,
    PaymentGateway value,
    isDark,
    String image,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        width: 40,
        height: 40,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(value.name == "payFast" ? 0 : 8.0),
          child:
              image == ''
                  ? Container(
                    color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                  )
                  : Image.asset(image),
        ),
      ),
    );
  }

  Obx cardDecoration(
    CabBookingController controller,
    PaymentGateway value,
    isDark,
    String image,
  ) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: [
            InkWell(
              onTap: () async {
                // Wallet tanlanganda balansni tekshirish
                if (value.name == PaymentGateway.wallet.name) {
                  // User ma'lumotlarini yangilash - eng so'nggi balansni olish
                  final updatedUser = await FireStoreUtils.getUserProfile(
                    FireStoreUtils.getCurrentUid(),
                  );
                  if (updatedUser != null) {
                    controller.userModel.value = updatedUser;
                  }

                  num walletAmount =
                      controller.userModel.value.walletAmount ?? 0;
                  num orderTotal = controller.totalAmount.value;

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
                    return; // Wallet tanlanmaydi
                  }
                }

                controller.selectedPaymentMethod.value = value.name;
              },
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          width:
                              controller.selectedPaymentMethod.value ==
                                      value.name
                                  ? 2
                                  : 1,
                          color:
                              controller.selectedPaymentMethod.value ==
                                      value.name
                                  ? const Color(0xFFFF6839)
                                  : const Color(0xFFE5E7EB),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        value.name == "payFast" ? 0 : 8.0,
                      ),
                      child: Image.asset(image),
                    ),
                  ),
                  const SizedBox(width: 10),
                  value.name == "wallet"
                      ? Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value.name.capitalizeString(),
                              textAlign: TextAlign.start,
                              style: AppThemeData.semiBoldTextStyle(
                                fontSize: 16,
                                color:
                                    isDark
                                        ? AppThemeData.grey50
                                        : AppThemeData.grey900,
                              ),
                            ),
                            Text(
                              Constant.amountShow(
                                amount:
                                    controller.userModel.value.walletAmount ==
                                            null
                                        ? '0.0'
                                        : controller
                                            .userModel
                                            .value
                                            .walletAmount
                                            .toString(),
                              ),
                              textAlign: TextAlign.start,
                              style: AppThemeData.semiBoldTextStyle(
                                fontSize: 14,
                                color:
                                    isDark
                                        ? AppThemeData.primary300
                                        : AppThemeData.primary300,
                              ),
                            ),
                          ],
                        ),
                      )
                      : Expanded(
                        child: Text(
                          value.name.capitalizeString(),
                          textAlign: TextAlign.start,
                          style: AppThemeData.semiBoldTextStyle(
                            fontSize: 16,
                            color:
                                isDark
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900,
                          ),
                        ),
                      ),
                  const Expanded(child: SizedBox()),
                  Radio(
                    value: value.name,
                    groupValue: controller.selectedPaymentMethod.value,
                    activeColor: const Color(0xFFFF6839),
                    onChanged: (value) {
                      controller.selectedPaymentMethod.value = value.toString();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
