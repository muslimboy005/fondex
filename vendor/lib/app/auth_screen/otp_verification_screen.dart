import 'package:vendor/app/auth_screen/signup_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../controller/otp_verification_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/theme_controller.dart';

class OtpVerificationScreen extends StatelessWidget {
  const OtpVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OtpVerifyController>(
      init: OtpVerifyController(),
      builder: (controller) {
        final themeController = Get.find<ThemeController>();
        final isDark = themeController.isDark.value;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            automaticallyImplyLeading: false,
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
            actions: [
              TextButton(
                onPressed: () {
                  // Handle skip action
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Skip".tr,
                      style: TextStyle(
                        fontFamily: AppThemeData.medium,
                        color: isDark
                            ? AppThemeData.greyDark500
                            : AppThemeData.grey500,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, left: 4),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: isDark
                            ? AppThemeData.greyDark500
                            : AppThemeData.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                            "${"Enter the OTP sent to your mobile".tr} ${controller.countryCode} ${controller.maskPhoneNumber(controller.phoneNumber.value)}",
                            style: TextStyle(
                              fontSize: 22,
                              fontFamily: AppThemeData.semiBold,
                              color: isDark
                                  ? AppThemeData.greyDark900
                                  : AppThemeData.grey900,
                            ),
                          ),

                          const SizedBox(height: 30),

                          /// OTP Field
                          PinCodeTextField(
                            appContext: context,
                            length: 6,
                            controller: controller.otpController.value,
                            keyboardType: TextInputType.number,
                            cursorColor: isDark
                                ? AppThemeData.greyDark500
                                : AppThemeData.grey500,
                            enablePinAutofill: true,
                            hintCharacter: "-",
                            textStyle: AppThemeData.semiBoldTextStyle(
                              fontSize: 18,
                              color: isDark
                                  ? AppThemeData.greyDark800
                                  : AppThemeData.grey800,
                            ),
                            pinTheme: PinTheme(
                              shape: PinCodeFieldShape.box,
                              borderRadius: BorderRadius.circular(12),
                              fieldHeight: 54,
                              fieldWidth: 51,
                              inactiveColor: isDark
                                  ? AppThemeData.greyDark200
                                  : AppThemeData.grey200,
                              inactiveFillColor: Colors.transparent,
                              selectedColor: isDark
                                  ? AppThemeData.greyDark400
                                  : AppThemeData.grey400,
                              selectedFillColor: isDark
                                  ? AppThemeData.surfaceDark
                                  : AppThemeData.grey50,
                              activeColor: isDark
                                  ? AppThemeData.greyDark200
                                  : AppThemeData.grey200,
                              activeFillColor: Colors.transparent,
                              errorBorderColor: AppThemeData.danger300,
                              disabledColor: Colors.transparent,
                              borderWidth: 1,
                            ),
                            enableActiveFill: true,
                            onCompleted: (v) {},
                            onChanged: (value) {},
                          ),

                          /// Resend OTP with Timer
                          Obx(
                            () => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!controller.canResend.value) ...[
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 20,
                                    color: isDark
                                        ? AppThemeData.greyDark500
                                        : AppThemeData.grey500,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${"Resend OTP in".tr} ${controller.formattedTime}",
                                    style: AppThemeData.mediumTextStyle(
                                      color: isDark
                                          ? AppThemeData.greyDark500
                                          : AppThemeData.grey500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ] else ...[
                                  Icon(
                                    Icons.refresh,
                                    size: 20,
                                    color: isDark
                                        ? AppThemeData.greyDark500
                                        : AppThemeData.grey500,
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      controller.otpController.value.clear();
                                      controller.sendOTP();
                                    },
                                    child: Text(
                                      "Resend OTP".tr,
                                      style: TextStyle(
                                        fontFamily: AppThemeData.semiBold,
                                        color: AppThemeData.primary300,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          /// Verify Button
                          RoundedButtonFill(
                            title: "Verify".tr,
                            color: AppThemeData.primary300,
                            textColor: AppThemeData.grey50,
                            onPress: controller.verifyOtp,
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
                          text: "Didn't have an account?".tr,
                          style: AppThemeData.mediumTextStyle(
                            color: isDark
                                ? AppThemeData.greyDark800
                                : AppThemeData.grey800,
                          ),
                          children: [
                            TextSpan(
                              text: "Sign up".tr,
                              style: TextStyle(
                                fontFamily: AppThemeData.medium,
                                color: AppThemeData.primary300,
                                decoration: TextDecoration.underline,
                                decorationColor: AppThemeData.primary300,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () =>
                                    Get.offAll(() => const SignupScreen()),
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
