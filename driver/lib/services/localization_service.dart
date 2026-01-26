import 'package:driver/lang/app_ru.dart';
import 'package:driver/lang/app_uz.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LocalizationService extends Translations {
  // Default locale
  static const locale = Locale('uz', 'UZ');

  static final locales = [
    const Locale('uz'),
    const Locale('ru'),
  ];

  // Keys and their translations
  // Translations are separated maps in `lang` file
  @override
  Map<String, Map<String, String>> get keys => {
        'ru': ruRU,
        'uz': uzUZ,
      };

  // Gets locale from language, and updates the locale
  void changeLocale(String lang) {
    Get.updateLocale(Locale(lang));
  }
}
