import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/auth_screen/phone_number_screen.dart';
import 'package:vendor/app/auth_screen/signup_screen.dart';
import 'package:vendor/app/forgot_password_screen/forgot_password_screen.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/login_controller.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/themes/text_field_widget.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: LoginController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome Back! 👋".tr,
                    style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 22, fontFamily: AppThemeData.semiBold),
                  ),
                  Text(
                    "Log in to continue managing your Store’s orders and reservations seamlessly.".tr,
                    style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.regular),
                  ),
                  const SizedBox(height: 32),
                  TextFieldWidget(
                    title: 'Email'.tr,
                    controller: controller.emailEditingController.value,
                    hintText: 'Enter email address'.tr,
                    prefix: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset("assets/icons/ic_mail.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                    ),
                  ),
                  TextFieldWidget(
                    title: 'Password'.tr,
                    controller: controller.passwordEditingController.value,
                    hintText: 'Enter Password'.tr,
                    obscureText: controller.passwordVisible.value,
                    prefix: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset("assets/icons/ic_lock.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                    ),
                    suffix: Padding(
                      padding: const EdgeInsets.all(12),
                      child: InkWell(
                        onTap: () {
                          controller.passwordVisible.value = !controller.passwordVisible.value;
                        },
                        child: controller.passwordVisible.value
                            ? SvgPicture.asset("assets/icons/ic_password_show.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn))
                            : SvgPicture.asset("assets/icons/ic_password_close.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () {
                        Get.to(const ForgotPasswordScreen());
                      },
                      child: Text(
                        "Forgot Password".tr,
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          decorationColor: AppThemeData.primary300,
                          color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                          fontSize: 14,
                          fontFamily: AppThemeData.regular,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  RoundedButtonFill(
                    title: "Login".tr,
                    color: AppThemeData.primary300,
                    textColor: AppThemeData.grey50,
                    onPress: () async {
                      if (controller.emailEditingController.value.text.trim().isEmpty) {
                        ShowToastDialog.showToast("Please enter valid email".tr);
                      } else if (controller.passwordEditingController.value.text.trim().isEmpty) {
                        ShowToastDialog.showToast("Please enter valid password".tr);
                      } else {
                        controller.loginWithEmailAndPassword();
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        const Expanded(child: Divider(thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                          child: Text(
                            "or".tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? AppThemeData.grey500 : AppThemeData.grey400, fontSize: 16, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  RoundedButtonFill(
                    title: "Continue with Mobile Number".tr,
                    textColor: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
                    color: isDark ? AppThemeData.grey900 : AppThemeData.grey100,
                    icon: SvgPicture.asset("assets/icons/ic_phone.svg", colorFilter: const ColorFilter.mode(AppThemeData.grey900, BlendMode.srcIn)),
                    isRight: false,
                    isCenter: true,
                    onPress: () async {
                      Get.to(const PhoneNumberScreen());
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RoundedButtonFill(
                          title: "with Google".tr,
                          textColor: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
                          color: isDark ? AppThemeData.grey900 : AppThemeData.grey100,
                          icon: SvgPicture.asset("assets/icons/ic_google.svg"),
                          isRight: false,
                          isCenter: true,
                          onPress: () async {
                            controller.loginWithGoogle();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Platform.isIOS
                          ? Expanded(
                              child: RoundedButtonFill(
                                title: "with Apple".tr,
                                isCenter: true,
                                textColor: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
                                color: isDark ? AppThemeData.grey900 : AppThemeData.grey100,
                                icon: SvgPicture.asset("assets/icons/ic_apple.svg"),
                                isRight: false,
                                onPress: () async {
                                  controller.loginWithApple();
                                },
                              ),
                            )
                          : const SizedBox(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.symmetric(vertical: Platform.isAndroid ? 10 : 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Didn’t have an account?'.tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                      ),
                      const WidgetSpan(child: SizedBox(width: 10)),
                      TextSpan(
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Get.to(const SignupScreen());
                          },
                        text: 'Sign up'.tr,
                        style: TextStyle(
                          color: AppThemeData.primary300,
                          fontFamily: AppThemeData.bold,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: AppThemeData.primary300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
