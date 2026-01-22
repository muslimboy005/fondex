import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/geoflutterfire/src/geoflutterfire.dart';
import 'package:driver/widget/geoflutterfire/src/models/point.dart';
import 'package:get/get.dart';

class RentalBookingSearchController extends GetxController {
  // Implementation of the controller

  RxBool isLoading = true.obs;

  Rx<UserModel> driverModel = UserModel().obs;
  Rx<UserModel> ownerModel = UserModel().obs;

  @override
  void onInit() {
    // TODO: implement onInit
    driverModel.value = Constant.userModel!;
    if (driverModel.value.ownerId != null && driverModel.value.ownerId!.isNotEmpty) {
      getOwnerDetails(driverModel.value.ownerId!);
    }
    getData();
    super.onInit();
  }

  Future<void> getData() async {
    await getRentalSearchBooking();
    isLoading.value = false;
    update();
  }

  Future<void> getOwnerDetails(String ownerId) async {
    ownerModel.value = await FireStoreUtils.getUserProfile(ownerId) ?? UserModel();
    update();
  }

  RxList<RentalOrderModel> rentalBookingData = <RentalOrderModel>[].obs;

  Future<void> getRentalSearchBooking() async {
    await searchParcelsOnce(srcLat: Constant.locationDataFinal!.latitude ?? 0.0, srcLng: Constant.locationDataFinal!.longitude ?? 0.0).then(
      (event) {
        rentalBookingData.value = event;
        update();
      },
    );
    isLoading.value = false;
  }

  Future<List<RentalOrderModel>> searchParcelsOnce({
    required double srcLat,
    required double srcLng,
  }) async {
    final ref = FireStoreUtils.fireStore
        .collection(CollectionName.rentalOrders)
        .where("vehicleId", isEqualTo: driverModel.value.vehicleId)
        .where("sectionId", isEqualTo: driverModel.value.sectionId)
        .where('status', isEqualTo: "Order Placed");

    GeoFirePoint center = Geoflutterfire().point(latitude: srcLat, longitude: srcLng);

    // Fetch documents once
    final docs = await Geoflutterfire()
        .collection(collectionRef: ref)
        .within(
          center: center,
          radius: double.parse(Constant.rentalRadius),
          field: "sourcePoint",
          strictMode: true,
        )
        .first;

    final now = DateTime.now();

    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['bookingDateTime'] == null) return false;

      // ✅ Check zone match
      if (data['zoneId'] == null || data['zoneId'] != driverModel.value.zoneId) {
        return false;
      }

      if (data['rejectedByDrivers'] != null) {
        List<dynamic> rejectedByDrivers = data['rejectedByDrivers'];
        if (rejectedByDrivers.contains(FireStoreUtils.getCurrentUid())) {
          return false;
        }
      }

      final Timestamp ts = data['bookingDateTime'];
      final orderDate = ts.toDate().toLocal();

      // ✅ Allow only today's or future bookings
      bool isToday = orderDate.year == now.year && orderDate.month == now.month && orderDate.day == now.day;

      return orderDate.isAfter(now) || isToday;
    }).toList();

    return filtered.map((e) => RentalOrderModel.fromJson(e.data()!)).toList();
  }
}
