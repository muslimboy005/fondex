import 'dart:convert';
import 'dart:developer' as dev;

import 'package:vendor/constant/constant.dart';
import 'package:http/http.dart' as http;

/// Yandex Geocoder REST API orqali geocoding (Google/Apple geocoding o‘rniga).
/// Reverse: koordinata → manzil. Forward: manzil matni → koordinata.

const String _uzManzilTopilmadi = 'Manzil topilmadi';
const String _logTag = '[YandexGeocoder]';

/// Yandex Geocoder API (geocode-maps.yandex.ru) uchun kalit – doim shu ishlatiladi.
String _getGeocoderApiKey() => Constant.yandexGeocoderApiKey;

/// O'zbekiston bbox (lon,lat ~ lon,lat) – faqat UZ ichida qidirish uchun rspn=1 bilan.
const String _uzBbox = '56.0,37.0~73.5,45.6';

String _geocoderUrl(String query, {bool reverse = false, bool restrictToUz = false}) {
  final key = _getGeocoderApiKey();
  if (key.isEmpty) return '';
  final geocode = reverse ? '$query' : Uri.encodeComponent(query);
  var url = 'https://geocode-maps.yandex.ru/1.x/?apikey=${Uri.encodeComponent(key)}'
      '&geocode=$geocode&format=json&lang=uz_UZ&results=5';
  if (!reverse && restrictToUz) {
    url += '&bbox=$_uzBbox&rspn=1';
  }
  return url;
}

/// Reverse: lat,lng → to‘liq manzil (Yandex, o‘zbekcha).
Future<String> getAddressFromCoordinatesYandex(double lat, double lng) async {
  dev.log('$_logTag [REVERSE] So‘rov boshlandi: lat=$lat lng=$lng');
  final key = _getGeocoderApiKey();
  if (key.isEmpty) {
    dev.log('$_logTag [REVERSE] API key bo‘sh – yandexGeocoderApiKey yoki mapAPIKey tekshiring');
    return _uzManzilTopilmadi;
  }
  dev.log('$_logTag [REVERSE] Yandex API ga zapros yuborilmoqda (geocode=$lng,$lat)...');
  try {
    final url = _geocoderUrl('$lng,$lat', reverse: true);
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    dev.log('$_logTag [REVERSE] Javob: statusCode=${r.statusCode} bodyLength=${r.body.length}');
    if (r.statusCode != 200) {
      dev.log('$_logTag [REVERSE] Xato: statusCode != 200. body(200): ${r.body.length > 200 ? r.body.substring(0, 200) + "..." : r.body}');
      return _uzManzilTopilmadi;
    }
    final json = jsonDecode(r.body);
    if (json is! Map<String, dynamic>) {
      dev.log('$_logTag [REVERSE] Javob JSON object emas');
      return _uzManzilTopilmadi;
    }
    final address = _parseReverseAddress(json);
    if (address != null && address.isNotEmpty) {
      dev.log('$_logTag [REVERSE] Manzil topildi: $address');
      return address;
    }
    dev.log('$_logTag [REVERSE] Javobda manzil yo‘q yoki parse xato. body(300): ${r.body.length > 300 ? r.body.substring(0, 300) + "..." : r.body}');
    return _uzManzilTopilmadi;
  } catch (e, st) {
    dev.log('$_logTag [REVERSE] Exception: $e', stackTrace: st);
    return _uzManzilTopilmadi;
  }
}

String? _parseReverseAddress(Map<String, dynamic> json) {
  try {
    final response = json['response'];
    if (response == null || response is! Map<String, dynamic>) {
      dev.log('$_logTag [REVERSE parse] response yo‘q yoki Map emas');
      return null;
    }
    final collection = response['GeoObjectCollection'];
    if (collection == null || collection is! Map<String, dynamic>) {
      dev.log('$_logTag [REVERSE parse] GeoObjectCollection yo‘q');
      return null;
    }
    final members = collection['featureMember'];
    if (members == null || members is! List || members.isEmpty) {
      dev.log('$_logTag [REVERSE parse] featureMember bo‘sh (length=${members is List ? members.length : 0})');
      return null;
    }
    final first = members[0];
    if (first is! Map<String, dynamic>) return null;
    final geoObject = first['GeoObject'];
    if (geoObject == null || geoObject is! Map<String, dynamic>) return null;
    final meta = geoObject['metaDataProperty'];
    if (meta == null || meta is! Map<String, dynamic>) return null;
    final geocoderMeta = meta['GeocoderMetaData'];
    if (geocoderMeta == null || geocoderMeta is! Map<String, dynamic>) return null;
    final text = geocoderMeta['text'];
    if (text is String && text.isNotEmpty) return text;
    final addr = geocoderMeta['Address'];
    if (addr != null && addr is Map<String, dynamic>) {
      final formatted = addr['formatted'];
      if (formatted is String && formatted.isNotEmpty) return formatted;
    }
    final name = geoObject['name'];
    return name is String ? name : null;
  } catch (_) {
    return null;
  }
}

