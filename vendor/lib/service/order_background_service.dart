import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor/firebase_options.dart';
import 'package:vendor/service/call_kit_service.dart';

const String _vendorIdKey = 'bg_vendor_id';
const String _foregroundFlagKey = 'bg_app_foreground';
const String _notificationChannelId = 'order_listener_channel';
const String _logTag = '[order_background_service]';

/// Persists the current vendor id so the background isolate can pick it up
/// on the next snapshot tick. Call after login (and clear on logout).
Future<void> setBackgroundVendorId(String vendorId) async {
  final prefs = await SharedPreferences.getInstance();
  if (vendorId.isEmpty) {
    await prefs.remove(_vendorIdKey);
  } else {
    await prefs.setString(_vendorIdKey, vendorId);
  }
  FlutterBackgroundService().invoke('setVendorId', {'vendorId': vendorId});
}

/// Flag the foreground UI state so the background isolate can decide whether
/// to suppress the CallKit popup (avoids ringing twice when the app is open).
Future<void> setAppForeground(bool isForeground) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_foregroundFlagKey, isForeground);
  FlutterBackgroundService()
      .invoke('foregroundState', {'foreground': isForeground});
}

Future<void> initializeOrderBackgroundService() async {
  // Safety-net channel creation. The authoritative registration happens in
  // MainApplication.onCreate() (Kotlin) because BootReceiver can start the
  // FGS before Dart runs on `adb install -r`. Keep this aligned with the
  // native definition.
  const channel = AndroidNotificationChannel(
    _notificationChannelId,
    'Order listener',
    description: 'Yangi zakazlar kuzatilishi uchun fon xizmati',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );
  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onOrderServiceStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: _notificationChannelId,
      initialNotificationTitle: 'Fondex Vendor',
      initialNotificationContent: 'Yangi zakazlar kuzatilmoqda',
      foregroundServiceNotificationId: 1313,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onOrderServiceStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onOrderServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    log('$_logTag Firebase init in isolate: $e');
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ordersSub;
  final Set<String> ringingOrderIds = <String>{};
  String? currentVendorId;
  bool isForeground = false;

  Future<void> resubscribe(String vendorId) async {
    await ordersSub?.cancel();
    ordersSub = null;
    for (final id in ringingOrderIds) {
      unawaited(CallKitService.endCall(id));
    }
    ringingOrderIds.clear();
    if (vendorId.isEmpty) return;
    log('$_logTag subscribing for vendorId=$vendorId');
    ordersSub = FirebaseFirestore.instance
        .collection('vendor_orders')
        .where('vendorID', isEqualTo: vendorId)
        .where('status', isEqualTo: 'Order Placed')
        .snapshots()
        .listen((snapshot) async {
      final Set<String> currentIds = <String>{};
      for (final doc in snapshot.docs) {
        final id = doc.id;
        currentIds.add(id);
        if (!ringingOrderIds.contains(id)) {
          ringingOrderIds.add(id);
          if (isForeground) {
            log('$_logTag new order $id arrived while foreground — '
                'foreground listener handles ringing');
            continue;
          }
          final data = doc.data();
          final title = (data['author']?['fullName'] ??
                  data['vendor']?['title'] ??
                  'Yangi zakaz')
              .toString();
          final amount = (data['toPayAmount'] ?? data['amount'] ?? '').toString();
          final body = amount.isEmpty ? 'Yangi zakaz keldi' : 'Summa: $amount';
          log('$_logTag CallKit show for $id');
          await CallKitService.showIncomingOrder(
            orderId: id,
            orderType: 'food',
            title: title,
            body: body,
          );
        }
      }
      final removed = ringingOrderIds.difference(currentIds);
      for (final id in removed) {
        log('$_logTag CallKit end for $id (no longer pending)');
        await CallKitService.endCall(id);
        ringingOrderIds.remove(id);
      }
    }, onError: (Object e, StackTrace st) {
      log('$_logTag stream error: $e');
    });
  }

  service.on('setVendorId').listen((event) async {
    final vendorId = (event?['vendorId'] ?? '').toString();
    if (vendorId == currentVendorId) return;
    currentVendorId = vendorId;
    await resubscribe(vendorId);
  });

  service.on('foregroundState').listen((event) {
    isForeground = (event?['foreground'] == true);
    log('$_logTag foreground=$isForeground');
  });

  service.on('stopService').listen((_) async {
    await ordersSub?.cancel();
    for (final id in ringingOrderIds) {
      unawaited(CallKitService.endCall(id));
    }
    ringingOrderIds.clear();
    service.stopSelf();
  });

  final prefs = await SharedPreferences.getInstance();
  isForeground = prefs.getBool(_foregroundFlagKey) ?? false;
  final initialVendorId = prefs.getString(_vendorIdKey) ?? '';
  if (initialVendorId.isNotEmpty) {
    currentVendorId = initialVendorId;
    await resubscribe(initialVendorId);
  }

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }
}
