import 'dart:convert';
import 'dart:developer';

import 'package:customer/models/app_placemark.dart';
import 'package:customer/models/lat_lng.dart';
import 'package:http/http.dart' as http;

/// Yandex Geocoder REST API: https://geocode-maps.yandex.ru/1.x/
/// Til: uz_UZ, qidiruv: faqat O'zbekiston.
class YandexGeocodingService {
  YandexGeocodingService({required this.apiKey});

  static const String _baseUrl = 'https://geocode-maps.yandex.ru/1.x/';
  /// O'zbekiston uchun til: o'zbekcha natijalar.
  static const String _lang = 'uz_UZ';
  /// O'zbekiston bbox: janubiy-g'arb ~ shimoliy-sharq (lon,lat~lon,lat)
  static const String _uzbekistanBbox = '56.0,37.0~73.2,45.6';
  final String apiKey;

  /// Reverse geocoding: (latitude, longitude) -> address (o'zbekcha/kirillcha).
  Future<AppPlacemark?> reverseGeocode(double lat, double lon) async {
    final url = Uri.parse(
      '$_baseUrl?apikey=$apiKey&geocode=$lon,$lat&format=json&lang=$_lang&results=1',
    );
    try {
      final response = await http.get(
        url,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'eMart/1.0',
        },
      );
      if (response.statusCode != 200) {
        log(
          '❌ [YandexGeocoder] reverseGeocode status=${response.statusCode} body=${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}',
        );
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseFirstPlacemark(data);
    } catch (e, st) {
      log('❌ [YandexGeocoder] reverseGeocode error: $e\n$st');
      return null;
    }
  }

  /// Reverse geocoding text fallback. Returns GeocoderMetaData.text/formatted.
  Future<String?> reverseGeocodeRawText(double lat, double lon) async {
    final url = Uri.parse(
      '$_baseUrl?apikey=$apiKey&geocode=$lon,$lat&format=json&lang=$_lang&results=1',
    );
    try {
      final response = await http.get(
        url,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'eMart/1.0',
        },
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final members = _getFeatureMembers(data);
      if (members.isEmpty) return null;
      final first = members.first;
      final meta =
          first['metaDataProperty']?['GeocoderMetaData'] as Map<String, dynamic>?;
      final address = meta?['Address'] as Map<String, dynamic>?;
      final formatted = address?['formatted']?.toString().trim();
      if (formatted != null && formatted.isNotEmpty) return formatted;
      final text = meta?['text']?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
      final name = first['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
      return null;
    } catch (e, st) {
      log('❌ [YandexGeocoder] reverseGeocodeRawText error: $e\n$st');
      return null;
    }
  }

  /// Reverse geocoding: returns formatted address string.
  Future<String> getAddressFromLatLng(double lat, double lon) async {
    final place = await reverseGeocode(lat, lon);
    if (place != null) return place.formattedAddress;
    return 'Manzil topilmadi';
  }

  /// Forward geocoding: faqat O'zbekiston ichidan qidiruv.
  Future<List<GeocodeResult>> search(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];
    final encoded = Uri.encodeComponent(query.trim());
    final url = Uri.parse(
      '$_baseUrl?apikey=$apiKey&geocode=$encoded&format=json&results=$limit&lang=$_lang&bbox=$_uzbekistanBbox',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseFeatureMembers(data);
    } catch (_) {
      return [];
    }
  }

  /// Forward: get first coordinate for an address (e.g. zip code).
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    final list = await search(address, limit: 1);
    if (list.isEmpty) return null;
    return list.first.latLng;
  }

  static AppPlacemark? _parseFirstPlacemark(Map<String, dynamic> data) {
    final members = _getFeatureMembers(data);
    if (members.isEmpty) return null;
    return _placemarkFromGeoObject(members.first);
  }

  static List<GeocodeResult> _parseFeatureMembers(Map<String, dynamic> data) {
    final members = _getFeatureMembers(data);
    return members.map((m) => _toGeocodeResult(m)).whereType<GeocodeResult>().toList();
  }

  static List<Map<String, dynamic>> _getFeatureMembers(Map<String, dynamic> data) {
    try {
      final collection = data['response']?['GeoObjectCollection'];
      if (collection == null) return [];
      final list = collection['featureMember'] as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => e as Map<String, dynamic>)
          .map((e) => e['GeoObject'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static AppPlacemark? _placemarkFromGeoObject(Map<String, dynamic> geo) {
    try {
      final meta = geo['metaDataProperty']?['GeocoderMetaData'] as Map<String, dynamic>?;
      final address = meta?['Address'] as Map<String, dynamic>?;
      final formattedFromText = (meta?['text'] as String?)?.trim();
      final geoName = (geo['name'] as String?)?.trim();
      final geoDescription = (geo['description'] as String?)?.trim();
      final formattedFromAddress = (address?['formatted'] as String?)?.trim();
      final formatted = [
        formattedFromAddress,
        formattedFromText,
        if (geoName != null && geoDescription != null && geoName.isNotEmpty && geoDescription.isNotEmpty)
          '$geoDescription, $geoName'
        else
          null,
        geoName,
      ].whereType<String>().firstWhere(
            (e) => e.isNotEmpty,
            orElse: () => '',
          );
      if (formatted.isEmpty) return null;

      final components = address?['Components'] as List<dynamic>? ?? [];
      String? street, locality, administrativeArea, country, postalCode, subLocality;

      for (final c in components) {
        final map = c as Map<String, dynamic>?;
        if (map == null) continue;
        final kind = (map['kind'] as String?)?.toLowerCase();
        final name = map['name'] as String?;
        if (name == null || name.isEmpty) continue;
        switch (kind) {
          case 'street':
            street = name;
            break;
          case 'locality':
            locality = name;
            break;
          case 'province':
          case 'area':
            administrativeArea = name;
            break;
          case 'country':
            country = name;
            break;
          case 'postal_code':
            postalCode = name;
            break;
          case 'district':
          case 'dependent_locality':
            subLocality = name;
            break;
        }
      }

      return AppPlacemark(
        name: formatted,
        street: street,
        locality: locality,
        administrativeArea: administrativeArea,
        country: country,
        postalCode: postalCode,
        subLocality: subLocality,
      );
    } catch (_) {
      return null;
    }
  }

  static GeocodeResult? _toGeocodeResult(Map<String, dynamic> geo) {
    try {
      final point = geo['Point'] as Map<String, dynamic>?;
      final pos = point?['pos'] as String?;
      if (pos == null) return null;
      final parts = pos.split(RegExp(r'\s+'));
      if (parts.length < 2) return null;
      final lon = double.tryParse(parts[0]);
      final lat = double.tryParse(parts[1]);
      if (lon == null || lat == null) return null;

      final meta = geo['metaDataProperty']?['GeocoderMetaData'] as Map<String, dynamic>?;
      final address = meta?['Address'] as Map<String, dynamic>?;
      final fromText = (meta?['text'] as String?)?.trim();
      final formatted =
          address?['formatted'] as String? ??
          (fromText?.isNotEmpty == true ? fromText : null) ??
          geo['name'] as String? ??
          '';

      return GeocodeResult(
        latLng: LatLng(lat, lon),
        displayName: formatted,
        placemark: _placemarkFromGeoObject(geo),
      );
    } catch (_) {
      return null;
    }
  }
}

class GeocodeResult {
  final LatLng latLng;
  final String displayName;
  final AppPlacemark? placemark;

  GeocodeResult({
    required this.latLng,
    required this.displayName,
    this.placemark,
  });
}
