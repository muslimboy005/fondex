import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'phone_registration_screen.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  /// Check if device is mobile (iOS or Android)
  bool get isMobileDevice {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  Widget build(BuildContext context) {
    // If mobile device, show phone registration screen
    // Otherwise, show regular login screen
    if (isMobileDevice) {
      return const PhoneRegistrationScreen();
    } else {
      return const LoginScreen();
    }
  }
}
