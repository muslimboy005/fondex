import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/auth_screens/auth_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:location/location.dart' as loc;

import '../../constant/assets.dart';
import '../../utils/utils.dart';

void _navigateAfterLocation() {
  if (Constant.userModel != null) {
    Get.offAll(const ServiceListScreen());
  } else {
    Get.offAll(const AuthScreen());
  }
}

Future<Position?> _getBestPosition() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await loc.Location().requestService();
    }
  } catch (_) {}

  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
  } catch (_) {}

  try {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(const Duration(seconds: 8));
  } catch (_) {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                Image.asset(AppAssets.icLocation),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    "Enable Location for a Personalized Experience".tr,
                    style: AppThemeData.boldTextStyle(
                      fontSize: 24,
                      color:
                          isDark
                              ? AppThemeData.greyDark900
                              : AppThemeData.grey900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Text(
                    "Allow location access to discover beauty stores and services near you."
                        .tr,
                    style: AppThemeData.mediumTextStyle(
                      fontSize: 14,
                      color:
                          isDark
                              ? AppThemeData.greyDark600
                              : AppThemeData.grey600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 30),
                RoundedButtonFill(
                  title: "Use current location".tr,
                  onPress: () async {
                    Constant.checkPermission(
                      context: context,
                      onTap: () async {
                        ShowToastDialog.showLoader("Please wait...".tr);
                        ShippingAddress addressModel = ShippingAddress();
                        try {
                          Position? newLocalData = await _getBestPosition();
                          if (newLocalData == null) {
                            throw Exception("Location not available");
                          }
                          try {
                            await placemarkFromCoordinates(
                              newLocalData.latitude,
                              newLocalData.longitude,
                            ).timeout(const Duration(seconds: 6)).then((valuePlaceMaker) {
                              Placemark placeMark = valuePlaceMaker[0];
                              addressModel.addressAs = "Home";
                              addressModel.location = UserLocation(
                                latitude: newLocalData.latitude,
                                longitude: newLocalData.longitude,
                              );
                              String currentLocation =
                                  "${placeMark.name}, ${placeMark.subLocality}, ${placeMark.locality}, ${placeMark.administrativeArea}, ${placeMark.postalCode}, ${placeMark.country}";
                              addressModel.locality = currentLocation;
                            });
                          } catch (_) {
                            addressModel.addressAs = "Home";
                            addressModel.location = UserLocation(
                              latitude: newLocalData.latitude,
                              longitude: newLocalData.longitude,
                            );
                            addressModel.locality = "${newLocalData.latitude}, ${newLocalData.longitude}";
                          }

                          Constant.selectedLocation = addressModel;
                          try {
                            Constant.currentLocation = newLocalData;
                          } catch (_) {}

                          ShowToastDialog.closeLoader();

                          _navigateAfterLocation();
                        } catch (e) {
                          try {
                            await placemarkFromCoordinates(
                              19.228825,
                              72.854118,
                            ).timeout(const Duration(seconds: 6)).then((valuePlaceMaker) {
                              Placemark placeMark = valuePlaceMaker[0];
                              addressModel.addressAs = "Home";
                              addressModel.location = UserLocation(
                                latitude: 19.228825,
                                longitude: 72.854118,
                              );
                              String currentLocation =
                                  "${placeMark.name}, ${placeMark.subLocality}, ${placeMark.locality}, ${placeMark.administrativeArea}, ${placeMark.postalCode}, ${placeMark.country}";
                              addressModel.locality = currentLocation;
                            });
                          } catch (_) {
                            addressModel.addressAs = "Home";
                            addressModel.location = UserLocation(
                              latitude: 19.228825,
                              longitude: 72.854118,
                            );
                            addressModel.locality = "19.228825, 72.854118";
                          }

                          Constant.selectedLocation = addressModel;
                          try {
                            Constant.currentLocation =
                                await Utils.getCurrentLocation().timeout(const Duration(seconds: 6));
                          } catch (_) {}

                          ShowToastDialog.closeLoader();

                          _navigateAfterLocation();
                        }
                      },
                    );
                  },
                  color: AppThemeData.grey900,
                  textColor: AppThemeData.grey50,
                ),
                const SizedBox(height: 10),
                RoundedButtonFill(
                  title: "Set from map".tr,
                  onPress: () async {
                    Constant.checkPermission(
                      context: context,
                      onTap: () async {
                        ShowToastDialog.showLoader("Please wait...".tr);
                        ShippingAddress addressModel = ShippingAddress();
                        try {
                          await _getBestPosition();
                          ShowToastDialog.closeLoader();
                          if (Constant.selectedMapType == 'osm') {
                            final result = await Get.to(() => MapPickerPage());
                            if (result != null) {
                              final firstPlace = result;
                              final lat = firstPlace.coordinates.latitude;
                              final lng = firstPlace.coordinates.longitude;
                              final address = firstPlace.address;

                              addressModel.addressAs = "Home";
                              addressModel.locality = address.toString();
                              addressModel.location = UserLocation(
                                latitude: lat,
                                longitude: lng,
                              );
                              Constant.selectedLocation = addressModel;
                              _navigateAfterLocation();
                            }
                          } else {
                            Get.to(LocationPickerScreen())!.then((value) async {
                              if (value != null) {
                                SelectedLocationModel selectedLocationModel =
                                    value;

                                addressModel.addressAs = "Home";
                                addressModel.locality = Utils.formatAddress(
                                  selectedLocation: selectedLocationModel,
                                );
                                addressModel.location = UserLocation(
                                  latitude:
                                      selectedLocationModel.latLng!.latitude,
                                  longitude:
                                      selectedLocationModel.latLng!.longitude,
                                );
                                Constant.selectedLocation = addressModel;

                                _navigateAfterLocation();
                              }
                            });
                          }
                        } catch (e) {
                          await placemarkFromCoordinates(
                            19.228825,
                            72.854118,
                          ).then((valuePlaceMaker) {
                            Placemark placeMark = valuePlaceMaker[0];
                            addressModel.addressAs = "Home";
                            addressModel.location = UserLocation(
                              latitude: 19.228825,
                              longitude: 72.854118,
                            );
                            String currentLocation =
                                "${placeMark.name}, ${placeMark.subLocality}, ${placeMark.locality}, ${placeMark.administrativeArea}, ${placeMark.postalCode}, ${placeMark.country}";
                            addressModel.locality = currentLocation;
                          });

                          Constant.selectedLocation = addressModel;
                          ShowToastDialog.closeLoader();

                          _navigateAfterLocation();
                        }
                      },
                    );
                  },
                  color: AppThemeData.grey50,
                  textColor: AppThemeData.grey900,
                ),
                const SizedBox(height: 20),
                Constant.userModel == null
                    ? GestureDetector(
                      onTap: () => Get.offAll(const AuthScreen()),
                      child: Text(
                        "Continue to login".tr,
                        style: AppThemeData.semiBoldTextStyle(
                          fontSize: 16,
                          color:
                              isDark
                                  ? AppThemeData.greyDark900
                                  : AppThemeData.grey900,
                        ),
                      ),
                    )
                    : GestureDetector(
                      onTap: () async {
                        Get.to(AddressListScreen())!.then((value) {
                          if (value != null) {
                            ShippingAddress addressModel = value;
                            Constant.selectedLocation = addressModel;
                            Get.offAll(const ServiceListScreen());
                          }
                        });
                      },
                      child: Text(
                        "Enter Manually location".tr,
                        style: AppThemeData.semiBoldTextStyle(
                          fontSize: 16,
                          color:
                              isDark
                                  ? AppThemeData.greyDark900
                                  : AppThemeData.grey900,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
