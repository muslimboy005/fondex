import 'package:customer/constant/constant.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:map_launcher/map_launcher.dart';
import '../themes/show_toast_dialog.dart';
import 'package:customer/service/yandex_geocoding_service.dart';
import 'package:location/location.dart' as loc;

class Utils {
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      await loc.Location().requestService();
      return null;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  static Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final service = YandexGeocodingService(apiKey: Constant.yandexGeocodeApiKey);
      final place = await service.reverseGeocode(lat, lng);
      return place?.formattedAddress ?? "Unknown location";
    } catch (e) {
      return "Unknown location";
    }
  }

  static Future<void> redirectMap({required String name, required double latitude, required double longLatitude}) async {
    final mapType = Constant.normalizeMapType(Constant.mapType);
    if (mapType == "google") {
      bool? isAvailable = await MapLauncher.isMapAvailable(MapType.google);
      if (isAvailable == true) {
        await MapLauncher.showDirections(mapType: MapType.google, directionsMode: DirectionsMode.driving, destinationTitle: name, destination: Coords(latitude, longLatitude));
      } else {
        ShowToastDialog.showToast("Google map is not installed".tr);
      }
    } else if (mapType == "googleGo") {
      bool? isAvailable = await MapLauncher.isMapAvailable(MapType.googleGo);
      if (isAvailable == true) {
        await MapLauncher.showDirections(mapType: MapType.googleGo, directionsMode: DirectionsMode.driving, destinationTitle: name, destination: Coords(latitude, longLatitude));
      } else {
        ShowToastDialog.showToast("Google Go map is not installed".tr);
      }
    } else if (mapType == "waze") {
      bool? isAvailable = await MapLauncher.isMapAvailable(MapType.waze);
      if (isAvailable == true) {
        await MapLauncher.showDirections(mapType: MapType.waze, directionsMode: DirectionsMode.driving, destinationTitle: name, destination: Coords(latitude, longLatitude));
      } else {
        ShowToastDialog.showToast("Waze is not installed".tr);
      }
    } else if (mapType == "mapswithme") {
      bool? isAvailable = await MapLauncher.isMapAvailable(MapType.mapswithme);
      if (isAvailable == true) {
        await MapLauncher.showDirections(mapType: MapType.mapswithme, directionsMode: DirectionsMode.driving, destinationTitle: name, destination: Coords(latitude, longLatitude));
      } else {
        ShowToastDialog.showToast("Mapswithme is not installed".tr);
      }
    } else if (mapType == "yandexNavi") {
      bool? isAvailable = await MapLauncher.isMapAvailable(MapType.yandexNavi);
      if (isAvailable == true) {
        await MapLauncher.showDirections(mapType: MapType.yandexNavi, directionsMode: DirectionsMode.driving, destinationTitle: name, destination: Coords(latitude, longLatitude));
      } else {
        ShowToastDialog.showToast("YandexNavi is not installed".tr);
      }
    } else if (mapType == "yandexMaps") {
      bool? isAvailable = await MapLauncher.isMapAvailable(MapType.yandexMaps);
      if (isAvailable == true) {
        await MapLauncher.showDirections(mapType: MapType.yandexMaps, directionsMode: DirectionsMode.driving, destinationTitle: name, destination: Coords(latitude, longLatitude));
      } else {
        ShowToastDialog.showToast("yandexMaps map is not installed".tr);
      }
    }
  }

  static String formatAddress({required SelectedLocationModel selectedLocation}) {
    final addr = selectedLocation.address;
    if (addr == null) return selectedLocation.latLng != null ? '${selectedLocation.latLng!.latitude}, ${selectedLocation.latLng!.longitude}' : '';
    return addr.formattedAddress;
  }
}
