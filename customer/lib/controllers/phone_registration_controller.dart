import 'dart:convert';
import 'dart:developer';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../screen_ui/auth_screens/otp_verification_screen.dart';

class PhoneRegistrationController extends GetxController {
  final Rx<TextEditingController> phoneController = TextEditingController().obs;
  final Rx<TextEditingController> countryCodeController =
      TextEditingController(text: "+998").obs;

  final RxBool isLoading = false.obs;

  /// Register user with phone number
  Future<void> registerWithPhone() async {
    final phone = phoneController.value.text.trim();
    final countryCode = countryCodeController.value.text.trim();

    log("📱 Phone Registration Started");
    log("Phone: $phone, Country Code: $countryCode");

    if (phone.isEmpty) {
      log("❌ Error: Phone number is empty");
      ShowToastDialog.showToast("Please enter your phone number".tr);
      return;
    }

    // Validate phone number length (9 digits for Uzbekistan)
    if (phone.length != 9) {
      log("❌ Error: Phone number length is ${phone.length}, expected 9");
      ShowToastDialog.showToast("Please enter a valid 9-digit phone number".tr);
      return;
    }

    try {
      isLoading.value = true;
      ShowToastDialog.showLoader("Registering...".tr);

      final fullPhoneNumber = "$countryCode$phone";
      final requestBody = {
        "userId": "test-uuid-12345",
        "email": fullPhoneNumber,
        "password": "Test1234!",
        "firstName": "Hurmatli",
        "lastName": "Mijoz",
      };

      log("🌐 API Request:");
      log("URL: https://emart-web.felix-its.uz/newRegister");
      log("Full Phone: $fullPhoneNumber");
      log("Request Body: ${jsonEncode(requestBody)}");

      final response = await http
          .post(
            Uri.parse('https://emart-web.felix-its.uz/newRegister'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              log("⏱️ Error: Request timeout");
              throw Exception("Request timeout");
            },
          );

      log("📥 API Response:");
      log("Status Code: ${response.statusCode}");
      log("Response Body: ${response.body}");

      ShowToastDialog.closeLoader();
      isLoading.value = false;

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          log("✅ Response parsed successfully");
          log("Access: ${data['access']}");
          log("OTP: ${data['otp']}");
          log("Message: ${data['message']}");

          if (data['access'] == true && data['otp'] != null) {
            log("✅ Registration successful, navigating to OTP screen");
            // Navigate to OTP screen with the OTP code
            Get.to(
              () => const OtpVerificationScreen(),
              arguments: {
                'countryCode': countryCode,
                'phoneNumber': phone,
                'otp': data['otp'].toString(),
                'isRegistration': true,
              },
            );
          } else {
            log("❌ Error: access is false or OTP is null");
            log("Access: ${data['access']}, OTP: ${data['otp']}");
            ShowToastDialog.showToast(
              data['message'] ?? "Registration failed".tr,
            );
          }
        } catch (parseError) {
          log("❌ Error parsing response: $parseError");
          log("Response body: ${response.body}");
          ShowToastDialog.showToast("Invalid response from server".tr);
        }
      } else {
        log("❌ Error: HTTP ${response.statusCode}");

        // Check if response is HTML (404 page, etc.)
        final isHtml =
            response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html') ||
            response.body.contains('<!DOCTYPE') ||
            response.body.contains('<html');

        if (isHtml) {
          log("❌ Error: Server returned HTML instead of JSON");
          String errorMessage;
          if (response.statusCode == 404) {
            errorMessage = "API endpoint not found. Please contact support.".tr;
          } else if (response.statusCode == 500) {
            errorMessage = "Server error. Please try again later.".tr;
          } else {
            errorMessage = "Registration failed (${response.statusCode})".tr;
          }
          ShowToastDialog.showToast(errorMessage);
        } else {
          // Try to parse as JSON
          try {
            final errorData = jsonDecode(response.body);
            log("Error data: $errorData");
            final message =
                errorData['message']?.toString() ??
                errorData['error']?.toString() ??
                "Registration failed (${response.statusCode})".tr;
            // Limit message length to prevent overflow
            final shortMessage =
                message.length > 100
                    ? "${message.substring(0, 100)}..."
                    : message;
            ShowToastDialog.showToast(shortMessage);
          } catch (e) {
            log("❌ Error parsing error response: $e");
            String errorMessage;
            if (response.statusCode == 404) {
              errorMessage =
                  "API endpoint not found. Please contact support.".tr;
            } else if (response.statusCode == 500) {
              errorMessage = "Server error. Please try again later.".tr;
            } else {
              errorMessage = "Registration failed (${response.statusCode})".tr;
            }
            ShowToastDialog.showToast(errorMessage);
          }
        }
      }
    } catch (e, stackTrace) {
      log("❌ Exception occurred:");
      log("Error: $e");
      log("Stack trace: $stackTrace");
      ShowToastDialog.closeLoader();
      isLoading.value = false;

      String errorMessage = "Something went wrong. Please try again.".tr;
      if (e.toString().contains('timeout')) {
        errorMessage =
            "Request timeout. Please check your internet connection.".tr;
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        errorMessage = "No internet connection. Please check your network.".tr;
      } else if (e.toString().contains('FormatException')) {
        errorMessage = "Invalid server response. Please try again.".tr;
      }

      ShowToastDialog.showToast(errorMessage);
    }
  }

  @override
  void onClose() {
    phoneController.value.dispose();
    countryCodeController.value.dispose();
    super.onClose();
  }
}
