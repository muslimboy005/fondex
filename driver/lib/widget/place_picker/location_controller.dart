import 'package:driver/constant/constant.dart';
import 'package:driver/widget/place_picker/selected_location_model.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

class LocationController extends GetxController {
  GoogleMapController? mapController;
  ym.YandexMapController? yandexMapController;
  var selectedLocation = Rxn<LatLng>();
  var selectedPlaceAddress = Rxn<Placemark>();
  var address = "Move the map to select a location".obs;
  TextEditingController searchController = TextEditingController();

  RxString zipCode = ''.obs;

  @override
  void onInit() {
    super.onInit();
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
        41.3111;
    final lng = Constant.selectedLocation.location?.longitude ??
        Constant.userModel?.location?.longitude ??
        69.2797;
    return LatLng(lat, lng);
  }

  Future<void> _moveCameraTo(LatLng target, {double zoom = 15}) async {
    if (Constant.isYandexMap) {
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
    } else {
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
    }
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
      List<Placemark> placemarks =
      await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        selectedPlaceAddress.value = place;
        address.value = "${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
      } else {
        address.value = "Address not found";
      }
    } catch (e) {
      print("Error getting address: $e");
      address.value = "Error getting address";
    }
  }

  void onMapMoved(CameraPosition position) {
    selectedLocation.value = position.target;
  }

  Future<void> getCoordinatesFromZipCode(String zipCode) async {
    try {
      List<Location> locations = await locationFromAddress(zipCode);
      if (locations.isNotEmpty) {
        selectedLocation.value =
            LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      print("Error getting coordinates for ZIP code: $e");
    }
  }

  void confirmLocation() {
    if (selectedLocation.value != null) {
      SelectedLocationModel selectedLocationModel = SelectedLocationModel(
        address: selectedPlaceAddress.value,
        latLng: selectedLocation.value,
      );
      Get.back(result: selectedLocationModel);
    }
  }
}
