import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

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

ym.Point yandexPointFromLatLng(double latitude, double longitude) {
  return ym.Point(latitude: latitude, longitude: longitude);
}
