import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/auth_screen/login_screen.dart';
import 'package:vendor/app/auth_screen/otp_screen.dart';
import 'package:vendor/app/dash_board_screens/app_not_access_screen.dart';
import 'package:vendor/app/dash_board_screens/dash_board_screen.dart';
import 'package:vendor/app/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/notification_service.dart';

class PhoneNumberController extends GetxController {
  Rx<TextEditingController> phoneNUmberEditingController = TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController = TextEditingController(text: Constant.defaultCountryCode).obs;

  Future<void> sendCode() async {
    if (phoneNUmberEditingController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter mobile number".tr);
      return;
    }

    ShowToastDialog.showLoader("please wait...".tr);
    
    // Check if user exists by phone number
    UserModel? existingUser = await FireStoreUtils.getUserByPhoneNumber(
      countryCodeEditingController.value.text,
      phoneNUmberEditingController.value.text,
    );

    ShowToastDialog.closeLoader();

    if (existingUser == null) {
      // User doesn't exist, show dialog for first name and last name
      _showNameDialog();
    } else {
      // User exists, proceed with OTP
      await _sendOTP();
    }
  }

  Future<void> _sendOTP() async {
    ShowToastDialog.showLoader("please wait...".tr);
    await FirebaseAuth.instance
        .verifyPhoneNumber(
          phoneNumber: countryCodeEditingController.value.text + phoneNUmberEditingController.value.text,
          verificationCompleted: (PhoneAuthCredential credential) {},
          verificationFailed: (FirebaseAuthException e) {
            debugPrint("FirebaseAuthException--->${e.message}");
            ShowToastDialog.closeLoader();
            if (e.code == 'invalid-phone-number') {
              ShowToastDialog.showToast("invalid_phone_number".tr);
            } else {
              ShowToastDialog.showToast(e.message);
            }
          },
          codeSent: (String verificationId, int? resendToken) {
            ShowToastDialog.closeLoader();
            Get.to(const OtpScreen(), arguments: {"countryCode": countryCodeEditingController.value.text, "phoneNumber": phoneNUmberEditingController.value.text, "verificationId": verificationId});
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        )
        .catchError((error) {
          debugPrint("catchError--->$error");
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("multiple_time_request".tr);
        });
  }

  void _showNameDialog() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    
    Get.dialog(
      Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter Your Name".tr,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(
                  labelText: "First Name".tr,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                  labelText: "Last Name".tr,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text("Cancel".tr),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      if (firstNameController.text.trim().isEmpty) {
                        ShowToastDialog.showToast("Please enter first name".tr);
                        return;
                      }
                      if (lastNameController.text.trim().isEmpty) {
                        ShowToastDialog.showToast("Please enter last name".tr);
                        return;
                      }
                      Get.back();
                      // Register directly without going to signup screen
                      await _registerUser(
                        firstNameController.text.trim(),
                        lastNameController.text.trim(),
                      );
                    },
                    child: Text("OK".tr),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _registerUser(String firstName, String lastName) async {
    ShowToastDialog.showLoader("Please wait".tr);
    
    try {
      // Create user model
      UserModel userModel = UserModel();
      userModel.countryCode = countryCodeEditingController.value.text;
      userModel.phoneNumber = phoneNUmberEditingController.value.text;
      userModel.firstName = firstName;
      userModel.lastName = lastName;
      userModel.email = "${userModel.phoneNumber}@vendor.emart";
      userModel.role = Constant.userRoleVendor;
      userModel.fcmToken = await NotificationService.getToken();
      userModel.active = Constant.autoApproveVendor == true ? true : false;
      userModel.countryCode = countryCodeEditingController.value.text;
      userModel.isDocumentVerify = Constant.isStoreVerification == true ? false : true;
      userModel.createdAt = Timestamp.now();
      userModel.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
      userModel.provider = 'phone';

      // Create email account with default password
      try {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: userModel.email!,
              password: "123456",
            );
        if (credential.user != null) {
          userModel.id = credential.user!.uid;
        }
      } catch (e) {
        if (e.toString().contains('email-already-in-use')) {
          // Email already exists, try to sign in
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: userModel.email!,
              password: "123456",
            );
            userModel.id = FirebaseAuth.instance.currentUser!.uid;
          } catch (signInError) {
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Registration failed. Please try again.".tr);
            return;
          }
        } else {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("Registration failed. Please try again.".tr);
          return;
        }
      }

      // Save user to Firestore
      await FireStoreUtils.updateUser(userModel).then((value) async {
        // Update Constant.userModel
        Constant.userModel = userModel;
        
        // Check sectionId if exists
        if (userModel.sectionId != null && userModel.sectionId!.isNotEmpty) {
          await FireStoreUtils.getSectionById(userModel.sectionId.toString()).then((value) {
            if (value != null) {
              Constant.selectedSection = value;
            }
          });
        }
        
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Registration successful".tr);
        
        // Navigate to dashboard based on approval status
        if (Constant.autoApproveVendor == true) {
          bool isPlanExpire = false;
          if (userModel.subscriptionPlan?.id != null) {
            if (userModel.subscriptionExpiryDate == null) {
              if (userModel.subscriptionPlan?.expiryDay == '-1') {
                isPlanExpire = false;
              } else {
                isPlanExpire = true;
              }
            } else {
              DateTime expiryDate = userModel.subscriptionExpiryDate!.toDate();
              isPlanExpire = expiryDate.isBefore(DateTime.now());
            }
          } else {
            isPlanExpire = true;
          }

          if (userModel.subscriptionPlanId == null || isPlanExpire == true) {
            if (userModel.sectionId == null || (userModel.sectionId != null && userModel.sectionId!.isEmpty) && Constant.isSubscriptionModelApplied == false) {
              Get.offAll(const DashBoardScreen());
            } else {
              Get.offAll(const SubscriptionPlanScreen());
            }
          } else if (userModel.subscriptionPlan?.features?.ownerMobileApp == true) {
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
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Registration failed. Please try again.".tr);
    }
  }
}
