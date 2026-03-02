import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:vendor/constant/constant.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/yandex_geocoding.dart';
import 'package:vendor/utils/yandex_map_utils.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart' as ym;

import 'place_model.dart';

class YandexMapPickerPage extends StatefulWidget {
  const YandexMapPickerPage({
    super.key,
    this.initialLocation,
    this.initialAddress,
  });

  final latlong.LatLng? initialLocation;
  final String? initialAddress;

  @override
  State<YandexMapPickerPage> createState() => _YandexMapPickerPageState();
}

class _YandexMapPickerPageState extends State<YandexMapPickerPage> {
  final TextEditingController searchController = TextEditingController();
  ym.YandexMapController? mapController;
  latlong.LatLng? selectedLocation;
  String selectedAddress = '';
  List<({double lat, double lng, String address})> searchResults = [];
  bool isSearching = false;
  Timer? _searchDebounce;
  bool _userLocationMoved = false;

  static const _uzBounds = ym.CameraBounds(
    minZoom: 6,
    maxZoom: 19,
    latLngBounds: ym.BoundingBox(
      southWest: ym.Point(latitude: Constant.uzSouth, longitude: Constant.uzWest),
      northEast: ym.Point(latitude: Constant.uzNorth, longitude: Constant.uzEast),
    ),
  );

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
      final address = await getAddressFromCoordinatesYandex(
        point.latitude,
        point.longitude,
      );
      if (address.isNotEmpty && mounted) {
        setState(() => selectedAddress = address);
      }
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => isSearching = true);
      try {
        final results = await getSearchResultsYandex(query);
        if (mounted) {
          setState(() {
            searchResults = results;
            isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => isSearching = false);
      }
    });
  }

  Future<void> _onSearchResultTap(({double lat, double lng, String address}) result) async {
    searchController.text = result.address;
    setState(() {
      searchResults = [];
      selectedLocation = latlong.LatLng(result.lat, result.lng);
      selectedAddress = result.address;
    });
    await _moveTo(selectedLocation!, zoom: 16);
  }

  Future<void> _moveToUserLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final target = latlong.LatLng(pos.latitude, pos.longitude);
      await _moveTo(target, zoom: 15);
      await _updateAddress(target);
      if (mounted) setState(() => selectedLocation = target);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      selectedLocation = widget.initialLocation;
      selectedAddress = widget.initialAddress ?? '';
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    final searchBg = isDark ? AppThemeData.greyDark100 : AppThemeData.grey50;
    final searchText = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
    final searchHint = isDark ? AppThemeData.greyDark400 : AppThemeData.grey400;
    final searchIcon = isDark ? AppThemeData.greyDark500 : AppThemeData.grey500;

    return Scaffold(
      appBar: AppBar(
        title: Text('Lokatsiyani tanlash'.tr),
      ),
      body: Stack(
        children: [
          ym.YandexMap(
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            cameraBounds: _uzBounds,
            onMapCreated: (controller) async {
              mapController = controller;
              await controller.toggleUserLayer(visible: true);
              if (selectedLocation != null) {
                await _moveTo(selectedLocation!, zoom: 15);
              } else {
                await _moveTo(
                  latlong.LatLng(Constant.uzCenterLat, Constant.uzCenterLng),
                  zoom: 10,
                );
                if (!_userLocationMoved) {
                  _userLocationMoved = true;
                  Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.medium,
                  ).then((pos) {
                    final target = latlong.LatLng(pos.latitude, pos.longitude);
                    _moveTo(target, zoom: 14);
                  }).catchError((_) {});
                }
              }
            },
            onMapTap: (point) async {
              final tapped = latlong.LatLng(point.latitude, point.longitude);
              setState(() => selectedLocation = tapped);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  color: searchBg,
                  child: TextField(
                    controller: searchController,
                    style: TextStyle(color: searchText, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Manzil qidirish (O\'zbekiston)...'.tr,
                      hintStyle: TextStyle(color: searchHint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                      prefixIcon: Icon(Icons.search, color: searchIcon),
                      suffixIcon: isSearching
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: searchIcon,
                                ),
                              ),
                            )
                          : null,
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (q) {
                      if (q.trim().isEmpty) return;
                      getSearchResultsYandex(q).then((results) {
                        if (mounted && results.isNotEmpty) {
                          _onSearchResultTap(results.first);
                        }
                      });
                    },
                  ),
                ),
                if (searchResults.isNotEmpty)
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    color: searchBg,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, i) {
                          final r = searchResults[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(Icons.place, size: 20, color: searchIcon),
                            title: Text(
                              r.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: searchText),
                            ),
                            onTap: () => _onSearchResultTap(r),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    mapController?.moveCamera(ym.CameraUpdate.zoomIn());
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    mapController?.moveCamera(ym.CameraUpdate.zoomOut());
                  },
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'my_location',
                  onPressed: _moveToUserLocation,
                  child: const Icon(Icons.my_location),
                ),
              ],
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
                    ? 'Lokatsiyani tasdiqlash'.tr
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
