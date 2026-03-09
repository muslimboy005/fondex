import 'package:driver/constant/constant.dart';
import 'package:driver/service/yandex_geocoding_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/widget/place_picker/location_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;
import 'package:driver/utils/yandex_map_utils.dart';

final YandexGeocodingService _yandexGeocoding = YandexGeocodingService(apiKey: Constant.yandexGeocodeApiKey);

class LocationPickerScreen extends StatelessWidget {
  const LocationPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX<LocationController>(
        init: LocationController(),
        builder: (controller) {
          return Scaffold(
            body: Stack(
              children: [
                controller.selectedLocation.value == null
                    ? const Center(child: CircularProgressIndicator())
                    : ym.YandexMap(
                            onMapCreated:
                                (ym.YandexMapController mapController) async {
                              controller.yandexMapController = mapController;
                              await mapController.toggleUserLayer(visible: true);
                              await mapController.moveCamera(
                                ym.CameraUpdate.newCameraPosition(
                                  ym.CameraPosition(
                                    target: ym.Point(
                                      latitude:
                                          controller.selectedLocation.value!.latitude,
                                      longitude:
                                          controller.selectedLocation.value!.longitude,
                                    ),
                                    zoom: 15,
                                  ),
                                ),
                              );
                            },
                            onMapTap: (ym.Point point) {
                              final tapped = LatLng(
                                point.latitude,
                                point.longitude,
                              );
                              controller.selectedLocation.value = tapped;
                              controller.getAddressFromLatLng(tapped);
                            },
                            onCameraPositionChanged:
                                (ym.CameraPosition position, ym.CameraUpdateReason _, bool finished) {
                              controller.selectedLocation.value = LatLng(
                                position.target.latitude,
                                position.target.longitude,
                              );
                              if (finished) {
                                controller.getAddressFromLatLng(
                                  controller.selectedLocation.value!,
                                );
                              }
                            },
                            mapObjects: controller.selectedLocation.value == null
                                ? const []
                                : [
                                    ym.PlacemarkMapObject(
                                      mapId:
                                          const ym.MapObjectId("selected-location"),
                                      point: ym.Point(
                                        latitude:
                                            controller.selectedLocation.value!.latitude,
                                        longitude:
                                            controller.selectedLocation.value!.longitude,
                                      ),
                                      icon: yandexPlacemarkIconFromAsset(
                                        'assets/icons/ic_cab_pickup.png',
                                      ),
                                      opacity: 1.0,
                                    ),
                                    ],
                                  ),
                Positioned(
                  top: 60,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          Get.back();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.arrow_back,
                              color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      GestureDetector(
                        onTap: () async {
                          final query = await _showSearchDialog(context);
                          if (query == null || query.isEmpty) return;
                          final results = await _yandexGeocoding.search(query, limit: 10);
                          if (results.isEmpty) return;
                          final picked = await _showResultsBottomSheet(context, results);
                          if (picked != null) {
                            final pos = LatLng(picked.latLng.latitude, picked.latLng.longitude);
                            controller.selectedLocation.value = pos;
                            final yandexController = controller.yandexMapController;
                            if (yandexController != null) {
                              await yandexController.moveCamera(
                                ym.CameraUpdate.newCameraPosition(
                                  ym.CameraPosition(
                                    target: ym.Point(latitude: picked.latLng.latitude, longitude: picked.latLng.longitude),
                                    zoom: 15,
                                  ),
                                ),
                              );
                            }
                            controller.getAddressFromLatLng(pos);
                          }
                        },
                        child: Container(
                          width: Responsive.width(100, context),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(60),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search),
                              const SizedBox(width: 8),
                              Text("Search place...".tr),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                Positioned(
                  bottom: 100,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 5),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Obx(() => Text(
                              controller.address.value,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            )),
                        const SizedBox(height: 10),
                        RoundedButtonFill(
                          title: "Confirm Location".tr,
                          height: 5.5,
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey50,
                          onPress: () => controller.confirmLocation(),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }
}

Future<String?> _showSearchDialog(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text("Search place...".tr),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: "Manzil yoki joy nomini yozing"),
        autofocus: true,
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim().isEmpty ? null : v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text("Cancel".tr),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim().isEmpty ? null : controller.text.trim()),
          child: Text("Search".tr),
        ),
      ],
    ),
  );
}

Future<GeocodeResult?> _showResultsBottomSheet(BuildContext context, List<GeocodeResult> results) async {
  return showModalBottomSheet<GeocodeResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollController) => ListView.builder(
        controller: scrollController,
        itemCount: results.length,
        itemBuilder: (_, i) {
          final r = results[i];
          return ListTile(
            title: Text(r.displayName),
            onTap: () => Navigator.of(ctx).pop(r),
          );
        },
      ),
    ),
  );
}
