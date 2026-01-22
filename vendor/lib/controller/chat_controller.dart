import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:vendor/constant/send_notification.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/conversation_model.dart';
import 'package:vendor/models/inbox_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class ChatController extends GetxController {
  Rx<TextEditingController> messageController = TextEditingController().obs;

  final ScrollController scrollController = ScrollController();

  /// Whether we should auto-scroll to bottom once on initial load.
  /// This prevents the list from being forced to scroll on subsequent real-time updates.
  @override
  void onInit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToBottom(animated: false);
    });

    getArgument();
    super.onInit();
  }

  RxBool isLoading = true.obs;
  RxString orderId = "".obs;
  RxString customerId = "".obs;
  RxString customerName = "".obs;
  RxString customerProfileImage = "".obs;
  RxString restaurantId = "".obs;
  RxString restaurantName = "".obs;
  RxString restaurantProfileImage = "".obs;
  RxString token = "".obs;
  RxString chatType = "".obs;

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderId.value = argumentData['orderId'];
      customerId.value = argumentData['customerId'];
      customerName.value = argumentData['customerName'];
      customerProfileImage.value = argumentData['customerProfileImage'] ?? "";
      restaurantId.value = argumentData['restaurantId'];
      restaurantName.value = argumentData['restaurantName'];
      restaurantProfileImage.value = argumentData['restaurantProfileImage'] ?? "";
      token.value = argumentData['token'];
      chatType.value = argumentData['chatType'];
    }
    isLoading.value = false;
  }

  /// Scrolls the chat view to the bottom (last message).
  /// If the controller isn't attached yet, schedules a post-frame callback to try again.
  void scrollToBottom({bool animated = true}) {
    if (scrollController.hasClients) {
      final target = scrollController.position.maxScrollExtent;
      if (animated) {
        scrollController.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } else {
        scrollController.jumpTo(target);
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom(animated: animated));
    }
  }

  Future<void> sendMessage(String message, Url? url, String videoThumbnail, String messageType) async {
    ShowToastDialog.showLoader("Sending...".tr);
    InboxModel inboxModel = InboxModel(
      lastSenderId: restaurantId.value,
      customerId: customerId.value,
      customerName: customerName.value,
      restaurantId: restaurantId.value,
      restaurantName: restaurantName.value,
      createdAt: Timestamp.now(),
      orderId: orderId.value,
      customerProfileImage: customerProfileImage.value,
      restaurantProfileImage: restaurantProfileImage.value,
      lastMessage: messageController.value.text,
      chatType: chatType.value,
    );
    if (chatType.value == 'customer') {
      await FireStoreUtils.addRestaurantInbox(inboxModel);
    }
    if (chatType.value == 'admin') {
      await FireStoreUtils.addAdminInbox(inboxModel);
    }

    ConversationModel conversationModel = ConversationModel(
      id: const Uuid().v4(),
      message: message,
      senderId: restaurantId.value,
      receiverId: customerId.value,
      createdAt: Timestamp.now(),
      url: url,
      orderId: orderId.value,
      messageType: messageType,
      videoThumbnail: videoThumbnail,
    );
    if (url != null) {
      if (url.mime.contains('image')) {
        conversationModel.message = "sent a message";
      } else if (url.mime.contains('video')) {
        conversationModel.message = "Sent a video";
      } else if (url.mime.contains('audio')) {
        conversationModel.message = "Sent a audio";
      }
    }
    log("messageType :: ${chatType.value}");
    if (chatType.value == 'customer') {
      await FireStoreUtils.addRestaurantChat(conversationModel);
      if (token.value.isNotEmpty) {
        SendNotification.sendChatFcmMessage(restaurantName.value, conversationModel.message.toString(), token.value, {});
      }
    }
    print("chatType :: ${chatType.value}");
    if (chatType.value == 'admin') {
      await FireStoreUtils.addAdminChat(conversationModel);
      if (token.value.isNotEmpty) {
        SendNotification.sendChatFcmMessage(restaurantName.value, conversationModel.message.toString(), token.value, {});
      }
    }

    // Clear the message input and scroll to the latest message so it's visible to the user.
    try {
      messageController.value.clear();
    } catch (_) {}
    ShowToastDialog.closeLoader();
    // Give a small delay to allow the new message to be rendered, then scroll
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
  }

  final ImagePicker imagePicker = ImagePicker();
}
