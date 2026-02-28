import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/theme_controller.dart';

/// Joriy ilova versiyasi [requiredVersion] dan past bo'lsa true.
/// Faqat major.minor.patch (1.0.2) solishtiriladi, build (+8, +7) hisobga olinmaydi.
/// Firestore app_version = Play Store'dagi versiya (masalan "1.0.1") bo'lsa, 1.0.2+8 >= 1.0.1 → yangilash ko'rsatilmaydi.
bool isUpdateRequired(String current, String requiredVersion) {
  if (requiredVersion.isEmpty) return false;
  try {
    final c = _parseVersion(current);
    final r = _parseVersion(requiredVersion);
    // Faqat birinchi 3 qism (major.minor.patch) bo'yicha solishtirish, build raqamini ignore qilish
    const maxParts = 3;
    for (int i = 0; i < maxParts; i++) {
      int cv = i < c.length ? c[i] : 0;
      int rv = i < r.length ? r[i] : 0;
      if (cv < rv) return true;
      if (cv > rv) return false;
    }
    return false;
  } catch (_) {
    return false;
  }
}

List<int> _parseVersion(String v) {
  return v
      .split(RegExp(r'[.\+]'))
      .map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0)
      .toList();
}

/// Firestore dan Version hujjatini bir marta olish.
/// Vendor ilovasi uchun avval vendor_app_version (va vendor_* linklar) qidiriladi; bo'lmasa app_version ishlatiladi.
Future<Map<String, String>> getVersionInfoFromFirestore() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection(CollectionName.settings)
        .doc('Version')
        .get();
    if (!doc.exists || doc.data() == null) {
      return {};
    }
    final d = doc.data()!;
    final vendorVersion = (d['vendor_app_version'] ?? '').toString().trim();
    final defaultVersion = (d['app_version'] ?? '').toString().trim();
    final vendorPlay = (d['vendor_googlePlayLink'] ?? '').toString().trim();
    final vendorStore = (d['vendor_appStoreLink'] ?? '').toString().trim();
    return {
      'app_version': vendorVersion.isNotEmpty ? vendorVersion : defaultVersion,
      'googlePlayLink': vendorPlay.isNotEmpty ? vendorPlay : (d['googlePlayLink'] ?? '').toString().trim(),
      'appStoreLink': vendorStore.isNotEmpty ? vendorStore : (d['appStoreLink'] ?? '').toString().trim(),
    };
  } catch (_) {
    return {};
  }
}

/// Yangi versiya bor-yo'qligini tekshirish; kerak bo'lsa bottom sheet ko'rsatadi.
/// Debug rejimida (flutter run) hech qachon ko'rsatilmaydi.
/// Return: true = yangilash kerak (sheet ko'rsatildi), false = davom etish mumkin
Future<bool> checkAndShowUpdateIfNeeded(BuildContext context) async {
  if (kDebugMode) return false;
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final versionInfo = await getVersionInfoFromFirestore();
    final requiredVersion = (versionInfo['app_version'] ?? Constant.appVersion).trim();
    if (requiredVersion.isEmpty) return false;
    if (!isUpdateRequired(currentVersion, requiredVersion)) return false;

    final playLink = versionInfo['googlePlayLink']?.isNotEmpty == true
        ? versionInfo['googlePlayLink']!
        : Constant.vendorPlayStoreUrl;
    final storeLink = versionInfo['appStoreLink']?.isNotEmpty == true
        ? versionInfo['appStoreLink']!
        : Constant.vendorAppStoreUrl;
    final storeUrl = Platform.isIOS ? storeLink : playLink;

    if (!context.mounted) return false;
    showUpdateRequiredBottomSheet(context, storeUrl);
    return true;
  } catch (_) {
    return false;
  }
}

/// Yopilmaydigan bottom sheet: tashqariga bosilsa ham yopilmaydi, faqat "Yangilash" ishlaydi
void showUpdateRequiredBottomSheet(BuildContext context, String storeUrl) {
  final themeController = Get.find<ThemeController>();
  final isDark = themeController.isDark.value;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black87,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.system_update_alt,
                size: 56,
                color: AppThemeData.primary300,
              ),
              const SizedBox(height: 16),
              Text(
                'Yangi versiya chiqdi'.tr,
                style: TextStyle(
                  fontFamily: AppThemeData.semiBold,
                  fontSize: 20,
                  color: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Iltimos, ilovani yangilang'.tr,
                style: TextStyle(
                  fontFamily: AppThemeData.medium,
                  fontSize: 15,
                  color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final uri = Uri.parse(storeUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeData.primary300,
                    foregroundColor: AppThemeData.grey50,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Yangilash'.tr,
                    style: const TextStyle(
                      fontFamily: AppThemeData.semiBold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Ekran ochilganda bir marta versiya tekshiruvini ishga tushiradi; kerak bo'lsa yangilash bottom sheet ko'rsatadi.
/// Splash emas, balki foydalanuvchi ochadigan ekranda (Dashboard, Auth, Onboarding va h.k.) ishlatish uchun.
class VersionCheckOnOpen extends StatefulWidget {
  const VersionCheckOnOpen({super.key, required this.child});

  final Widget child;

  @override
  State<VersionCheckOnOpen> createState() => _VersionCheckOnOpenState();
}

class _VersionCheckOnOpenState extends State<VersionCheckOnOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await checkAndShowUpdateIfNeeded(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
