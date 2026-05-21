import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:vendor/app/splash_screen.dart';
import 'package:vendor/controller/global_setting_controller.dart';
import 'package:vendor/controller/locale_controller.dart';
import 'package:vendor/firebase_options.dart';
import 'package:vendor/service/audio_player_service.dart';
import 'package:vendor/service/call_kit_service.dart';
import 'package:vendor/service/localization_service.dart';
import 'package:vendor/service/order_background_service.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/easy_loading_config.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/notification_service.dart';
import 'package:vendor/utils/preferences.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase, handling duplicate-app errors during hot restart
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Ignore duplicate-app errors (can happen during hot restart/reload)
    if (e.toString().contains('duplicate-app') ||
        e.toString().contains('[core/duplicate-app]')) {
      // Firebase already initialized, continue
    } else {
      rethrow;
    }
  }
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest,
  );
  await Preferences.initPref();
  await AudioPlayerService.initAudio();

  // Background FCM handler still registered as an iOS killed-state fallback.
  // Primary path is the Firestore-driven background service below.
  FirebaseMessaging.onBackgroundMessage(firebaseMessageBackgroundHandle);

  // Foreground-service backed Firestore listener that rings CallKit when a
  // new vendor order arrives even while the app is backgrounded.
  await initializeOrderBackgroundService();

  // Listen for CallKit accept/decline events. Fires in foreground; for cold
  // starts the accept event is captured by the deeplink router via the
  // persisted pendingOrderId SharedPreferences value.
  _listenCallKitEvents();

  Get.put(ThemeController());
  Get.put(LocaleController());
  await configEasyLoading();
  runApp(const MyApp());
}

void _listenCallKitEvents() {
  FlutterCallkitIncoming.onEvent.listen((event) async {
    if (event == null) return;
    log('CallKit event: ${event.event} body=${event.body}');
    final extra = event.body['extra'] as Map?;
    final orderId = (extra?['orderId'] ?? event.body['id'] ?? '').toString();
    final orderType = (extra?['orderType'] ?? 'food').toString();
    switch (event.event) {
      case Event.actionCallAccept:
        if (orderId.isNotEmpty) {
          await Preferences.setString(Preferences.pendingOrderId, orderId);
          await Preferences.setString(Preferences.pendingOrderType, orderType);
        }
        await CallKitService.endCall(orderId);
        break;
      case Event.actionCallDecline:
      case Event.actionCallTimeout:
        if (orderId.isNotEmpty) {
          unawaited(_rejectOrderInBackground(orderId));
        }
        await Preferences.clearKeyData(Preferences.pendingOrderId);
        await Preferences.clearKeyData(Preferences.pendingOrderType);
        await CallKitService.endCall(orderId);
        break;
      case Event.actionCallEnded:
      case Event.actionCallToggleMute:
      case Event.actionCallToggleHold:
      case Event.actionCallToggleAudioSession:
      case Event.actionCallCustom:
      default:
        break;
    }
  });
}

/// Vendor CallKit decline/timeout kelganda orderni Firestore da "Order Rejected"
/// ga o'zgartiradi. Faqat hali "Order Placed" holatida bo'lgan orderlar uchun.
Future<void> _rejectOrderInBackground(String orderId) async {
  try {
    final ref = FirebaseFirestore.instance
        .collection('vendor_orders')
        .doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final status = (snap.data()?['status'] ?? '').toString();
    if (status != 'Order Placed') return;
    await ref.set({'status': 'Order Rejected'}, SetOptions(merge: true));
    log('_rejectOrderInBackground: order $orderId rejected');
  } catch (e) {
    log('_rejectOrderInBackground error: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final themeController = Get.find<ThemeController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AudioPlayerService.initAudio();
      setAppForeground(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      setAppForeground(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Get.put(ThemeController());
    return Obx(
      () => GetMaterialApp(
        title: 'Fondex Vendor'.tr,
        debugShowCheckedModeBanner: false,
        themeMode: themeController.themeMode,
        theme: ThemeData(
          scaffoldBackgroundColor: AppThemeData.surface,
          textTheme: TextTheme(
            bodyLarge: TextStyle(color: AppThemeData.grey900),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppThemeData.surface,
            foregroundColor: AppThemeData.grey900,
            iconTheme: IconThemeData(color: AppThemeData.grey900),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: AppThemeData.surface,
            selectedItemColor: AppThemeData.primary300,
            unselectedItemColor: AppThemeData.grey600,
            selectedLabelStyle: TextStyle(
              fontFamily: AppThemeData.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: AppThemeData.bold,
              fontSize: 12,
            ),
            type: BottomNavigationBarType.fixed,
          ),
        ),
        darkTheme: ThemeData(
          scaffoldBackgroundColor: AppThemeData.surfaceDark,
          textTheme: TextTheme(
            bodyLarge: TextStyle(color: AppThemeData.greyDark900),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppThemeData.surfaceDark,
            foregroundColor: AppThemeData.greyDark900,
            iconTheme: IconThemeData(color: AppThemeData.greyDark900),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: AppThemeData.grey900,
            selectedItemColor: AppThemeData.primary300,
            unselectedItemColor: AppThemeData.grey300,
            selectedLabelStyle: TextStyle(
              fontFamily: AppThemeData.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: AppThemeData.bold,
              fontSize: 12,
            ),
            type: BottomNavigationBarType.fixed,
          ),
        ),
        localizationsDelegates: const [CountryLocalizations.delegate],
        locale: Get.find<LocaleController>().locale.value,
        fallbackLocale: LocalizationService.locale,
        translations: LocalizationService(),
        builder: (context, child) {
          return SafeArea(
            bottom: true,
            top: false,
            child: EasyLoading.init()(context, child),
          );
        },
        home: GetBuilder<GlobalSettingController>(
          init: GlobalSettingController(),
          builder: (context) {
            return const SplashScreen();
          },
        ),
      ),
    );
  }
}
