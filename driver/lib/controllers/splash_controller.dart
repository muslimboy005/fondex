import 'dart:async';
import 'dart:developer';

import 'package:driver/app/auth_screen/auth_screen.dart';
import 'package:driver/app/cab_screen/cab_dashboard_screen.dart';
import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/app/maintenance_mode_screen/maintenance_mode_screen.dart';
import 'package:driver/app/on_boarding_screen.dart';
import 'package:driver/app/owner_screen/owner_dashboard_screen.dart';
import 'package:driver/app/parcel_screen/parcel_dashboard_screen.dart';
import 'package:driver/app/rental_service/rental_dashboard_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:driver/utils/preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    Timer(const Duration(seconds: 3), () => redirectScreen());
    super.onInit();
  }

  Future<void> redirectScreen() async {
    try {
      log("🚀 [SPLASH] redirectScreen boshlandi");

      if (Constant.isMaintenanceModeForDriver == true) {
        log("🚀 [SPLASH] Maintenance mode - MaintenanceModeScreen ga o'tmoqda");
        Get.offAll(const MaintenanceModeScreen());
        return;
      }

      final isOnBoardingFinished =
          Preferences.getBoolean(Preferences.isFinishOnBoardingKey);
      log("🚀 [SPLASH] OnBoarding tugaganmi: $isOnBoardingFinished");

      if (isOnBoardingFinished == false) {
        log("🚀 [SPLASH] OnBoarding tugamagan - OnboardingScreen ga o'tmoqda");
        Get.offAll(const OnboardingScreen());
        return;
      }

      log("🚀 [SPLASH] Login holatini tekshiryapmiz...");
      bool isLogin = await FireStoreUtils.isLogin();
      log("🚀 [SPLASH] isLogin natijasi: $isLogin");

      if (isLogin == true) {
        final currentUid = FireStoreUtils.getCurrentUid();
        log("🚀 [SPLASH] Current UID: $currentUid");
        log("🚀 [SPLASH] getUserProfile chaqirilmoqda...");

        await FireStoreUtils.getUserProfile(currentUid).then((value) async {
          log("🚀 [SPLASH] getUserProfile natijasi: ${value != null ? 'user topildi' : 'user topilmadi'}");

          if (value != null) {
            try {
              UserModel userModel = value;
              log("🚀 [SPLASH] UserModel olingan: ${userModel.id}");
              log("🚀 [SPLASH] User role: ${userModel.role}");
              log("🚀 [SPLASH] User active: ${userModel.active}");
              log("🚀 [SPLASH] User serviceType: ${userModel.serviceType}");
              log("🚀 [SPLASH] User isOwner: ${userModel.isOwner}");
              log(userModel.toJson().toString());

              if (userModel.role == Constant.userRoleDriver) {
                log("🚀 [SPLASH] User role to'g'ri (driver)");

                if (userModel.active == true) {
                  // Force driver home to open with in-app Yandex map for auto orders
                  Constant.selectedMapType = 'yandexMaps';
                  Constant.mapType = 'inappmap';
                  Constant.singleOrderReceive = true;

                  log("🚀 [SPLASH] User active - FCM token olinmoqda...");
                  try {
                    userModel.fcmToken = await NotificationService.getToken();
                    log("🚀 [SPLASH] FCM token olingan: ${userModel.fcmToken?.substring(0, 20)}...");
                  } catch (e) {
                    log("❌ [SPLASH] FCM token olishda xatolik: $e");
                    // Continue even if FCM fails
                  }

                  // Update user in background (non-blocking) with timeout
                  log("🚀 [SPLASH] updateUser chaqirilmoqda (non-blocking)...");
                  unawaited(
                    FireStoreUtils.updateUser(userModel).timeout(
                      const Duration(seconds: 5),
                      onTimeout: () {
                        log("⏱️ [SPLASH] updateUser timeout (5 sekund)");
                        return false;
                      },
                    ).catchError((error) {
                      log("❌ [SPLASH] updateUser xatosi: $error");
                      return false;
                    }),
                  );
                  log("🚀 [SPLASH] updateUser background'da ishlayapti, navigation davom etmoqda...");

                  // Navigate immediately without waiting for updateUser
                  if (userModel.isOwner == true) {
                    log("🚀 [SPLASH] Owner user - OwnerDashboardScreen ga o'tmoqda");
                    Get.offAll(() => OwnerDashboardScreen());
                  } else {
                    final st = userModel.serviceType ?? '';
                    log("🚀 [SPLASH] serviceType: $st");

                    if (st == "delivery_service" || st == "delivery-service") {
                      log("🚀 [SPLASH] DashBoardScreen ga o'tmoqda");
                      Get.offAll(() => const DashBoardScreen());
                    } else if (st == "cab_service" || st == "cab-service") {
                      log("🚀 [SPLASH] CabDashboardScreen ga o'tmoqda");
                      Get.offAll(() => const CabDashboardScreen());
                    } else if (st == "parcel_delivery") {
                      log("🚀 [SPLASH] ParcelDashboardScreen ga o'tmoqda");
                      Get.offAll(() => const ParcelDashboardScreen());
                    } else if (st == "rental_service" || st == "rental-service") {
                      log("🚀 [SPLASH] RentalDashboardScreen ga o'tmoqda");
                      Get.offAll(() => const RentalDashboardScreen());
                    } else {
                      log("❌ [SPLASH] Noma'lum serviceType: $st - AuthScreen ga o'tmoqda");
                      unawaited(FirebaseAuth.instance.signOut());
                      Get.offAll(const AuthScreen());
                    }
                  }
                } else {
                  log("❌ [SPLASH] User active emas - AuthScreen ga o'tmoqda");
                  await FirebaseAuth.instance.signOut();
                  Get.offAll(const AuthScreen());
                }
              } else {
                log("❌ [SPLASH] User role noto'g'ri: ${userModel.role} - AuthScreen ga o'tmoqda");
                await FirebaseAuth.instance.signOut();
                Get.offAll(const AuthScreen());
              }
            } catch (e) {
              log("❌ [SPLASH] UserModel ishlatishda xatolik: $e");
              await FirebaseAuth.instance.signOut();
              Get.offAll(const AuthScreen());
            }
          } else {
            log("❌ [SPLASH] getUserProfile null qaytdi - AuthScreen ga o'tmoqda");
            await FirebaseAuth.instance.signOut();
            Get.offAll(const AuthScreen());
          }
        }).catchError((error) {
          log("❌ [SPLASH] getUserProfile xatosi: $error");
          FirebaseAuth.instance.signOut().then((_) {
            Get.offAll(const AuthScreen());
          });
        });
      } else {
        log("🚀 [SPLASH] Login qilinmagan - AuthScreen ga o'tmoqda");
        await FirebaseAuth.instance.signOut();
        Get.offAll(const AuthScreen());
      }
    } catch (e, stackTrace) {
      log("❌ [SPLASH] redirectScreen umumiy xatosi: $e");
      log("❌ [SPLASH] Stack trace: $stackTrace");
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      Get.offAll(const AuthScreen());
    }
  }
}
