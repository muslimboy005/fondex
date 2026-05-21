import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vendor/service/call_kit_service.dart';
import 'package:vendor/utils/preferences.dart';

/// Background FCM handler. Executes in an isolated Dart engine — no GetX state
/// is available. Must be a top-level (or static) function with
/// `@pragma('vm:entry-point')` so it survives tree-shaking in release builds.
@pragma('vm:entry-point')
Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  log("BackGround Message :: ${message.messageId} data=${message.data}");
  final data = message.data;
  if (data['callkit'] == '1' || data['type'] == 'order_placed' || data['type'] == 'schedule_order' || data['type'] == 'dinein_placed') {
    final orderId = (data['orderId'] ?? data['order_id'] ?? data['id'] ?? '').toString();
    final title = (data['title'] ?? message.notification?.title ?? 'Yangi zakaz').toString();
    final body = (data['body'] ?? message.notification?.body ?? '').toString();
    await CallKitService.showIncomingOrder(
      orderId: orderId,
      orderType: 'food',
      title: title,
      body: body,
    );
  }
}

class NotificationService {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// iOS: bitta umumiy kutish — parallel [getToken] va [subscribe] 2 marta poll qilmasin.
  static Future<bool>? _iosApnsReadyFuture;

  static Future<bool> _ensureIosApnsReady() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }
    _iosApnsReadyFuture ??= _pollIosApnsToken();
    return _iosApnsReadyFuture!;
  }

  /// Simulyatorda APNS bo‘lmaydi — ~5s dan keyin jim; haqiqiy qurilma odatda oldinroq.
  static Future<bool> _pollIosApnsToken() async {
    const steps = 25;
    const delay = Duration(milliseconds: 200);
    for (var i = 0; i < steps; i++) {
      try {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.isNotEmpty) return true;
      } catch (_) {}
      await Future<void>.delayed(delay);
    }
    return false;
  }

  Future<void> initInfo() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    var request = await FirebaseMessaging.instance.requestPermission(alert: true, announcement: false, badge: true, carPlay: false, criticalAlert: false, provisional: false, sound: true);

    if (request.authorizationStatus == AuthorizationStatus.authorized || request.authorizationStatus == AuthorizationStatus.provisional) {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      var iosInitializationSettings = const DarwinInitializationSettings();
      final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: iosInitializationSettings);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings, onDidReceiveNotificationResponse: (payload) {});
      setupInteractedMessage();
      // Register the background handler unconditionally on every cold start.
      FirebaseMessaging.onBackgroundMessage(firebaseMessageBackgroundHandle);
      await _syncVoipTokenIfAvailable();
    }
  }

  Future<void> setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleOrderPushData(initialMessage.data, foreground: false);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      log("::::::::::::onMessage:::::::::::::::::");
      final data = message.data;
      if (_isIncomingOrder(data)) {
        await _showCallKitForData(data, message);
      } else if (message.notification != null) {
        log(message.notification.toString());
        display(message);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleOrderPushData(message.data, foreground: true);
    });
    log("::::::::::::Permission authorized:::::::::::::::::");
    await _subscribeToVendorTopic();
  }

  bool _isIncomingOrder(Map<String, dynamic> data) {
    if (data.isEmpty) return false;
    if (data['callkit'] == '1') return true;
    final type = data['type']?.toString() ?? '';
    return type == 'order_placed' || type == 'schedule_order' || type == 'dinein_placed';
  }

  Future<void> _showCallKitForData(Map<String, dynamic> data, RemoteMessage message) async {
    final orderId = (data['orderId'] ?? data['order_id'] ?? data['id'] ?? '').toString();
    final title = (data['title'] ?? message.notification?.title ?? 'Yangi zakaz').toString();
    final body = (data['body'] ?? message.notification?.body ?? '').toString();
    await CallKitService.showIncomingOrder(
      orderId: orderId,
      orderType: 'food',
      title: title,
      body: body,
    );
  }

  /// Persists order id so the navigation layer can route after the user
  /// accepts the CallKit prompt (handled in main.dart's onEvent listener).
  void _handleOrderPushData(Map<String, dynamic> data, {required bool foreground}) {
    if (data.isEmpty) return;
    final orderId = (data['orderId'] ?? data['order_id'] ?? data['id'] ?? '').toString();
    if (orderId.isEmpty) return;
    Preferences.setString(Preferences.pendingOrderId, orderId);
    Preferences.setString(Preferences.pendingOrderType, 'food');
  }

  static Future<void> _subscribeToVendorTopic() async {
    if (!await _ensureIosApnsReady()) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic("vendor");
    } catch (e) {
      if (kDebugMode) log('FCM subscribeToTopic vendor: $e');
    }
  }

  /// iOS only — fetches the VoIP push token from PushKit and stores it on the
  /// current user's Firestore doc so the customer app can target it.
  static Future<void> _syncVoipTokenIfAvailable() async {
    try {
      final token = await CallKitService.getIosVoipToken();
      if (token == null || token.isEmpty) return;
      await Preferences.setString(Preferences.voipToken, token);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('vendor_users').doc(uid).set(
        {'voipToken': token},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) log('VoIP token sync failed: $e');
    }
  }

  /// iOS: [getAPNSToken] bo‘lmasa [getToken] chaqirilmaydi (simulyator — log yo‘q).
  static Future<String?> getToken() async {
    if (!await _ensureIosApnsReady()) return null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      if (kDebugMode) log('FCM getToken: $e');
    }
    return null;
  }

  void display(RemoteMessage message) async {
    log('Got a message whilst in the foreground!');
    log('Message data: ${message.notification!.body.toString()}');
    try {
      AndroidNotificationChannel channel = const AndroidNotificationChannel('0', 'goRide-customer', description: 'Show QuickLAI Notification', importance: Importance.max);
      AndroidNotificationDetails notificationDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: 'your channel Description',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const DarwinNotificationDetails darwinNotificationDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      NotificationDetails notificationDetailsBoth = NotificationDetails(android: notificationDetails, iOS: darwinNotificationDetails);
      await FlutterLocalNotificationsPlugin().show(0, message.notification!.title, message.notification!.body, notificationDetailsBoth, payload: jsonEncode(message.data));
    } on Exception catch (e) {
      log(e.toString());
    }
  }
}
