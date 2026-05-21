import 'dart:developer';
import 'dart:io';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

/// Shows an incoming-call style UI for new vendor orders.
///
/// Works in three states:
/// - Foreground: shows over current screen with ringtone.
/// - Background: shows above lock screen via full-screen intent (Android) /
///   CallKit (iOS).
/// - Terminated: invoked from background FCM handler / iOS PushKit handler.
class CallKitService {
  static const _uuidGen = Uuid();

  /// Shows the incoming-order CallKit UI.
  ///
  /// [orderId] — required for routing once user accepts.
  /// [orderType] — "food" | "cab" | "parcel" | "rental" — used by deeplink.
  /// [title] — primary text (e.g. "New order #1234").
  /// [body] — secondary text (e.g. amount + address).
  static Future<void> showIncomingOrder({
    required String orderId,
    String orderType = "food",
    required String title,
    required String body,
  }) async {
    try {
      final params = CallKitParams(
        id: orderId.isNotEmpty ? orderId : _uuidGen.v4(),
        nameCaller: title,
        appName: 'Fondex Vendor',
        avatar: 'https://i.imgur.com/9V0XJ4z.png',
        handle: body,
        type: 0,
        textAccept: 'Qabul qilish',
        textDecline: 'Rad etish',
        duration: 45000,
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: false,
          subtitle: 'Yangi zakaz qabul qilinmadi',
        ),
        extra: <String, dynamic>{
          'orderId': orderId,
          'orderType': orderType,
          'kind': 'vendor_order',
        },
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0955fa',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: 'Incoming Orders',
          missedCallNotificationChannelName: 'Missed Orders',
          isShowCallID: false,
        ),
        ios: const IOSParams(
          iconName: 'CallKitLogo',
          handleType: 'generic',
          supportsVideo: false,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: false,
          supportsHolding: false,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (e) {
      log("CallKitService.showIncomingOrder error: $e");
    }
  }

  /// Ends/dismisses any active CallKit UI for a given order id.
  static Future<void> endCall(String orderId) async {
    try {
      await FlutterCallkitIncoming.endCall(orderId);
    } catch (e) {
      log("CallKitService.endCall error: $e");
    }
  }

  /// Ends all currently visible CallKit UIs.
  static Future<void> endAll() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      log("CallKitService.endAll error: $e");
    }
  }

  /// Returns iOS VoIP push token (PushKit) or null on Android.
  static Future<String?> getIosVoipToken() async {
    if (!Platform.isIOS) return null;
    try {
      final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      return (token.isEmpty) ? null : token;
    } catch (e) {
      log("CallKitService.getIosVoipToken error: $e");
      return null;
    }
  }
}
