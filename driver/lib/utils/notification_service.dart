import 'dart:convert';
import 'dart:developer';
import 'package:driver/app/chat_screens/chat_screen.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/cab_home_controller.dart';
import 'package:driver/controllers/home_controller.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  log("BackGround Message :: ${message.messageId}");
}

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initInfo() async {
    try {
      print("🔔 [INIT] Notification service initInfo boshlandi");

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      print(
          "🔔 [INIT] Foreground notification presentation options o'rnatildi");

      var request = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print("🔔 [INIT] Permission so'rovi yuborildi");
      print("🔔 [INIT] Permission status: ${request.authorizationStatus}");
      print("🔔 [INIT] Permission alert: ${request.alert}");
      print("🔔 [INIT] Permission badge: ${request.badge}");
      print("🔔 [INIT] Permission sound: ${request.sound}");

      if (request.authorizationStatus == AuthorizationStatus.authorized ||
          request.authorizationStatus == AuthorizationStatus.provisional) {
        print("🔔 [INIT] Permission berildi, notification service sozlanmoqda");

        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');

        const DarwinInitializationSettings iosInitializationSettings =
            DarwinInitializationSettings();

        final InitializationSettings initializationSettings =
            InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: iosInitializationSettings,
        );

        await flutterLocalNotificationsPlugin.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            print(
                "🔔 [INIT] Notification response qabul qilindi: ${response.payload}");
            if (response.payload != null) {
              try {
                _handleNotificationClick(jsonDecode(response.payload!));
              } catch (e) {
                print("🔔 [INIT] Notification click handle xatolik: $e");
                log("Notification click handle error: $e");
              }
            }
          },
        );
        print("🔔 [INIT] Local notifications plugin initialized");

        await setupInteractedMessage();
        print("🔔 [INIT] setupInteractedMessage muvaffaqiyatli yakunlandi");
      } else {
        print(
            "🔔 [INIT] ⚠️ Permission rad etildi! Status: ${request.authorizationStatus}");
        print(
            "🔔 [INIT] ⚠️ Notification service ishlamaydi, permission kerak!");
        log("Notification permission denied: ${request.authorizationStatus}");
      }
    } catch (e, stackTrace) {
      print("🔔 [INIT] ❌ Xatolik initInfo da: $e");
      print("🔔 [INIT] Stack trace: $stackTrace");
      log("Notification initInfo error: $e\n$stackTrace");
    }
  }

  Future<void> setupInteractedMessage() async {
    try {
      print("🔔 [SETUP] setupInteractedMessage boshlandi");

      // App opened from terminated state
      RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print(
            "🔔 [SETUP] Initial message topildi: ${initialMessage.messageId}");
        print("🔔 [SETUP] Initial message data: ${initialMessage.data}");
        _handleNotificationClick(initialMessage.data);
      } else {
        print("🔔 [SETUP] Initial message yo'q");
      }

      // App in background and notification tapped
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("🔔 [SETUP] onMessageOpenedApp - notification bosildi");
        print("🔔 [SETUP] Message data: ${message.data}");
        try {
          _handleNotificationClick(message.data);
        } catch (e) {
          print("🔔 [SETUP] onMessageOpenedApp handle xatolik: $e");
          log("onMessageOpenedApp error: $e");
        }
      });
      print("🔔 [SETUP] onMessageOpenedApp listener o'rnatildi");

      // App in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("🔔 [NOTIFICATION] ========================================");
        print("🔔 [NOTIFICATION] Bildirishnoma keldi - onMessage");
        print("🔔 [NOTIFICATION] message.messageId: ${message.messageId}");
        print("🔔 [NOTIFICATION] message.data: ${message.data}");
        print("🔔 [NOTIFICATION] message.data.keys: ${message.data.keys}");
        print(
            "🔔 [NOTIFICATION] message.notification?.title: ${message.notification?.title}");
        print(
            "🔔 [NOTIFICATION] message.notification?.body: ${message.notification?.body}");
        print("🔔 [NOTIFICATION] ========================================");

        try {
          if (message.notification != null) {
            print("🔔 [NOTIFICATION] Notification display qilinmoqda");
            display(message);
          } else {
            print(
                "🔔 [NOTIFICATION] ⚠️ message.notification null, display qilinmaydi");
          }

          // Handle order notifications - trigger order refresh for cab orders
          final data = message.data;
          print("🔔 [NOTIFICATION] data.isNotEmpty: ${data.isNotEmpty}");

          // Check if this is a cab order notification or any order-related notification
          if (data.isNotEmpty) {
            final notificationType = data["type"]?.toString() ?? "";
            print("🔔 [NOTIFICATION] notificationType: $notificationType");

            final isOrderNotification = notificationType == "NEW_RIDE" ||
                notificationType == "ride_booking" ||
                notificationType.contains("order") ||
                notificationType.contains("ride") ||
                notificationType.contains("cab_order");

            print(
                "🔔 [NOTIFICATION] isOrderNotification: $isOrderNotification");

            if (isOrderNotification) {
              print(
                  "🔔 [NOTIFICATION] CabHomeController registered: ${Get.isRegistered<CabHomeController>()}");
              print(
                  "🔔 [NOTIFICATION] HomeController registered: ${Get.isRegistered<HomeController>()}");

              // Handle both controllers - they will check their respective order types
              // Handle CabHomeController (for cab/ride orders and barber courier with orderCabRequestData)
              if (Get.isRegistered<CabHomeController>()) {
                try {
                  final cabController = Get.find<CabHomeController>();
                  print("🔔 [NOTIFICATION] CabHomeController topildi");
                  log("Notification: Triggering order refresh for cab controller");

                  final rideId = data["rideId"]?.toString() ?? "";
                  print("🔔 [NOTIFICATION] rideId: $rideId");

                  final driverId = FireStoreUtils.getCurrentUid();
                  FireStoreUtils.getUserProfile(driverId).then((driverModel) {
                    if (driverModel == null) {
                      print("🔔 [NOTIFICATION] Driver document null");
                      return;
                    }
                    cabController.driverModel.value = driverModel;
                    // Oflayn haydovchiga zakaz ko'rsatilmaydi (barbar kelmasin)
                    if (driverModel.isActive != true) {
                      print("🔔 [NOTIFICATION] Haydovchi oflayn - zakaz yuklanmaydi");
                      return;
                    }
                    print("🔔 [NOTIFICATION] Driver document yangilandi, orderCabRequestData: ${driverModel.orderCabRequestData?.id}");
                    log("Notification: Driver document refreshed, orderCabRequestData: ${driverModel.orderCabRequestData?.id}");

                    if (rideId.isNotEmpty) {
                      print("🔔 [NOTIFICATION] rideId dan order o'qilmoqda: $rideId");
                      cabController.getOrderByRideId(rideId);
                    }
                    if (driverModel.orderCabRequestData == null && rideId.isNotEmpty) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        cabController.getOrderByRideId(rideId);
                      });
                    }
                    Future.delayed(const Duration(milliseconds: 300), () {
                      cabController.getCurrentOrder();
                    });
                    Future.delayed(const Duration(milliseconds: 500), () {
                      cabController.getCurrentOrder();
                    });
                    Future.delayed(const Duration(milliseconds: 1000), () {
                      cabController.getCurrentOrder();
                    });
                    Future.delayed(const Duration(milliseconds: 2000), () {
                      cabController.getCurrentOrder();
                    });
                  });
                } catch (e) {
                  print("🔔 [NOTIFICATION] Xatolik: $e");
                  log("Error refreshing cab order from notification: $e");
                }
              } else {
                print(
                    "🔔 [NOTIFICATION] CabHomeController hali ro'yxatdan o'tmagan!");
                log("Notification: CabHomeController not registered yet");
              }

              // Handle HomeController (for food delivery orders and barber courier)
              // Check if this is a cab order notification first
              final isCabOrder =
                  data["type"]?.toString().contains("ride") == true ||
                      data["type"]?.toString().contains("cab") == true ||
                      data["rideId"]?.toString().isNotEmpty == true;

              // If it's a cab order, handle it with CabHomeController (already handled above)
              // Otherwise, handle with HomeController for food delivery and barber courier
              if (!isCabOrder && Get.isRegistered<HomeController>()) {
                try {
                  final homeController = Get.find<HomeController>();
                  print("🔔 [NOTIFICATION] HomeController topildi");
                  log("Notification: Triggering order refresh for home controller");

                  // Notification data ichidagi orderId (orderId, order_id yoki id – new_delivery_order da id ishlatiladi)
                  final orderId = data["orderId"]?.toString() ??
                      data["order_id"]?.toString() ??
                      data["id"]?.toString() ??
                      "";
                  print("🔔 [NOTIFICATION] orderId: $orderId");

                  // Darhol orderId bo‘yicha stream boshlash – driver dokumenti yangilanmasa ham buyurtma chiqadi
                  if (orderId.isNotEmpty) {
                    print("🔔 [NOTIFICATION] listenToOrderById chaqirilmoqda: $orderId");
                    homeController.listenToOrderById(orderId);
                  }

                  // Driver dokumentini yangilash (orderRequestData va boshqalar)
                  final driverId = FireStoreUtils.getCurrentUid();
                  print(
                      "🔔 [NOTIFICATION] Driver ID: $driverId, getUserProfile chaqirilmoqda (HomeController)");

                  FireStoreUtils.getUserProfile(driverId).then((driverModel) {
                    if (driverModel != null) {
                      print(
                          "🔔 [NOTIFICATION] Driver document yangilandi (HomeController)");
                      print(
                          "🔔 [NOTIFICATION] orderRequestData: ${driverModel.orderRequestData}");
                      homeController.driverModel.value = driverModel;
                      log("Notification: Driver document refreshed, orderRequestData: ${driverModel.orderRequestData}");

                      // Bildirishnomadan orderId kelgan bo‘lsa getCurrentOrder() chaqirmaymiz –
                      // u birinchi buyurtmaga obuna bo‘lib listenToOrderById streamini bekor qiladi
                      if (orderId.isEmpty) {
                        homeController.getCurrentOrder();
                      }
                    } else {
                      print(
                          "🔔 [NOTIFICATION] Driver document null (HomeController)");
                    }
                  });

                  // orderId bo‘lmaganda qolgan tekshiruvlar uchun getCurrentOrder (delay bilan)
                  if (orderId.isEmpty) {
                    Future.delayed(const Duration(milliseconds: 300), () {
                      homeController.getCurrentOrder();
                    });
                    Future.delayed(const Duration(milliseconds: 500), () {
                      homeController.getCurrentOrder();
                    });
                    Future.delayed(const Duration(milliseconds: 1000), () {
                      homeController.getCurrentOrder();
                    });
                    Future.delayed(const Duration(milliseconds: 2000), () {
                      homeController.getCurrentOrder();
                    });
                  }
                } catch (e) {
                  print("🔔 [NOTIFICATION] Xatolik (HomeController): $e");
                  log("Error refreshing home order from notification: $e");
                }
              } else {
                print(
                    "🔔 [NOTIFICATION] HomeController hali ro'yxatdan o'tmagan!");
                log("Notification: HomeController not registered yet");
              }
            }
          }
        } catch (e) {
          print("🔔 [NOTIFICATION] ❌ onMessage listener ichida xatolik: $e");
          log("onMessage listener error: $e");
        }
      });

      print("🔔 [SETUP] onMessage listener o'rnatildi");

      // Subscribe to driver topic
      try {
        await FirebaseMessaging.instance.subscribeToTopic("driver");
        print("🔔 [SETUP] 'driver' topic ga subscribe qilindi");
      } catch (e) {
        print("🔔 [SETUP] ⚠️ Topic subscribe xatolik: $e");
        log("Topic subscribe error: $e");
      }

      print("🔔 [SETUP] setupInteractedMessage muvaffaqiyatli yakunlandi");
    } catch (e, stackTrace) {
      print("🔔 [SETUP] ❌ setupInteractedMessage xatolik: $e");
      print("🔔 [SETUP] Stack trace: $stackTrace");
      log("setupInteractedMessage error: $e\n$stackTrace");
    }
  }

  static Future<String> getToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    return token ?? "";
  }

  void display(RemoteMessage message) async {
    try {
      print("🔔 [DISPLAY] Notification display boshlandi");
      print("🔔 [DISPLAY] Title: ${message.notification?.title}");
      print("🔔 [DISPLAY] Body: ${message.notification?.body}");
      print("🔔 [DISPLAY] Data: ${message.data}");

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'driver_notifications_channel',
        'Driver Notifications',
        channelDescription: 'App Notifications',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        message.notification?.title ?? "New Notification",
        message.notification?.body ?? "",
        notificationDetails,
        payload: jsonEncode(message.data),
      );
      print("🔔 [DISPLAY] ✅ Notification muvaffaqiyatli ko'rsatildi");
    } catch (e, stackTrace) {
      print("🔔 [DISPLAY] ❌ Notification display xatolik: $e");
      print("🔔 [DISPLAY] Stack trace: $stackTrace");
      log("Notification display error: $e\n$stackTrace");
    }
  }

  void _handleNotificationClick(Map<String, dynamic> data) async {
    log("Notification Click Data: $data");

    if (data["type"] == "chat") {
      String? orderId = data["orderId"];
      String? restaurantId = data["restaurantId"];
      String? customerId = data["customerId"];
      String? chatType =
          data["chatType"] ?? "Driver"; // must match ChatController

      if (orderId == null || restaurantId == null || customerId == null) {
        log("Invalid chat data in notification.");
        return;
      }

      ShowToastDialog.showLoader("Loading chat...".tr);

      // Fetch the profiles
      UserModel? customer = await FireStoreUtils.getUserProfile(customerId);
      UserModel? restaurantUser =
          await FireStoreUtils.getUserProfile(restaurantId);

      ShowToastDialog.closeLoader();

      if (customer == null || restaurantUser == null) {
        log("Failed to load user profiles for chat navigation.");
        return;
      }

      // Navigate to ChatScreen with exact arguments
      Get.to(() => const ChatScreen(), arguments: {
        "customerName": customer.fullName(),
        "restaurantName": restaurantUser.fullName(),
        "orderId": orderId,
        "restaurantId": restaurantUser.id,
        "customerId": customer.id,
        "customerProfileImage": customer.profilePictureURL ?? "",
        "restaurantProfileImage": restaurantUser.profilePictureURL ?? "",
        "token": restaurantUser.fcmToken,
        "chatType": chatType, // must match ChatController
      });
    } else {
      // Yangi buyurtma bildirishnomasi bosilganda – orderId bo‘yicha stream boshlash (kuryer buyurtmasi)
      final orderIdFromPayload = data["orderId"]?.toString() ??
          data["order_id"]?.toString() ??
          data["id"]?.toString() ??
          "";
      final rideId = data["rideId"]?.toString() ?? "";
      if (orderIdFromPayload.isNotEmpty &&
          rideId.isEmpty &&
          Get.isRegistered<HomeController>()) {
        try {
          Get.find<HomeController>().listenToOrderById(orderIdFromPayload);
          log("Notification tap: listenToOrderById($orderIdFromPayload)");
        } catch (e) {
          log("Notification tap HomeController error: $e");
        }
      } else if (rideId.isNotEmpty && Get.isRegistered<CabHomeController>()) {
        try {
          Get.find<CabHomeController>().getOrderByRideId(rideId);
          log("Notification tap: getOrderByRideId($rideId)");
        } catch (e) {
          log("Notification tap CabHomeController error: $e");
        }
      } else {
        log("Unhandled notification type: ${data['type']}");
      }
    }
  }
}
