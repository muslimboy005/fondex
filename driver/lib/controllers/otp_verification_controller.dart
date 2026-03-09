import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../app/auth_screen/auth_screen.dart';
import '../app/auth_screen/signup_screen.dart';
import '../app/cab_screen/cab_dashboard_screen.dart';
import '../app/dash_board_screen/dash_board_screen.dart';
import '../app/owner_screen/owner_dashboard_screen.dart';
import '../app/parcel_screen/parcel_dashboard_screen.dart';
import '../app/rental_service/rental_dashboard_screen.dart';
import '../constant/constant.dart';
import '../models/user_model.dart';
import '../utils/fire_store_utils.dart';
import '../utils/notification_service.dart';

/// Default hisob – faqat telefon OTP da akkaunt yo‘q bo‘lganda yashirin ishlatiladi (foydalanuvchiga ko‘rinmasin)
const String _kDefaultEmail = '943015405@gmail.com';
const String _kDefaultPassword = '123456';

class OtpVerifyController extends GetxController {
  /// Use a normal controller (NOT obs)
  final Rx<TextEditingController> otpController = TextEditingController().obs;

  /// Reactive Strings
  final RxString countryCode = "".obs;
  final RxString phoneNumber = "".obs;
  final RxString verificationId = "".obs;
  final RxString expectedOtp = "".obs;
  final RxBool isRegistration = false.obs;
  RxInt resendToken = 0.obs;

  /// Timer for OTP expiration
  Timer? _otpTimer;
  final RxInt remainingSeconds = 60.obs;
  final RxBool canResend = false.obs;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments ?? {};

    log("🔐 OTP Verification Controller Initialized");
    log("Arguments: $args");

    countryCode.value = args['countryCode'] ?? "";
    phoneNumber.value = args['phoneNumber'] ?? "";
    verificationId.value = args['verificationId'] ?? "";
    expectedOtp.value = args['otp'] ?? "";
    isRegistration.value = args['isRegistration'] ?? false;

    log("Country Code: ${countryCode.value}");
    log("Phone Number: ${phoneNumber.value}");
    log("Verification ID: ${verificationId.value}");
    log("Expected OTP: ${expectedOtp.value}");
    log("Is Registration: ${isRegistration.value}");

