import 'dart:convert';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/lat_lng.dart';
import 'package:customer/models/rating_model.dart';
import 'package:customer/utils/yandex_map_utils.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../models/cab_order_model.dart';
import '../models/user_model.dart';
import '../service/fire_store_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CabOrderDetailsController extends GetxController {
  Rx<CabOrderModel> cabOrder = CabOrderModel().obs;

  RxBool isLoading = false.obs;

  RxList<YandexMarkerInput> yandexMarkers = <YandexMarkerInput>[].obs;
  RxList<LatLng> polylinePoints = <LatLng>[].obs;

  final Rx<UserModel> driverUser = UserModel().obs;
  Rx<RatingModel> ratingModel = RatingModel().obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null) {
      cabOrder.value = args['cabOrderModel'] as CabOrderModel;
      calculateTotalAmount();
      _setMarkers();
      _getRoute();
    }
    fetchDriverDetails();
  }

  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }

  Future<void> fetchDriverDetails() async {
    if (cabOrder.value.driverId != null) {
      await FireStoreUtils.getUserProfile(cabOrder.value.driverId ?? '').then((value) {
        if (value != null) driverUser.value = value;
      });
      await FireStoreUtils.getReviewsbyID(cabOrder.value.id.toString()).then((value) {
        if (value != null) ratingModel.value = value;
      });
    }
  }

  void calculateTotalAmount() {
    taxAmount = 0.0.obs;
    discount = 0.0.obs;
    subTotal.value = double.parse(cabOrder.value.subTotal.toString());
    discount.value = double.parse(cabOrder.value.discount ?? '0.0');
    if (cabOrder.value.taxSetting != null) {
      for (var element in cabOrder.value.taxSetting!) {
        taxAmount.value += Constant.calculateTax(
          amount: (subTotal.value - discount.value).toString(),
          taxModel: element,
        );
      }
    }
    totalAmount.value = (subTotal.value - discount.value) + taxAmount.value;
    update();
  }

  void _setMarkers() {
    final sourceLat = cabOrder.value.sourceLocation!.latitude!;
    final sourceLng = cabOrder.value.sourceLocation!.longitude!;
    final destLat = cabOrder.value.destinationLocation!.latitude!;
    final destLng = cabOrder.value.destinationLocation!.longitude!;

    yandexMarkers.value = [
      YandexMarkerInput(id: 'source', latitude: sourceLat, longitude: sourceLng, assetIcon: 'assets/icons/ic_cab_pickup.png'),
      YandexMarkerInput(id: 'destination', latitude: destLat, longitude: destLng, assetIcon: 'assets/icons/ic_cab_destination.png'),
    ];
  }

  Future<void> _getRoute() async {
    final src = cabOrder.value.sourceLocation;
    final dest = cabOrder.value.destinationLocation;
    if (src == null || dest == null) return;

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${src.longitude},${src.latitude};${dest.longitude},${dest.latitude}?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data["routes"] != null && (data["routes"] as List).isNotEmpty) {
        final geometry = data["routes"][0]["geometry"]["coordinates"] as List;
        polylinePoints.value = geometry
            .map((coord) => LatLng(
                  (coord[1] as num).toDouble(),
                  (coord[0] as num).toDouble(),
                ))
            .toList();
      }
    } catch (_) {}
  }
}
