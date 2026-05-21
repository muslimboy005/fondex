import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/app/splash_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:driver/controllers/cab_home_controller.dart';
import 'package:driver/controllers/global_setting_controller.dart';
import 'package:driver/controllers/home_controller.dart';
import 'package:driver/controllers/locale_controller.dart';
import 'package:driver/firebase_options.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/services/call_kit_service.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/services/order_background_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/easy_loading_config.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:driver/utils/preferences.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

void main() async {
  // Set up error handling to prevent app crashes
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Log error but don't crash the app
    debugPrint('Flutter Error: ${details.exception}');
  };

  // Handle async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async Error: $error');
    return true; // Prevent app from crashing
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase - check if already initialized to avoid duplicate app error
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // If initialization fails with duplicate-app error, Firebase was initialized
        // between the check and initialization - this is fine, continue
        if (!e.toString().contains('duplicate-app')) {
          debugPrint('Firebase initialization error: $e');
        }
      }
    }

    // Activate Firebase App Check only if not already activated
    try {
      // Use debug provider in development, play integrity in production
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      );
    } catch (e) {
      // FirebaseAppCheck might already be activated or have issues, continue anyway
      debugPrint('FirebaseAppCheck activation error (continuing anyway): $e');
      // Don't block app startup if App Check fails
    }
    await Preferences.initPref();

    // Initialize intl date formatting (required before DateFormat with locale in wallet etc.)
    await initializeDateFormatting();

    // FCM background handler stays as an iOS killed-state fallback. Primary
    // ringing path is the Firestore-driven background service below.
    FirebaseMessaging.onBackgroundMessage(firebaseMessageBackgroundHandle);

    // Foreground-service backed Firestore listener that rings CallKit when a
    // new order/ride is offered while the app is backgrounded.
    await initializeOrderBackgroundService();

    // CallKit accept/decline → route the driver into the matching order screen.
    _listenCallKitEvents();

    // Bg isolate forwards new-order rings here; main isolate has a healthy
    // plugin channel so this is the reliable path when the app is paused.
    _listenBgRingRequests();

    // Android 13+: runtime POST_NOTIFICATIONS prompt; without it the CallKit
    // incoming-call notification cannot post.
    try {
      await FlutterCallkitIncoming.requestNotificationPermission({
        'rationaleMessagePermission':
            'Yangi zakazlarni qabul qilish uchun bildirishnomalar kerak',
        'postNotificationMessageRequired':
            'Bildirishnomalar Settings ichida yoqilishi kerak',
      });
      // Android 14+: full-screen-intent grant — lock-screen call UI needs this.
      await FlutterCallkitIncoming.requestFullIntentPermission();
    } catch (e) {
      debugPrint('CallKit permission request failed: $e');
    }

    Get.put(ThemeController());
    Get.put(LocaleController());
    await configEasyLoading();
    runApp(const MyApp());
  }, (error, stack) {
    // Handle any uncaught errors
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stack');
  });
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
          if (orderType == 'cab') {
            await Preferences.setString(Preferences.pendingRideId, orderId);
          } else {
            await Preferences.setString(Preferences.pendingOrderId, orderId);
          }
          await Preferences.setString(Preferences.pendingOrderType, orderType);
        }
        // If the app is already running, trigger the appropriate controller
        // immediately. Otherwise the controller's onReady will consume the
        // pending pointer once it initializes.
        try {
          if (orderType == 'cab' && Get.isRegistered<CabHomeController>()) {
            Get.find<CabHomeController>().getOrderByRideId(orderId);
          } else if (Get.isRegistered<HomeController>()) {
            Get.find<HomeController>().listenToOrderById(orderId);
          }
        } catch (e) {
          log('CallKit accept routing error: $e');
        }
        await CallKitService.endCall(orderId);
        break;
      case Event.actionCallDecline:
      case Event.actionCallTimeout:
        await Preferences.clearKeyData(Preferences.pendingOrderId);
        await Preferences.clearKeyData(Preferences.pendingRideId);
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

void _listenBgRingRequests() {
  FlutterBackgroundService().on('ringOrder').listen((event) async {
    if (event == null) return;
    final orderId = (event['orderId'] ?? '').toString();
    if (orderId.isEmpty) return;
    log('main isolate ringOrder -> $orderId');
    await CallKitService.showIncomingOrder(
      orderId: orderId,
      orderType: (event['orderType'] ?? 'food').toString(),
      title: (event['title'] ?? 'Yangi zakaz').toString(),
      body: (event['body'] ?? '').toString(),
    );
  });
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
    WidgetsBinding.instance.addObserver(this);
    super.initState();
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
    return Obx(() => GetMaterialApp(
          title: 'Fondex Driver'.tr,
          debugShowCheckedModeBanner: false,
          themeMode: themeController.themeMode,
          theme: ThemeData(
            scaffoldBackgroundColor: AppThemeData.surface,
            textTheme:
                TextTheme(bodyLarge: TextStyle(color: AppThemeData.grey900)),
            appBarTheme: AppBarTheme(
              backgroundColor: AppThemeData.surface,
              foregroundColor: AppThemeData.grey900,
              iconTheme: IconThemeData(color: AppThemeData.grey900),
            ),
          ),
          darkTheme: ThemeData(
            scaffoldBackgroundColor: AppThemeData.surfaceDark,
            textTheme: TextTheme(
                bodyLarge: TextStyle(color: AppThemeData.greyDark900)),
            appBarTheme: AppBarTheme(
              backgroundColor: AppThemeData.surfaceDark,
              foregroundColor: AppThemeData.greyDark900,
              iconTheme: IconThemeData(color: AppThemeData.greyDark900),
            ),
          ),
          localizationsDelegates: const [
            CountryLocalizations.delegate,
          ],
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
        ));
  }
}
