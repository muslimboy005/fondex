import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/refer_friend_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../controllers/theme_controller.dart';
import '../../../themes/show_toast_dialog.dart';

class ReferFriendScreen extends StatelessWidget {
  const ReferFriendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: ReferFriendController(),
      builder: (controller) {
        return Scaffold(
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Container(
                    width: Responsive.width(100, context),
                    height: Responsive.height(100, context),
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage("assets/images/refer_friend.png"),
                        fit: BoxFit.fill,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () {
                                  Get.back();
                                },
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: AppThemeData.grey50,
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 60),
                                  Center(
                                    child: SvgPicture.asset(
                                      "assets/images/referal_top.svg",
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Refer your friend and earn".tr,
                                    style: TextStyle(
                                      fontSize: 22,
                                      color:
                                          isDark
                                              ? AppThemeData.grey50
                                              : AppThemeData.grey50,
                                      fontFamily: AppThemeData.regular,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${Constant.amountShow(amount: Constant.sectionConstantModel!.referralAmount)} ${'Each🎉'.tr}",
                                    style: TextStyle(
                                      fontSize: 24,
                                      color:
                                          isDark
                                              ? AppThemeData.grey50
                                              : AppThemeData.grey50,
                                      fontFamily: AppThemeData.semiBold,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    "Invite Friends & Businesses".tr,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color:
                                          isDark
                                              ? AppThemeData.ecommerce100
                                              : AppThemeData.ecommerceDark100,
                                      fontFamily: AppThemeData.semiBold,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "${'Invite your friends to sign up with Foodie using your code, and you’ll earn'.tr} ${Constant.amountShow(amount: Constant.sectionConstantModel!.referralAmount)} ${'after their Success the first order! 💸🍔'.tr}",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color:
                                          isDark
                                              ? AppThemeData.grey50
                                              : AppThemeData.grey50,
                                      fontFamily: AppThemeData.regular,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  Container(
                                    decoration: ShapeDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment(0.00, -1.00),
                                        end: Alignment(0, 1),
                                        colors: [
                                          Color(0xFF271366),
                                          Color(0xFF4826B2),
                                        ],
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          120,
                                        ),
                                      ),
                                      shadows: const [
                                        BoxShadow(
                                          color: Color(0x14FFFFFF),
                                          blurRadius: 120,
                                          offset: Offset(0, 0),
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 80,
                                        vertical: 16,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            controller
                                                    .displayReferralCode
                                                    .isNotEmpty
                                                ? controller.displayReferralCode
                                                : '—',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color:
                                                  isDark
                                                      ? AppThemeData
                                                          .ecommerce100
                                                      : AppThemeData
                                                          .ecommerceDark100,
                                              fontFamily: AppThemeData.semiBold,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          InkWell(
                                            onTap: () {
                                              final code =
                                                  controller
                                                      .displayReferralCode;
                                              if (code.isNotEmpty) {
                                                Clipboard.setData(
                                                  ClipboardData(text: code),
                                                );
                                                ShowToastDialog.showToast(
                                                  "Copied".tr,
                                                );
                                              }
                                            },
                                            child: Icon(
                                              Icons.copy,
                                              color:
                                                  controller
                                                          .displayReferralCode
                                                          .isNotEmpty
                                                      ? AppThemeData
                                                          .ecommerce100
                                                      : AppThemeData.grey50
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Divider(
                                            thickness: 1,
                                            color:
                                                isDark
                                                    ? AppThemeData.ecommerce100
                                                    : AppThemeData
                                                        .ecommerceDark100,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 30,
                                          ),
                                          child: Text(
                                            "or".tr,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color:
                                                  isDark
                                                      ? AppThemeData
                                                          .ecommerce100
                                                      : AppThemeData
                                                          .ecommerceDark100,
                                              fontSize: 12,
                                              fontFamily: AppThemeData.medium,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color:
                                                isDark
                                                    ? AppThemeData.ecommerce100
                                                    : AppThemeData
                                                        .ecommerceDark100,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  RoundedButtonFill(
                                    title: "Share Code".tr,
                                    width: 55,
                                    color: AppThemeData.ecommerce300,
                                    textColor: AppThemeData.grey50,
                                    onPress: () async {
                                      final code =
                                          controller.displayReferralCode;
                                      if (code.isNotEmpty) {
                                        await Share.share(
                                          "${"Hey there, thanks for choosing Foodie. Hope you love our product. If you do, share it with your friends using code".tr} $code ${"and get".tr}${Constant.amountShow(amount: Constant.sectionConstantModel!.referralAmount.toString())} ${"when order completed".tr}",
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
        );
      },
    );
  }
}
