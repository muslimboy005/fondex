import 'package:customer/models/lat_lng.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

ym.PlacemarkIcon _defaultPlacemarkIcon(String assetName) {
  return ym.PlacemarkIcon.single(
    ym.PlacemarkIconStyle(
      image: ym.BitmapDescriptor.fromAssetImage(assetName),
      anchor: const Offset(0.5, 1.0),
      scale: 0.28,
    ),
  );
}

ym.PlacemarkIcon yandexPlacemarkIconFromAsset(
  String assetName, {
  Offset anchor = const Offset(0.5, 1.0),
  double scale = 0.18,
}) {
  return ym.PlacemarkIcon.single(
    ym.PlacemarkIconStyle(
      image: ym.BitmapDescriptor.fromAssetImage(assetName),
      anchor: anchor,
      scale: scale,
    ),
  );
}

/// Input for a single placemark (replaces Google Marker).
class YandexMarkerInput {
  final String id;
  final double latitude;
  final double longitude;
  final String? title;
  final String? assetIcon;
  final VoidCallback? onTap;

  const YandexMarkerInput({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.title,
    this.assetIcon,
    this.onTap,
  });
}

ym.PlacemarkIcon _iconForMarkerId(String id, [String? assetIcon]) {
  final path = assetIcon ?? _defaultAssetForMarkerId(id);
  return _defaultPlacemarkIcon(path);
}

String _defaultAssetForMarkerId(String id) {
  final lower = id.toLowerCase();
  if (lower == 'departure' || lower == 'pickup' || lower == 'source') {
    return 'assets/icons/ic_cab_pickup.png';
  }
  if (lower == 'destination' || lower == 'dropoff' || lower == 'dest') {
    return 'assets/icons/ic_cab_destination.png';
  }
  if (lower.contains('driver') || lower.contains('taxi')) {
    return 'assets/icons/ic_taxi.png';
  }
  if (lower.startsWith('stop')) {
    return 'assets/icons/ic_location.png';
  }
  return 'assets/images/map_selected.png';
}

ym.PlacemarkIcon _iconForMarker(gmap.Marker marker) {
  final id = marker.markerId.value.toLowerCase();
  return _defaultPlacemarkIcon(_defaultAssetForMarkerId(id));
}

ym.Point yandexPointFromLatLng(LatLng latLng) {
  return ym.Point(latitude: latLng.latitude, longitude: latLng.longitude);
}

/// Build Yandex map objects from Google Marker and Polyline sets (for cab/live_tracking).
List<ym.MapObject> yandexMapObjectsFromGoogle({
  Iterable<gmap.Marker> markers = const [],
  Iterable<gmap.Polyline> polylines = const [],
}) {
  final mapObjects = <ym.MapObject>[];
  for (final polyline in polylines) {
    mapObjects.add(
      ym.PolylineMapObject(
        mapId: ym.MapObjectId('polyline_${polyline.polylineId.value}'),
        polyline: ym.Polyline(
          points: polyline.points
              .map((point) => ym.Point(latitude: point.latitude, longitude: point.longitude))
              .toList(),
        ),
        strokeColor: polyline.color,
        strokeWidth: polyline.width.toDouble(),
        zIndex: 1,
      ),
    );
  }
  for (final marker in markers) {
    mapObjects.add(
      ym.PlacemarkMapObject(
        mapId: ym.MapObjectId('marker_${marker.markerId.value}'),
        point: ym.Point(
          latitude: marker.position.latitude,
          longitude: marker.position.longitude,
        ),
        icon: _iconForMarker(marker),
        opacity: 1.0,
        consumeTapEvents: true,
        onTap: (_, __) {
          marker.onTap?.call();
          marker.infoWindow.onTap?.call();
        },
        zIndex: 2,
      ),
    );
  }
  return mapObjects;
}

ym.BoundingBox yandexBoundsFromLatLngs(List<LatLng> points) {
  double? minLat, maxLat, minLng, maxLng;
  for (final point in points) {
    minLat = minLat == null ? point.latitude : (point.latitude < minLat ? point.latitude : minLat);
    maxLat = maxLat == null ? point.latitude : (point.latitude > maxLat ? point.latitude : maxLat);
    minLng = minLng == null ? point.longitude : (point.longitude < minLng ? point.longitude : minLng);
    maxLng = maxLng == null ? point.longitude : (point.longitude > maxLng ? point.longitude : maxLng);
  }
  return ym.BoundingBox(
    northEast: ym.Point(latitude: maxLat ?? 0.0, longitude: maxLng ?? 0.0),
    southWest: ym.Point(latitude: minLat ?? 0.0, longitude: minLng ?? 0.0),
  );
}

List<ym.MapObject> yandexMapObjectsFromMarkers({
  List<YandexMarkerInput> markers = const [],
  List<LatLng> polylinePoints = const [],
  Color polylineColor = const Color(0xFF0066FF),
  double polylineWidth = 4.0,
}) {
  final mapObjects = <ym.MapObject>[];

  if (polylinePoints.length >= 2) {
    mapObjects.add(
      ym.PolylineMapObject(
        mapId: const ym.MapObjectId('polyline_route'),
        polyline: ym.Polyline(
          points: polylinePoints.map((p) => ym.Point(latitude: p.latitude, longitude: p.longitude)).toList(),
        ),
        strokeColor: polylineColor,
        strokeWidth: polylineWidth,
        zIndex: 1,
      ),
    );
  }

  for (final m in markers) {
    final onTap = m.onTap;
    mapObjects.add(
      ym.PlacemarkMapObject(
        mapId: ym.MapObjectId('marker_${m.id}'),
        point: ym.Point(latitude: m.latitude, longitude: m.longitude),
        icon: _iconForMarkerId(m.id, m.assetIcon),
        opacity: 1.0,
        consumeTapEvents: true,
        onTap: (_, __) => onTap?.call(),
        zIndex: 2,
      ),
    );
  }

  return mapObjects;
}
