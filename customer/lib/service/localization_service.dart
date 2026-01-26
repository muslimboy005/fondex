import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../lang/app_ru.dart';
import '../lang/app_uz.dart';
import '../utils/preferences.dart';

class LocalizationService extends Translations {
  // Default locale
  static Locale get locale {
    final savedLang = Preferences.getString(Preferences.languageCodeKey);
    if (savedLang.isNotEmpty) {
      try {
        final langData = savedLang;
        // Try to parse language code from saved data
        if (langData.contains('"slug"')) {
          // Extract slug from JSON string
          final slugMatch = RegExp(
            r'"slug"\s*:\s*"([^"]+)"',
          ).firstMatch(langData);
          if (slugMatch != null) {
            final slug = slugMatch.group(1);
            if (slug == 'ru') return const Locale('ru', 'RU');
            if (slug == 'uz') return const Locale('uz', 'UZ');
          }
        } else {
          // Direct language code
          if (langData == 'ru' || langData.contains('ru'))
            return const Locale('ru', 'RU');
          if (langData == 'uz' || langData.contains('uz'))
            return const Locale('uz', 'UZ');
        }
      } catch (e) {
        // If parsing fails, return default
      }
    }
    return const Locale('uz', 'UZ'); // Default to Uzbek
  }

  static final locales = [const Locale('ru', 'RU'), const Locale('uz', 'UZ')];

  // Keys and their translations
  // Translations are separated maps in `lang` file
  @override
  Map<String, Map<String, String>> get keys => {'ru_RU': ruRU, 'uz_UZ': uzUZ};

  // Gets locale from language, and updates the locale
  void changeLocale(String lang) {
    Locale newLocale;
    if (lang == 'ru') {
      newLocale = const Locale('ru', 'RU');
    } else if (lang == 'uz') {
      newLocale = const Locale('uz', 'UZ');
    } else {
      newLocale = const Locale('uz', 'UZ'); // Default to Uzbek if unknown
    }
    Get.updateLocale(newLocale);
  }
}
