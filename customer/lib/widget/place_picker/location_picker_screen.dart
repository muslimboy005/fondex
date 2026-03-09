import 'package:customer/constant/constant.dart';
import 'package:customer/models/lat_lng.dart';
import 'package:customer/service/yandex_geocoding_service.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/widget/place_picker/location_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;
import 'package:customer/utils/yandex_map_utils.dart';

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
                      onMapCreated: (ym.YandexMapController mapController) async {
                        controller.yandexMapController = mapController;
                        await mapController.toggleUserLayer(visible: true);
                        await mapController.moveCamera(
                          ym.CameraUpdate.newCameraPosition(
                            ym.CameraPosition(
                              target: ym.Point(
                                latitude: controller.selectedLocation.value!.latitude,
                                longitude: controller.selectedLocation.value!.longitude,
                              ),
                              zoom: 15,
                            ),
                          ),
                        );
                      },
                      onMapTap: (ym.Point point) {
                        final tapped = LatLng(point.latitude, point.longitude);
                        controller.selectedLocation.value = tapped;
                        controller.getAddressFromLatLng(tapped);
                      },
                      onCameraPositionChanged:
                          (ym.CameraPosition position, ym.CameraUpdateReason _, bool finished) {
                        controller.selectedLocation.value =
                            LatLng(position.target.latitude, position.target.longitude);
                        if (finished) {
                          controller.getAddressFromLatLng(controller.selectedLocation.value!);
                        }
                      },
                      mapObjects: controller.selectedLocation.value == null
                          ? const []
                          : [
                              ym.PlacemarkMapObject(
                                mapId: const ym.MapObjectId("selected-location"),
                                point: ym.Point(
                                  latitude: controller.selectedLocation.value!.latitude,
                                  longitude: controller.selectedLocation.value!.longitude,
                                ),
                                icon: yandexPlacemarkIconFromAsset(
                                  'assets/icons/ic_location.png',
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
                      onTap: () => Get.back(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.arrow_back_ios_new_outlined,
                            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        final query = await _showYandexSearchDialog(context);
                        if (query == null || query.isEmpty) return;
                        final results = await _yandexGeocoding.search(query, limit: 10);
                        if (!context.mounted) return;
                        final picked = await _showSearchResults(context, results);
                        if (picked != null) {
                          controller.selectedLocation.value = picked.latLng;
                          await controller.yandexMapController?.moveCamera(
                            ym.CameraUpdate.newCameraPosition(
                              ym.CameraPosition(
                                target: ym.Point(
                                  latitude: picked.latLng.latitude,
                                  longitude: picked.latLng.longitude,
                                ),
                                zoom: 15,
                              ),
                            ),
                          );
                          controller.getAddressFromLatLng(picked.latLng);
                        }
                      },
                      child: Container(
                        width: Responsive.width(100, context),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search),
                            SizedBox(width: 8),
                            Text("Search place..."),
                          ],
                        ),
                      ),
                    ),
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
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(
                        () => Text(
                          controller.address.value,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 10),
                      RoundedButtonFill(
                        title: "Confirm Location".tr,
                        height: 5.5,
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey50,
                        onPress: () => controller.confirmLocation(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _showYandexSearchDialog(BuildContext context) async {
    final textController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Search place'.tr),
        content: TextField(
          controller: textController,
          decoration: InputDecoration(hintText: 'Enter address...'.tr),
          autofocus: true,
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim().isEmpty ? null : v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel'.tr)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(
              textController.text.trim().isEmpty ? null : textController.text.trim(),
            ),
            child: Text('Search'.tr),
          ),
        ],
      ),
    );
  }

  Future<GeocodeResult?> _showSearchResults(BuildContext context, List<GeocodeResult> results) async {
    if (results.isEmpty) return null;
    return showModalBottomSheet<GeocodeResult>(
      context: context,
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        itemCount: results.length,
        itemBuilder: (_, i) {
          final r = results[i];
          return ListTile(
            title: Text(r.displayName),
            onTap: () => Navigator.of(ctx).pop(r),
          );
        },
      ),
    );
  }
}
