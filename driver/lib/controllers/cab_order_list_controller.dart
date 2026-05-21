import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/cab_order_model.dart';
import '../utils/fire_store_utils.dart';

class CabOrderListController extends GetxController {
  RxBool isLoading = true.obs;
  RxString selectedTab = "on_going".obs;
  RxList<CabOrderModel> cabOrder = <CabOrderModel>[].obs;

  RxList<String> tabTitles = ["on_going", "completed", "cancelled"].obs;

  RxString driverId = ''.obs;
  StreamSubscription<List<CabOrderModel>>? _cabOrdersSubscription;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    driverId.value = args?['driverId'] ?? FireStoreUtils.getCurrentUid();
    fetchCabOrders();
  }

  @override
  void onClose() {
    _cabOrdersSubscription?.cancel();
    super.onClose();
  }

  void selectTab(String tab) {
    selectedTab.value = tab;
    fetchCabOrders();
  }

  void fetchCabOrders() {
    isLoading.value = true;
    _cabOrdersSubscription?.cancel();
    _cabOrdersSubscription =
        FireStoreUtils.getCabDriverOrders(driverId.value).listen((orders) {
      print("cabOrder length ::::::${cabOrder.length}");
      cabOrder.value = orders;
      isLoading.value = false;
    }, onError: (error) {
      print("getCabDriverOrders() stream error: $error");
      cabOrder.clear();
      isLoading.value = false;
    });
  }

  /// Return filtered list for a specific tab title
  List<CabOrderModel> getOrdersForTab(String tab) {
    switch (tab) {
      case "on_going":
        return cabOrder
            .where((order) => [
                  "Order Placed",
                  "Order Accepted",
                  "Driver Accepted",
                  "Driver Pending",
                  "Order Shipped",
                  "In Transit"
                ].contains(order.status))
            .toList();

      case "completed":
        return cabOrder
            .where((order) => ["Order Completed"].contains(order.status))
            .toList();

      case "cancelled":
        return cabOrder
            .where((order) => [
                  "Order Rejected",
                  "Order Cancelled",
                  "Driver Rejected"
                ].contains(order.status))
            .toList();

      default:
        return [];
    }
  }

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }
}
