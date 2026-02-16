import 'package:driver/app/cab_screen/cab_dashboard_screen.dart';
import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/app/owner_screen/owner_dashboard_screen.dart';
import 'package:driver/app/parcel_screen/parcel_dashboard_screen.dart';
import 'package:driver/app/rental_service/rental_dashboard_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginController extends GetxController {
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;
  Rx<TextEditingController> passwordEditingController = TextEditingController().obs;

  RxBool passwordVisible = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
  }

  Future<void> loginWithEmailAndPassword() async {
    // Validate email and password before attempting login
    final email = emailEditingController.value.text.toLowerCase().trim();
    final password = passwordEditingController.value.text.trim();
    
    if (email.isEmpty) {
      ShowToastDialog.showToast("Please enter your email address.".tr);
      return;
    }
    
    if (password.isEmpty) {
      ShowToastDialog.showToast("Please enter your password.".tr);
      return;
    }
    
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      UserModel? userModel = await FireStoreUtils.getUserProfile(credential.user!.uid);
      if (userModel?.role == Constant.userRoleDriver) {
        if (userModel?.active == true) {
          userModel?.fcmToken = await NotificationService.getToken();
          await FireStoreUtils.updateUser(userModel!);
          if (Constant.autoApproveDriver == true) {
            if (userModel.isOwner == true) {
              Get.offAll(OwnerDashboardScreen());
            } else {
              print(userModel.serviceType);
              if (userModel.serviceType == "delivery-service") {
                Get.offAll(const DashBoardScreen());
              } else if (userModel.serviceType == "cab-service") {
                Get.offAll(const CabDashboardScreen());
              } else if (userModel.serviceType == "parcel_delivery") {
                Get.offAll(const ParcelDashboardScreen());
              } else if (userModel.serviceType == "rental-service") {
                Get.offAll(const RentalDashboardScreen());
              }
            }
          }
        } else {
          await FirebaseAuth.instance.signOut();
          ShowToastDialog.showToast("This user is disable please contact to administrator".tr);
        }
      } else {
        await FirebaseAuth.instance.signOut();
        ShowToastDialog.showToast("This user is not created in driver application.".tr);
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      if (e.code == 'user-not-found') {
        ShowToastDialog.showToast("No user found for that email.".tr);
      } else if (e.code == 'wrong-password') {
        ShowToastDialog.showToast("Wrong password provided for that user.".tr);
      } else if (e.code == 'invalid-email') {
        ShowToastDialog.showToast("Invalid Email.".tr);
      } else if (e.code == 'invalid-credential') {
        ShowToastDialog.showToast("Invalid email or password. Please check your credentials and try again.".tr);
      } else if (e.code == 'too-many-requests') {
        ShowToastDialog.showToast("Too many failed login attempts. Please try again later.".tr);
      } else if (e.code == 'network-request-failed') {
        ShowToastDialog.showToast("Network error. Please check your internet connection.".tr);
      } else {
        ShowToastDialog.showToast("${'Login failed'.tr}: ${e.message ?? e.code}");
      }
    } catch (e) {
      print("Login Error: $e");
      ShowToastDialog.showToast("An error occurred. Please try again.".tr);
    } finally {
      ShowToastDialog.closeLoader();
    }
  }

}
