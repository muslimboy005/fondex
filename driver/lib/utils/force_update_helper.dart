import 'package:driver/constant/constant.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateHelper {
  static bool _isBottomSheetShown = false;

  static Future<void> checkAndShowIfNeeded() async {
    if (_isBottomSheetShown) return;
    try {
      final minRequiredVersion =
          await FireStoreUtils.getDriverMinRequiredVersion();
      if (minRequiredVersion.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      if (_compareVersions(currentVersion, minRequiredVersion) >= 0) return;

      _isBottomSheetShown = true;
      _showForceUpdateBottomSheet(minRequiredVersion);
    } catch (_) {}
  }

  static int _compareVersions(String current, String minimum) {
    final currentParts =
        RegExp(r'\d+')
            .allMatches(current)
            .map((m) => int.tryParse(m.group(0) ?? '0') ?? 0)
            .toList();
    final minimumParts =
        RegExp(r'\d+')
            .allMatches(minimum)
            .map((m) => int.tryParse(m.group(0) ?? '0') ?? 0)
            .toList();

    final maxLength = currentParts.length > minimumParts.length
        ? currentParts.length
        : minimumParts.length;
    for (int i = 0; i < maxLength; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final m = i < minimumParts.length ? minimumParts[i] : 0;
      if (c > m) return 1;
      if (c < m) return -1;
    }
    return 0;
  }

  static void _showForceUpdateBottomSheet(String minRequiredVersion) {
    if (Get.isBottomSheetOpen == true) return;

    Get.bottomSheet(
      PopScope(
        canPop: false,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New version is available'.tr,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${'Please update the app to continue'.tr} ($minRequiredVersion).',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openStoreForUpdate,
                    child: Text('Update'.tr),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isDismissible: false,
      enableDrag: false,
      barrierColor: Colors.black54,
    );
  }

  static Future<void> _openStoreForUpdate() async {
    final url = GetPlatform.isIOS ? Constant.appStoreLink : Constant.googlePlayLink;
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
