import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_booking_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/screen_ui/cab_service_screens/cab_dashboard_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CabPaymentSummaryScreen extends StatelessWidget {
  const CabPaymentSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      final controller = Get.find<CabBookingController>();
      final order = controller.completedOrder.value;
      final fareDouble = order.finalFare ?? 0.0;
      final fareStr =
          Constant.amountShow(amount: fareDouble.toString());
      final paymentMethod = (order.paymentMethod ?? '').toLowerCase();
      final distance =
          order.finalDistance ?? double.tryParse(order.distance ?? '0') ?? 0.0;
      final duration = order.duration ?? '';

      return Scaffold(
        backgroundColor:
            isDark ? AppThemeData.greyDark900 : AppThemeData.grey50,
        appBar: AppBar(
          title: Text("To'lov".tr),
          backgroundColor:
              isDark ? AppThemeData.greyDark900 : AppThemeData.grey50,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppThemeData.grey800 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 56,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Sayohat tugadi".tr,
                        style: AppThemeData.semiBoldTextStyle(
                          fontSize: 18,
                          color: isDark
                              ? AppThemeData.grey50
                              : AppThemeData.grey900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        fareStr,
                        style: AppThemeData.semiBoldTextStyle(
                          fontSize: 32,
                          color: AppThemeData.primary300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppThemeData.grey800 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _row(
                        context,
                        isDark,
                        "Masofa".tr,
                        "${distance.toStringAsFixed(1)} km",
                      ),
                      const Divider(height: 20),
                      _row(
                        context,
                        isDark,
                        "Davomiyligi".tr,
                        duration.isEmpty ? '-' : duration,
                      ),
                      const Divider(height: 20),
                      _row(
                        context,
                        isDark,
                        "To'lov turi".tr,
                        _paymentLabel(paymentMethod),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () =>
                        _onPayPressed(controller, paymentMethod, fareDouble),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeData.primary300,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "To'lash".tr,
                      style: AppThemeData.semiBoldTextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _row(
    BuildContext context,
    bool isDark,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppThemeData.regularTextStyle(
              fontSize: 14,
              color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
            ),
          ),
        ),
        Text(
          value,
          style: AppThemeData.semiBoldTextStyle(
            fontSize: 14,
            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
          ),
        ),
      ],
    );
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cod':
        return "Naqd".tr;
      case 'wallet':
        return "Hamyon".tr;
      case 'payme':
        return 'Payme';
      default:
        return method.isEmpty ? '-' : method;
    }
  }

  Future<void> _onPayPressed(
    CabBookingController controller,
    String paymentMethod,
    double amount,
  ) async {
    try {
      if (paymentMethod == 'wallet') {
        final uid = FireStoreUtils.getCurrentUidOrNull();
        if (uid == null) {
          ShowToastDialog.showToast("Please login first".tr);
          return;
        }
        ShowToastDialog.showLoader("Please wait".tr);
        await FireStoreUtils.updateUserWallet(
          amount: "-${amount.toString()}",
          userId: uid,
        );
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("To'lov muvaffaqiyatli amalga oshirildi".tr);
      } else {
        // For COD / Payme — we just confirm; cash is handed to driver, payme
        // flows have their own gateway hook elsewhere.
        ShowToastDialog.showToast("Rahmat! Sayohat yakunlandi.".tr);
      }
      Get.offAll(() => const CabDashboardScreen());
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("To'lovda xatolik. Qaytadan urinib ko'ring.".tr);
    }
  }
}
