import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/firebase_options.dart';
import 'package:driver/services/call_kit_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _driverIdKey = 'bg_driver_id';
const String _foregroundFlagKey = 'bg_app_foreground';
const String _notificationChannelId = 'order_listener_channel';
const String _logTag = '[order_background_service]';

Future<void> setBackgroundDriverId(String driverId) async {
  final prefs = await SharedPreferences.getInstance();
  if (driverId.isEmpty) {
    await prefs.remove(_driverIdKey);
  } else {
    await prefs.setString(_driverIdKey, driverId);
  }
  FlutterBackgroundService().invoke('setDriverId', {'driverId': driverId});
}

Future<void> setAppForeground(bool isForeground) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_foregroundFlagKey, isForeground);
  FlutterBackgroundService()
      .invoke('foregroundState', {'foreground': isForeground});
}

Future<void> initializeOrderBackgroundService() async {
  final localNotif = FlutterLocalNotificationsPlugin();
  const channel = AndroidNotificationChannel(
    _notificationChannelId,
    'Order listener',
    description: 'Yangi zakazlar kuzatilishi uchun fon xizmati',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );
  await localNotif
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
      initialNotificationTitle: 'Fondex Driver',
      initialNotificationContent: 'Yangi zakazlar kuzatilmoqda',
      foregroundServiceNotificationId: 1414,
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

Future<void> _ringOrder(
  ServiceInstance service, {
  required String orderId,
  required String orderType,
  required String title,
  required String body,
}) async {
  log('$_logTag ring -> id=$orderId type=$orderType');
  service.invoke('ringOrder', {
    'orderId': orderId,
    'orderType': orderType,
    'title': title,
    'body': body,
  });
  await CallKitService.showIncomingOrder(
    orderId: orderId,
    orderType: orderType,
    title: title,
    body: body,
  );
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

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? driverSub;
  final Set<String> ringingOrderIds = <String>{};
  String? ringingCabId;
  String? currentDriverId;
  bool isForeground = false;

  Future<void> endAllRinging() async {
    for (final id in ringingOrderIds) {
      unawaited(CallKitService.endCall(id));
    }
    ringingOrderIds.clear();
    if (ringingCabId != null) {
      unawaited(CallKitService.endCall(ringingCabId!));
      ringingCabId = null;
    }
  }

  Future<void> resubscribe(String driverId) async {
    await driverSub?.cancel();
    driverSub = null;
    await endAllRinging();
    if (driverId.isEmpty) return;
    log('$_logTag subscribing for driverId=$driverId');
    driverSub = FirebaseFirestore.instance
        .collection('users')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        log('$_logTag snapshot empty for driverId=$driverId');
        return;
      }
      final data = snapshot.data() ?? <String, dynamic>{};
      final isActive = data['isActive'] == true;
      if (!isActive) {
        log('$_logTag isActive=false — suppressing all rings');
        await endAllRinging();
        return;
      }
      final List<dynamic> rawRequests =
          (data['orderRequestData'] as List?) ?? const [];
      final Set<String> currentIds = rawRequests
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet();
      for (final id in currentIds) {
        if (!ringingOrderIds.contains(id)) {
          ringingOrderIds.add(id);
          if (isForeground) {
            log('$_logTag new delivery $id while foreground — skip ring');
            continue;
          }
          await _ringOrder(
            service,
            orderId: id,
            orderType: 'food',
            title: 'Yangi zakaz',
            body: 'Yangi yetkazib berish so\'rovi',
          );
        }
      }
      final removed = ringingOrderIds.difference(currentIds);
      for (final id in removed) {
        log('$_logTag CallKit end delivery $id');
        await CallKitService.endCall(id);
        ringingOrderIds.remove(id);
      }

      final cabRaw = data['ordercabRequestData'];
      if (cabRaw is Map) {
        final cabId = (cabRaw['id'] ?? '').toString();
        if (cabId.isNotEmpty && cabId != ringingCabId) {
          if (ringingCabId != null) {
            await CallKitService.endCall(ringingCabId!);
          }
          ringingCabId = cabId;
          if (!isForeground) {
            final source = (cabRaw['sourceLocationName'] ?? '').toString();
            await _ringOrder(
              service,
              orderId: cabId,
              orderType: 'cab',
              title: 'Yangi taklif',
              body: source.isEmpty ? 'Yangi yo\'lovchi' : source,
            );
          }
        }
      } else if (ringingCabId != null) {
        log('$_logTag CallKit end cab ${ringingCabId!}');
        await CallKitService.endCall(ringingCabId!);
        ringingCabId = null;
      }
    }, onError: (Object e, StackTrace st) {
      log('$_logTag stream error: $e');
    });
  }

  service.on('setDriverId').listen((event) async {
    final driverId = (event?['driverId'] ?? '').toString();
    if (driverId == currentDriverId) return;
    currentDriverId = driverId;
    await resubscribe(driverId);
  });

  service.on('foregroundState').listen((event) {
    isForeground = (event?['foreground'] == true);
    log('$_logTag foreground=$isForeground');
  });

  service.on('stopService').listen((_) async {
    await driverSub?.cancel();
    await endAllRinging();
    service.stopSelf();
  });

  final prefs = await SharedPreferences.getInstance();
  isForeground = prefs.getBool(_foregroundFlagKey) ?? false;
  final initialDriverId = prefs.getString(_driverIdKey) ?? '';
  log('$_logTag service start: driverId="$initialDriverId" '
      'isForeground=$isForeground');
  if (initialDriverId.isNotEmpty) {
    currentDriverId = initialDriverId;
    await resubscribe(initialDriverId);
  } else {
    log('$_logTag NO driverId in prefs — no Firestore subscription yet');
  }
}
