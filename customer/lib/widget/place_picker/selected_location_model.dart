import 'package:customer/models/app_placemark.dart';
import 'package:customer/models/lat_lng.dart';

class SelectedLocationModel {
  AppPlacemark? address;
  LatLng? latLng;

  SelectedLocationModel({this.address, this.latLng});

  SelectedLocationModel.fromJson(Map<String, dynamic> json) {
    address = json['address'] as AppPlacemark?;
    latLng = json['latLng'] as LatLng?;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['address'] = address;
    data['latLng'] = latLng;
    return data;
  }
}