/// Forward: manzil matni → barcha natijalar (faqat O'zbekiston). Ro'yxat bo'sh bo'lishi mumkin.
Future<List<({double lat, double lng, String address})>> getSearchResultsYandex(String address) async {
  final query = address.trim();
  if (query.isEmpty) return [];
  final key = _getGeocoderApiKey();
  if (key.isEmpty) return [];
  try {
    final url = _geocoderUrl(query, restrictToUz: true).replaceFirst('results=5', 'results=10');
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return [];
    final json = jsonDecode(r.body);
    if (json is! Map<String, dynamic>) return [];
    return _parseForwardAllResults(json);
  } catch (e, st) {
    dev.log('$_logTag [SEARCH] Exception: $e', stackTrace: st);
    return [];
  }
}

List<({double lat, double lng, String address})> _parseForwardAllResults(Map<String, dynamic> json) {
  final list = <({double lat, double lng, String address})>[];
  try {
    final response = json['response'];
    if (response == null || response is! Map<String, dynamic>) return list;
    final collection = response['GeoObjectCollection'];
    if (collection == null || collection is! Map<String, dynamic>) return list;
    final members = collection['featureMember'];
    if (members == null || members is! List) return list;
    for (final m in members) {
      if (m is! Map<String, dynamic>) continue;
      final geoObject = m['GeoObject'];
      if (geoObject == null || geoObject is! Map<String, dynamic>) continue;
      final point = geoObject['Point'];
      if (point == null || point is! Map<String, dynamic>) continue;
      final pos = point['pos'];
      if (pos is! String) continue;
      final parts = pos.split(' ');
      if (parts.length != 2) continue;
      final lng = double.tryParse(parts[0]);
      final lat = double.tryParse(parts[1]);
      if (lat == null || lng == null) continue;
      String address = '';
      final meta = geoObject['metaDataProperty'];
      if (meta is Map<String, dynamic>) {
        final geocoderMeta = meta['GeocoderMetaData'];
        if (geocoderMeta is Map<String, dynamic>) {
          final text = geocoderMeta['text'];
          if (text is String) address = text;
          if (address.isEmpty && geocoderMeta['Address'] is Map<String, dynamic>) {
            final formatted = (geocoderMeta['Address'] as Map<String, dynamic>)['formatted'];
            if (formatted is String) address = formatted;
          }
        }
      }
      if (address.isEmpty) address = geoObject['name'] is String ? geoObject['name'] as String : '';
      list.add((lat: lat, lng: lng, address: address));
    }
  } catch (_) {}
  return list;
}

/// Forward: manzil matni → birinchi natija (lat, lng). Topilmasa null. Faqat O'zbekiston.
Future<({double lat, double lng})?> getLocationFromAddressYandex(String address) async {
  final query = address.trim();
  dev.log('$_logTag [FORWARD] So‘rov boshlandi: query="$query"');
  final key = _getGeocoderApiKey();
  if (key.isEmpty) {
    dev.log('$_logTag [FORWARD] API key bo‘sh – yandexGeocoderApiKey yoki mapAPIKey tekshiring');
    return null;
  }
  if (query.isEmpty) {
    dev.log('$_logTag [FORWARD] Query bo‘sh');
    return null;
  }
  dev.log('$_logTag [FORWARD] Yandex API ga zapros yuborilmoqda (faqat O\'zbekiston)...');
  try {
    final url = _geocoderUrl(query, restrictToUz: true);
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    dev.log('$_logTag [FORWARD] Javob: statusCode=${r.statusCode} bodyLength=${r.body.length}');
    if (r.statusCode != 200) {
      dev.log('$_logTag [FORWARD] Xato: statusCode != 200. body(200): ${r.body.length > 200 ? r.body.substring(0, 200) + "..." : r.body}');
      return null;
    }
    final json = jsonDecode(r.body);
    if (json is! Map<String, dynamic>) {
      dev.log('$_logTag [FORWARD] Javob JSON object emas');
      return null;
    }
    final result = _parseForwardCoordinates(json);
    if (result != null) {
      dev.log('$_logTag [FORWARD] Koordinata topildi: lat=${result.lat} lng=${result.lng}');
    } else {
      dev.log('$_logTag [FORWARD] Javobda koordinata yo‘q yoki parse xato. body(300): ${r.body.length > 300 ? r.body.substring(0, 300) + "..." : r.body}');
    }
    return result;
  } catch (e, st) {
    dev.log('$_logTag [FORWARD] Exception: $e', stackTrace: st);
    return null;
  }
}

({double lat, double lng})? _parseForwardCoordinates(Map<String, dynamic> json) {
  try {
    final response = json['response'];
    if (response == null || response is! Map<String, dynamic>) return null;
    final collection = response['GeoObjectCollection'];
    if (collection == null || collection is! Map<String, dynamic>) return null;
    final members = collection['featureMember'];
    if (members == null || members is! List || members.isEmpty) return null;
    final first = members[0];
    if (first is! Map<String, dynamic>) return null;
    final geoObject = first['GeoObject'];
    if (geoObject == null || geoObject is! Map<String, dynamic>) return null;
    final point = geoObject['Point'];
    if (point == null || point is! Map<String, dynamic>) return null;
    final pos = point['pos'];
    if (pos is! String) return null;
    final parts = pos.split(' ');
    if (parts.length != 2) return null;
    final lng = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  } catch (_) {
    return null;
  }
}
