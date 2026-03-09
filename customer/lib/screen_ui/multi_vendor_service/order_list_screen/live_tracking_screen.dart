import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/live_tracking_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;
import 'package:customer/utils/yandex_map_utils.dart';
import '../../../controllers/theme_controller.dart';

class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<LiveTrackingController>(
      init: LiveTrackingController(),
      builder: (controller) {
        if (controller.isLoading.value) {
          return Scaffold(body: Constant.loader());
        }

        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface, title: Text("Live Tracking".tr), centerTitle: false),
          body:
              Constant.isYandexMap
                      ? ym.YandexMap(
                        onMapCreated: (ym.YandexMapController mapController) async {
                          controller.yandexMapController = mapController;
                          await mapController.toggleUserLayer(visible: true);
                          await mapController.moveCamera(
                            ym.CameraUpdate.newCameraPosition(
                              ym.CameraPosition(
                                target: ym.Point(
                                  latitude: controller.driverUserModel.value.location?.latitude ?? 0.0,
                                  longitude: controller.driverUserModel.value.location?.longitude ?? 0.0,
                                ),
                                zoom: 14,
                              ),
                            ),
                          );
                        },
                        mapObjects: yandexMapObjectsFromGoogle(
                          markers: controller.markers.values,
                          polylines: controller.polyLines.values,
                        ),
                      )
                      : gmap.GoogleMap(
                        onMapCreated: (gmap.GoogleMapController mapController) {
                          controller.mapController = mapController;
                        },
                        myLocationEnabled: true,
                        zoomControlsEnabled: false,
                        polylines: Set<gmap.Polyline>.of(controller.polyLines.values),
                        markers: Set<gmap.Marker>.of(controller.markers.values),
                        initialCameraPosition: gmap.CameraPosition(
                          zoom: 14,
                          target: gmap.LatLng(controller.driverUserModel.value.location?.latitude ?? 0.0, controller.driverUserModel.value.location?.longitude ?? 0.0),
                        ),
                      ),
        );
      },
    );
  }
}
