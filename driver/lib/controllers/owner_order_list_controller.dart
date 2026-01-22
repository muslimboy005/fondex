import 'package:get/get.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import '../models/cab_order_model.dart';
import '../models/parcel_order_model.dart';
import '../models/rental_order_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OwnerOrderListController extends GetxController {
  // Loading flags
  RxBool isLoadingCab = false.obs;
  RxBool isLoadingParcel = false.obs;
  RxBool isLoadingRental = false.obs;

  // Service list
  RxList<String> serviceList = ['Cab Service', 'Parcel Service', 'Rental Service'].obs;
  RxString selectedService = 'Cab Service'.obs;
  RxString serviceKey = 'cab-service'.obs;

  // Driver list
  RxList<UserModel> driverList = <UserModel>[].obs;
  Rx<UserModel?> selectedDriver = Rx<UserModel?>(null);
  RxBool isDriverSelected = false.obs;
  RxString driverId = ''.obs;

  // Cab Orders
  RxList<CabOrderModel> cabOrders = <CabOrderModel>[].obs;
  RxString cabSelectedTab = 'On Going'.obs;
  final List<String> cabTabTitles = ["On Going", "Completed", "Cancelled"];

  // Parcel Orders
  RxList<ParcelOrderModel> parcelOrders = <ParcelOrderModel>[].obs;
  RxString parcelSelectedTab = 'In Transit'.obs;
  final List<String> parcelTabTitles = ["In Transit", "Delivered", "Cancelled"];

  // Rental Orders
  RxList<RentalOrderModel> rentalOrders = <RentalOrderModel>[].obs;
  RxString rentalSelectedTab = 'On Going'.obs;
  final List<String> rentalTabTitles = ["On Going", "Completed", "Cancelled"];

  @override
  void onInit() {
    super.onInit();
    getDriverList();
  }

  // Fetch all drivers
  Future<void> getDriverList() async {
    try {
      driverList.value = await FireStoreUtils.getOwnerDriver();

      print("Drivers fetched: ${driverList.length}");
      for (var d in driverList) {
        print("${d.firstName} ${d.lastName} - ${d.serviceType}");
      }

      // Default: Cab Service + All drivers
      selectedService.value = 'Cab Service';
      serviceKey.value = 'cab-service';
      selectedDriver.value = null;
      isDriverSelected.value = false;

      fetchOrdersByService();
    } catch (e) {
      ShowToastDialog.showToast("Error fetching drivers: $e");
    }
  }

  // Filter drivers by selected service
  List<UserModel> get filteredDrivers {
    final serviceKeyMap = {
      'cab service': 'cab-service',
      'parcel service': 'parcel_delivery',
      'rental service': 'rental-service',
    };
    final key = serviceKeyMap[selectedService.value.toLowerCase()];
    return driverList.where((driver) => driver.serviceType == key).toList();
  }

  // Called on Search button
  void searchOrders() {
    if (selectedDriver.value != null) {
      driverId.value = selectedDriver.value!.id!;
      isDriverSelected.value = true;
    } else {
      driverId.value = '';
      isDriverSelected.value = false;
    }

    final serviceMap = {
      'Cab Service': 'cab-service',
      'Parcel Service': 'parcel_delivery',
      'Rental Service': 'rental-service',
    };
    serviceKey.value = serviceMap[selectedService.value] ?? 'cab-service';

    fetchOrdersByService();
  }

  Future<void> fetchOrdersByService() async {
    if (serviceKey.value == 'cab-service') {
      await fetchCabOrders();
    } else if (serviceKey.value == 'parcel_delivery') {
      await fetchParcelOrders();
    } else if (serviceKey.value == 'rental-service') {
      await fetchRentalOrders();
    }
  }

  // -------------------- CAB ORDERS --------------------
  Future<void> fetchCabOrders() async {
    try {
      isLoadingCab.value = true;

      print("Fetching Cab Orders for Driver ID: ${driverId.value}, Is Driver Selected: ${isDriverSelected.value}");
      if (isDriverSelected.value) {
        cabOrders.value = await FireStoreUtils.getCabDriverOrdersOnce(driverId.value);
      } else {
        List<UserModel> drivers = filteredDrivers;
        List<CabOrderModel> allOrders = [];
        for (var driver in drivers) {
          List<CabOrderModel> driverOrders =
          await FireStoreUtils.getCabDriverOrdersOnce(driver.id ?? '');
          allOrders.addAll(driverOrders);
        }
        cabOrders.value = allOrders;
      }
      print("Total Cab Orders: ${cabOrders.length}");
    } catch (e) {
      ShowToastDialog.showToast("Error fetching cab orders: $e");
    } finally {
      isLoadingCab.value = false;
    }
  }

  List<CabOrderModel> getCabOrdersForTab(String tab) {
    switch (tab) {
      case "On Going":
        return cabOrders
            .where((order) => [
          "Order Placed",
          "Order Accepted",
          "Driver Accepted",
          "Driver Pending",
          "Order Shipped",
          "In Transit"
        ].contains(order.status))
            .toList();
      case "Completed":
        return cabOrders.where((order) => ["Order Completed"].contains(order.status)).toList();
      case "Cancelled":
        return cabOrders
            .where((order) => ["Order Rejected", "Order Cancelled", "Driver Rejected"].contains(order.status))
            .toList();
      default:
        return [];
    }
  }

  // -------------------- PARCEL ORDERS --------------------
  Future<void> fetchParcelOrders() async {
    try {
      isLoadingParcel.value = true;

      if (isDriverSelected.value) {
        parcelOrders.value = await FireStoreUtils.getParcelDriverOrdersOnce(driverId.value);
      } else {
        List<UserModel> drivers = filteredDrivers;
        List<ParcelOrderModel> allOrders = [];
        for (var driver in drivers) {
          List<ParcelOrderModel> driverOrders =
          await FireStoreUtils.getParcelDriverOrdersOnce(driver.id ?? '');
          allOrders.addAll(driverOrders);
        }
        parcelOrders.value = allOrders;
      }
    } catch (e) {
      ShowToastDialog.showToast("Error fetching parcel orders: $e");
    } finally {
      isLoadingParcel.value = false;
    }
  }

  List<ParcelOrderModel> getParcelOrdersForTab(String tab) {
    switch (tab) {
      case "In Transit":
        return parcelOrders
            .where((order) => [
          "Order Placed",
          "Order Accepted",
          "Driver Accepted",
          "Driver Pending",
          "Order Shipped",
          "In Transit"
        ].contains(order.status))
            .toList();
      case "Delivered":
        return parcelOrders.where((order) => ["Order Completed"].contains(order.status)).toList();
      case "Cancelled":
        return parcelOrders
            .where((order) => ["Order Rejected", "Order Cancelled", "Driver Rejected"].contains(order.status))
            .toList();
      default:
        return [];
    }
  }

  // -------------------- RENTAL ORDERS --------------------
  Future<void> fetchRentalOrders() async {
    try {
      isLoadingRental.value = true;

      if (isDriverSelected.value) {
        rentalOrders.value = await FireStoreUtils.getRentalDriverOrdersOnce(driverId.value);
      } else {
        List<UserModel> drivers = filteredDrivers;
        List<RentalOrderModel> allOrders = [];
        for (var driver in drivers) {
          List<RentalOrderModel> driverOrders =
          await FireStoreUtils.getRentalDriverOrdersOnce(driver.id ?? '');
          allOrders.addAll(driverOrders);
        }
        rentalOrders.value = allOrders;
      }
    } catch (e) {
      ShowToastDialog.showToast("Error fetching rental orders: $e");
    } finally {
      isLoadingRental.value = false;
    }
  }

  List<RentalOrderModel> getRentalOrdersForTab(String tab) {
    switch (tab) {
      case "On Going":
        return rentalOrders
            .where((order) => [
          "Order Placed",
          "Order Accepted",
          "Driver Accepted",
          "Driver Pending",
          "Order Shipped",
          "In Transit"
        ].contains(order.status))
            .toList();
      case "Completed":
        return rentalOrders.where((order) => ["Order Completed"].contains(order.status)).toList();
      case "Cancelled":
        return rentalOrders
            .where((order) => ["Order Rejected", "Order Cancelled", "Driver Rejected"].contains(order.status))
            .toList();
      default:
        return [];
    }
  }

  // -------------------- DATE FORMAT --------------------
  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }
}
