import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/service/audio_player_service.dart';
import 'package:vendor/service/order_background_service.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/force_update_helper.dart';
import 'package:vendor/app/Home_screen/order_details_screen.dart';
import 'package:vendor/utils/preferences.dart';

class HomeController extends GetxController {
  RxBool isLoading = true.obs;

  Rx<TextEditingController> estimatedTimeController = TextEditingController().obs;
  Rx<TextEditingController> courierCompanyName = TextEditingController().obs;
  Rx<TextEditingController> courierCompanyTrackingId = TextEditingController().obs;

  /// Tayyorlash vaqti: daqiqa (0–120) va sekund (0–59)
  RxInt prepareMinutes = 15.obs;
  RxInt prepareSeconds = 0.obs;

  void setPrepareTimeFromController() {
    estimatedTimeController.value.text =
        '${prepareMinutes.value.toString().padLeft(2, '0')}:${prepareSeconds.value.toString().padLeft(2, '0')}';
  }

  /// Tayyorlash vaqti dialogini ochishdan oldin chaqiriladi
  void initPrepareTimeForDialog() {
    prepareMinutes.value = 15;
    prepareSeconds.value = 0;
    setPrepareTimeFromController();
  }

  RxInt selectedTabIndex = 0.obs;

  /// CallKit orqali qabul qilingan orderning ID si. home_screen.dart bu fieldni
  /// kuzatadi va tegishli order bottom sheet ni avtomatik ochadi.
  RxString pendingHighlightOrderId = ''.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getUserProfile();
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    ForceUpdateHelper.checkAndShowIfNeeded();
    _consumePendingCallkitOrder();
    // newOrderList yangilanganda pendingHighlightOrderId ga mos order bor-yo'qligini tekshiradi
    ever(newOrderList, (_) => _tryOpenHighlightedOrder());
    ever(pendingHighlightOrderId, (_) => _tryOpenHighlightedOrder());
  }

  /// CallKit orqali qabul qilingan order newOrderList da topilsa,
  /// avtomatik OrderDetailsScreen ochadi.
  void _tryOpenHighlightedOrder() {
    final id = pendingHighlightOrderId.value;
    if (id.isEmpty) return;
    try {
      final order = newOrderList.firstWhere((o) => o.id == id);
      pendingHighlightOrderId.value = '';
      Get.to(
        const OrderDetailsScreen(),
        arguments: {"orderModel": order},
      );
    } catch (_) {
      // Order hali newOrderList da yo'q — keyingi snapshot yangilaganda qaytadan uriniladi
    }
  }

  /// If the vendor accepted an order from a CallKit prompt while the app was
  /// terminated, [Preferences.pendingOrderId] will be set. We pull the user
  /// onto the "New" tab so the order is immediately visible.
  Future<void> _consumePendingCallkitOrder() async {
    final orderId = Preferences.getString(Preferences.pendingOrderId);
    if (orderId.isEmpty) return;
    await Preferences.clearKeyData(Preferences.pendingOrderId);
    await Preferences.clearKeyData(Preferences.pendingOrderType);
    selectedTabIndex.value = 0;
    // home_screen.dart bu fieldni kuzatadi va o'sha order uchun bottom sheet ochadi.
    pendingHighlightOrderId.value = orderId;
  }

  RxList<OrderModel> allOrderList = <OrderModel>[].obs;
  RxList<OrderModel> newOrderList = <OrderModel>[].obs;
  RxList<OrderModel> acceptedOrderList = <OrderModel>[].obs;
  RxList<OrderModel> completedOrderList = <OrderModel>[].obs;
  RxList<OrderModel> rejectedOrderList = <OrderModel>[].obs;
  RxList<OrderModel> cancelledOrderList = <OrderModel>[].obs;

  Rx<UserModel> userModel = UserModel().obs;
  Rx<VendorModel> vendermodel = VendorModel().obs;

  Future<void> getUserProfile() async {
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value != null) {
        userModel.value = value;
        Constant.userModel = userModel.value;
      }
    });
    final vendorId = userModel.value.vendorID ?? '';
    unawaited(setBackgroundVendorId(vendorId));
    if (vendorId.isNotEmpty) {
      await FireStoreUtils.getVendorById(vendorId).then((vender) {
        if (vender?.id != null) {
          vendermodel.value = vender!;
        }
      });
    }
    await getOrder();
    isLoading.value = false;
  }

  RxList<UserModel> driverUserList = <UserModel>[].obs;
  Rx<UserModel> selectDriverUser = UserModel().obs;

  StreamSubscription? _ordersSubscription;

  @override
  void onClose() {
    _ordersSubscription?.cancel();
    super.onClose();
  }

  Future<void> getAllDriverList() async {
    await FireStoreUtils.getAvalibleDrivers().then((value) {
      if (value.isNotEmpty == true) {
        driverUserList.value = value;
      }
    });
    isLoading.value = false;
  }

  Future<void> _diagnoseOrders() async {
    final vendorId = Constant.userModel?.vendorID;
    final uid = FireStoreUtils.getCurrentUid();
    developer.log(
      '🔎 [DIAG] start userModel.id=${Constant.userModel?.id} '
      'userModel.role=${Constant.userModel?.role} '
      'userModel.vendorID="$vendorId" '
      'currentUid=$uid '
      'collection=${CollectionName.vendorOrders}',
    );

    // 1) Raw user doc — tasdiqlash uchun
    try {
      final userDoc = await FireStoreUtils.fireStore
          .collection(CollectionName.users)
          .doc(uid)
          .get();
      developer.log(
        '🔎 [DIAG] users/$uid exists=${userDoc.exists} '
        'vendorID="${userDoc.data()?['vendorID']}" '
        '(${userDoc.data()?['vendorID']?.runtimeType}) '
        'role=${userDoc.data()?['role']}',
      );
    } catch (e, st) {
      developer.log('❌ [DIAG] users/$uid get error: $e',
          error: e, stackTrace: st);
    }

    // 2) Server-dan to'g'ridan-to'g'ri (kesh emas)
    try {
      final server = await FireStoreUtils.fireStore
          .collection(CollectionName.vendorOrders)
          .where('vendorID', isEqualTo: vendorId)
          .orderBy('createdAt', descending: true)
          .get(const GetOptions(source: Source.server));
      developer.log(
        '🔎 [DIAG] server get (where+orderBy): docs=${server.docs.length} '
        'isFromCache=${server.metadata.isFromCache}',
      );
      for (var i = 0; i < server.docs.length && i < 3; i++) {
        final d = server.docs[i];
        developer.log(
          '🔎 [DIAG] server.doc[$i] id=${d.id} keys=${d.data().keys.toList()}',
        );
      }
    } catch (e, st) {
      developer.log(
        '❌ [DIAG] server get (where+orderBy) FAILED: $e',
        error: e,
        stackTrace: st,
      );
    }

    // 3) Indekssiz (orderBy yo'q) — kompozit index muammosini ajratish uchun
    try {
      final noIndex = await FireStoreUtils.fireStore
          .collection(CollectionName.vendorOrders)
          .where('vendorID', isEqualTo: vendorId)
          .get(const GetOptions(source: Source.server));
      developer.log(
        '🔎 [DIAG] server get (where ONLY, no orderBy): docs=${noIndex.docs.length}',
      );
    } catch (e, st) {
      developer.log(
        '❌ [DIAG] server get (where ONLY) FAILED: $e',
        error: e,
        stackTrace: st,
      );
    }

    // 4) Filtrsiz limit(5) — to'plamda umuman nima borligini ko'rish
    try {
      final any = await FireStoreUtils.fireStore
          .collection(CollectionName.vendorOrders)
          .limit(5)
          .get(const GetOptions(source: Source.server));
      developer.log(
        '🔎 [DIAG] server get (no filter, limit 5): docs=${any.docs.length}',
      );
      for (var i = 0; i < any.docs.length; i++) {
        final d = any.docs[i];
        final data = d.data();
        final v = data['vendorID'];
        final author = data['authorID'];
        final vendorNested =
            data['vendor'] is Map ? (data['vendor'] as Map) : null;
        developer.log(
          '🔎 [DIAG] any.doc[$i] id=${d.id} '
          'vendorID="$v" (${v?.runtimeType}) '
          'authorID="$author" '
          'vendor.id="${vendorNested?['id']}" '
          'vendor.author="${vendorNested?['author']}" '
          'status=${data['status']}',
        );
      }
    } catch (e, st) {
      developer.log(
        '❌ [DIAG] server get (no filter) FAILED: $e',
        error: e,
        stackTrace: st,
      );
    }

    // 5) vendors/<vendorID> hujjati mavjudmi, author kim?
    try {
      final v = await FireStoreUtils.fireStore
          .collection(CollectionName.vendors)
          .doc(vendorId)
          .get(const GetOptions(source: Source.server));
      developer.log(
        '🔎 [DIAG] vendors/$vendorId exists=${v.exists} '
        'author="${v.data()?['author']}" '
        'title="${v.data()?['title']}"',
      );
    } catch (e, st) {
      developer.log('❌ [DIAG] vendors/$vendorId get FAILED: $e',
          error: e, stackTrace: st);
    }

    // 6) author == currentUid bo'yicha vendor topib ko'ramiz — vendor hujjati boshqa ID ga ko'chgan bo'lsa
    try {
      final byAuthor = await FireStoreUtils.fireStore
          .collection(CollectionName.vendors)
          .where('author', isEqualTo: uid)
          .limit(5)
          .get(const GetOptions(source: Source.server));
      developer.log(
        '🔎 [DIAG] vendors where author=$uid: docs=${byAuthor.docs.length}',
      );
      for (var i = 0; i < byAuthor.docs.length; i++) {
        final d = byAuthor.docs[i];
        developer.log(
          '🔎 [DIAG] vendors-by-author[$i] id=${d.id} '
          'title="${d.data()['title']}"',
        );
      }
    } catch (e, st) {
      developer.log('❌ [DIAG] vendors where author=$uid FAILED: $e',
          error: e, stackTrace: st);
    }

    // 7) authorID == currentUid bo'yicha tegishli order topib ko'ramiz
    try {
      final byAuthorOrder = await FireStoreUtils.fireStore
          .collection(CollectionName.vendorOrders)
          .where('authorID', isEqualTo: uid)
          .limit(5)
          .get(const GetOptions(source: Source.server));
      developer.log(
        '🔎 [DIAG] vendor_orders where authorID=$uid: docs=${byAuthorOrder.docs.length}',
      );
    } catch (e, st) {
      developer.log('❌ [DIAG] vendor_orders where authorID FAILED: $e',
          error: e, stackTrace: st);
    }

    // 8) vendor.author (nested) == currentUid bo'yicha qidirish — vendorID o'zgargan
    //    bo'lsa ham, vendor obyekti ichidagi author maydoni saqlanib qolgan bo'ladi
    try {
      final byNested = await FireStoreUtils.fireStore
          .collection(CollectionName.vendorOrders)
          .where('vendor.author', isEqualTo: uid)
          .limit(20)
          .get(const GetOptions(source: Source.server));
      developer.log(
        '🔎 [DIAG] vendor_orders where vendor.author=$uid: docs=${byNested.docs.length}',
      );
      final foundVendorIds = <String>{};
      for (var i = 0; i < byNested.docs.length; i++) {
        final d = byNested.docs[i];
        final v = d.data()['vendorID']?.toString();
        if (v != null) foundVendorIds.add(v);
        if (i < 5) {
          developer.log(
            '🔎 [DIAG] nested-match[$i] orderId=${d.id} '
            'vendorID="$v" status=${d.data()['status']}',
          );
        }
      }
      developer.log(
        '🔎 [DIAG] HAQIQIY vendorID lar (nested.author=$uid bo\'yicha): '
        '${foundVendorIds.toList()}',
      );
    } catch (e, st) {
      developer.log('❌ [DIAG] vendor_orders where vendor.author FAILED: $e',
          error: e, stackTrace: st);
    }

    // 9) Kengroq tasvir — vendor_orders dagi unique vendorID lar (kichik to'plam)
    try {
      final wide = await FireStoreUtils.fireStore
          .collection(CollectionName.vendorOrders)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get(const GetOptions(source: Source.server));
      final uniqueVendorIds = <String>{};
      for (final d in wide.docs) {
        final v = d.data()['vendorID']?.toString();
        if (v != null && v.isNotEmpty) uniqueVendorIds.add(v);
      }
      developer.log(
        '🔎 [DIAG] oxirgi 50 ordering unique vendorID lari (jami ${uniqueVendorIds.length}): '
        '$uniqueVendorIds',
      );
      developer.log(
        '🔎 [DIAG] sizning vendorID="$vendorId" shu ro\'yxatda bormi? '
        '${uniqueVendorIds.contains(vendorId)}',
      );
    } catch (e, st) {
      developer.log('❌ [DIAG] wide scan FAILED: $e',
          error: e, stackTrace: st);
    }

    developer.log('🔎 [DIAG] end');
  }

  Future<void> getOrder() async {
    try {
      developer.log(
        '🟦 [getOrder] subscribe: vendorID=${Constant.userModel?.vendorID} '
        'currentUid=${FireStoreUtils.getCurrentUid()} '
        'collection=${CollectionName.vendorOrders}',
      );
      // Bir martalik tashxis — listenerga parallel ravishda
      unawaited(_diagnoseOrders());
      await _ordersSubscription?.cancel();
      _ordersSubscription = FireStoreUtils.fireStore
          .collection(CollectionName.vendorOrders)
          .where('vendorID', isEqualTo: Constant.userModel!.vendorID)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
        (event) {
          developer.log(
            '🟦 [getOrder] snapshot received: docs=${event.docs.length} '
            'metadata.isFromCache=${event.metadata.isFromCache} '
            'hasPendingWrites=${event.metadata.hasPendingWrites}',
          );
          for (var i = 0; i < event.docs.length && i < 3; i++) {
            final d = event.docs[i];
            developer.log(
              '🟦 [getOrder] doc[$i] id=${d.id} keys=${d.data().keys.toList()}',
            );
          }
          allOrderList.clear();
          int parsedOk = 0;
          int parseFailed = 0;
          for (var element in event.docs) {
            try {
              final data = element.data();
              final orderModel = OrderModel.fromJson(data);
              allOrderList.add(orderModel);
              parsedOk++;
            } catch (e, st) {
              parseFailed++;
              final data = element.data();
              final typesDump = data.map(
                (k, v) => MapEntry(k, '${v.runtimeType} = $v'),
              );
              developer.log(
                '❌ [ORDER_PARSE] docId=${element.id} error=$e',
                error: e,
                stackTrace: st,
              );
              developer.log('❌ [ORDER_PARSE] raw types: $typesDump');
            }
          }
          developer.log(
            '🟦 [getOrder] parse summary: ok=$parsedOk failed=$parseFailed '
            'allOrderList.length=${allOrderList.length}',
          );
          // Ro'yxatlarni to'liq allOrderList dan bir marta filtrlash (kuryer qabul qilganda ham "Qabul qilingan"da qoladi, faqat yetkazilgach "Tugallangan"ga o'tadi)
          newOrderList.value = allOrderList.where((p0) => p0.status == Constant.orderPlaced).toList();
          acceptedOrderList.value = allOrderList
              .where(
                (p0) =>
                    p0.status == Constant.orderAccepted ||
                    p0.status == Constant.driverPending ||
                    p0.status == Constant.driverAccepted ||
                    p0.status == Constant.driverRejected ||
                    p0.status == Constant.orderShipped ||
                    p0.status == Constant.orderInTransit,
              )
              .toList();
          completedOrderList.value = allOrderList.where((p0) => p0.status == Constant.orderCompleted).toList();
          rejectedOrderList.value = allOrderList.where((p0) => p0.status == Constant.orderRejected).toList();
          cancelledOrderList.value = allOrderList.where((p0) => p0.status == Constant.orderCancelled).toList();
          update();
          // Ringtone yuklash UI ni bloklamasin; katta base64 data URL 30s timeout va "Skipped frames" beradi
          if (newOrderList.isNotEmpty == true) {
            unawaited(AudioPlayerService.playSound(true));
          }
        },
        onError: (error, st) {
          // Handle Firestore index error gracefully
          if (error.toString().contains('failed-precondition') ||
              error.toString().contains('index')) {
            developer.log(
              '❌ [getOrder] Firestore index required. Please create the index in Firebase Console. error=$error',
              error: error,
              stackTrace: st is StackTrace ? st : null,
            );
          } else {
            developer.log(
              '❌ [getOrder] Error fetching orders: $error',
              error: error,
              stackTrace: st is StackTrace ? st : null,
            );
          }
        },
      );
    } catch (e, st) {
      developer.log(
        '❌ [getOrder] outer error: $e',
        error: e,
        stackTrace: st,
      );
    }
  }
}
