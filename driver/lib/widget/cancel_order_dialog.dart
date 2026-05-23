import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shows a confirm dialog allowing the driver to cancel an order/ride.
///
/// Returns `null` when the dialog is dismissed or "No" is tapped.
/// Returns the entered reason (possibly an empty string) on confirm.
Future<String?> showCancelOrderDialog(BuildContext context) async {
  final controller = TextEditingController();
  final themeController = Get.isRegistered<ThemeController>()
      ? Get.find<ThemeController>()
      : null;
  final bool isDark = themeController?.isDark.value ?? false;

  final result = await showDialog<String?>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor:
            isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          "Cancel Order".tr,
          style: AppThemeData.semiBoldTextStyle(
            fontSize: 18,
            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Are you sure you want to cancel this order?".tr,
              style: AppThemeData.regularTextStyle(
                fontSize: 14,
                color: isDark ? AppThemeData.grey200 : AppThemeData.grey700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              minLines: 1,
              style: AppThemeData.regularTextStyle(
                fontSize: 14,
                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
              ),
              decoration: InputDecoration(
                labelText: "Cancel Reason".tr,
                labelStyle: AppThemeData.regularTextStyle(
                  fontSize: 14,
                  color:
                      isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppThemeData.greyDark200
                        : AppThemeData.grey200,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppThemeData.greyDark200
                        : AppThemeData.grey200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppThemeData.primary300,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(
              "No".tr,
              style: AppThemeData.semiBoldTextStyle(
                fontSize: 14,
                color: isDark ? AppThemeData.grey200 : AppThemeData.grey700,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(
              "Yes, Cancel".tr,
              style: AppThemeData.semiBoldTextStyle(
                fontSize: 14,
                color: AppThemeData.danger300,
              ),
            ),
          ),
        ],
      );
    },
  );

  controller.dispose();
  return result;
}
