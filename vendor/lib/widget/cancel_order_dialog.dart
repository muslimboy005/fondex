import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/theme_controller.dart';

Future<String?> showCancelOrderDialog(BuildContext context) async {
  final TextEditingController reasonController = TextEditingController();
  final themeController = Get.find<ThemeController>();
  final isDark = themeController.isDark.value;

  final result = await showDialog<String?>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.only(
            left: 20,
            top: 20,
            right: 20,
            bottom: 20,
          ),
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                "Cancel Order".tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: AppThemeData.semiBold,
                  color: isDark
                      ? AppThemeData.grey100
                      : AppThemeData.grey800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Are you sure you want to cancel this order?".tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: AppThemeData.regular,
                  color: isDark
                      ? AppThemeData.grey200
                      : AppThemeData.grey700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: AppThemeData.semiBoldTextStyle(
                  color: isDark
                      ? AppThemeData.greyDark900
                      : AppThemeData.grey900,
                ),
                decoration: InputDecoration(
                  labelText: "Cancel Reason".tr,
                  labelStyle: AppThemeData.regularTextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppThemeData.greyDark400
                        : AppThemeData.grey500,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppThemeData.greyDark100
                      : AppThemeData.grey50,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
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
                      color: isDark
                          ? AppThemeData.greyDark400
                          : AppThemeData.grey400,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(ctx).pop(null);
                      },
                      child: Container(
                        height: Responsive.height(5, ctx),
                        decoration: ShapeDecoration(
                          color: isDark
                              ? AppThemeData.grey700
                              : AppThemeData.grey200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(200),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "No".tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppThemeData.medium,
                              color: isDark
                                  ? AppThemeData.grey100
                                  : AppThemeData.grey900,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(ctx).pop(reasonController.text.trim());
                      },
                      child: Container(
                        height: Responsive.height(5, ctx),
                        decoration: ShapeDecoration(
                          color: AppThemeData.danger300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(200),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Yes, Cancel".tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppThemeData.medium,
                              color: AppThemeData.grey50,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
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

  reasonController.dispose();
  return result;
}
