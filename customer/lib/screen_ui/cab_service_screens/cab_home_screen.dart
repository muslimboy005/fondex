import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_home_controller.dart';
import 'package:customer/controllers/cab_booking_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:customer/utils/utils.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:latlong2/latlong.dart' as latlong;

import 'Intercity_home_screen.dart';
import 'cab_booking_screen.dart';

class CabHomeScreen extends StatelessWidget {
  CabHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: CabHomeController(),
      builder: (homeController) {
        return GetX(
          init: CabBookingController(),
          builder: (controller) {
            return Scaffold(
              body:
                  // 2 bosqichli loading - initial loading tez tugaydi
                  homeController.isInitialLoading.value ||
                          controller.isInitialLoading.value
                      ? Constant.loader()
                      : Stack(
                        children: [
                          // Map View
                          Constant.selectedMapType == "osm"
                              ? flutterMap.FlutterMap(
                                mapController: controller.mapOsmController,
                                options: flutterMap.MapOptions(
                                  initialCenter:
                                      Constant.currentLocation != null
                                          ? latlong.LatLng(
                                            Constant.currentLocation!.latitude,
                                            Constant.currentLocation!.longitude,
                                          )
                                          : latlong.LatLng(
                                            41.4219057,
                                            -102.0840772,
                                          ),
                                  initialZoom: 14,
                                  onTap:
                                      controller.isMapPickingMode.value
                                          ? (tapPosition, point) {
                                            controller
                                                .getAddressFromPickedLocation(
                                                  point.latitude,
                                                  point.longitude,
                                                );
                                          }
                                          : null,
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
                                  // Map picking marker
                                  Obx(
                                    () =>
                                        controller.isMapPickingMode.value &&
                                                controller
                                                        .tempPickedLocation
                                                        .value
                                                        .latitude !=
                                                    0
                                            ? flutterMap.MarkerLayer(
                                              markers: [
                                                flutterMap.Marker(
                                                  point:
                                                      controller
                                                          .tempPickedLocation
                                                          .value,
                                                  width: 50,
                                                  height: 50,
                                                  child: Icon(
                                                    Icons.location_on,
                                                    color:
                                                        controller
                                                                .isPickingSource
                                                                .value
                                                            ? Colors.green
                                                            : Colors.red,
                                                    size: 50,
                                                  ),
                                                ),
                                              ],
                                            )
                                            : const SizedBox.shrink(),
                                  ),
                                ],
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
                                onTap:
                                    controller.isMapPickingMode.value
                                        ? (position) {
                                          controller
                                              .getAddressFromPickedLocation(
                                                position.latitude,
                                                position.longitude,
                                              );
                                        }
                                        : null,
                                initialCameraPosition: CameraPosition(
                                  target: controller.currentPosition.value,
                                  zoom: 14,
                                ),
                                myLocationEnabled: true,
                                zoomControlsEnabled: true,
                                zoomGesturesEnabled: true,
                                markers: {
                                  ...controller.markers.toSet(),
                                  if (controller.isMapPickingMode.value &&
                                      controller
                                              .tempPickedLocation
                                              .value
                                              .latitude !=
                                          0)
                                    Marker(
                                      markerId: const MarkerId(
                                        'picked_location',
                                      ),
                                      position: LatLng(
                                        controller
                                            .tempPickedLocation
                                            .value
                                            .latitude,
                                        controller
                                            .tempPickedLocation
                                            .value
                                            .longitude,
                                      ),
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            controller.isPickingSource.value
                                                ? BitmapDescriptor.hueGreen
                                                : BitmapDescriptor.hueRed,
                                          ),
                                    ),
                                },
                              ),
                          // Back Button
                          Positioned(
                            top: 50,
                            left: Constant.isRtl ? null : 20,
                            right: Constant.isRtl ? 20 : null,
                            child: Obx(
                              () => InkWell(
                                onTap: () {
                                  if (controller.isMapPickingMode.value) {
                                    controller.cancelMapPicking();
                                    if (_sheetController.isAttached) {
                                      _sheetController.animateTo(
                                        0.50,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOut,
                                      );
                                    }
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
                                        controller.isMapPickingMode.value
                                            ? Icons.close
                                            : Icons.arrow_back_ios_new,
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
                          ),
                          // Map Picking Mode Header
                          Obx(
                            () =>
                                controller.isMapPickingMode.value
                                    ? Positioned(
                                      top: 50,
                                      left: 70,
                                      right: 20,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              controller.isPickingSource.value
                                                  ? Colors.green
                                                  : Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.touch_app,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                controller.isPickingSource.value
                                                    ? "Xaritadan boshlang'ich joyni tanlang"
                                                        .tr
                                                    : "Xaritadan boradigan joyni tanlang"
                                                        .tr,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    : const SizedBox.shrink(),
                          ),
                          // Map Picking Bottom Card
                          Obx(
                            () =>
                                controller.isMapPickingMode.value
                                    ? Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color:
                                              isDark
                                                  ? AppThemeData.grey700
                                                  : Colors.white,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(24),
                                              ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, -3),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Drag handle
                                            Container(
                                              width: 40,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: AppThemeData.grey400,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            // Selected address
                                            Obx(
                                              () =>
                                                  controller
                                                          .isLoadingAddress
                                                          .value
                                                      ? const Padding(
                                                        padding: EdgeInsets.all(
                                                          20,
                                                        ),
                                                        child:
                                                            CircularProgressIndicator(),
                                                      )
                                                      : controller
                                                          .tempPickedAddress
                                                          .value
                                                          .isEmpty
                                                      ? Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              20,
                                                            ),
                                                        child: Column(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .touch_app_outlined,
                                                              size: 48,
                                                              color:
                                                                  isDark
                                                                      ? AppThemeData
                                                                          .grey400
                                                                      : AppThemeData
                                                                          .grey500,
                                                            ),
                                                            const SizedBox(
                                                              height: 12,
                                                            ),
                                                            Text(
                                                              "Xaritadagi joyga bosing"
                                                                  .tr,
                                                              style: AppThemeData.mediumTextStyle(
                                                                fontSize: 16,
                                                                color:
                                                                    isDark
                                                                        ? AppThemeData
                                                                            .grey400
                                                                        : AppThemeData
                                                                            .grey600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                      : Column(
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  16,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  isDark
                                                                      ? AppThemeData
                                                                          .grey600
                                                                      : AppThemeData
                                                                          .grey50,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Container(
                                                                  width: 40,
                                                                  height: 40,
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        controller.isPickingSource.value
                                                                            ? Colors.green.withOpacity(
                                                                              0.1,
                                                                            )
                                                                            : Colors.red.withOpacity(
                                                                              0.1,
                                                                            ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                  ),
                                                                  child: Icon(
                                                                    Icons
                                                                        .location_on,
                                                                    color:
                                                                        controller.isPickingSource.value
                                                                            ? Colors.green
                                                                            : Colors.red,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 12,
                                                                ),
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        controller.isPickingSource.value
                                                                            ? "Boshlang'ich joy".tr
                                                                            : "Boradigan joy".tr,
                                                                        style: AppThemeData.semiBoldTextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          color:
                                                                              controller.isPickingSource.value
                                                                                  ? Colors.green
                                                                                  : Colors.red,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            4,
                                                                      ),
                                                                      Text(
                                                                        controller
                                                                            .tempPickedAddress
                                                                            .value,
                                                                        style: AppThemeData.mediumTextStyle(
                                                                          fontSize:
                                                                              14,
                                                                          color:
                                                                              isDark
                                                                                  ? AppThemeData.grey100
                                                                                  : AppThemeData.grey800,
                                                                        ),
                                                                        maxLines:
                                                                            2,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 16,
                                                          ),
                                                          // Confirm button
                                                          SizedBox(
                                                            width:
                                                                double.infinity,
                                                            height: 50,
                                                            child: ElevatedButton(
                                                              onPressed: () {
                                                                controller
                                                                    .confirmPickedLocation();
                                                                if (_sheetController
                                                                    .isAttached) {
                                                                  _sheetController.animateTo(
                                                                    0.50,
                                                                    duration: const Duration(
                                                                      milliseconds:
                                                                          300,
                                                                    ),
                                                                    curve:
                                                                        Curves
                                                                            .easeOut,
                                                                  );
                                                                }
                                                              },
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    controller
                                                                            .isPickingSource
                                                                            .value
                                                                        ? Colors
                                                                            .green
                                                                        : Colors
                                                                            .red,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .check_circle,
                                                                    color:
                                                                        Colors
                                                                            .white,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    "Tasdiqlash"
                                                                        .tr,
                                                                    style: const TextStyle(
                                                                      color:
                                                                          Colors
                                                                              .white,
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    : const SizedBox.shrink(),
                          ),
                          // Bottom Sheet (only when not in map picking mode)
                          Obx(
                            () =>
                                !controller.isMapPickingMode.value
                                    ? bottomSheet(context, controller, isDark)
                                    : const SizedBox.shrink(),
                          ),
                        ],
                      ),
            );
          },
        );
      },
    );
  }

  // Global sheet controller
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  Widget bottomSheet(
    BuildContext context,
    CabBookingController controller,
    bool isDark,
  ) {
    final RxString selectedServiceType = 'ride'.obs; // 'ride' or 'intercity'
    final sheetController = _sheetController;
    Timer? searchDebounce;

    // Controller'dan focus node va focus holatini olish
    final destinationFocusNode = controller.destinationFocusNode;
    final isDestinationFocused = controller.isDestinationFocused;
    final sourceFocusNode = controller.sourceFocusNode;
    final isSourceFocused = controller.isSourceFocused;

    // Focus node listener - faqat bir marta qo'shish (useEffect kabi)
    if (!controller.focusListenerAdded) {
      destinationFocusNode.addListener(() {
        isDestinationFocused.value = destinationFocusNode.hasFocus;
        // Klaviatura ochilganda bottom sheet ni 0.85 ga o'zgartirish
        if (destinationFocusNode.hasFocus) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (sheetController.isAttached) {
              sheetController.animateTo(
                0.85,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        } else {
          // Klaviatura yopilganda bottom sheet ni 0.5 ga qaytarish
          Future.delayed(const Duration(milliseconds: 300), () {
            if (sheetController.isAttached) {
              sheetController.animateTo(
                0.50,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      });
      controller.focusListenerAdded = true;
    }

    // Source focus node listener
    if (!controller.sourceFocusListenerAdded) {
      sourceFocusNode.addListener(() {
        isSourceFocused.value = sourceFocusNode.hasFocus;
        if (sourceFocusNode.hasFocus) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (sheetController.isAttached) {
              sheetController.animateTo(
                0.85,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        } else {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (sheetController.isAttached) {
              sheetController.animateTo(
                0.50,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      });
      controller.sourceFocusListenerAdded = true;
    }

    // TextFieldWidget'da onchange callback allaqachon mavjud va u ishlayapti
    // Shuning uchun bu yerda listener qo'shish shart emas
    // Listener'lar har safar qayta qo'shilganda muammo yaratishi mumkin

    return Positioned.fill(
      child: DraggableScrollableSheet(
        controller: sheetController,
        initialChildSize: 0.50,
        minChildSize: 0.50,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    Expanded(
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
                                  // Shahar ichi card
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        selectedServiceType.value = 'ride';
                                      },
                                      child: Container(
                                        height: 80,
                                        clipBehavior: Clip.hardEdge,
                                        decoration: BoxDecoration(
                                          color:
                                              selectedServiceType.value ==
                                                      'ride'
                                                  ? AppThemeData.taxiBooking500
                                                  : (isDark
                                                      ? AppThemeData.grey600
                                                      : AppThemeData.grey100),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 16,
                                                top: 16,
                                              ),
                                              child: Text(
                                                "City rides, 24x7 availability"
                                                    .tr,
                                                style:
                                                    AppThemeData.semiBoldTextStyle(
                                                      fontSize: 16,
                                                      color:
                                                          selectedServiceType
                                                                      .value ==
                                                                  'ride'
                                                              ? Colors.white
                                                              : (isDark
                                                                  ? AppThemeData
                                                                      .grey400
                                                                  : AppThemeData
                                                                      .grey800),
                                                    ),
                                              ),
                                            ),
                                            Positioned(
                                              right: -30,
                                              bottom: -20,
                                              child: Image.asset(
                                                "assets/images/in_city.png",
                                                height: 90,
                                                width: 110,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Shahar tashqarisi card
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        selectedServiceType.value = 'intercity';
                                      },
                                      child: Container(
                                        height: 80,
                                        clipBehavior: Clip.hardEdge,
                                        decoration: BoxDecoration(
                                          color:
                                              selectedServiceType.value ==
                                                      'intercity'
                                                  ? const Color(0xFF6B46C1)
                                                  : (isDark
                                                      ? AppThemeData.grey600
                                                      : AppThemeData.grey100),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 16,
                                                top: 12,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "City".tr,
                                                    style: AppThemeData.semiBoldTextStyle(
                                                      fontSize: 16,
                                                      color:
                                                          selectedServiceType
                                                                      .value ==
                                                                  'intercity'
                                                              ? Colors.white
                                                              : (isDark
                                                                  ? AppThemeData
                                                                      .grey400
                                                                  : AppThemeData
                                                                      .grey800),
                                                    ),
                                                  ),
                                                  Text(
                                                    "Outside".tr,
                                                    style: AppThemeData.semiBoldTextStyle(
                                                      fontSize: 16,
                                                      color:
                                                          selectedServiceType
                                                                      .value ==
                                                                  'intercity'
                                                              ? Colors.white
                                                              : (isDark
                                                                  ? AppThemeData
                                                                      .grey400
                                                                  : AppThemeData
                                                                      .grey800),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Positioned(
                                              right: -25,
                                              bottom: -15,
                                              child: Image.asset(
                                                "assets/images/out_city.png",
                                                height: 85,
                                                width: 100,
                                                fit: BoxFit.contain,
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
                            // Origin Location with Map Picker
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      controller.sourceFocusNode.requestFocus();
                                    },
                                    child: TextFieldWidget(
                                      controller:
                                          controller
                                              .sourceTextEditController
                                              .value,
                                      hintText:
                                          Constant.selectedLocation
                                                  .getFullAddress()
                                                  .isNotEmpty
                                              ? Constant.selectedLocation
                                                  .getFullAddress()
                                              : "Pickup Location".tr,
                                      enable: true,
                                      focusNode: controller.sourceFocusNode,
                                      onchange: (value) {
                                        searchDebounce?.cancel();
                                        final trimmedValue = value.trim();
                                        if (trimmedValue.isNotEmpty &&
                                            trimmedValue.length >= 4) {
                                          searchDebounce = Timer(
                                            const Duration(milliseconds: 700),
                                            () {
                                              if (Constant.selectedMapType ==
                                                  'osm') {
                                                controller.searchSourceOSM(
                                                  trimmedValue,
                                                );
                                              } else {
                                                controller.searchSourceGoogle(
                                                  trimmedValue,
                                                );
                                              }
                                            },
                                          );
                                        } else {
                                          controller.sourceSearchResults
                                              .clear();
                                        }
                                      },
                                      prefix: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 10,
                                          right: 10,
                                        ),
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.green.shade700,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Map Picker Button for Source
                                _buildMapPickerButton(
                                  context: context,
                                  controller: controller,
                                  isDark: isDark,
                                  isSource: true,
                                  tooltip: "Xaritadan tanlash".tr,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Suggested Source Locations
                            Obx(
                              () =>
                                  controller.isSourceFocused.value
                                      ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (controller
                                              .isSearchingSource
                                              .value)
                                            const Padding(
                                              padding: EdgeInsets.all(20.0),
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          else if (controller
                                              .sourceSearchError
                                              .value
                                              .isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                20.0,
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    Icons.error_outline,
                                                    color: Colors.red,
                                                    size: 40,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    controller
                                                        .sourceSearchError
                                                        .value,
                                                    style:
                                                        AppThemeData.mediumTextStyle(
                                                          fontSize: 14,
                                                          color: Colors.red,
                                                        ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            )
                                          else if (controller
                                              .sourceSearchResults
                                              .isEmpty)
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                20.0,
                                              ),
                                              child: Text(
                                                controller
                                                            .sourceTextEditController
                                                            .value
                                                            .text
                                                            .trim()
                                                            .length <
                                                        4
                                                    ? "Please enter at least 4 characters"
                                                        .tr
                                                    : "No results found".tr,
                                                style:
                                                    AppThemeData.mediumTextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          isDark
                                                              ? AppThemeData
                                                                  .greyDark700
                                                              : AppThemeData
                                                                  .grey700,
                                                    ),
                                              ),
                                            )
                                          else
                                            ...controller.sourceSearchResults.map((
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
                                                            .sourceTextEditController
                                                            .value
                                                            .text =
                                                        result['address'] ?? '';
                                                    controller
                                                        .setDepartureMarker(
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
                                                                .sourceTextEditController
                                                                .value
                                                                .text =
                                                            details['address'] ??
                                                            '';
                                                        controller
                                                            .setDepartureMarker(
                                                              details['lat']
                                                                  as double,
                                                              details['lng']
                                                                  as double,
                                                            );
                                                      }
                                                    }
                                                  }
                                                  controller.sourceFocusNode
                                                      .unfocus();
                                                  controller
                                                      .isSourceFocused
                                                      .value = false;
                                                },
                                                isDark,
                                              );
                                            }).toList(),
                                        ],
                                      )
                                      : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 12),
                            // Destination Location with Map Picker
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      controller.destinationFocusNode
                                          .requestFocus();
                                    },
                                    child: TextFieldWidget(
                                      controller:
                                          controller
                                              .destinationTextEditController
                                              .value,
                                      hintText: "→ Qayerga boramiz?".tr,
                                      enable: true,
                                      focusNode:
                                          controller.destinationFocusNode,
                                      onchange: (value) {
                                        searchDebounce?.cancel();
                                        final trimmedValue = value.trim();
                                        if (trimmedValue.isNotEmpty &&
                                            trimmedValue.length >= 4) {
                                          searchDebounce = Timer(
                                            const Duration(milliseconds: 700),
                                            () {
                                              if (Constant.selectedMapType ==
                                                  'osm') {
                                                controller.searchDestinationOSM(
                                                  trimmedValue,
                                                );
                                              } else {
                                                controller
                                                    .searchDestinationGoogle(
                                                      trimmedValue,
                                                    );
                                              }
                                            },
                                          );
                                        } else {
                                          controller.destinationSearchResults
                                              .clear();
                                        }
                                      },
                                      prefix: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 10,
                                          right: 10,
                                        ),
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.red.shade700,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Map Picker Button for Destination
                                _buildMapPickerButton(
                                  context: context,
                                  controller: controller,
                                  isDark: isDark,
                                  isSource: false,
                                  tooltip: "Xaritadan tanlash".tr,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Suggested Destinations
                            Obx(
                              () =>
                                  controller.isDestinationFocused.value
                                      ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (controller
                                              .isSearchingDestination
                                              .value)
                                            const Padding(
                                              padding: EdgeInsets.all(20.0),
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          else if (controller
                                              .searchError
                                              .value
                                              .isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                20.0,
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    Icons.error_outline,
                                                    color: Colors.red,
                                                    size: 40,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    controller
                                                        .searchError
                                                        .value,
                                                    style:
                                                        AppThemeData.mediumTextStyle(
                                                          fontSize: 14,
                                                          color: Colors.red,
                                                        ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            )
                                          else if (controller
                                              .destinationSearchResults
                                              .isEmpty)
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                20.0,
                                              ),
                                              child: Text(
                                                controller
                                                            .destinationTextEditController
                                                            .value
                                                            .text
                                                            .trim()
                                                            .length <
                                                        4
                                                    ? "Please enter at least 4 characters"
                                                        .tr
                                                    : "No results found".tr,
                                                style:
                                                    AppThemeData.mediumTextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          isDark
                                                              ? AppThemeData
                                                                  .greyDark700
                                                              : AppThemeData
                                                                  .grey700,
                                                    ),
                                              ),
                                            )
                                          else
                                            ...controller.destinationSearchResults.map((
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
                                                  controller
                                                      .destinationFocusNode
                                                      .unfocus();
                                                  controller
                                                      .isDestinationFocused
                                                      .value = false;
                                                },
                                                isDark,
                                              );
                                            }).toList(),
                                        ],
                                      )
                                      : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Davom etish tugmasi - doim ko'rinadigan
                    Container(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppThemeData.grey700 : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Obx(() {
                        // Markerlarni tekshirish - asosiy shart
                        final hasSourceMarker =
                            Constant.selectedMapType == 'osm'
                                ? controller
                                            .departureLatLongOsm
                                            .value
                                            .latitude !=
                                        0.0 &&
                                    controller
                                            .departureLatLongOsm
                                            .value
                                            .longitude !=
                                        0.0
                                : controller.departureLatLong.value.latitude !=
                                        0.0 &&
                                    controller
                                            .departureLatLong
                                            .value
                                            .longitude !=
                                        0.0;

                        final hasDestinationMarker =
                            Constant.selectedMapType == 'osm'
                                ? controller
                                            .destinationLatLongOsm
                                            .value
                                            .latitude !=
                                        0.0 &&
                                    controller
                                            .destinationLatLongOsm
                                            .value
                                            .longitude !=
                                        0.0
                                : controller
                                            .destinationLatLong
                                            .value
                                            .latitude !=
                                        0.0 &&
                                    controller
                                            .destinationLatLong
                                            .value
                                            .longitude !=
                                        0.0;

                        // Ikkala marker ham bo'lishi kerak
                        final isEnabled =
                            hasSourceMarker && hasDestinationMarker;

                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient:
                                isEnabled
                                    ? null
                                    : LinearGradient(
                                      colors: [
                                        Colors.orange.shade50,
                                        Colors.orange.shade100,
                                      ],
                                    ),
                            border:
                                isEnabled
                                    ? null
                                    : Border.all(
                                      color: Colors.orange.shade300,
                                      width: 2,
                                    ),
                            boxShadow:
                                isEnabled
                                    ? [
                                      BoxShadow(
                                        color: AppThemeData.primary300
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                    : [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                          ),
                          child: AnimatedOpacity(
                            opacity: isEnabled ? 1.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed:
                                    isEnabled
                                        ? () {
                                          // Focus'larni olib tashlash
                                          controller.sourceFocusNode.unfocus();
                                          controller.destinationFocusNode
                                              .unfocus();
                                          controller.isSourceFocused.value =
                                              false;
                                          controller
                                              .isDestinationFocused
                                              .value = false;

                                          // Vehicle selection ekraniga o'tish
                                          if (selectedServiceType.value ==
                                              'ride') {
                                            controller.bottomSheetType.value =
                                                'vehicleSelection';
                                            Get.to(() => CabBookingScreen());
                                          } else {
                                            Get.to(() => IntercityHomeScreen());
                                          }
                                        }
                                        : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isEnabled
                                          ? AppThemeData.primary300
                                          : Colors.transparent,
                                  foregroundColor:
                                      isEnabled
                                          ? Colors.white
                                          : Colors.orange.shade700,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            isEnabled
                                                ? Colors.white.withOpacity(0.2)
                                                : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isEnabled
                                            ? Icons.arrow_forward_rounded
                                            : Icons.location_searching,
                                        size: 24,
                                        color:
                                            isEnabled
                                                ? Colors.white
                                                : Colors.orange.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        isEnabled
                                            ? "Davom etish".tr
                                            : "Ikkala joyni tanlang".tr,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              isEnabled
                                                  ? Colors.white
                                                  : Colors.orange.shade800,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapPickerButton({
    required BuildContext context,
    required CabBookingController controller,
    required bool isDark,
    required bool isSource,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Focus'ni olib tashlash
            if (isSource) {
              controller.sourceFocusNode.unfocus();
              controller.isSourceFocused.value = false;
            } else {
              controller.destinationFocusNode.unfocus();
              controller.isDestinationFocused.value = false;
            }

            // Map picking rejimini yoqish
            controller.isPickingSource.value = isSource;
            controller.isMapPickingMode.value = true;
            controller.tempPickedAddress.value = '';
            controller.tempPickedLocation.value = latlong.LatLng(0, 0);

            // Bottom sheet ni 0.18 ga pasaytirish
            if (_sheetController.isAttached) {
              _sheetController.animateTo(
                0.18,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isSource
                        ? [Colors.green.shade400, Colors.green.shade600]
                        : [Colors.red.shade400, Colors.red.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isSource ? Colors.green : Colors.red).withOpacity(
                    0.3,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.map_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
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
}
