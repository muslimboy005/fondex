// ignore_for_file: non_constant_identifier_names

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/notification_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

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
            'notification': {'body': notificationModel!.message ?? '', 'title': notificationModel.subject ?? ''},
            'data': payload,
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
            'data': payload,
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

  /// Driver ilovasiga CallKit-style incoming order push yuboradi.
  /// Data-only FCM (notification bloki yo'q) → driverning background handler i
  /// ishlaydi va CallKit popup ko'rsatadi. iOS uchun VoIP token ham qo'llab-quvvatlanadi.
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
      final NotificationModel? template =
          await FireStoreUtils.getNotificationContent(type);

      final Map<String, dynamic> mergedData = <String, dynamic>{
        ...data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
        'type': type,
        'callkit': '1',
        if (template?.subject != null)
          'title': (data['title'] ?? template!.subject).toString(),
        if (template?.message != null)
          'body': (data['body'] ?? template!.message).toString(),
      };

      final androidResponse = await http.post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken'
        },
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
      debugPrint(
          "CallKit Android push status: ${androidResponse.statusCode} body=${androidResponse.body}");
      anySuccess = androidResponse.statusCode == 200;

      if (voipToken != null &&
          voipToken.isNotEmpty &&
          iosBundleId != null &&
          iosBundleId.isNotEmpty) {
        final iosResponse = await http.post(
          Uri.parse(
              'https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken'
          },
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
        debugPrint(
            "CallKit iOS VoIP push status: ${iosResponse.statusCode} body=${iosResponse.body}");
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
            'data': payload,
          },
        }),
      );
      debugPrint("Notification status: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print("error :::::::::::$e");
      return false;
    }
  }
}
