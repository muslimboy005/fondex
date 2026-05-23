import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../themes/app_them_data.dart';
import '../themes/round_button_fill.dart';

Future<String?> showCancelOrderDialog(BuildContext context) {
  final TextEditingController reasonController = TextEditingController();
  final themeController = Get.find<ThemeController>();
  final isDark = themeController.isDark.value;

  return showDialog<String?>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext ctx) {
      return Dialog(
        backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Cancel Order".tr,
                style: AppThemeData.semiBoldTextStyle(
                  color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Are you sure you want to cancel this order?".tr,
                style: AppThemeData.regularTextStyle(
                  color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: AppThemeData.regularTextStyle(
                  color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  labelText: "Cancel Reason".tr,
                  labelStyle: AppThemeData.regularTextStyle(
                    color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500,
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppThemeData.danger300),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: RoundedButtonFill(
                      title: "No".tr,
                      height: 5,
                      borderRadius: 12,
                      color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                      textColor: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                      onPress: () {
                        Navigator.of(ctx).pop(null);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RoundedButtonFill(
                      title: "Yes, Cancel".tr,
                      height: 5,
                      borderRadius: 12,
                      color: AppThemeData.danger300,
                      textColor: AppThemeData.grey50,
                      onPress: () {
                        Navigator.of(ctx).pop(reasonController.text.trim());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
