import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/driver_location_controller.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;
import 'package:driver/utils/yandex_map_utils.dart';

class DriverLocationScreen extends StatelessWidget {
  const DriverLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
        init: DriverLocationController(),
        builder: (controller) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                "Driver Locations".tr,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              backgroundColor: isDark ? Colors.black : Colors.white,
              iconTheme: IconThemeData(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            body: controller.isLoading.value
                ? Constant.loader()
                : ym.YandexMap(
                    onMapCreated:
                        (ym.YandexMapController mapController) async {
                      controller.yandexMapController = mapController;
                      await mapController.toggleUserLayer(visible: true);
                      final initialLat =
                          controller.driverList.isNotEmpty &&
                                  controller.driverList.first.location != null
                              ? controller.driverList.first.location!.latitude!
                              : 41.3111;
                      final initialLng =
                          controller.driverList.isNotEmpty &&
                                  controller.driverList.first.location != null
                              ? controller.driverList.first.location!.longitude!
                              : 69.2797;
                      await mapController.moveCamera(
                        ym.CameraUpdate.newCameraPosition(
                          ym.CameraPosition(
                            target: ym.Point(
                              latitude: initialLat,
                              longitude: initialLng,
                            ),
                            zoom: 14,
                          ),
                        ),
                      );
                    },
                    mapObjects: yandexMapObjectsFromGoogle(
                      markers: controller.markers,
                    ),
                  ),
          );
        });
  }
}
