import 'package:customer/constant/constant.dart';
import 'package:customer/models/app_placemark.dart';
import 'package:customer/models/lat_lng.dart';
import 'package:customer/service/yandex_geocoding_service.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

class LocationController extends GetxController {
  ym.YandexMapController? yandexMapController;
  var selectedLocation = Rxn<LatLng>();
  var selectedPlaceAddress = Rxn<AppPlacemark>();
  var address = "Move the map to select a location".obs;
  TextEditingController searchController = TextEditingController();

  RxString zipCode = ''.obs;

  late final YandexGeocodingService _geocoding;

  @override
  void onInit() {
    super.onInit();
    _geocoding = YandexGeocodingService(apiKey: Constant.yandexGeocodeApiKey);
    getArgument();
    getCurrentLocation();
  }

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      zipCode.value = argumentData['zipCode'] ?? '';
      if (zipCode.value.isNotEmpty) {
        getCoordinatesFromZipCode(zipCode.value);
      }
    }
    update();
  }

  LatLng _fallbackLatLng() {
    final lat = Constant.selectedLocation.location?.latitude ??
        Constant.userModel?.location?.latitude ??
        Constant.defaultLocationLat;
    final lng = Constant.selectedLocation.location?.longitude ??
        Constant.userModel?.location?.longitude ??
        Constant.defaultLocationLng;
    return LatLng(lat, lng);
  }

  Future<void> _moveCameraTo(LatLng target, {double zoom = 15}) async {
    final controller = yandexMapController;
    if (controller == null) return;
    await controller.moveCamera(
      ym.CameraUpdate.newCameraPosition(
        ym.CameraPosition(
          target: ym.Point(latitude: target.latitude, longitude: target.longitude),
          zoom: zoom,
        ),
      ),
    );
  }

  Future<void> getCurrentLocation() async {
    final fallback = _fallbackLatLng();
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position? position;
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
            .timeout(const Duration(seconds: 8));
      }
      final resolved = position == null
          ? fallback
          : LatLng(position.latitude, position.longitude);
      selectedLocation.value = resolved;
      await _moveCameraTo(resolved);
      await getAddressFromLatLng(resolved);
    } catch (e) {
      selectedLocation.value = fallback;
      await _moveCameraTo(fallback);
      await getAddressFromLatLng(fallback);
    }
  }

  Future<void> getAddressFromLatLng(LatLng latLng) async {
    try {
      final place = await _geocoding.reverseGeocode(latLng.latitude, latLng.longitude);
      if (place != null) {
        selectedPlaceAddress.value = place;
        address.value = place.formattedAddress;
      } else {
        address.value = "Address not found";
      }
    } catch (e) {
      print("Error getting address: $e");
      address.value = "Error getting address";
    }
  }

  Future<void> getCoordinatesFromZipCode(String zipCode) async {
    try {
      final latLng = await _geocoding.getCoordinatesFromAddress(zipCode);
      if (latLng != null) {
        selectedLocation.value = latLng;
        await _moveCameraTo(latLng);
        await getAddressFromLatLng(latLng);
      }
    } catch (e) {
      print("Error getting coordinates for ZIP code: $e");
    }
  }

  void confirmLocation() {
    if (selectedLocation.value != null) {
      Get.back(
        result: SelectedLocationModel(
          address: selectedPlaceAddress.value,
          latLng: selectedLocation.value,
        ),
      );
    }
  }
}
