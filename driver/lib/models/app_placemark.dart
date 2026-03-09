import 'package:driver/utils/uzbek_transliteration.dart';

/// App-level placemark for address (replaces geocoding.Placemark).
/// Manzillar lotin o'zbekchada (Yandex kirill javobini lotinga o'giramiz).
class AppPlacemark {
  final String? name;
  final String? street;
  final String? locality;
  final String? administrativeArea;
  final String? country;
  final String? postalCode;
  final String? subLocality;

  const AppPlacemark({
    this.name,
    this.street,
    this.locality,
    this.administrativeArea,
    this.country,
    this.postalCode,
    this.subLocality,
  });

  /// Single-line formatted address in Latin Uzbek (street, locality, area, country).
  String get formattedAddress {
    final parts = <String>[
      if (street != null && street!.isNotEmpty) street!,
      if (locality != null && locality!.isNotEmpty) locality!,
      if (administrativeArea != null && administrativeArea!.isNotEmpty)
        administrativeArea!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    final raw = parts.isEmpty ? 'Unknown location' : parts.join(', ');
    return cyrillicToLatinUzbek(raw);
  }
}
