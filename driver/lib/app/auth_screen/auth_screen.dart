import 'package:flutter/material.dart';
import 'phone_registration_screen.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Onboarding va logout dan keyin ham doim raqam orqali kirish (PhoneRegistrationScreen)
    return const PhoneRegistrationScreen();
  }
}
