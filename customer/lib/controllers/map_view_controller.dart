import 'package:customer/utils/yandex_map_utils.dart';
import 'package:get/get.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;
import '../screen_ui/multi_vendor_service/restaurant_details_screen/restaurant_details_screen.dart';
import 'food_home_controller.dart';

class MapViewController extends GetxController {
  ym.YandexMapController? yandexMapController;

  FoodHomeController homeController = Get.find<FoodHomeController>();

  RxList<YandexMarkerInput> yandexMarkers = <YandexMarkerInput>[].obs;

  @override
  void onInit() {
    super.onInit();
    addMarkerSetup();
  }

  Future<void> addMarkerSetup() async {
    final list = <YandexMarkerInput>[];
    for (final element in homeController.allNearestRestaurant) {
      list.add(
        YandexMarkerInput(
          id: element.id.toString(),
          latitude: element.latitude ?? 0.0,
          longitude: element.longitude ?? 0.0,
          title: element.title,
          assetIcon: 'assets/images/map_selected.png',
          onTap: () {
            Get.to(
              const RestaurantDetailsScreen(),
              arguments: {"vendorModel": element},
            );
          },
        ),
      );
    }
    yandexMarkers.value = list;
  }
}
