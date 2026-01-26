import 'package:country_code_picker/country_code_picker.dart';
import 'package:vendor/app/auth_screen/login_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controller/phone_registration_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/text_field_widget.dart';
import '../../themes/theme_controller.dart';

class PhoneRegistrationScreen extends StatelessWidget {
  const PhoneRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<PhoneRegistrationController>(
      init: PhoneRegistrationController(),
      builder: (controller) {
        final themeController = Get.find<ThemeController>();
        final isDark = themeController.isDark.value;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: isDark
                ? AppThemeData.surfaceDark
                : AppThemeData.surface,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                size: 20,
                color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500,
              ),
              onPressed: () {
                Get.back();
              },
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Enter your phone number to register and get started."
                                .tr,
                            style: TextStyle(
                              fontSize: 22,
                              fontFamily: AppThemeData.semiBold,
                              color: isDark
                                  ? AppThemeData.greyDark900
                                  : AppThemeData.grey900,
                            ),
                          ),
                          const SizedBox(height: 25),
                          TextFieldWidget(
                            title: "Phone Number*".tr,
                            hintText: "Enter phone number".tr,
                            controller: controller.phoneController.value,
                            textInputType:
                                const TextInputType.numberWithOptions(
                                  signed: true,
                                  decimal: true,
                                ),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp('[0-9]'),
                              ),
                              LengthLimitingTextInputFormatter(9),
                            ],
                            prefix: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CountryCodePicker(
                                  onChanged: (value) {
                                    controller
                                            .countryCodeController
                                            .value
                                            .text =
                                        value.dialCode ??
                                        Constant.defaultCountryCode;
                                  },
                                  initialSelection:
                                      controller
                                          .countryCodeController
                                          .value
                                          .text
                                          .isNotEmpty
                                      ? controller
                                            .countryCodeController
                                            .value
                                            .text
                                      : Constant.defaultCountryCode,
                                  showCountryOnly: false,
                                  showOnlyCountryWhenClosed: false,
                                  alignLeft: false,
                                  textStyle: TextStyle(
                                    fontSize: 16,
                                    color: isDark
                                        ? AppThemeData.greyDark900
                                        : Colors.black,
                                  ),
                                  dialogTextStyle: TextStyle(
                                    fontSize: 16,
                                    color: isDark
                                        ? AppThemeData.greyDark900
                                        : AppThemeData.grey900,
                                  ),
                                  searchStyle: TextStyle(
                                    fontSize: 16,
                                    color: isDark
                                        ? AppThemeData.greyDark900
                                        : AppThemeData.grey900,
                                  ),
                                  dialogBackgroundColor: isDark
                                      ? AppThemeData.surfaceDark
                                      : AppThemeData.surface,
                                  padding: EdgeInsets.zero,
                                ),
                                Container(
                                  height: 24,
                                  width: 1,
                                  color: AppThemeData.grey400,
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          RoundedButtonFill(
                            title: "Register".tr,
                            color: AppThemeData.primary300,
                            textColor: AppThemeData.grey50,
                            onPress: controller.registerWithPhone,
                          ),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 1,
                                color: isDark
                                    ? AppThemeData.greyDark300
                                    : AppThemeData.grey300,
                              ),
                              const SizedBox(width: 15),
                              Text(
                                "or continue with".tr,
                                style: TextStyle(
                                  fontFamily: AppThemeData.regular,
                                  color: isDark
                                      ? AppThemeData.greyDark400
                                      : AppThemeData.grey400,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Container(
                                width: 52,
                                height: 1,
                                color: isDark
                                    ? AppThemeData.greyDark400
                                    : AppThemeData.grey400,
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          RoundedButtonFill(
                            title: "Email address".tr,
                            color: isDark
                                ? AppThemeData.greyDark200
                                : AppThemeData.grey200,
                            textColor: isDark
                                ? AppThemeData.greyDark900
                                : AppThemeData.grey900,
                            onPress: () => Get.to(() => const LoginScreen()),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Center(
                      child: Text.rich(
                        TextSpan(
                          text: "Already have an account?".tr,
                          style: TextStyle(
                            fontFamily: AppThemeData.medium,
                            color: isDark
                                ? AppThemeData.greyDark800
                                : AppThemeData.grey800,
                          ),
                          children: [
                            TextSpan(
                              text: "Sign in".tr,
                              style: TextStyle(
                                fontFamily: AppThemeData.medium,
                                color: AppThemeData.primary300,
                                decoration: TextDecoration.underline,
                                decorationColor: AppThemeData.primary300,
                                decorationStyle: TextDecorationStyle.solid,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Get.back();
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