    // Start OTP expiration timer
    startOtpTimer();
  }

  /// Start 1 minute countdown timer
  void startOtpTimer() {
    canResend.value = false;
    remainingSeconds.value = 60;

    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      } else {
        timer.cancel();
        canResend.value = true;
        log("⏰ OTP timer expired, resend enabled");
      }
    });
  }

  /// Format seconds to MM:SS
  String get formattedTime {
    final minutes = remainingSeconds.value ~/ 60;
    final seconds = remainingSeconds.value % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  Future<bool> sendOTP() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: countryCode.value + phoneNumber.value,
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {},
      codeSent: (String verificationId0, int? resendToken0) async {
        verificationId.value = verificationId0;
        resendToken.value = resendToken0!;
        ShowToastDialog.showToast("OTP sent".tr);
        // Restart timer when OTP is resent
        startOtpTimer();
      },
      timeout: const Duration(seconds: 25),
      forceResendingToken: resendToken.value,
      codeAutoRetrievalTimeout: (String verificationId0) {
        verificationId0 = verificationId.value;
      },
    );
    return true;
  }

  void verifyOtp() async {
    final enteredOtp = otpController.value.text.trim();
    log("🔐 OTP Verification Started");
    log("Entered OTP: $enteredOtp (length: ${enteredOtp.length})");

    if (enteredOtp.length != 6) {
      log("❌ Error: OTP length is ${enteredOtp.length}, expected 6");
      ShowToastDialog.showToast("Enter valid 6-digit OTP".tr);
      return;
    }

    // Handle new registration flow
    if (isRegistration.value) {
      log("📱 Using new registration flow");
      await verifyRegistrationOtp();
      return;
    }

    log("🔥 Using Firebase phone auth flow");

    // Handle Firebase phone auth flow
    try {
      ShowToastDialog.showLoader("Verifying OTP...".tr);

      log("🔑 Creating Firebase credential");
      log("Verification ID: ${verificationId.value}");
      log("SMS Code: ${otpController.value.text.trim()}");

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId.value,
        smsCode: otpController.value.text.trim(),
      );

      log("📱 Getting FCM token");
      final fcmToken = await NotificationService.getToken();
      log("FCM Token: $fcmToken");

      log("🔐 Signing in with credential");
      final result = await _auth.signInWithCredential(credential);
      log("✅ Firebase sign in successful");
      log("User ID: ${result.user?.uid}");
      log("Is New User: ${result.additionalUserInfo?.isNewUser}");

      if (result.additionalUserInfo?.isNewUser == true) {
        final userModel = UserModel(
          id: result.user!.uid,
          countryCode: countryCode.value,
          phoneNumber: phoneNumber.value,
          fcmToken: fcmToken,
          active: true,
        );
        ShowToastDialog.closeLoader();
        Get.to(
          () => const SignupScreen(),
          arguments: {'type': 'mobileNumber', 'userModel': userModel},
        );
        return;
      }

      final exists = await FireStoreUtils.userExistOrNot(result.user!.uid);
      ShowToastDialog.closeLoader();

      if (!exists) {
        await _auth.signOut();
        final ok = await _silentLoginWithDefaultAccount(
          phoneNumber.value,
          countryCode.value,
        );
        if (!ok) {
          final userModel = UserModel(
            id: result.user!.uid,
            countryCode: countryCode.value,
            phoneNumber: phoneNumber.value,
            fcmToken: fcmToken,
          );
          Get.off(
            () => const SignupScreen(),
            arguments: {'type': 'mobileNumber', 'userModel': userModel},
          );
        }
        return;
      }

      final userModel = await FireStoreUtils.getUserProfile(result.user!.uid);
      if (userModel == null || userModel.role != Constant.userRoleDriver) {
        await _auth.signOut();
        Get.offAll(() => const AuthScreen());
        return;
      }

      if (userModel.active == false) {
        ShowToastDialog.showToast("This user is disabled".tr);
        await _auth.signOut();
        Get.offAll(() => const AuthScreen());
        return;
      }

      userModel.fcmToken = fcmToken;
      await FireStoreUtils.updateUser(userModel);

      // Navigate based on isOwner and serviceType (delivery_service yoki delivery-service)
      final st = userModel.serviceType ?? '';
      if (userModel.isOwner == true) {
        Get.offAll(() => OwnerDashboardScreen());
      } else if (st == "delivery_service" || st == "delivery-service") {
        Get.offAll(() => const DashBoardScreen());
      } else if (st == "cab_service" || st == "cab-service") {
        Get.offAll(() => const CabDashboardScreen());
      } else if (st == "parcel_delivery") {
        Get.offAll(() => const ParcelDashboardScreen());
      } else if (st == "rental_service" || st == "rental-service") {
        Get.offAll(() => const RentalDashboardScreen());
      } else {
        Get.offAll(() => const SignupScreen());
      }
    } catch (e, stackTrace) {
      log("❌ Firebase OTP Verification Error:");
      log("Error: $e");
      log("Stack trace: $stackTrace");
      ShowToastDialog.closeLoader();

      String errorMessage = "Invalid OTP or Verification Failed".tr;
      if (e is FirebaseAuthException) {
        log("Firebase Auth Error Code: ${e.code}");
        log("Firebase Auth Error Message: ${e.message}");
        if (e.code == 'invalid-verification-code') {
          errorMessage = "Invalid OTP code. Please try again.".tr;
        } else if (e.code == 'session-expired') {
          errorMessage = "OTP session expired. Please request a new code.".tr;
        } else {
          errorMessage = e.message ?? "Verification failed".tr;
        }
      }

      ShowToastDialog.showToast(errorMessage);
    }
  }

  /// Telefon OTP da akkaunt yo‘q bo‘lsa: default email/parol bilan yashirin kirish,
  /// joriy raqamni userga yozish va dashboardga yo‘naltirish. Foydalanuvchiga ko‘rinmaydi.
  Future<bool> _silentLoginWithDefaultAccount(
    String currentPhone,
    String currentCountryCode,
  ) async {
    try {
      log("🔐 Silent login with default account (user not shown)");
      ShowToastDialog.showLoader("Please wait".tr);
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _kDefaultEmail,
        password: _kDefaultPassword,
      );
      final userModel = await FireStoreUtils.getUserProfile(userCredential.user!.uid);
      if (userModel == null || userModel.role != Constant.userRoleDriver) {
        await _auth.signOut();
        ShowToastDialog.closeLoader();
        return false;
      }
      if (userModel.active == false) {
        await _auth.signOut();
        ShowToastDialog.closeLoader();
        return false;
      }
      userModel.phoneNumber = currentPhone;
      userModel.countryCode = currentCountryCode;
      userModel.fcmToken = await NotificationService.getToken();
      await FireStoreUtils.updateUser(userModel);
      ShowToastDialog.closeLoader();
      final st = userModel.serviceType ?? '';
      if (userModel.isOwner == true) {
        Get.offAll(() => OwnerDashboardScreen());
      } else if (st == "delivery_service" || st == "delivery-service") {
        Get.offAll(() => const DashBoardScreen());
      } else if (st == "cab_service" || st == "cab-service") {
        Get.offAll(() => const CabDashboardScreen());
      } else if (st == "parcel_delivery") {
        Get.offAll(() => const ParcelDashboardScreen());
      } else if (st == "rental_service" || st == "rental-service") {
        Get.offAll(() => const RentalDashboardScreen());
      } else {
        Get.offAll(() => const SignupScreen());
      }
      return true;
    } catch (e) {
      log("Silent login failed: $e");
      await _auth.signOut();
      ShowToastDialog.closeLoader();
      return false;
    }
  }

  /// Verify OTP for new registration flow
  Future<void> verifyRegistrationOtp() async {
    try {
      log("═══════════════════════════════════════════════════════════");
      log("🚀 OTP VERIFICATION PROCESS STARTED");
      log("═══════════════════════════════════════════════════════════");

      ShowToastDialog.showLoader("Verifying OTP...".tr);

      final enteredOtp = otpController.value.text.trim();
      final fullPhoneNumber = "${countryCode.value}${phoneNumber.value}";

      log("📱 INPUT DATA:");
      log("   Country Code: ${countryCode.value}");
      log("   Phone Number: ${phoneNumber.value}");
      log("   Full Phone: $fullPhoneNumber");
      log("   Entered OTP: $enteredOtp");
      log("   OTP Length: ${enteredOtp.length}");

      // Call API to verify OTP
      final requestBody = {
        "email": fullPhoneNumber,
        "otp": enteredOtp,
        "role": "driver",
      };

      log("🌐 API REQUEST:");
      log("   URL: https://emart-web.felix-its.uz/confirmOtp");
      log("   Method: POST");
      log("   Headers: Content-Type: application/json");
      log("   Request Body: ${jsonEncode(requestBody)}");
      log("   Timeout: 30 seconds");

      final response = await http
          .post(
        Uri.parse('https://emart-web.felix-its.uz/confirmOtp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          log("⏱️ ❌ ERROR: Request timeout after 30 seconds");
          throw Exception("Request timeout");
        },
      );

      log("📥 API RESPONSE RECEIVED:");
      log("   Status Code: ${response.statusCode}");
      log("   Response Headers: ${response.headers}");
      log("   Response Body Length: ${response.body.length} characters");
      log("   Response Body: ${response.body}");

      ShowToastDialog.closeLoader();

      if (response.statusCode == 200) {
        log("✅ HTTP Status: 200 OK");
        try {
          log("🔄 PARSING JSON RESPONSE...");
          final data = jsonDecode(response.body);
          log("✅ JSON Parsed Successfully");
          log("📊 RESPONSE DATA:");
          log("   Raw Data: $data");
          log("   Success (sucsses): ${data['sucsses']}");
          log("   Success (success): ${data['success']}");
          log(
            "   Is New: ${data['is_new']} (type: ${data['is_new'].runtimeType})",
          );
          log("   Role: ${data['role']} (type: ${data['role'].runtimeType})");

          final success = data['sucsses'] ?? data['success'] ?? "";
          final isNew = data['is_new'] == true || data['is_new'] == "true";
          final role = data['role'] ?? "";

          log("🔍 VALIDATION:");
          log("   Success Value: '$success'");
          log("   Success Check: ${success.toString().toLowerCase() == "ok"}");
          log("   Is New Value: $isNew");
          log("   Role Value: '$role'");
          log("   Role Check: ${role.toString().toLowerCase() == "driver"}");

          if (success.toString().toLowerCase() != "ok") {
            log("❌ VALIDATION FAILED: Success is not 'ok'");
            log("   Expected: 'ok'");
            log("   Got: '$success'");
            Get.snackbar(
              "Error".tr,
              "OTP xato".tr,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
            return;
          }

          // Check if role is not driver and not empty
          final roleLower = role.toString().toLowerCase();
          if (roleLower.isNotEmpty && roleLower != "driver") {
            log("❌ VALIDATION FAILED: Role is not 'driver' and not empty");
            log("   Expected: 'driver' or empty string");
            log("   Got: '$role'");
            Get.snackbar(
              "Error".tr,
              "Bu raqam bilan boshqa ilovada ro'yxatdan o'tgansiz".tr,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
            return;
          }

          if (roleLower.isEmpty) {
            log("⚠️ WARNING: Role is empty, proceeding anyway");
          }

          log("✅ VALIDATION PASSED");

          // Generate email and password
          log("🔧 GENERATING FIREBASE CREDENTIALS...");
          final originalPhone = phoneNumber.value;
          log("   Original Phone: $originalPhone");

          // Remove + and country code, keep only phone number digits
          final phoneDigits = phoneNumber.value.replaceAll(
            RegExp(r'[^\d]'),
            '',
          );
          log("   Phone Digits Only: $phoneDigits");

          // Email: telefon@gmail.com, parol doim 123456 (Sign up da ko'rinmaydi)
          final firebaseEmail = "$phoneDigits@gmail.com";
          final firebasePassword = "123456";

          log("📧 FIREBASE CREDENTIALS GENERATED (telefon@gmail.com, parol 123456):");
          log("   Email: $firebaseEmail");
          log("   Password: $firebasePassword");
          log("   Phone: $phoneDigits");
          log("   Country Code: ${countryCode.value}");

          if (isNew) {
            // New user - register with Firebase and navigate to signup screen
            log("👤 USER TYPE: NEW USER");
            log("   Action: Registering with Firebase and navigating to signup screen");
            await _registerWithFirebaseAndNavigateToSignup(
              firebaseEmail,
              firebasePassword,
              phoneDigits,
            );
          } else {
            // Existing user - login with Firebase
            log("👤 USER TYPE: EXISTING USER");
            log("   Action: Logging in with Firebase");
            await _loginWithFirebase(firebaseEmail, firebasePassword);
          }
        } catch (parseError, parseStackTrace) {
          log("❌ JSON PARSING ERROR:");
          log("   Error: $parseError");
          log("   Stack Trace: $parseStackTrace");
          log("   Response Body: ${response.body}");
          log("   Response Body Type: ${response.body.runtimeType}");
          Get.snackbar(
            "Error".tr,
            "OTP xato".tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        log("❌ HTTP ERROR:");
        log("   Status Code: ${response.statusCode}");
        log("   Response Body: ${response.body}");
        log("   Response Headers: ${response.headers}");
        Get.snackbar(
          "Error".tr,
          "OTP xato".tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e, stackTrace) {
      log("❌ EXCEPTION IN OTP VERIFICATION:");
      log("   Error Type: ${e.runtimeType}");
      log("   Error Message: $e");
      log("   Stack Trace: $stackTrace");
      ShowToastDialog.closeLoader();
      Get.snackbar(
        "Error".tr,
        "OTP xato".tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    log("═══════════════════════════════════════════════════════════");
    log("🏁 OTP VERIFICATION PROCESS ENDED");
    log("═══════════════════════════════════════════════════════════");
  }

  /// Register with Firebase and navigate to signup screen (no dialog)
  Future<void> _registerWithFirebaseAndNavigateToSignup(
    String email,
    String password,
    String phone,
  ) async {
    log("═══════════════════════════════════════════════════════════");
    log("🔥 FIREBASE REGISTRATION AND NAVIGATION TO SIGNUP");
    log("═══════════════════════════════════════════════════════════");
    log("   Email: $email");
    log("   Phone: $phone");
    log("   Password: $password (hidden)");

    try {
      ShowToastDialog.showLoader("Registering...".tr);
      log("⏳ Creating Firebase user account...");

      // Create user with email and password
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      log("✅ FIREBASE USER CREATED:");
      log("   User ID: ${userCredential.user?.uid}");
      log("   Email: ${userCredential.user?.email}");

      // Get FCM token
      log("📱 Getting FCM token...");
      final fcmToken = await NotificationService.getToken();
      log("✅ FCM Token: $fcmToken");

      // Create user model with empty firstName and lastName (will be filled in signup screen)
      log("👤 Creating UserModel...");
      final userModel = UserModel(
        id: userCredential.user!.uid,
        email: email,
        firstName: "", // Will be filled in signup screen
        lastName: "", // Will be filled in signup screen
        phoneNumber: phone,
        countryCode: countryCode.value,
        fcmToken: fcmToken,
        role: Constant.userRoleDriver,
        active: true,
        createdAt: Timestamp.now(),
        provider: 'phone',
      );

      log("📊 USER MODEL CREATED:");
      log("   ID: ${userModel.id}");
      log("   Email: ${userModel.email}");
      log("   Phone: ${userModel.phoneNumber}");
      log("   Role: ${userModel.role}");

      // Save to Firestore
      log("💾 Saving user to Firestore...");
      await FireStoreUtils.updateUser(userModel);
      log("✅ USER SAVED TO FIRESTORE");

      ShowToastDialog.closeLoader();

      log("🧭 Navigating to SignupScreen...");
      // Navigate to signup screen with pre-filled data (email, phone already set, hidden from user)
      Get.offAll(
        () => const SignupScreen(),
        arguments: {
          'type': 'mobileNumber',
          'userModel': userModel,
        },
      );
      log("✅ Navigation completed");
    } catch (e, stackTrace) {
      log("❌ FIREBASE REGISTRATION ERROR:");
      log("   Error Type: ${e.runtimeType}");
      log("   Error Message: $e");
      log("   Stack Trace: $stackTrace");

      if (e is FirebaseAuthException) {
        log("   Firebase Auth Error Code: ${e.code}");
        log("   Firebase Auth Error Message: ${e.message}");
      }

      ShowToastDialog.closeLoader();
      Get.snackbar(
        "Error".tr,
        "Registration failed. Please try again.".tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    log("═══════════════════════════════════════════════════════════");
  }

  /// Login with Firebase (background)
  Future<void> _loginWithFirebase(String email, String password) async {
    log("═══════════════════════════════════════════════════════════");
    log("🔥 FIREBASE LOGIN STARTED");
    log("═══════════════════════════════════════════════════════════");
    log("📋 LOGIN DATA:");
    log("   Email: $email");
    log("   Password: $password (hidden)");

    try {
      ShowToastDialog.showLoader("Logging in...".tr);
      log("⏳ Signing in with Firebase...");
      log("   Attempting sign in at: ${DateTime.now()}");

      // Sign in with email and password with timeout
      log("   Calling signInWithEmailAndPassword...");
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          log("⏱️ ❌ TIMEOUT: Firebase sign in timed out after 30 seconds");
          throw TimeoutException("Firebase sign in timeout");
        },
      );

      log("✅ FIREBASE LOGIN SUCCESSFUL:");
      log("   Login completed at: ${DateTime.now()}");
      log("   User ID: ${userCredential.user?.uid}");
      log("   Email: ${userCredential.user?.email}");
      log("   Email Verified: ${userCredential.user?.emailVerified}");
      log("   Last Sign In: ${userCredential.user?.metadata.lastSignInTime}");
      log("   Creation Time: ${userCredential.user?.metadata.creationTime}");

      // Get user profile
      log("📥 Fetching user profile from Firestore...");
      log("   User ID to fetch: ${userCredential.user!.uid}");
      log("   Fetching at: ${DateTime.now()}");

      final userModel = await FireStoreUtils.getUserProfile(
        userCredential.user!.uid,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          log(
            "⏱️ ❌ TIMEOUT: Firestore getUserProfile timed out after 15 seconds",
          );
          throw TimeoutException("Firestore getUserProfile timeout");
        },
      );

      log("📥 Firestore response received at: ${DateTime.now()}");

      if (userModel == null) {
        log("❌ ERROR: User profile not found in Firestore");
        log("   User ID: ${userCredential.user!.uid}");
        await FirebaseAuth.instance.signOut();
        log("   Signed out from Firebase");
        Get.snackbar(
          "Error".tr,
          "User not found".tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      log("✅ USER PROFILE RETRIEVED:");
      log("   ID: ${userModel.id}");
      log("   Email: ${userModel.email}");
      log("   Name: ${userModel.firstName} ${userModel.lastName}");
      log("   Phone: ${userModel.phoneNumber}");
      log("   Role: ${userModel.role}");
      log("   Active: ${userModel.active}");

      if (userModel.role != Constant.userRoleDriver) {
        log("❌ ERROR: User role is not driver");
        log("   Expected Role: ${Constant.userRoleDriver}");
        log("   Actual Role: ${userModel.role}");
        await FirebaseAuth.instance.signOut();
        log("   Signed out from Firebase");
        Get.snackbar(
          "Error".tr,
          "User not found".tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      if (userModel.active == false) {
        log("❌ ERROR: User account is disabled");
        await FirebaseAuth.instance.signOut();
        log("   Signed out from Firebase");
        Get.snackbar(
          "Error".tr,
          "This user is disabled".tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Update FCM token
      log("📱 Updating FCM token...");
      log("   Getting FCM token at: ${DateTime.now()}");
      final fcmToken = await NotificationService.getToken();
      log("   New FCM Token: $fcmToken");
      log("   Updating user in Firestore...");
      userModel.fcmToken = fcmToken;
      try {
        await FireStoreUtils.updateUser(userModel).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            log("⏱️ ⚠️ TIMEOUT: Firestore updateUser timed out after 15 seconds");
            throw TimeoutException("Firestore updateUser timeout");
          },
        );
        log("✅ FCM token updated in Firestore");
        log("   Update completed at: ${DateTime.now()}");
      } catch (e) {
        log("⚠️ updateUser failed, continuing login: $e");
      }

      ShowToastDialog.closeLoader();

      // Navigate based on isOwner and serviceType (qabul qilamiz: delivery_service yoki delivery-service)
      log("🧭 Checking user type...");
      if (userModel.isOwner == true) {
        log("   Navigating to Owner Dashboard...");
        Get.offAll(() => OwnerDashboardScreen());
      } else {
        final st = userModel.serviceType ?? '';
        log("   Service Type: $st");
        if (st == "delivery_service" || st == "delivery-service") {
          log("   Navigating to Delivery Dashboard...");
          Get.offAll(() => const DashBoardScreen());
        } else if (st == "cab_service" || st == "cab-service") {
          log("   Navigating to Cab Dashboard...");
          Get.offAll(() => const CabDashboardScreen());
        } else if (st == "parcel_delivery") {
          log("   Navigating to Parcel Dashboard...");
          Get.offAll(() => const ParcelDashboardScreen());
        } else if (st == "rental_service" || st == "rental-service") {
          log("   Navigating to Rental Dashboard...");
          Get.offAll(() => const RentalDashboardScreen());
        } else {
          log("   No service type, navigating to Signup...");
          Get.offAll(() => const SignupScreen());
        }
      }
      log("✅ Navigation completed");
    } catch (e, stackTrace) {
      log("❌ FIREBASE LOGIN ERROR:");
      log("   Error occurred at: ${DateTime.now()}");
      log("   Error Type: ${e.runtimeType}");
      log("   Error Message: $e");
      log("   Stack Trace: $stackTrace");

      if (e is FirebaseAuthException) {
        log("   🔥 FIREBASE AUTH EXCEPTION:");
        log("   Error Code: ${e.code}");
        log("   Error Message: ${e.message}");
        log("   Email: ${e.email}");
        log("   Credential: ${e.credential}");
      } else if (e is TimeoutException) {
        log("   ⏱️ TIMEOUT EXCEPTION:");
        log("   Operation timed out");
      }

      ShowToastDialog.closeLoader();

      String errorMessage = "Login failed. Please try again.".tr;
      if (e is FirebaseAuthException) {
        if (e.code == 'user-not-found') {
          errorMessage = "User not found. Please register first.".tr;
        } else if (e.code == 'wrong-password') {
          errorMessage = "Invalid password.".tr;
        } else if (e.code == 'invalid-email') {
          errorMessage = "Invalid email address.".tr;
        } else if (e.code == 'user-disabled') {
          errorMessage = "User account is disabled.".tr;
        } else {
          errorMessage = e.message ?? "Login failed. Please try again.".tr;
        }
      } else if (e is TimeoutException) {
        errorMessage =
            "Login timeout. Please check your internet connection.".tr;
      }

      Get.snackbar(
        "Error".tr,
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    log("═══════════════════════════════════════════════════════════");
    log("🏁 FIREBASE LOGIN ENDED");
    log("═══════════════════════════════════════════════════════════");
  }

  String maskPhoneNumber(String phone) {
    if (phone.length < 4) return phone;

    final first = phone.substring(0, 2);
    final last = phone.substring(phone.length - 2);
    return "$first*** ***$last";
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    otpController.value.dispose();
    super.dispose();
  }
}
