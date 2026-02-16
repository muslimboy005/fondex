import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;
import 'package:driver/constant/constant.dart';

/// Marker hajmi (0.22 = kichik)
const double _markerScale = 0.15;

ym.PlacemarkIcon _defaultPlacemarkIcon(String assetName) {
  return ym.PlacemarkIcon.single(
    ym.PlacemarkIconStyle(
      image: ym.BitmapDescriptor.fromAssetImage(assetName),
      anchor: const Offset(0.5, 1.0),
      scale: assetName == 'assets/icons/ic_cab.png'
          ? 1.0
          : assetName == 'assets/images/food_delivery.png'
              ? 0.65
              : _markerScale,
    ),
  );
}

ym.PlacemarkIcon yandexPlacemarkIconFromAsset(
  String assetName, {
  Offset anchor = const Offset(0.5, 1.0),
  double scale = _markerScale,
}) {
  return ym.PlacemarkIcon.single(
    ym.PlacemarkIconStyle(
      image: ym.BitmapDescriptor.fromAssetImage(assetName),
      anchor: anchor,
      scale: scale,
    ),
  );
}

String _driverAssetForServiceType() {
  final serviceType =
      Constant.userModel?.serviceType?.toLowerCase().trim() ?? '';
  if (serviceType == 'delivery-service' || serviceType == 'parcel_delivery') {
    return 'assets/images/food_delivery.png';
  }
  return 'assets/icons/ic_cab.png';
}

ym.PlacemarkIcon _iconForMarker(gmap.Marker marker) {
  final id = marker.markerId.value.toLowerCase();
  String assetName;
  if (id == 'departure' || id == 'pickup' || id == 'source') {
    assetName = 'assets/icons/ic_cab_pickup.png';
  } else if (id == 'destination' || id == 'dropoff' || id == 'dest') {
    assetName = 'assets/icons/ic_cab_destination.png';
  } else if (id.contains('driver') || id.contains('taxi')) {
    assetName = _driverAssetForServiceType();
  } else if (id.startsWith('stop')) {
    assetName = 'assets/icons/ic_cab_pickup.png';
  } else {
    assetName = 'assets/icons/ic_cab_pickup.png';
  }
  return _defaultPlacemarkIcon(assetName);
}

ym.Point yandexPointFromLatLng(gmap.LatLng latLng) {
  return ym.Point(latitude: latLng.latitude, longitude: latLng.longitude);
}

ym.BoundingBox yandexBoundsFromLatLngs(List<gmap.LatLng> points) {
  double? minLat;
  double? maxLat;
  double? minLng;
  double? maxLng;

  for (final point in points) {
    minLat = minLat == null
        ? point.latitude
        : (point.latitude < minLat ? point.latitude : minLat);
    maxLat = maxLat == null
        ? point.latitude
        : (point.latitude > maxLat ? point.latitude : maxLat);
    minLng = minLng == null
        ? point.longitude
        : (point.longitude < minLng ? point.longitude : minLng);
    maxLng = maxLng == null
        ? point.longitude
        : (point.longitude > maxLng ? point.longitude : maxLng);
  }

  return ym.BoundingBox(
    northEast: ym.Point(latitude: maxLat ?? 0.0, longitude: maxLng ?? 0.0),
    southWest: ym.Point(latitude: minLat ?? 0.0, longitude: minLng ?? 0.0),
  );
}

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
              .map((point) => ym.Point(
                  latitude: point.latitude, longitude: point.longitude))
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
