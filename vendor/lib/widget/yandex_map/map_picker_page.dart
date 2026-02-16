import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;
import '../osm_map/place_model.dart';
import 'package:vendor/utils/yandex_map_utils.dart';

class YandexMapPickerPage extends StatefulWidget {
  const YandexMapPickerPage({super.key});

  @override
  State<YandexMapPickerPage> createState() => _YandexMapPickerPageState();
}

class _YandexMapPickerPageState extends State<YandexMapPickerPage> {
  final TextEditingController searchController = TextEditingController();
  ym.YandexMapController? mapController;
  latlong.LatLng? selectedLocation;
  String selectedAddress = '';

  Future<void> _moveTo(latlong.LatLng target, {double zoom = 15}) async {
    if (mapController == null) return;
    await mapController!.moveCamera(
      ym.CameraUpdate.newCameraPosition(
        ym.CameraPosition(
          target: ym.Point(latitude: target.latitude, longitude: target.longitude),
          zoom: zoom,
        ),
      ),
    );
  }

  Future<void> _updateAddress(latlong.LatLng point) async {
    try {
      final placemarks =
          await placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          selectedAddress =
              "${place.street ?? ''} ${place.locality ?? ''} ${place.administrativeArea ?? ''} ${place.country ?? ''}"
                  .trim();
        });
      }
    } catch (_) {}
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;
    try {
      final results = await locationFromAddress(query);
      if (results.isEmpty) return;
      final location = results.first;
      final target = latlong.LatLng(location.latitude, location.longitude);
      setState(() {
        selectedLocation = target;
      });
      await _moveTo(target);
      await _updateAddress(target);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
      ),
      body: Stack(
        children: [
          ym.YandexMap(
            onMapCreated: (controller) async {
              mapController = controller;
              await controller.toggleUserLayer(visible: true);
              if (selectedLocation != null) {
                await _moveTo(selectedLocation!);
              }
            },
            onMapTap: (point) async {
              final tapped =
                  latlong.LatLng(point.latitude, point.longitude);
              setState(() {
                selectedLocation = tapped;
              });
              await _updateAddress(tapped);
            },
            mapObjects: selectedLocation == null
                ? const []
                : [
                    ym.PlacemarkMapObject(
                      mapId: const ym.MapObjectId('selected_location'),
                      point: ym.Point(
                        latitude: selectedLocation!.latitude,
                        longitude: selectedLocation!.longitude,
                      ),
                      icon: yandexPlacemarkIconFromAsset(
                        'assets/images/ic_logo.png',
                      ),
                      opacity: 1.0,
                    ),
                  ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  hintText: 'Search location...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: _searchAddress,
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: selectedLocation == null
                  ? null
                  : () {
                      final place = PlaceModel(
                        coordinates: selectedLocation!,
                        address: selectedAddress,
                      );
                      Get.back(result: place);
                    },
              child: Text(
                selectedAddress.isEmpty
                    ? 'Confirm location'
                    : selectedAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
