import 'dart:developer';
import 'package:customer/constant/constant.dart';
import 'package:customer/service/yandex_geocoding_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Manzil qidiruv natijasi (Yandex Geocoding orqali, O'zbekiston).
class SearchSuggestion {
  final String displayName;
  final String address;
  final double lat;
  final double lng;

  SearchSuggestion({
    required this.displayName,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class OsmSearchPlaceController extends GetxController {
  Rx<TextEditingController> searchTxtController = TextEditingController().obs;
  RxList<SearchSuggestion> suggestionsList = <SearchSuggestion>[].obs;

  @override
  void onInit() {
    super.onInit();
    searchTxtController.value.addListener(() {
      _onChanged();
    });
  }

  void _onChanged() {
    fetchAddress(searchTxtController.value.text);
  }

  Future<void> fetchAddress(String text) async {
    log(":: fetchAddress :: $text");
    if (text.trim().isEmpty || text.trim().length < 2) {
      suggestionsList.value = [];
      return;
    }
    try {
      final geocoding = YandexGeocodingService(apiKey: Constant.yandexGeocodeApiKey);
      final results = await geocoding.search(text.trim(), limit: 10);
      suggestionsList.value = results.map((r) {
        return SearchSuggestion(
          displayName: r.displayName,
          address: r.placemark?.formattedAddress ?? r.displayName,
          lat: r.latLng.latitude,
          lng: r.latLng.longitude,
        );
      }).toList();
    } catch (e) {
      log(e.toString());
      suggestionsList.value = [];
    }
  }
}
