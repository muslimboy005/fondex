/// App-level LatLng (replaces google_maps_flutter.LatLng / latlong2.LatLng).
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
