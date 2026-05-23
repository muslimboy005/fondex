import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

class OrderDetailsController extends GetxController {
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  Rx<OrderModel> orderModel = OrderModel().obs;

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderModel.value = argumentData['orderModel'];
    }
    calculatePrice();
    update();
  }

  RxDouble subTotal = 0.0.obs;
  RxDouble specialDiscountAmount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;

  Future<void> calculatePrice() async {
    subTotal.value = 0.0;
    specialDiscountAmount.value = 0.0;
    taxAmount.value = 0.0;
    totalAmount.value = 0.0;

    for (var element in orderModel.value.products!) {
      if (double.parse(element.discountPrice.toString()) <= 0) {
        subTotal.value = subTotal.value +
            double.parse(element.price.toString()) * double.parse(element.quantity.toString()) +
            (double.parse(element.extrasPrice.toString()) * double.parse(element.quantity.toString()));
      } else {
        subTotal.value = subTotal.value +
            double.parse(element.discountPrice.toString()) * double.parse(element.quantity.toString()) +
            (double.parse(element.extrasPrice.toString()) * double.parse(element.quantity.toString()));
      }
    }

    if (orderModel.value.specialDiscount != null && orderModel.value.specialDiscount!['special_discount'] != null) {
      specialDiscountAmount.value = double.parse(orderModel.value.specialDiscount!['special_discount'].toString());
    }

    if (orderModel.value.taxSetting != null) {
      for (var element in orderModel.value.taxSetting!) {
        taxAmount.value = taxAmount.value +
            Constant.calculateTax(amount: (subTotal.value - double.parse(orderModel.value.discount.toString()) - specialDiscountAmount.value).toString(), taxModel: element);
      }
    }

    totalAmount.value = (subTotal.value - double.parse(orderModel.value.discount.toString()) - specialDiscountAmount.value) +
        taxAmount.value +
        double.parse(orderModel.value.deliveryCharge.toString()) +
        double.parse(orderModel.value.tipAmount.toString());

    isLoading.value = false;
  }

  /// Cancel an in-progress vendor order: update Firestore, remove from this
  /// driver's inProgressOrderID, and notify the customer + vendor.
  Future<void> cancelOrder({String? reason}) async {
    ShowToastDialog.showLoader('Cancelling order...'.tr);
    try {
      orderModel.value.status = Constant.orderCancelled;
      orderModel.value.cancelReason = reason;
      await FireStoreUtils.setOrder(orderModel.value);

      // Remove orderId from this driver's inProgressOrderID
      final driver = Constant.userModel;
      if (driver != null) {
        driver.orderRequestData?.remove(orderModel.value.id);
        driver.inProgressOrderID?.remove(orderModel.value.id);
        await FireStoreUtils.updateUser(driver);
      }

      // Notify customer
      final customerToken = orderModel.value.author?.fcmToken;
      if (customerToken != null && customerToken.isNotEmpty) {
        await SendNotification.sendOneNotification(
          token: customerToken,
          title: 'Cancelled Order'.tr,
          body: (reason == null || reason.isEmpty)
              ? 'Your order was cancelled by the driver.'.tr
              : reason,
          payload: {'orderId': orderModel.value.id ?? ''},
        );
      }

      // Notify vendor / restaurant
      final vendorToken = orderModel.value.vendor?.fcmToken;
      if (vendorToken != null && vendorToken.isNotEmpty) {
        await SendNotification.sendOneNotification(
          token: vendorToken,
          title: 'Cancelled Order'.tr,
          body: (reason == null || reason.isEmpty)
              ? 'Order was cancelled by the driver.'.tr
              : reason,
          payload: {'orderId': orderModel.value.id ?? ''},
        );
      }

      orderModel.refresh();
      update();
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast('Order cancelled successfully'.tr);
      Get.back(result: true);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(e.toString());
    }
  }
}
