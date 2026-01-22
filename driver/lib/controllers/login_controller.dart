import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:driver/app/auth_screen/signup_screen.dart';
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
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
        ShowToastDialog.showToast("Login failed: ${e.message ?? e.code}".tr);
      }
    } catch (e) {
      print("Login Error: $e");
      ShowToastDialog.showToast("An error occurred. Please try again.".tr);
    } finally {
      ShowToastDialog.closeLoader();
    }
  }

  Future<void> loginWithGoogle() async {
    ShowToastDialog.showLoader("Please wait".tr);
    await signInWithGoogle().then((value) async {
      ShowToastDialog.closeLoader();
      if (value != null) {
        if (value.additionalUserInfo!.isNewUser) {
          UserModel userModel = UserModel();
          userModel.id = value.user!.uid;
          userModel.email = value.user!.email;
          userModel.firstName = value.user!.displayName?.split(' ').first;
          userModel.lastName = value.user!.displayName?.split(' ').last;
          userModel.provider = 'google';

          ShowToastDialog.closeLoader();
          Get.to(const SignupScreen(), arguments: {
            "userModel": userModel,
            "type": "google",
          });
        } else {
          await FireStoreUtils.userExistOrNot(value.user!.uid).then((userExit) async {
            ShowToastDialog.closeLoader();
            if (userExit == true) {
              UserModel? userModel = await FireStoreUtils.getUserProfile(value.user!.uid);
              if (userModel != null && userModel.role == Constant.userRoleDriver) {
                if (userModel.active == true) {
                  userModel.fcmToken = await NotificationService.getToken();
                  await FireStoreUtils.updateUser(userModel);
                  if (userModel.isOwner == true) {
                    Get.offAll(OwnerDashboardScreen());
                  } else {
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
                } else {
                  await FirebaseAuth.instance.signOut();
                  ShowToastDialog.showToast("This user is disable please contact to administrator".tr);
                }
              } else {
                await FirebaseAuth.instance.signOut();
                // ShowToastDialog.showToast("This user is disable please contact to administrator".tr);
              }
            } else {
              UserModel userModel = UserModel();
              userModel.id = value.user!.uid;
              userModel.email = value.user!.email;
              userModel.firstName = value.user!.displayName?.split(' ').first;
              userModel.lastName = value.user!.displayName?.split(' ').last;
              userModel.provider = 'google';

              Get.to(const SignupScreen(), arguments: {
                "userModel": userModel,
                "type": "google",
              });
            }
          });
        }
      }
    });
  }

  Future<void> loginWithApple() async {
    ShowToastDialog.showLoader("Please wait".tr);
    await signInWithApple().then((value) async {
      ShowToastDialog.closeLoader();
      if (value != null) {
        Map<String, dynamic> map = value;
        AuthorizationCredentialAppleID appleCredential = map['appleCredential'];
        UserCredential userCredential = map['userCredential'];
        if (userCredential.additionalUserInfo!.isNewUser) {
          UserModel userModel = UserModel();
          userModel.id = userCredential.user!.uid;
          userModel.email = appleCredential.email;
          userModel.firstName = appleCredential.givenName;
          userModel.lastName = appleCredential.familyName;
          userModel.provider = 'apple';

          ShowToastDialog.closeLoader();
          Get.off(const SignupScreen(), arguments: {
            "userModel": userModel,
            "type": "apple",
          });
        } else {
          await FireStoreUtils.userExistOrNot(userCredential.user!.uid).then((userExit) async {
            ShowToastDialog.closeLoader();
            if (userExit == true) {
              UserModel? userModel = await FireStoreUtils.getUserProfile(userCredential.user!.uid);
              if (userModel != null && userModel.role == Constant.userRoleDriver) {
                if (userModel.active == true) {
                  userModel.fcmToken = await NotificationService.getToken();
                  await FireStoreUtils.updateUser(userModel);
                  if (userModel.isOwner == true) {
                    Get.offAll(OwnerDashboardScreen());
                  } else {
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
                } else {
                  await FirebaseAuth.instance.signOut();
                  ShowToastDialog.showToast("This user is disable please contact to administrator".tr);
                }
              } else {
                await FirebaseAuth.instance.signOut();
                // ShowToastDialog.showToast("This user is disable please contact to administrator".tr);
              }
            } else {
              UserModel userModel = UserModel();
              userModel.id = userCredential.user!.uid;
              userModel.email = appleCredential.email;
              userModel.firstName = appleCredential.givenName;
              userModel.lastName = appleCredential.familyName;
              userModel.provider = 'apple';

              Get.off(const SignupScreen(), arguments: {
                "userModel": userModel,
                "type": "apple",
              });
            }
          });
        }
      }
    });
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      await googleSignIn.initialize();

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();
      if (googleUser.id.isEmpty) return null;

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      return userCredential;
    } catch (e) {
      print("Google Sign-In Error: $e");
      return null;
    }
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>?> signInWithApple() async {
    try {
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      // Request credential for the currently signed in Apple account.
      AuthorizationCredentialAppleID appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
        // webAuthenticationOptions: WebAuthenticationOptions(clientId: clientID, redirectUri: Uri.parse(redirectURL)),
      );

      // Create an `OAuthCredential` from the credential returned by Apple.
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in the user with Firebase. If the nonce we generated earlier does
      // not match the nonce in `appleCredential.identityToken`, sign in will fail.
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      return {"appleCredential": appleCredential, "userCredential": userCredential};
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }
}
