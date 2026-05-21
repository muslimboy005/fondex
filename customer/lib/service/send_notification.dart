import 'dart:convert';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/notification_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class SendNotification {
  static final _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  static Future getCharacters() {
    return http.get(Uri.parse(Constant.jsonNotificationFileURL.toString()));
  }

  static Future<String> getAccessToken() async {
    Map<String, dynamic> jsonData = {};

    await getCharacters().then((response) {
      jsonData = json.decode(response.body);
    });
    final serviceAccountCredentials = ServiceAccountCredentials.fromJson(jsonData);
    final client = await clientViaServiceAccount(serviceAccountCredentials, _scopes);
    return client.credentials.accessToken.data;
  }

  static Map<String, dynamic> _stringifyPayload(Map<String, dynamic>? payload) {
    final Map<String, dynamic> out = {};
    if (payload == null) return out;
    payload.forEach((k, v) {
      if (v == null) return;
      out[k] = v is String ? v : v.toString();
    });
    return out;
  }

  static Future<bool> sendFcmMessage(String type, String token, Map<String, dynamic>? payload) async {
    print(type);
    try {
      final String accessToken = await getAccessToken();
      NotificationModel? notificationModel = await FireStoreUtils.getNotificationContent(type);

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
        headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
        body: jsonEncode(<String, dynamic>{
          'message': {
            'token': token,
            'notification': {'body': notificationModel?.message ?? '', 'title': notificationModel?.subject ?? ''},
            'data': _stringifyPayload({...?payload, 'type': type}),
            'android': {
              'priority': 'HIGH',
              'ttl': '60s',
              'notification': {'sound': 'default', 'channel_id': '0'},
            },
            'apns': {
              'headers': {'apns-priority': '10', 'apns-push-type': 'alert'},
              'payload': {
                'aps': {'content-available': 1, 'sound': 'default', 'mutable-content': 1},
              },
            },
          },
        }),
      );

      debugPrint("Notification status: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }

  static Future<bool> sendOneNotification({required String token, required String title, required String body, required Map<String, dynamic> payload}) async {
    try {
      final String accessToken = await getAccessToken();

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
        headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
        body: jsonEncode(<String, dynamic>{
          'message': {
            'token': token,
            'notification': {'body': body, 'title': title},
            'data': _stringifyPayload(payload),
            'android': {
              'priority': 'HIGH',
              'ttl': '60s',
              'notification': {'sound': 'default', 'channel_id': '0'},
            },
            'apns': {
              'headers': {'apns-priority': '10', 'apns-push-type': 'alert'},
              'payload': {
                'aps': {'content-available': 1, 'sound': 'default', 'mutable-content': 1},
              },
            },
          },
        }),
      );

      debugPrint("Notification status: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }

  /// Sends a CallKit-style incoming order push to a vendor or driver.
  ///
  /// On Android this delivers a high-priority data-only FCM message — the
  /// receiving app's background handler shows a full-screen incoming-call UI.
  ///
  /// On iOS this delivers a VoIP push to the dedicated `voipToken` (PushKit).
  /// The receiving app must call `CXProvider.reportNewIncomingCall` within
  /// ~5 seconds (handled by flutter_callkit_incoming inside AppDelegate).
  ///
  /// [token] — FCM token (Android delivery).
  /// [voipToken] — APNs VoIP push token, optional (iOS delivery, may be null).
  /// [iosBundleId] — bundle id of the receiver app (vendor/driver). Used to
  ///   build the `apns-topic` (`<bundleId>.voip`).
  /// [data] — extra fields available to the receiving app: orderId, rideId,
  ///   amount, address, title, body, customerName, etc.
  static Future<bool> sendCallKitNotification({
    required String type,
    required String token,
    String? voipToken,
    String? iosBundleId,
    required Map<String, dynamic> data,
  }) async {
    bool anySuccess = false;
    try {
      final String accessToken = await getAccessToken();
      final NotificationModel? template = await FireStoreUtils.getNotificationContent(type);

      final Map<String, dynamic> mergedData = _stringifyPayload({
        ...data,
        'type': type,
        'callkit': '1',
        if (template?.subject != null) 'title': data['title'] ?? template!.subject,
        if (template?.message != null) 'body': data['body'] ?? template!.message,
      });

      final androidResponse = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
        headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
        body: jsonEncode(<String, dynamic>{
          'message': {
            'token': token,
            'data': mergedData,
            'android': {
              'priority': 'HIGH',
              'ttl': '60s',
              'direct_boot_ok': true,
            },
          },
        }),
      );

      debugPrint("CallKit Android push status: ${androidResponse.statusCode} body=${androidResponse.body}");
      anySuccess = androidResponse.statusCode == 200;

      if (voipToken != null && voipToken.isNotEmpty && iosBundleId != null && iosBundleId.isNotEmpty) {
        final iosResponse = await http.post(
          Uri.parse('https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
          headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
          body: jsonEncode(<String, dynamic>{
            'message': {
              'token': voipToken,
              'data': mergedData,
              'apns': {
                'headers': {
                  'apns-priority': '10',
                  'apns-push-type': 'voip',
                  'apns-topic': '$iosBundleId.voip',
                  'apns-expiration': '0',
                },
                'payload': {
                  'aps': {'content-available': 1},
                  ...mergedData,
                },
              },
            },
          }),
        );
        debugPrint("CallKit iOS VoIP push status: ${iosResponse.statusCode} body=${iosResponse.body}");
        anySuccess = anySuccess || iosResponse.statusCode == 200;
      }

      return anySuccess;
    } catch (e) {
      debugPrint("sendCallKitNotification error: $e");
      return anySuccess;
    }
  }

  static Future<bool> sendChatFcmMessage(String title, String message, String token, Map<String, dynamic>? payload) async {
    try {
      final String accessToken = await getAccessToken();
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
        headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
        body: jsonEncode(<String, dynamic>{
          'message': {
            'token': token,
            'notification': {'body': message, 'title': title},
            'data': _stringifyPayload(payload),
            'android': {
              'priority': 'HIGH',
              'ttl': '60s',
              'notification': {'sound': 'default', 'channel_id': '0'},
            },
            'apns': {
              'headers': {'apns-priority': '10', 'apns-push-type': 'alert'},
              'payload': {
                'aps': {'content-available': 1, 'sound': 'default'},
              },
            },
          },
        }),
      );
      debugPrint("Notification status: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print(e);
      return false;
    }
  }
}
