import 'dart:async';
import 'dart:developer';

import 'package:driver/app/auth_screen/auth_screen.dart';
import 'package:driver/app/cab_screen/cab_order_list_screen.dart';
import 'package:driver/app/change%20langauge/change_language_screen.dart';
import 'package:driver/app/chat_screens/driver_inbox_screen.dart';
import 'package:driver/app/edit_profile_screen/edit_profile_screen.dart';
import 'package:driver/app/terms_and_condition/terms_and_condition_screen.dart';
import 'package:driver/app/verification_screen/verification_screen.dart';
import 'package:driver/app/wallet_screen/wallet_screen.dart';
import 'package:driver/app/withdraw_method_setup_screens/withdraw_method_setup_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/cab_dashboard_controller.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/custom_dialog_box.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';

import '../vehicle_information_screen/vehicle_information_screen.dart';
import 'cab_home_screen.dart';

class CabDashboardScreen extends StatelessWidget {
  const CabDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
        init: CabDashBoardController(),
        builder: (controller) {
          return Scaffold(
            drawerEnableOpenDragGesture: false,
            appBar: AppBar(
              // backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              titleSpacing: 5,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back 👋'.tr,
                    style: TextStyle(
                      color:
                          isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                      fontSize: 12,
                      fontFamily: AppThemeData.medium,
                    ),
                  ),
                  Text(
                    controller.userModel.value.fullName().tr,
                    style: TextStyle(
                      color:
                          isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                      fontSize: 14,
                      fontFamily: AppThemeData.semiBold,
                    ),
                  )
                ],
              ),
              actions: [
                controller.userModel.value.ownerId != null &&
                        controller.userModel.value.ownerId!.isNotEmpty
                    ? SizedBox()
                    : InkWell(
                        onTap: () {
                          Get.to(const WalletScreen(isAppBarShow: true));
                        },
                        child: SvgPicture.asset(
                            "assets/icons/ic_wallet_home.svg")),
                const SizedBox(
                  width: 10,
                ),
                InkWell(
                    onTap: () {
                      Get.to(const EditProfileScreen());
                    },
                    child:
                        SvgPicture.asset("assets/icons/ic_user_business.svg")),
                const SizedBox(
                  width: 10,
                ),
              ],
              leading: Builder(builder: (context) {
                return InkWell(
                  onTap: () {
                    Scaffold.of(context).openDrawer();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                        decoration: ShapeDecoration(
                          color: isDark
                              ? AppThemeData.carRent600
                              : AppThemeData.carRent50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(120),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: SvgPicture.asset(
                              "assets/icons/ic_drawer_open.svg"),
                        )),
                  ),
                );
              }),
            ),
            drawer: const DrawerView(),
            body: controller.drawerIndex.value == 0
                ? const CabHomeScreen()
                : controller.drawerIndex.value == 1
                    ? const CabOrderListScreen()
                    : controller.drawerIndex.value == 2
                        ? const WalletScreen(
                            isAppBarShow: false,
                          )
                        : controller.drawerIndex.value == 3
                            ? const WithdrawMethodSetupScreen()
                            : controller.drawerIndex.value == 4
                                ? const VerificationScreen()
                                : controller.drawerIndex.value == 5
                                    ? const DriverInboxScreen()
                                    : controller.drawerIndex.value == 6
                                        ? const VehicleInformationScreen()
                                        : controller.drawerIndex.value == 7
                                            ? const ChangeLanguageScreen()
                                            : controller.drawerIndex.value == 8
                                                ? const TermsAndConditionScreen(
                                                    type: "temsandcondition")
                                                : const TermsAndConditionScreen(
                                                    type: "privacy"),
          );
        },
      );
    });
  }
}

