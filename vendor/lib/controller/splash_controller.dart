import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:vendor/app/auth_screen/auth_screen.dart';
import 'package:vendor/app/dash_board_screens/app_not_access_screen.dart';
import 'package:vendor/app/dash_board_screens/dash_board_screen.dart';
import 'package:vendor/app/maintenance_mode_screen/maintenance_mode_screen.dart';
import 'package:vendor/app/on_boarding_screen.dart';
import 'package:vendor/app/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/notification_service.dart';
import 'package:vendor/utils/preferences.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    Timer(const Duration(seconds: 3), () => redirectScreen());
    super.onInit();
  }

  Future<void> redirectScreen() async {
    if (Constant.isMaintenanceModeForVendor == true) {
      Get.offAll(const MaintenanceModeScreen());
      return;
    }
    if (Preferences.getBoolean(Preferences.isFinishOnBoardingKey) == false) {
      Get.offAll(const OnboardingScreen());
    } else {
      bool isLogin = await FireStoreUtils.isLogin();
      if (isLogin == true) {
        await FireStoreUtils.getUserProfile(
          FireStoreUtils.getCurrentUid(),
        ).then((value) async {
          if (value != null) {
            Constant.userModel = value;
            if (Constant.userModel?.role == Constant.userRoleVendor) {
              if (Constant.userModel?.active == true) {
                Constant.userModel?.fcmToken =
                    await NotificationService.getToken();
                await FireStoreUtils.updateUser(Constant.userModel!);
                bool isPlanExpire = false;
                if (Constant.userModel?.subscriptionPlan?.id != null) {
                  if (Constant.userModel?.subscriptionExpiryDate == null) {
                    if (Constant.userModel?.subscriptionPlan?.expiryDay ==
                        '-1') {
                      isPlanExpire = false;
                    } else {
                      isPlanExpire = true;
                    }
                  } else {
                    DateTime expiryDate = Constant
                        .userModel!
                        .subscriptionExpiryDate!
                        .toDate();
                    isPlanExpire = expiryDate.isBefore(DateTime.now());
                  }
                } else {
                  isPlanExpire = true;
                }

                if (value.sectionId != null || value.sectionId!.isNotEmpty) {
                  await FireStoreUtils.getSectionById(
                    value.sectionId.toString(),
                  ).then((value) {
                    if (value != null) {
                      Constant.selectedSection = value;
                    }
                  });
                }

                if (Constant.userModel?.subscriptionPlanId == null ||
                    isPlanExpire == true) {
                  if (Constant.userModel!.sectionId!.isEmpty &&
                      Constant.isSubscriptionModelApplied == false) {
                    Get.offAll(const DashBoardScreen());
                  } else {
                    Get.offAll(const SubscriptionPlanScreen());
                  }
                } else if (Constant
                        .userModel!
                        .subscriptionPlan
                        ?.features
                        ?.ownerMobileApp ==
                    true) {
                  Get.offAll(const DashBoardScreen());
                } else {
                  Get.offAll(const AppNotAccessScreen());
                }
              } else {
                await FirebaseAuth.instance.signOut();
                Get.offAll(const AuthScreen());
              }
            } else {
              await FirebaseAuth.instance.signOut();
              Get.offAll(const AuthScreen());
            }
          }
        });
      } else {
        await FirebaseAuth.instance.signOut();
        Get.offAll(const AuthScreen());
      }
    }
  }
}
