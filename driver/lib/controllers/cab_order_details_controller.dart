import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import '../constant/constant.dart';
import '../constant/send_notification.dart';
import '../constant/show_toast_dialog.dart';
import '../models/cab_order_model.dart';
import '../models/user_model.dart';
import '../themes/app_them_data.dart';
import '../utils/fire_store_utils.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CabOrderDetailsController extends GetxController {
  Rx<CabOrderModel> cabOrder = CabOrderModel().obs;

  RxBool isLoading = false.obs;

  RxSet<gmap.Marker> googleMarkers = <gmap.Marker>{}.obs;
  RxSet<gmap.Polyline> googlePolylines = <gmap.Polyline>{}.obs;

  final Rx<UserModel?> driverUser = Rx<UserModel?>(null);

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
  }

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }

  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  RxDouble adminCommission = 0.0.obs;

  Future<void> fetchDriverDetails() async {
    if (cabOrder.value.driverId != null) {
      await FireStoreUtils.getUserProfile(cabOrder.value.driverId ?? '').then((value) {
        if (value != null) {
          driverUser.value = value;
        }
      });
    }
  }

  static double _safeFare(num? value, double def) {
    if (value == null) return def;
    final d = value.toDouble();
    return d.isNaN || d.isInfinite ? def : d;
  }

  void calculateTotalAmount() {
    taxAmount = 0.0.obs;
    discount = 0.0.obs;
    final rawSubTotal = double.parse(cabOrder.value.subTotal.toString());
    final minFare = _safeFare(cabOrder.value.vehicleType?.minimum_delivery_charges, 0.0);
    subTotal.value = rawSubTotal < minFare ? minFare : rawSubTotal;
    discount.value = double.parse(cabOrder.value.discount ?? '0.0');

    for (var element in cabOrder.value.taxSetting!) {
      taxAmount.value = (taxAmount.value + Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: element));
    }

    if (cabOrder.value.adminCommission!.isNotEmpty) {
      adminCommission.value = Constant.calculateAdminCommission(
          amount: (subTotal.value - discount.value).toString(),
          adminCommissionType: cabOrder.value.adminCommissionType.toString(),
          adminCommission: cabOrder.value.adminCommission ?? '0');
    }

    totalAmount.value = (subTotal.value - discount.value) + taxAmount.value;
    update();
  }

  void _setMarkers() {
    final sourceLat = cabOrder.value.sourceLocation!.latitude;
    final sourceLng = cabOrder.value.sourceLocation!.longitude;
    final destLat = cabOrder.value.destinationLocation!.latitude;
    final destLng = cabOrder.value.destinationLocation!.longitude;

    googleMarkers
      ..clear()
      ..addAll({
      gmap.Marker(
        markerId: const gmap.MarkerId('source'),
        position: gmap.LatLng(sourceLat!, sourceLng!),
        icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueGreen),
      ),
      gmap.Marker(
        markerId: const gmap.MarkerId('destination'),
        position: gmap.LatLng(destLat!, destLng!),
        icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueRed),
      ),
    });
  }

  /// Cancel an in-progress ride: mark Firestore doc as cancelled and notify
  /// the customer (FCM + remove from their inProgressOrderID).
  Future<void> cancelRide({String? reason}) async {
    ShowToastDialog.showLoader('Cancelling ride...'.tr);
    try {
      await FireStoreUtils.updateCabOrderCancel(
        orderId: cabOrder.value.id!,
        reason: reason,
      );
      cabOrder.value.status = Constant.orderCancelled;
      cabOrder.value.cancelReason = reason;
      cabOrder.refresh();

      // Also remove from current driver's inProgressOrderID so the home
      // controller can pick up new requests again.
      final driver = Constant.userModel;
      if (driver != null) {
        driver.inProgressOrderID?.remove(cabOrder.value.id);
        await FireStoreUtils.updateUser(driver);
      }

      final customerId = cabOrder.value.authorID;
      if (customerId != null && customerId.isNotEmpty) {
        final customer = await FireStoreUtils.getUserProfile(customerId);
        if (customer != null) {
          customer.inProgressOrderID?.remove(cabOrder.value.id);
          await FireStoreUtils.updateUser(customer);
          final token = customer.fcmToken;
          if (token != null && token.isNotEmpty) {
            await SendNotification.sendOneNotification(
              token: token,
              title: 'Cancelled Order'.tr,
              body: (reason == null || reason.isEmpty)
                  ? 'Your ride was cancelled by the driver.'.tr
                  : reason,
              payload: {'orderId': cabOrder.value.id ?? ''},
            );
          }
        }
      }

      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast('Order cancelled successfully'.tr);
      Get.back(result: true);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(e.toString());
    }
  }

  /// Route polyline (OSRM) - Yandex only flow.
  Future<void> _getRoute() async {
    final src = cabOrder.value.sourceLocation;
    final dest = cabOrder.value.destinationLocation;
    if (src == null || dest == null) return;
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${src.longitude},${src.latitude};${dest.longitude},${dest.latitude}?overview=full&geometries=geojson',
    );
    final response = await http.get(url);
    final data = jsonDecode(response.body);

    if (data["routes"] is List && (data["routes"] as List).isNotEmpty) {
      final geometry = data["routes"][0]["geometry"]["coordinates"] as List;
      final polylineCoords = geometry
          .map((coord) => gmap.LatLng(
                (coord[1] as num).toDouble(),
                (coord[0] as num).toDouble(),
              ))
          .toList();
      googlePolylines
        ..clear()
        ..addAll({
        gmap.Polyline(
          polylineId: const gmap.PolylineId("route"),
          color: AppThemeData.onDemandDark100,
          width: 5,
          points: polylineCoords,
        )
      });
    }
  }

}
