import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

ym.PlacemarkIcon _defaultPlacemarkIcon(String assetName) {
  return ym.PlacemarkIcon.single(
    ym.PlacemarkIconStyle(
      image: ym.BitmapDescriptor.fromAssetImage(assetName),
      anchor: const Offset(0.5, 1.0),
      scale: 1.0,
    ),
  );
}

ym.PlacemarkIcon yandexPlacemarkIconFromAsset(
  String assetName, {
  Offset anchor = const Offset(0.5, 1.0),
  double scale = 1.0,
}) {
  return ym.PlacemarkIcon.single(
    ym.PlacemarkIconStyle(
      image: ym.BitmapDescriptor.fromAssetImage(assetName),
      anchor: anchor,
      scale: scale,
    ),
  );
}

ym.PlacemarkIcon _iconForMarker(gmap.Marker marker) {
  final id = marker.markerId.value.toLowerCase();
  String assetName;
  if (id == 'departure' || id == 'pickup' || id == 'source') {
    assetName = 'assets/images/ic_logo.png';
  } else if (id == 'destination' || id == 'dropoff' || id == 'dest') {
    assetName = 'assets/images/ic_logo.png';
  } else if (id.contains('driver') || id.contains('taxi')) {
    assetName = 'assets/images/ic_logo.png';
  } else if (id.startsWith('stop')) {
    assetName = 'assets/images/ic_logo.png';
  } else {
    assetName = 'assets/images/ic_logo.png';
  }
  return _defaultPlacemarkIcon(assetName);
}

ym.Point yandexPointFromLatLng(gmap.LatLng latLng) {
  return ym.Point(latitude: latLng.latitude, longitude: latLng.longitude);
}

List<ym.MapObject> yandexMapObjectsFromGoogle({
  Iterable<gmap.Marker> markers = const [],
}) {
  final mapObjects = <ym.MapObject>[];
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
        zIndex: 1,
      ),
    );
  }
  return mapObjects;
}
