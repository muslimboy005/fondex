import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/auth_screen/login_screen.dart';
import 'package:vendor/app/auth_screen/signup_screen.dart';
import 'package:vendor/app/dash_board_screens/app_not_access_screen.dart';
import 'package:vendor/app/dash_board_screens/dash_board_screen.dart';
import 'package:vendor/app/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/notification_service.dart';

class SignupController extends GetxController {
  Rx<TextEditingController> firstNameEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> lastNameEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> emailEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> phoneNUmberEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController =
      TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> passwordEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> conformPasswordEditingController =
      TextEditingController().obs;

  RxBool passwordVisible = true.obs;
  RxBool conformPasswordVisible = true.obs;

  RxString type = "".obs;

  Rx<UserModel> userModel = UserModel().obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  RxBool autoRegister = false.obs;

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      type.value = argumentData['type'];
      userModel.value = argumentData['userModel'];
      autoRegister.value = argumentData['autoRegister'] ?? false;
      if (type.value == "mobileNumber") {
        phoneNUmberEditingController.value.text = userModel.value.phoneNumber
            .toString();
        countryCodeEditingController.value.text = userModel.value.countryCode
            .toString();
        emailEditingController.value.text = userModel.value.email ?? "";
        firstNameEditingController.value.text = userModel.value.firstName ?? "";
        lastNameEditingController.value.text = userModel.value.lastName ?? "";
        // Password is not shown/asked, it's default "123456" in Firebase
        // If autoRegister is true, automatically register
        if (autoRegister.value) {
          // Auto-register after a short delay to ensure UI is ready
          Future.delayed(const Duration(milliseconds: 500), () {
            signUpWithEmailAndPassword();
          });
        }
      } else if (type.value == "google" || type.value == "apple") {
        emailEditingController.value.text = userModel.value.email ?? "";
        firstNameEditingController.value.text = userModel.value.firstName ?? "";
        lastNameEditingController.value.text = userModel.value.lastName ?? "";
      }
    }
  }

  Future<void> signUpWithEmailAndPassword() async {
    signUp();
  }

  Future<void> signUp() async {
    ShowToastDialog.showLoader("Please wait".tr);
    if (type.value == "google" ||
        type.value == "apple" ||
        type.value == "mobileNumber") {
      userModel.value.firstName = firstNameEditingController.value.text
          .toString();
      userModel.value.lastName = lastNameEditingController.value.text
          .toString();
      userModel.value.email = emailEditingController.value.text
          .toString()
          .toLowerCase();
      userModel.value.phoneNumber = phoneNUmberEditingController.value.text
          .toString();
      userModel.value.role = Constant.userRoleVendor;
      userModel.value.fcmToken = await NotificationService.getToken();
      userModel.value.active = Constant.autoApproveVendor == true
          ? true
          : false;
      userModel.value.countryCode = countryCodeEditingController.value.text;
      userModel.value.isDocumentVerify = Constant.isStoreVerification == true
          ? false
          : true;
      userModel.value.createdAt = Timestamp.now();
      userModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';

      // If autoRegister is true and email is empty, generate a default email
      if (autoRegister.value && (userModel.value.email == null || userModel.value.email!.isEmpty)) {
        userModel.value.email = "${userModel.value.phoneNumber}@vendor.emart";
      }

      // If autoRegister is true, create email account with default password
      if (autoRegister.value && type.value == "mobileNumber") {
        try {
          // Create email account with default password
          final credential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: userModel.value.email!,
                password: "123456",
              );
          if (credential.user != null) {
            userModel.value.id = credential.user!.uid;
            userModel.value.provider = 'phone';
          }
        } catch (e) {
          ShowToastDialog.closeLoader();
          if (e.toString().contains('email-already-in-use')) {
            // Email already exists, try to sign in and link phone
            try {
              await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: userModel.value.email!,
                password: "123456",
              );
              userModel.value.id = FirebaseAuth.instance.currentUser!.uid;
            } catch (signInError) {
              ShowToastDialog.showToast("Registration failed. Please try again.".tr);
              return;
            }
          } else {
            ShowToastDialog.showToast("Registration failed. Please try again.".tr);
            return;
          }
        }
      }

      await FireStoreUtils.updateUser(userModel.value).then((value) async {
        ShowToastDialog.closeLoader();
        if (autoRegister.value) {
          // After auto-registration, navigate to signup screen (or onboarding)
          ShowToastDialog.showToast("Registration successful".tr);
          Get.offAll(const SignupScreen());
        } else if (Constant.autoApproveVendor == true) {
          bool isPlanExpire = false;
          if (userModel.value.subscriptionPlan?.id != null) {
            if (userModel.value.subscriptionExpiryDate == null) {
              if (userModel.value.subscriptionPlan?.expiryDay == '-1') {
                isPlanExpire = false;
              } else {
                isPlanExpire = true;
              }
            } else {
              DateTime expiryDate = userModel.value.subscriptionExpiryDate!
                  .toDate();
              isPlanExpire = expiryDate.isBefore(DateTime.now());
            }
          } else {
            isPlanExpire = true;
          }
          if (userModel.value.subscriptionPlanId == null ||
              isPlanExpire == true) {
            if (Constant.isSubscriptionModelApplied == false) {
              Get.offAll(const DashBoardScreen());
            } else {
              Get.offAll(const SubscriptionPlanScreen());
            }
          } else if (userModel
                      .value
                      .subscriptionPlan
                      ?.features
                      ?.ownerMobileApp !=
                  false ||
              userModel.value.subscriptionPlan?.type == 'free') {
            Get.offAll(const DashBoardScreen());
          } else {
            Get.offAll(const AppNotAccessScreen());
          }
        } else {
          ShowToastDialog.showToast(
            "Thank you for sign up, your application is under approval so please wait till that approve."
                .tr,
          );
          Get.offAll(const LoginScreen());
        }
      });
    } else {
      try {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: emailEditingController.value.text.trim(),
              password: passwordEditingController.value.text.trim(),
            );
        if (credential.user != null) {
          userModel.value.id = credential.user!.uid;
          userModel.value.firstName = firstNameEditingController.value.text
              .toString();
          userModel.value.lastName = lastNameEditingController.value.text
              .toString();
          userModel.value.email = emailEditingController.value.text
              .toString()
              .toLowerCase();
          userModel.value.phoneNumber = phoneNUmberEditingController.value.text
              .toString();
          userModel.value.role = Constant.userRoleVendor;
          userModel.value.fcmToken = await NotificationService.getToken();
          userModel.value.active = Constant.autoApproveVendor == true
              ? true
              : false;
          userModel.value.isDocumentVerify =
              Constant.isStoreVerification == true ? false : true;
          userModel.value.countryCode = countryCodeEditingController.value.text;
          userModel.value.appIdentifier = Platform.isAndroid
              ? 'android'
              : 'ios';
          userModel.value.createdAt = Timestamp.now();
          userModel.value.provider = 'email';

          await FireStoreUtils.updateUser(userModel.value).then((value) async {
            if (Constant.autoApproveVendor == true) {
              bool isPlanExpire = false;
              if (userModel.value.subscriptionPlan?.id != null) {
                if (userModel.value.subscriptionExpiryDate == null) {
                  if (userModel.value.subscriptionPlan?.expiryDay == '-1') {
                    isPlanExpire = false;
                  } else {
                    isPlanExpire = true;
                  }
                } else {
                  DateTime expiryDate = userModel.value.subscriptionExpiryDate!
                      .toDate();
                  isPlanExpire = expiryDate.isBefore(DateTime.now());
                }
              } else {
                isPlanExpire = true;
              }
              if (userModel.value.subscriptionPlanId == null ||
                  isPlanExpire == true) {
                if (Constant.isSubscriptionModelApplied == false) {
                  Get.offAll(const DashBoardScreen());
                } else {
                  Get.offAll(const SubscriptionPlanScreen());
                }
              } else if (userModel
                          .value
                          .subscriptionPlan
                          ?.features
                          ?.ownerMobileApp !=
                      false ||
                  userModel.value.subscriptionPlan?.type == 'free') {
                Get.offAll(const DashBoardScreen());
              } else {
                Get.offAll(const AppNotAccessScreen());
              }
            } else {
              ShowToastDialog.showToast(
                "Thank you for sign up, your application is under approval so please wait till that approve."
                    .tr,
              );
              Get.offAll(const LoginScreen());
            }
          });
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          ShowToastDialog.showToast("The password provided is too weak.".tr);
        } else if (e.code == 'email-already-in-use') {
          ShowToastDialog.showToast(
            "The account already exists for that email.".tr,
          );
        } else if (e.code == 'invalid-email') {
          ShowToastDialog.showToast("Enter email is Invalid".tr);
        }
      } catch (e) {
        ShowToastDialog.showToast(e.toString());
      }
    }

    ShowToastDialog.closeLoader();
  }
}
