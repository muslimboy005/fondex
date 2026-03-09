import 'package:driver/constant/constant.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;
import 'package:driver/utils/yandex_map_utils.dart';
import '../../controllers/parcel_tracking_controller.dart';
import '../../themes/app_them_data.dart';

class ParcelTrackingScreen extends StatelessWidget {
  const ParcelTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<ParcelTrackingController>(
      init: ParcelTrackingController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            elevation: 2,
            backgroundColor: AppThemeData.primary300,
            title: Text("Map view".tr),
            leading: InkWell(
                onTap: () {
                  Get.back();
                },
                child: const Icon(
                  Icons.arrow_back,
                )),
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : Obx(
                  () => ym.YandexMap(
                    onMapCreated:
                        (ym.YandexMapController mapController) async {
                      controller.yandexMapController = mapController;
                      await mapController.toggleUserLayer(visible: true);
                      await mapController.moveCamera(
                        ym.CameraUpdate.newCameraPosition(
                          ym.CameraPosition(
                            target: ym.Point(
                              latitude: Constant.userModel?.location?.latitude ?? 41.3111,
                              longitude: Constant.userModel?.location?.longitude ?? 69.2797,
                            ),
                            zoom: 15,
                          ),
                        ),
                      );
                    },
                    mapObjects: yandexMapObjectsFromGoogle(
                      markers: controller.markers.values,
                      polylines: controller.polyLines.values,
                    ),
                  ),
                ),
        );
      },
    );
  }
}
