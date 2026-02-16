import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/dash_board_controller.dart';
import 'package:vendor/themes/app_them_data.dart';

class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
        init: DashBoardController(),
        builder: (controller) {
          return PopScope(
            canPop: controller.canPopNow.value,
            onPopInvoked: (didPop) {
              final now = DateTime.now();
              if (controller.currentBackPressTime == null ||
                  now.difference(controller.currentBackPressTime!) >
                      const Duration(seconds: 2)) {
                controller.currentBackPressTime = now;
                controller.canPopNow.value = false;
                ShowToastDialog.showToast("Double press to exit".tr);
                return;
              } else {
                controller.canPopNow.value = true;
              }
            },
            child: controller.isLoading.value
                ? Constant.loader()
                : Scaffold(
                    body:
                        controller.pageList[controller.selectedIndex.value
                            .clamp(0, controller.pageList.length - 1)],
                    bottomNavigationBar: BottomNavigationBar(
                      type: BottomNavigationBarType.fixed,
                      showUnselectedLabels: true,
                      showSelectedLabels: true,
                      selectedFontSize: 12,
                      selectedLabelStyle: const TextStyle(
                        fontFamily: AppThemeData.bold,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontFamily: AppThemeData.bold,
                      ),
                      currentIndex: controller.selectedIndex.value.clamp(
                        0,
                        controller.pageList.length - 1,
                      ),
                      backgroundColor: isDark
                          ? AppThemeData.grey900
                          : AppThemeData.grey50,
                      selectedItemColor: isDark
                          ? AppThemeData.primary300
                          : AppThemeData.primary300,
                      unselectedItemColor: isDark
                          ? AppThemeData.grey300
                          : AppThemeData.grey600,
                      onTap: (int index) {
                        controller.selectedIndex.value = index;
                      },
                      items:
                          controller.sectionModel.value.dineInActive != null &&
                              controller.sectionModel.value.dineInActive == true
                          ? [
                              navigationBarItem(
                                isDark,
                                index: 0,
                                assetIcon: "assets/icons/ic_home_cab.svg",
                                label: 'Home'.tr,
                                controller: controller,
                              ),
                              navigationBarItem(
                                isDark,
                                index: 1,
                                assetIcon: "assets/icons/ic_dinein.svg",
                                label: 'Dine in'.tr,
                                controller: controller,
                              ),
                              navigationBarItem(
                                isDark,
                                index: 2,
                                assetIcon: "assets/icons/ic_menu.svg",
                                label: 'Products'.tr,
                                controller: controller,
                              ),
                              navigationBarItem(
                                isDark,
                                index: 3,
                                assetIcon: "assets/icons/ic_wallet.svg",
                                label: 'Wallet'.tr,
                                controller: controller,
                              ),
                              navigationBarItem(
                                isDark,
                                index: 4,
                                assetIcon: "assets/icons/ic_profile.svg",
                                label: 'Profile'.tr,
                                controller: controller,
                              ),
                            ]
                          : [
                              navigationBarItem(
                                isDark,
                                index: 0,
                                assetIcon: "assets/icons/ic_home_cab.svg",
                                label: 'Home'.tr,
                                controller: controller,
                              ),
                              navigationBarItem(
                                isDark,
                                index: 1,
                                assetIcon: "assets/icons/ic_menu.svg",
                                label: 'Products'.tr,
                                controller: controller,
                              ),
                              navigationBarItem(
                                isDark,
                                index: 2,
                                assetIcon: "assets/icons/ic_wallet.svg",
                                label: 'Wallet'.tr,
                                controller: controller,
                              ),
                              navigationBarItem(
                                isDark,
                                index: 3,
                                assetIcon: "assets/icons/ic_profile.svg",
                                label: 'Profile'.tr,
                                controller: controller,
                              ),
                            ],
                    ),
                  ),
          );
        },
      );
    });
  }

  BottomNavigationBarItem navigationBarItem(
    isDark, {
    required int index,
    required String label,
    required String assetIcon,
    required DashBoardController controller,
  }) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: SvgPicture.asset(
          assetIcon,
          height: 22,
          width: 22,
          color: controller.selectedIndex.value == index
              ? isDark
                    ? AppThemeData.primary300
                    : AppThemeData.primary300
              : isDark
              ? AppThemeData.grey300
              : AppThemeData.grey600,
        ),
      ),
      label: label,
    );
  }
}
