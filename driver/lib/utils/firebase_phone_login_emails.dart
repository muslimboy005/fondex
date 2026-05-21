import 'package:firebase_auth/firebase_auth.dart';

/// Gmail-first then fondex.com fallback for phone-number-shaped Firebase emails.
List<String> firebasePhoneLoginEmailAttempts(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return [];

  final localPart =
      trimmed.contains('@') ? trimmed.split('@').first : trimmed;
  final digits = localPart.replaceAll(RegExp(r'[^\d]'), '');

  const minDigits = 9;
  if (digits.length >= minDigits) {
    return <String>['$digits@gmail.com', '$digits@fondex.com'];
  }

  if (trimmed.contains('@')) {
    return <String>[trimmed];
  }
  return <String>[];
}

bool firebasePhoneLoginShouldTryNextEmail(FirebaseAuthException e) {
  return e.code == 'user-not-found' || e.code == 'invalid-credential';
}
