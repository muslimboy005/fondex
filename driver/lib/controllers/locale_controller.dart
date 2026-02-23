import 'dart:convert';
import 'package:driver/models/language_model.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LocaleController extends GetxController {
  final Rx<Locale> locale = (LocalizationService.locale).obs;

  @override
  void onInit() {
    super.onInit();
    _loadSavedLocale();
  }

  void _loadSavedLocale() {
    final saved = Preferences.getString(Preferences.languageCodeKey).toString();
    if (saved.isEmpty) {
      final defaultLang = LanguageModel(slug: 'uz', isRtl: false, title: "O'zbek");
      Preferences.setString(Preferences.languageCodeKey, jsonEncode(defaultLang.toJson()));
      locale.value = const Locale('uz');
      Get.updateLocale(const Locale('uz'));
      return;
    }
    try {
      final map = jsonDecode(saved) as Map<String, dynamic>;
      final slug = map['slug']?.toString();
      if (slug != null && slug.isNotEmpty) {
        locale.value = Locale(slug);
        Get.updateLocale(Locale(slug));
      }
    } catch (_) {}
  }

  void setLocale(String slug) {
    if (slug.isEmpty) return;
    locale.value = Locale(slug);
    Get.updateLocale(Locale(slug));
  }
}