class DrawerView extends StatelessWidget {
  const DrawerView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      var isDark = themeController.isDark.value;
      return GetX(
          init: CabDashBoardController(),
          builder: (controller) {
            return Drawer(
              backgroundColor:
                  isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              child: SafeArea(
                child: Column(
                  children: [
                    // Header Section with Gradient
                    _buildProfileHeader(context, controller, isDark),

                    // Scrollable Menu Content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            // Status Card
                            _buildStatusCard(controller, isDark),

                            const SizedBox(height: 24),

                            // Main Menu Section
                            _buildSectionTitle('Menu'.tr, isDark),
                            const SizedBox(height: 12),
                            _buildMenuCard(
                              isDark: isDark,
                              children: [
                                _buildMenuItem(
                                  icon: Icons.home_rounded,
                                  title: 'Home'.tr,
                                  isDark: isDark,
                                  isSelected: controller.drawerIndex.value == 0,
                                  onTap: () {
                                    Get.back();
                                    controller.drawerIndex.value = 0;
                                  },
                                ),
                                _buildDivider(isDark),
                                _buildMenuItem(
                                  icon: Icons.receipt_long_rounded,
                                  title: 'Orders'.tr,
                                  isDark: isDark,
                                  isSelected: controller.drawerIndex.value == 1,
                                  onTap: () {
                                    Get.back();
                                    controller.drawerIndex.value = 1;
                                  },
                                ),
                                if (controller.userModel.value.ownerId ==
                                        null ||
                                    controller
                                        .userModel.value.ownerId!.isEmpty) ...[
                                  _buildDivider(isDark),
                                  _buildMenuItem(
                                    icon: Icons.account_balance_wallet_rounded,
                                    title: 'Wallet'.tr,
                                    isDark: isDark,
                                    isSelected:
                                        controller.drawerIndex.value == 2,
                                    onTap: () {
                                      Get.back();
                                      controller.drawerIndex.value = 2;
                                    },
                                  ),
                                ],
                                if ((controller.userModel.value.ownerId ==
                                            null ||
                                        controller.userModel.value.ownerId!
                                            .isEmpty) &&
                                    Constant.isDriverVerification == true &&
                                    !(controller.userModel.value.ownerId !=
                                            null &&
                                        controller.userModel.value.ownerId!
                                            .isNotEmpty &&
                                        Constant.isOwnerVerification ==
                                            true)) ...[
                                  _buildDivider(isDark),
                                  _buildMenuItem(
                                    icon: Icons.verified_user_rounded,
                                    title: 'Document Verification'.tr,
                                    isDark: isDark,
                                    isSelected:
                                        controller.drawerIndex.value == 4,
                                    badgeText: controller.userModel.value
                                                .isDocumentVerify ==
                                            true
                                        ? null
                                        : 'Pending'.tr,
                                    badgeColor: AppThemeData.warning300,
                                    onTap: () {
                                      Get.back();
                                      controller.drawerIndex.value = 4;
                                    },
                                  ),
                                ],
                                _buildDivider(isDark),
                                _buildMenuItem(
                                  icon: Icons.chat_bubble_rounded,
                                  title: 'Inbox'.tr,
                                  isDark: isDark,
                                  isSelected: controller.drawerIndex.value == 5,
                                  onTap: () {
                                    Get.back();
                                    controller.drawerIndex.value = 5;
                                  },
                                ),
                                _buildDivider(isDark),
                                _buildMenuItem(
                                  icon: Icons.directions_car_rounded,
                                  title: 'Vehicle Information'.tr,
                                  isDark: isDark,
                                  isSelected: controller.drawerIndex.value == 6,
                                  onTap: () {
                                    Get.back();
                                    controller.drawerIndex.value = 6;
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Settings Section
                            _buildSectionTitle('Settings'.tr, isDark),
                            const SizedBox(height: 12),
                            _buildMenuCard(
                              isDark: isDark,
                              children: [
                                _buildMenuItem(
                                  icon: Icons.language_rounded,
                                  title: 'Change Language'.tr,
                                  isDark: isDark,
                                  isSelected: controller.drawerIndex.value == 7,
                                  onTap: () {
                                    Get.back();
                                    controller.drawerIndex.value = 7;
                                  },
                                ),
                                _buildDivider(isDark),
                                _buildSwitchMenuItem(
                                  icon: isDark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                  title: 'Dark Mode'.tr,
                                  isDark: isDark,
                                  value: controller.isDarkModeSwitch.value,
                                  onChanged: (value) {
                                    controller.toggleDarkMode(value);
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Share & Rate Section
                            // _buildSectionTitle('Share & Support'.tr, isDark),
                            // const SizedBox(height: 12),
                            // _buildMenuCard(
                            //   isDark: isDark,
                            //   children: [
                            //     _buildMenuItem(
                            //       icon: Icons.share_rounded,
                            //       title: 'Share App'.tr,
                            //       isDark: isDark,
                            //       onTap: () {
                            //         Get.back();
                            //         Share.share(
                            //             '${'Check out eMart, your ultimate food delivery application!'.tr} \n\n${'Google Play:'.tr} ${Constant.googlePlayLink} \n\n${'App Store:'.tr} ${Constant.appStoreLink}',
                            //             subject: 'Look what I made!'.tr);
                            //       },
                            //     ),
                            //     _buildDivider(isDark),
                            //     _buildMenuItem(
                            //       icon: Icons.star_rounded,
                            //       title: 'Rate the App'.tr,
                            //       isDark: isDark,
                            //       iconColor: AppThemeData.warning300,
                            //       onTap: () {
                            //         Get.back();
                            //         final InAppReview inAppReview =
                            //             InAppReview.instance;
                            //         inAppReview.requestReview();
                            //       },
                            //     ),
                            //   ],
                            // ),

                            // const SizedBox(height: 24),

                            // Legal Section
                            _buildSectionTitle('Legal'.tr, isDark),
                            const SizedBox(height: 12),
                            _buildMenuCard(
                              isDark: isDark,
                              children: [
                                _buildMenuItem(
                                  icon: Icons.description_rounded,
                                  title: 'Terms and Conditions'.tr,
                                  isDark: isDark,
                                  isSelected: controller.drawerIndex.value == 8,
                                  onTap: () {
                                    Get.back();
                                    controller.drawerIndex.value = 8;
                                  },
                                ),
                                _buildDivider(isDark),
                                _buildMenuItem(
                                  icon: Icons.privacy_tip_rounded,
                                  title: 'Privacy Policy'.tr,
                                  isDark: isDark,
                                  isSelected: controller.drawerIndex.value == 9,
                                  onTap: () {
                                    Get.back();
                                    controller.drawerIndex.value = 9;
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Logout & Delete Section
                            _buildLogoutButton(context, controller, isDark),
                            const SizedBox(height: 16),
                            _buildDeleteAccountButton(context, isDark),

                            const SizedBox(height: 24),

                            // Version
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
    });
  }

  Widget _buildProfileHeader(
      BuildContext context, CabDashBoardController controller, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppThemeData.primary600,
                  AppThemeData.primary500,
                ]
              : [
                  AppThemeData.primary300,
                  AppThemeData.primary400,
                ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          children: [
            Row(
              children: [
                // Profile Image with Border
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: NetworkImageWidget(
                      imageUrl: controller.userModel.value.profilePictureURL
                              ?.toString() ??
                          "",
                      height: 60,
                      width: 60,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.userModel.value.fullName().tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: AppThemeData.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.userModel.value.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontFamily: AppThemeData.regular,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Edit Profile Button
                GestureDetector(
                  onTap: () {
                    Get.back();
                    Get.to(const EditProfileScreen());
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(CabDashBoardController controller, bool isDark) {
    final isActive = controller.userModel.value.isActive ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  const Color(0xFF00C853).withOpacity(0.15),
                  const Color(0xFF69F0AE).withOpacity(0.1),
                ]
              : [
                  AppThemeData.grey300.withOpacity(0.15),
                  AppThemeData.grey200.withOpacity(0.1),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFF00C853).withOpacity(0.3)
              : (isDark ? AppThemeData.grey700 : AppThemeData.grey300),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF00C853).withOpacity(0.2)
                  : (isDark ? AppThemeData.grey700 : AppThemeData.grey200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isActive
                  ? Icons.wifi_tethering_rounded
                  : Icons.wifi_tethering_off_rounded,
              color: isActive
                  ? const Color(0xFF00C853)
                  : (isDark ? AppThemeData.grey400 : AppThemeData.grey500),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Availability Status'.tr,
                  style: TextStyle(
                    color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                    fontSize: 12,
                    fontFamily: AppThemeData.medium,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive ? 'Online - Ready for rides'.tr : 'Offline'.tr,
                  style: TextStyle(
                    color: isActive
                        ? const Color(0xFF00C853)
                        : (isDark
                            ? AppThemeData.grey100
                            : AppThemeData.grey800),
                    fontSize: 15,
                    fontFamily: AppThemeData.semiBold,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: CupertinoSwitch(
              value: isActive,
              activeTrackColor: const Color(0xFF00C853),
              onChanged: (value) async {
                if (Constant.isDriverVerification == true) {
                  if (controller.userModel.value.isDocumentVerify == true) {
                    controller.userModel.value.isActive = value;
                    controller.userModel.value.inProgressOrderID =
                        controller.userModel.value.inProgressOrderID;
                    controller.userModel.value.orderCabRequestData =
                        controller.userModel.value.orderCabRequestData;
                    if (controller.userModel.value.isActive == true) {
                      controller.updateCurrentLocation();
                    }
                    await FireStoreUtils.updateUser(controller.userModel.value);
                  } else {
                    ShowToastDialog.showToast(
                        "Document verification is pending. Please proceed to set up your document verification."
                            .tr);
                  }
                } else {
                  controller.userModel.value.isActive = value;
                  controller.userModel.value.inProgressOrderID =
                      controller.userModel.value.inProgressOrderID;
                  controller.userModel.value.orderCabRequestData =
                      controller.userModel.value.orderCabRequestData;
                  if (controller.userModel.value.isActive == true) {
                    controller.updateCurrentLocation();
                  }
                  await FireStoreUtils.updateUser(controller.userModel.value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
          fontSize: 11,
          fontFamily: AppThemeData.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuCard(
      {required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.grey800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required bool isDark,
    bool isSelected = false,
    String? badgeText,
    Color? badgeColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppThemeData.primary300.withOpacity(0.15)
                      : (isDark ? AppThemeData.grey700 : AppThemeData.grey100),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ??
                      (isSelected
                          ? AppThemeData.primary300
                          : (isDark
                              ? AppThemeData.grey300
                              : AppThemeData.grey600)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? AppThemeData.primary300
                        : (isDark
                            ? AppThemeData.grey100
                            : AppThemeData.grey800),
                    fontSize: 15,
                    fontFamily: isSelected
                        ? AppThemeData.semiBold
                        : AppThemeData.medium,
                  ),
                ),
              ),
              if (badgeText != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? AppThemeData.primary300)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor ?? AppThemeData.primary300,
                      fontSize: 11,
                      fontFamily: AppThemeData.semiBold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchMenuItem({
    required IconData icon,
    required String title,
    required bool isDark,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppThemeData.grey700 : AppThemeData.grey100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                fontSize: 15,
                fontFamily: AppThemeData.medium,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: CupertinoSwitch(
              value: value,
              activeTrackColor: AppThemeData.primary300,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 58,
      color: isDark ? AppThemeData.grey700 : AppThemeData.grey100,
    );
  }

  Widget _buildLogoutButton(
      BuildContext context, CabDashBoardController controller, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Get.back();
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return CustomDialogBox(
                  title: "Log out".tr,
                  descriptions:
                      "Are you sure you want to log out? You will need to enter your credentials to log back in."
                          .tr,
                  positiveString: "Log out".tr,
                  negativeString: "Cancel".tr,
                  positiveClick: () async {
                    await AudioPlayerService.playSound(false);
                    final userModel = controller.userModel.value;
                    if (userModel.id != null && userModel.id!.isNotEmpty) {
                      userModel.fcmToken = "";
                      unawaited(
                          FireStoreUtils.updateUser(userModel).catchError((e) {
                        log("Logout: Failed to update user FCM token: $e");
                        return false;
                      }));
                    }
                    await FirebaseAuth.instance.signOut();
                    Get.offAll(const AuthScreen());
                  },
                  negativeClick: () {
                    Get.back();
                  },
                  img: Image.asset(
                    'assets/images/ic_logout.gif',
                    height: 50,
                    width: 50,
                  ),
                );
              });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppThemeData.danger300.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppThemeData.danger300.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                color: AppThemeData.danger300,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Log Out'.tr,
                style: TextStyle(
                  color: AppThemeData.danger300,
                  fontSize: 15,
                  fontFamily: AppThemeData.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton(BuildContext context, bool isDark) {
    return Center(
      child: TextButton(
        onPressed: () {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return CustomDialogBox(
                  title: "Delete Account".tr,
                  descriptions:
                      "Are you sure you want to delete your account? This action is irreversible and will permanently remove all your data."
                          .tr,
                  positiveString: "Delete".tr,
                  negativeString: "Cancel".tr,
                  positiveClick: () async {
                    ShowToastDialog.showLoader("Please wait".tr);
                    await FireStoreUtils.deleteUser().then((value) {
                      ShowToastDialog.closeLoader();
                      if (value == true) {
                        ShowToastDialog.showToast(
                            "Account deleted successfully".tr);
                        Get.offAll(const AuthScreen());
                      } else {
                        ShowToastDialog.showToast("Contact Administrator".tr);
                      }
                    });
                  },
                  negativeClick: () {
                    Get.back();
                  },
                  img: Image.asset(
                    'assets/icons/delete_dialog.gif',
                    height: 50,
                    width: 50,
                  ),
                );
              });
        },
        child: Text(
          'Delete Account'.tr,
          style: TextStyle(
            color: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
            fontSize: 13,
            fontFamily: AppThemeData.medium,
            decoration: TextDecoration.underline,
            decorationColor:
                isDark ? AppThemeData.grey500 : AppThemeData.grey400,
          ),
        ),
      ),
    );
  }
}
