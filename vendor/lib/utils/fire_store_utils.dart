import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
import 'package:vendor/app/chat_screens/ChatVideoContainer.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/send_notification.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/AttributesModel.dart';
import 'package:vendor/models/SectionModel.dart';
import 'package:vendor/models/advertisement_model.dart';
import 'package:vendor/models/brands_model.dart';
import 'package:vendor/models/conversation_model.dart';
import 'package:vendor/models/coupon_model.dart';
import 'package:vendor/models/dine_in_booking_model.dart';
import 'package:vendor/models/document_model.dart';
import 'package:vendor/models/driver_document_model.dart';
import 'package:vendor/models/email_template_model.dart';
import 'package:vendor/models/inbox_model.dart';
import 'package:vendor/models/mail_setting.dart';
import 'package:vendor/models/notification_model.dart';
import 'package:vendor/models/on_boarding_model.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/models/payment_model/cod_setting_model.dart';
import 'package:vendor/models/payment_model/flutter_wave_model.dart';
import 'package:vendor/models/payment_model/mercado_pago_model.dart';
import 'package:vendor/models/payment_model/mid_trans.dart';
import 'package:vendor/models/payment_model/orange_money.dart';
import 'package:vendor/models/payment_model/pay_fast_model.dart';
import 'package:vendor/models/payment_model/pay_stack_model.dart';
import 'package:vendor/models/payment_model/paypal_model.dart';
import 'package:vendor/models/payment_model/paytm_model.dart';
import 'package:vendor/models/payment_model/razorpay_model.dart';
import 'package:vendor/models/payment_model/stripe_model.dart';
import 'package:vendor/models/payment_model/wallet_setting_model.dart';
import 'package:vendor/models/payment_model/xendit.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/models/rating_model.dart';
import 'package:vendor/models/referral_model.dart';
import 'package:vendor/models/review_attribute_model.dart';
import 'package:vendor/models/story_model.dart';
import 'package:vendor/models/subscription_history.dart';
import 'package:vendor/models/subscription_plan_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_category_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/models/wallet_transaction_model.dart';
import 'package:vendor/models/withdraw_method_model.dart';
import 'package:vendor/models/withdrawal_model.dart';
import 'package:vendor/models/zone_model.dart';
import 'package:vendor/service/audio_player_service.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/utils/preferences.dart';
import 'package:video_compress/video_compress.dart';

class FireStoreUtils {
  static FirebaseFirestore fireStore = FirebaseFirestore.instance;

  static String getCurrentUid() {
    return FirebaseAuth.instance.currentUser!.uid;
  }

  static Future<bool> isLogin() async {
    bool isLogin = false;
    if (FirebaseAuth.instance.currentUser != null) {
      isLogin = await userExistOrNot(FirebaseAuth.instance.currentUser!.uid);
    } else {
      isLogin = false;
    }
    return isLogin;
  }

  static Future<bool> userExistOrNot(String uid) async {
    bool isExist = false;

    await fireStore
        .collection(CollectionName.users)
        .doc(uid)
        .get()
        .then((value) {
          if (value.exists) {
            isExist = true;
          } else {
            isExist = false;
          }
        })
        .catchError((error) {
          log("Failed to check user exist: $error");
          isExist = false;
        });
    return isExist;
  }

  static Future<UserModel?> getUserProfile(String uuid) async {
    UserModel? userModel;
    await fireStore.collection(CollectionName.users).doc(uuid).get().then((
      value,
    ) {
      if (value.exists) {
        userModel = UserModel.fromJson(value.data()!);
        Constant.userModel = userModel;
      }
    });
    return userModel;
  }

  static Future<UserModel?> getUserById(String uuid) async {
    UserModel? userModel;
    log("uuid :: $uuid");
    await fireStore.collection(CollectionName.users).doc(uuid).get().then((
      value,
    ) {
      if (value.exists) {
        userModel = UserModel.fromJson(value.data()!);
      }
    });
    return userModel;
  }

  static Future<UserModel?> getUserByPhoneNumber(
    String countryCode,
    String phoneNumber,
  ) async {
    UserModel? userModel;
    try {
      await fireStore
          .collection(CollectionName.users)
          .where('countryCode', isEqualTo: countryCode)
          .where('phoneNumber', isEqualTo: phoneNumber)
          .where('role', isEqualTo: Constant.userRoleVendor)
          .get()
          .then((value) {
            if (value.docs.isNotEmpty) {
              userModel = UserModel.fromJson(value.docs.first.data());
            }
          });
    } catch (e) {
      log("Failed to get user by phone number: $e");
    }
    return userModel;
  }

  static Future<bool?> updateUserWallet({
    required String amount,
    required String userId,
  }) async {
    bool isAdded = false;
    await getUserProfile(userId).then((value) async {
      if (value != null) {
        UserModel userModel = value;
        userModel.walletAmount =
            ((userModel.walletAmount ?? 0.0) + double.parse(amount));
        await FireStoreUtils.updateUser(userModel).then((value) {
          isAdded = value;
        });
      }
    });
    return isAdded;
  }

  static Future<bool> updateUser(UserModel userModel) async {
    bool isUpdate = false;
    await fireStore
        .collection(CollectionName.users)
        .doc(userModel.id)
        .set(userModel.toJson())
        .whenComplete(() {
          Constant.userModel = userModel;
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  static Future<bool> updateDriverUser(UserModel userModel) async {
    bool isUpdate = false;
    await fireStore
        .collection(CollectionName.users)
        .doc(userModel.id)
        .set(userModel.toJson())
        .whenComplete(() {
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  static Future<bool> withdrawWalletAmount(WithdrawalModel userModel) async {
    bool isUpdate = false;
    await fireStore
        .collection(CollectionName.payouts)
        .doc(userModel.id)
        .set(userModel.toJson())
        .whenComplete(() {
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  static Future<List<OnBoardingModel>> getOnBoardingList() async {
    List<OnBoardingModel> onBoardingModel = [];
    await fireStore
        .collection(CollectionName.onBoarding)
        .where("type", isEqualTo: "store")
        .get()
        .then((value) {
          for (var element in value.docs) {
            OnBoardingModel documentModel = OnBoardingModel.fromJson(
              element.data(),
            );
            onBoardingModel.add(documentModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return onBoardingModel;
  }

  static Future<bool?> setWalletTransaction(
    WalletTransactionModel walletTransactionModel,
  ) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.wallet)
        .doc(walletTransactionModel.id)
        .set(walletTransactionModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  Future<void> getSettings() async {
    try {
      await FirebaseFirestore.instance
          .collection(CollectionName.settings)
          .doc("globalSettings")
          .get()
          .then((value) async {
            Constant.orderRingtoneUrl =
                value.data()?['order_ringtone_url'] ?? '';
            Constant.defaultCountryCode =
                value.data()?['defaultCountryCode'] ?? '';
            Constant.defaultCountry = value.data()?['defaultCountry'] ?? '';
            Preferences.setString(
              Preferences.orderRingtone,
              Constant.orderRingtoneUrl,
            );
            AppThemeData.primary300 = Color(
              int.parse(
                value.data()!['app_store_color'].replaceFirst("#", "0xff"),
              ),
            );
            Constant.isEnableAdsFeature =
                value.data()?['isEnableAdsFeature'] ?? false;
            Constant.isSelfDeliveryFeature =
                value.data()?['isSelfDelivery'] ?? false;
            if (Constant.orderRingtoneUrl.isNotEmpty) {
              await AudioPlayerService.initAudio();
            }
          });

      fireStore
          .collection(CollectionName.settings)
          .doc("DriverNearBy")
          .get()
          .then((event) {
            if (event.exists) {
              Constant.selectedMapType = Constant.normalizeSelectedMapType(
                event.data()!["selectedMapType"],
              );
              Constant.singleOrderReceive = event.data()!['singleOrderReceive'];
              Constant.distanceType = event.data()!["distanceType"];
            }
          });

      FirebaseFirestore.instance
          .collection(CollectionName.settings)
          .doc("scheduleOrderNotification")
          .get()
          .then((time) {
            if (time.exists) {
              Constant.scheduleOrderTime = time.data()!["notifyTime"];
              Constant.scheduleOrderTimeType = time.data()!["timeUnit"];
            }
          });

      fireStore
          .collection(CollectionName.settings)
          .doc("maintenance_settings")
          .snapshots()
          .listen((event) {
            if (event.exists && event.data() != null) {
              Constant.isMaintenanceModeForVendor =
                  event.data()?["isMaintenanceModeForVendor"] ?? false;
            }
          });

      await FirebaseFirestore.instance
          .collection(CollectionName.settings)
          .doc('vendor')
          .get()
          .then((value) {
            Constant.autoApproveVendor = value.data()!['auto_approve_vendor'];
            Constant.autoApproveStore = value.data()!['auto_approve_store'];
            Constant.isSubscriptionModelApplied = value
                .data()!['subscription_model'];
          });

      fireStore
          .collection(CollectionName.settings)
          .doc("googleMapKey")
          .snapshots()
          .listen((event) {
            if (event.exists) {
              Constant.mapAPIKey = event.data()!["key"];
            }
          });

      fireStore.collection(CollectionName.settings).doc('story').get().then((
        value,
      ) {
        Constant.storyEnable = value.data()!['isEnabled'];
      });

      fireStore
          .collection(CollectionName.settings)
          .doc('placeHolderImage')
          .get()
          .then((value) {
            Constant.placeholderImage = value.data()!['image'];
          });

      fireStore
          .collection(CollectionName.settings)
          .doc("Version")
          .snapshots()
          .listen((event) {
            if (event.exists) {
              Constant.googlePlayLink = event.data()!["googlePlayLink"] ?? '';
              Constant.appStoreLink = event.data()!["appStoreLink"] ?? '';
              Constant.appVersion = event.data()!["app_version"] ?? '';
              Constant.storeUrl = event.data()!["storeUrl"] ?? '';
            }
          });

      FirebaseFirestore.instance
          .collection(CollectionName.settings)
          .doc("specialDiscountOffer")
          .get()
          .then((dineinresult) {
            if (dineinresult.exists) {
              Constant.specialDiscountOfferEnable = dineinresult
                  .data()!["isEnable"];
            }
          });

      FirebaseFirestore.instance
          .collection(CollectionName.settings)
          .doc("emailSetting")
          .get()
          .then((value) {
            if (value.exists) {
              Constant.mailSettings = MailSettings.fromJson(value.data()!);
            }
          });

      FirebaseFirestore.instance
          .collection(CollectionName.settings)
          .doc("ContactUs")
          .get()
          .then((time) {
            if (time.exists) {
              Constant.adminEmail = time.data()!["Email"];
            }
          });

      fireStore
          .collection(CollectionName.settings)
          .doc("notification_setting")
          .snapshots()
          .listen((event) {
            if (event.exists) {
              Constant.senderId = event.data()?["senderId"];
              Constant.jsonNotificationFileURL = event.data()?["serviceJson"];
            }
          });

      await FirebaseFirestore.instance
          .collection(CollectionName.settings)
          .doc("document_verification_settings")
          .get()
          .then((value) {
            Constant.isStoreVerification = value.data()!['isStoreVerification'];
          });

      fireStore
          .collection(CollectionName.settings)
          .doc("privacyPolicy")
          .get()
          .then((event) {
            if (event.exists) {
              Constant.privacyPolicy = event.data()!["privacy_policy"];
            }
          });

      fireStore
          .collection(CollectionName.settings)
          .doc("termsAndConditions")
          .get()
          .then((event) {
            if (event.exists) {
              Constant.termsAndConditions = event
                  .data()!["terms_and_condition"];
            }
          });

      fireStore
          .collection(CollectionName.settings)
          .doc("digitalProduct")
          .get()
          .then((event) {
            if (event.exists) {
              Constant.digitalProductFileSize =
                  event.data()!["fileSize"] ?? "10";
            }
          });
    } catch (e) {
      log(e.toString());
    }
  }

  static Future<bool?> checkReferralCodeValidOrNot(String referralCode) async {
    bool? isExit;
    try {
      await fireStore
          .collection(CollectionName.referral)
          .where("referralCode", isEqualTo: referralCode)
          .get()
          .then((value) {
            if (value.size > 0) {
              isExit = true;
            } else {
              isExit = false;
            }
          });
    } catch (e, s) {
      print('FireStoreUtils.firebaseCreateNewUser $e $s');
      return false;
    }
    return isExit;
  }

  static Future<ReferralModel?> getReferralUserByCode(
    String referralCode,
  ) async {
    ReferralModel? referralModel;
    try {
      await fireStore
          .collection(CollectionName.referral)
          .where("referralCode", isEqualTo: referralCode)
          .get()
          .then((value) {
            if (value.docs.isNotEmpty) {
              referralModel = ReferralModel.fromJson(value.docs.first.data());
            }
          });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return referralModel;
  }

  static Future<OrderModel?> getOrderByOrderId(String orderId) async {
    OrderModel? orderModel;
    try {
      await fireStore
          .collection(CollectionName.vendorOrders)
          .doc(orderId)
          .get()
          .then((value) {
            if (value.exists) {
              orderModel = OrderModel.fromJson(value.data()!);
            }
          });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return orderModel;
  }

  static Future<String?> referralAdd(ReferralModel ratingModel) async {
    try {
      await fireStore
          .collection(CollectionName.referral)
          .doc(ratingModel.id)
          .set(ratingModel.toJson());
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return null;
  }

  static Future<List<ZoneModel>?> getZone(String sectionId) async {
    List<ZoneModel> airPortList = [];
    await fireStore
        .collection(CollectionName.zone)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            ZoneModel ariPortModel = ZoneModel.fromJson(element.data());
            airPortList.add(ariPortModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return airPortList;
  }

  static Future<List<OrderModel>?> getAllOrder() async {
    List<OrderModel> orderList = [];
    try {
      await fireStore
          .collection(CollectionName.vendorOrders)
          .where('vendorID', isEqualTo: Constant.userModel!.vendorID)
          .orderBy('createdAt', descending: true)
          .get()
          .then((value) {
            for (var element in value.docs) {
              OrderModel orderModel = OrderModel.fromJson(element.data());
              orderList.add(orderModel);
            }
          })
          .catchError((error) {
            log(error.toString());
          });
    } catch (e) {
      log(e.toString());
    }
    return orderList;
  }

  static Future<bool> deleteCashbackRedeem(OrderModel orderModel) async {
    bool isUpdate = false;
    try {
      final querySnapshot = await fireStore
          .collection(CollectionName.cashbackRedeem)
          .where('orderId', isEqualTo: orderModel.id)
          .where('cashbackId', isEqualTo: orderModel.cashback?.id)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          await fireStore
              .collection(CollectionName.cashbackRedeem)
              .doc(doc.id)
              .delete();
        }
        isUpdate = true;
      } else {
        isUpdate = false;
      }
    } catch (e) {
      isUpdate = false;
      rethrow;
    }
    return isUpdate;
  }

  static Future<bool> updateOrder(OrderModel orderModel) async {
    bool isUpdate = false;

    await fireStore
        .collection(CollectionName.vendorOrders)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .whenComplete(() {
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  static Future restaurantVendorWalletSet(OrderModel orderModel) async {
    double subTotal = 0.0;
    double specialDiscount = 0.0;
    double taxAmount = 0.0;
    // double adminCommission = 0.0;

    for (var element in orderModel.products!) {
      if (double.parse(element.discountPrice.toString()) <= 0) {
        subTotal =
            subTotal +
            double.parse(element.price.toString()) *
                double.parse(element.quantity.toString()) +
            (double.parse(element.extrasPrice.toString()) *
                double.parse(element.quantity.toString()));
      } else {
        subTotal =
            subTotal +
            double.parse(element.discountPrice.toString()) *
                double.parse(element.quantity.toString()) +
            (double.parse(element.extrasPrice.toString()) *
                double.parse(element.quantity.toString()));
      }
    }

    if (orderModel.specialDiscount != null &&
        orderModel.specialDiscount!['special_discount'] != null) {
      specialDiscount = double.parse(
        orderModel.specialDiscount!['special_discount'].toString(),
      );
    }

    if (orderModel.taxSetting != null) {
      for (var element in orderModel.taxSetting!) {
        taxAmount =
            taxAmount +
            Constant.calculateTax(
              amount:
                  (subTotal -
                          double.parse(orderModel.discount.toString()) -
                          specialDiscount)
                      .toString(),
              taxModel: element,
            );
      }
    }

    double basePrice = 0;
    if (Constant.vendorAdminCommission!.isEnabled == true) {
      basePrice =
          (subTotal / (1 + (double.parse(orderModel.adminCommission!) / 100))) -
          double.parse(orderModel.discount.toString()) -
          specialDiscount;
    } else {
      basePrice =
          subTotal -
          double.parse(orderModel.discount.toString()) -
          specialDiscount;
    }

    WalletTransactionModel historyModel = WalletTransactionModel(
      amount: basePrice,
      id: const Uuid().v4(),
      orderId: orderModel.id,
      userId: orderModel.vendor!.author,
      date: Timestamp.now(),
      isTopup: true,
      note: "Order Amount credited",
      paymentMethod: "Wallet",
      paymentStatus: "success",
      transactionUser: "vendor",
    );

    await fireStore
        .collection(CollectionName.wallet)
        .doc(historyModel.id)
        .set(historyModel.toJson());

    WalletTransactionModel taxModel = WalletTransactionModel(
      amount: taxAmount,
      id: const Uuid().v4(),
      orderId: orderModel.id,
      userId: orderModel.vendor!.author,
      date: Timestamp.now(),
      isTopup: true,
      note: "Order Tax credited",
      paymentMethod: "tax",
      paymentStatus: "success",
      transactionUser: "vendor",
    );

    await fireStore
        .collection(CollectionName.wallet)
        .doc(historyModel.id)
        .set(historyModel.toJson());
    await fireStore
        .collection(CollectionName.wallet)
        .doc(taxModel.id)
        .set(taxModel.toJson());

    await updateUserWallet(
      amount: (basePrice + taxAmount).toString(),
      userId: orderModel.vendor!.author.toString(),
    );
  }

  static Future<RatingModel?> getOrderReviewsByID(
    String orderId,
    String productID,
  ) async {
    RatingModel? ratingModel;

    await fireStore
        .collection(CollectionName.foodsReview)
        .where('orderid', isEqualTo: orderId)
        .where('productId', isEqualTo: productID)
        .get()
        .then((value) {
          print("======>");
          print(value.docs.length);
          if (value.docs.isNotEmpty) {
            ratingModel = RatingModel.fromJson(value.docs.first.data());
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return ratingModel;
  }

  static Future<List<ProductModel>?> getProduct() async {
    List<ProductModel> productList = [];

    try {
      // Try with orderBy first (requires index)
      final querySnapshot = await fireStore
          .collection(CollectionName.vendorProducts)
          .where('vendorID', isEqualTo: Constant.userModel!.vendorID)
          .orderBy('createdAt', descending: false)
          .get();

      for (var element in querySnapshot.docs) {
        ProductModel productModel = ProductModel.fromJson(element.data());
        productList.add(productModel);
      }
    } catch (e) {
      // If index error, try without orderBy and sort in Dart
      if (e.toString().contains('failed-precondition') ||
          e.toString().contains('index') ||
          e.toString().contains('FAILED_PRECONDITION')) {
        log('Firestore index not ready, fetching without orderBy...');
        try {
          final querySnapshot = await fireStore
              .collection(CollectionName.vendorProducts)
              .where('vendorID', isEqualTo: Constant.userModel!.vendorID)
              .get();

          for (var element in querySnapshot.docs) {
            ProductModel productModel = ProductModel.fromJson(element.data());
            productList.add(productModel);
          }

          // Sort by createdAt in Dart
          productList.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return a.createdAt!.compareTo(b.createdAt!);
          });

          log(
            'Products fetched without orderBy, sorted in Dart. Count: ${productList.length}',
          );
        } catch (fallbackError) {
          log('Error fetching products without orderBy: $fallbackError');
        }
      } else {
        log('Error in getProduct: $e');
      }
    }

    return productList;
  }

  static Future<List<AdvertisementModel>?> getAdvertisement() async {
    List<AdvertisementModel> advertisementList = [];
    await fireStore
        .collection(CollectionName.advertisements)
        .where('vendorId', isEqualTo: Constant.userModel!.vendorID)
        .get()
        .then((value) {
          for (var element in value.docs) {
            AdvertisementModel advertisementModel = AdvertisementModel.fromJson(
              element.data(),
            );
            advertisementList.add(advertisementModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });

    // Sort by createdAt descending in code to avoid composite index requirement
    advertisementList.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    return advertisementList;
  }

  static Future<AdvertisementModel> getAdvertisementById({
    required String advertisementId,
  }) async {
    AdvertisementModel advertisementdata = AdvertisementModel();
    await fireStore
        .collection(CollectionName.advertisements)
        .doc(advertisementId)
        .get()
        .then((value) {
          AdvertisementModel advertisementModel = AdvertisementModel.fromJson(
            value.data() as Map<String, dynamic>,
          );
          advertisementdata = advertisementModel;
        })
        .catchError((error) {
          log(error.toString());
        });
    return advertisementdata;
  }

  static Future<bool> updateProduct(ProductModel productModel) async {
    bool isUpdate = false;
    await fireStore
        .collection(CollectionName.vendorProducts)
        .doc(productModel.id)
        .set(productModel.toJson())
        .whenComplete(() {
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  static Future<bool> deleteProduct(ProductModel productModel) async {
    bool isUpdate = false;
    await fireStore
        .collection(CollectionName.vendorProducts)
        .doc(productModel.id)
        .delete()
        .whenComplete(() {
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  static Future<List<WalletTransactionModel>?> getWalletTransaction() async {
    List<WalletTransactionModel> walletTransactionList = [];
    await fireStore
        .collection(CollectionName.wallet)
        .where('user_id', isEqualTo: FireStoreUtils.getCurrentUid())
        .get()
        .then((value) {
          for (var element in value.docs) {
            WalletTransactionModel walletTransactionModel =
                WalletTransactionModel.fromJson(element.data());
            walletTransactionList.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });

    // Sort by date descending in code to avoid composite index requirement
    walletTransactionList.sort((a, b) => b.date!.compareTo(a.date!));
    return walletTransactionList;
  }

  static Future<List<SectionModel>> getSection() async {
    List<SectionModel> walletTransactionList = [];
    await fireStore
        .collection(CollectionName.sections)
        .where('isActive', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            SectionModel sectionModel = SectionModel.fromJson(element.data());
            walletTransactionList.add(sectionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return walletTransactionList;
  }

  static Future<List<WalletTransactionModel>?> getFilterWalletTransaction(
    Timestamp startTime,
    Timestamp endTime,
  ) async {
    List<WalletTransactionModel> walletTransactionList = [];
    await fireStore
        .collection(CollectionName.wallet)
        .where('user_id', isEqualTo: FireStoreUtils.getCurrentUid())
        .where('date', isGreaterThanOrEqualTo: startTime)
        .where('date', isLessThanOrEqualTo: endTime)
        .get()
        .then((value) {
          for (var element in value.docs) {
            WalletTransactionModel walletTransactionModel =
                WalletTransactionModel.fromJson(element.data());
            walletTransactionList.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });

    // Sort by date descending in code to avoid composite index requirement
    walletTransactionList.sort((a, b) => b.date!.compareTo(a.date!));
    return walletTransactionList;
  }

  static Future<List<WithdrawalModel>?> getWithdrawHistory() async {
    List<WithdrawalModel> walletTransactionList = [];
    await fireStore
        .collection(CollectionName.payouts)
        .where('vendorID', isEqualTo: Constant.userModel!.vendorID.toString())
        .orderBy('paidDate', descending: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            WithdrawalModel walletTransactionModel = WithdrawalModel.fromJson(
              element.data(),
            );
            walletTransactionList.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return walletTransactionList;
  }

  static Future getPaymentSettingsData() async {
    await fireStore
        .collection(CollectionName.settings)
        .doc("payFastSettings")
        .get()
        .then((value) async {
          if (value.exists) {
            PayFastModel payFastModel = PayFastModel.fromJson(value.data()!);
            await Preferences.setString(
              Preferences.payFastSettings,
              jsonEncode(payFastModel.toJson()),
            );
          }
        });
    await fireStore
        .collection(CollectionName.settings)
        .doc("MercadoPago")
        .get()
        .then((value) async {
          if (value.exists) {
            MercadoPagoModel mercadoPagoModel = MercadoPagoModel.fromJson(
              value.data()!,
            );
            await Preferences.setString(
              Preferences.mercadoPago,
              jsonEncode(mercadoPagoModel.toJson()),
            );
          }
        });
    await fireStore
        .collection(CollectionName.settings)
        .doc("paypalSettings")
        .get()
        .then((value) async {
          if (value.exists) {
            PayPalModel payPalModel = PayPalModel.fromJson(value.data()!);
            await Preferences.setString(
              Preferences.paypalSettings,
              jsonEncode(payPalModel.toJson()),
            );
          }
        });
    await fireStore
        .collection(CollectionName.settings)
        .doc("stripeSettings")
        .get()
        .then((value) async {
          if (value.exists) {
            StripeModel stripeModel = StripeModel.fromJson(value.data()!);
            await Preferences.setString(
              Preferences.stripeSettings,
              jsonEncode(stripeModel.toJson()),
            );
          }
        });
    await fireStore
        .collection(CollectionName.settings)
        .doc("flutterWave")
        .get()
        .then((value) async {
          if (value.exists) {
            FlutterWaveModel flutterWaveModel = FlutterWaveModel.fromJson(
              value.data()!,
            );
            await Preferences.setString(
              Preferences.flutterWave,
              jsonEncode(flutterWaveModel.toJson()),
            );
          }
        });
    await fireStore
        .collection(CollectionName.settings)
        .doc("payStack")
        .get()
        .then((value) async {
          if (value.exists) {
            PayStackModel payStackModel = PayStackModel.fromJson(value.data()!);
            await Preferences.setString(
              Preferences.payStack,
              jsonEncode(payStackModel.toJson()),
            );
          }
        });
    await fireStore
        .collection(CollectionName.settings)
        .doc("PaytmSettings")
        .get()
        .then((value) async {
          if (value.exists) {
            PaytmModel paytmModel = PaytmModel.fromJson(value.data()!);
            await Preferences.setString(
              Preferences.paytmSettings,
              jsonEncode(paytmModel.toJson()),
            );
          }
        });
    await fireStore
        .collection(CollectionName.settings)
        .doc("walletSettings")
        .get()
        .then((value) async {
          if (value.exists) {
            WalletSettingModel walletSettingModel = WalletSettingModel.fromJson(
              value.data()!,
            );
            await Preferences.setString(
              Preferences.walletSettings,
              jsonEncode(walletSettingModel.toJson()),
            );
          }
        });
    await fireStore
        .collection(CollectionName.settings)
        .doc("razorpaySettings")
        .get()
        .then((value) async {
          if (value.exists) {
            RazorPayModel razorPayModel = RazorPayModel.fromJson(value.data()!);
            await Preferences.setString(
              Preferences.razorpaySettings,
              jsonEncode(razorPayModel.toJson()),
            );
          }
        });
    await fireStore
        .collection(CollectionName.settings)
        .doc("CODSettings")
        .get()
        .then((value) async {
          if (value.exists) {
            CodSettingModel codSettingModel = CodSettingModel.fromJson(
              value.data()!,
            );
            await Preferences.setString(
              Preferences.codSettings,
              jsonEncode(codSettingModel.toJson()),
            );
          }
        });

    await fireStore
        .collection(CollectionName.settings)
        .doc("midtrans_settings")
        .get()
        .then((value) async {
          if (value.exists) {
            MidTrans midTrans = MidTrans.fromJson(value.data()!);
            await Preferences.setString(
              Preferences.midTransSettings,
              jsonEncode(midTrans.toJson()),
            );
          }
        });

    await fireStore
        .collection(CollectionName.settings)
        .doc("orange_money_settings")
        .get()
        .then((value) async {
          if (value.exists) {
            OrangeMoney orangeMoney = OrangeMoney.fromJson(value.data()!);
            await Preferences.setString(
              Preferences.orangeMoneySettings,
              jsonEncode(orangeMoney.toJson()),
            );
          }
        });

    await fireStore
        .collection(CollectionName.settings)
        .doc("xendit_settings")
        .get()
        .then((value) async {
          if (value.exists) {
            Xendit xendit = Xendit.fromJson(value.data()!);
            await Preferences.setString(
              Preferences.xenditSettings,
              jsonEncode(xendit.toJson()),
            );
          }
        });
  }

  static Future<VendorModel?> getVendorById(String vendorId) async {
    VendorModel? vendorModel;
    try {
      if (vendorId.isNotEmpty) {
        await fireStore
            .collection(CollectionName.vendors)
            .doc(vendorId)
            .get()
            .then((value) {
              if (value.exists) {
                vendorModel = VendorModel.fromJson(value.data()!);
              }
            });
      }
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorModel;
  }

  static Future<SectionModel?> getSectionById(String sectionId) async {
    SectionModel? sectionModel;
    try {
      await fireStore
          .collection(CollectionName.sections)
          .doc(sectionId)
          .get()
          .then((value) {
            if (value.exists) {
              sectionModel = SectionModel.fromJson(value.data()!);
            }
          });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return sectionModel;
  }

  static Future<List<VendorCategoryModel>> getVendorCategoryById(
    String sectionId,
  ) async {
    List<VendorCategoryModel> attributeList = [];
    await fireStore
        .collection(CollectionName.vendorCategories)
        .where('section_id', isEqualTo: sectionId)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            VendorCategoryModel favouriteModel = VendorCategoryModel.fromJson(
              element.data(),
            );
            attributeList.add(favouriteModel);
          }
        });
    return attributeList;
  }

  static Future<ProductModel?> getProductById(String productId) async {
    ProductModel? vendorCategoryModel;
    try {
      await fireStore
          .collection(CollectionName.vendorProducts)
          .doc(productId)
          .get()
          .then((value) {
            if (value.exists) {
              vendorCategoryModel = ProductModel.fromJson(value.data()!);
            }
          });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorCategoryModel;
  }

  static Future<VendorCategoryModel?> getVendorCategoryByCategoryId(
    String categoryId,
  ) async {
    VendorCategoryModel? vendorCategoryModel;
    try {
      await fireStore
          .collection(CollectionName.vendorCategories)
          .doc(categoryId)
          .get()
          .then((value) {
            if (value.exists) {
              vendorCategoryModel = VendorCategoryModel.fromJson(value.data()!);
            }
          });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorCategoryModel;
  }

  static Future<ReviewAttributeModel?> getVendorReviewAttribute(
    String attributeId,
  ) async {
    ReviewAttributeModel? vendorCategoryModel;
    try {
      await fireStore
          .collection(CollectionName.reviewAttributes)
          .doc(attributeId)
          .get()
          .then((value) {
            if (value.exists) {
              vendorCategoryModel = ReviewAttributeModel.fromJson(
                value.data()!,
              );
            }
          });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorCategoryModel;
  }

  static Future<List<AttributesModel>?> getAttributes() async {
    List<AttributesModel> attributeList = [];
    await fireStore.collection(CollectionName.vendorAttributes).get().then((
      value,
    ) {
      for (var element in value.docs) {
        AttributesModel favouriteModel = AttributesModel.fromJson(
          element.data(),
        );
        attributeList.add(favouriteModel);
      }
    });
    return attributeList;
  }

  static Future<List<BrandsModel>> getBrands() async {
    List<BrandsModel> attributeList = [];
    await fireStore.collection(CollectionName.brands).get().then((value) {
      for (var element in value.docs) {
        BrandsModel favouriteModel = BrandsModel.fromJson(element.data());
        attributeList.add(favouriteModel);
      }
    });
    return attributeList;
  }

  static Future<DeliveryCharge?> getDeliveryCharge() async {
    DeliveryCharge? deliveryCharge;
    try {
      await fireStore
          .collection(CollectionName.settings)
          .doc("DeliveryCharge")
          .get()
          .then((value) {
            if (value.exists) {
              deliveryCharge = DeliveryCharge.fromJson(value.data()!);
            }
          });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return deliveryCharge;
  }

  static Future<List<DineInBookingModel>> getDineInBooking(
    bool isUpcoming,
  ) async {
    List<DineInBookingModel> list = [];

    if (isUpcoming) {
      await fireStore
          .collection(CollectionName.bookedTable)
          .where('vendorID', isEqualTo: Constant.userModel!.vendorID)
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date', descending: true)
          .orderBy('createdAt', descending: true)
          .get()
          .then((value) {
            for (var element in value.docs) {
              DineInBookingModel taxModel = DineInBookingModel.fromJson(
                element.data(),
              );
              list.add(taxModel);
            }
          })
          .catchError((error) {
            log(error.toString());
          });
    } else {
      await fireStore
          .collection(CollectionName.bookedTable)
          .where('vendorID', isEqualTo: Constant.userModel!.vendorID)
          .where('date', isLessThan: Timestamp.now())
          .orderBy('date', descending: true)
          .orderBy('createdAt', descending: true)
          .get()
          .then((value) {
            for (var element in value.docs) {
              DineInBookingModel taxModel = DineInBookingModel.fromJson(
                element.data(),
              );
              list.add(taxModel);
            }
          })
          .catchError((error) {
            log(error.toString());
          });
    }

    return list;
  }

  static Future<List<CouponModel>> getAllVendorCoupons(String vendorId) async {
    List<CouponModel> coupon = [];

    await fireStore
        .collection(CollectionName.coupons)
        .where("vendorID", isEqualTo: vendorId)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
        .where("isPublic", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel taxModel = CouponModel.fromJson(element.data());
            coupon.add(taxModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return coupon;
  }

  static Future<bool?> setOrder(OrderModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.vendorOrders)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<bool?> setCoupon(CouponModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.coupons)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<bool?> deleteCoupon(CouponModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.coupons)
        .doc(orderModel.id)
        .delete()
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<List<CouponModel>> getOffer(String vendorId) async {
    List<CouponModel> list = [];
    await fireStore
        .collection(CollectionName.coupons)
        .where("vendorID", isEqualTo: vendorId)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel taxModel = CouponModel.fromJson(element.data());
            list.add(taxModel);
          }
        });

    // Sort by createdAt descending in code to avoid composite index requirement
    list.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    return list;
  }

  static Future<List<DocumentModel>> getDocumentList() async {
    List<DocumentModel> documentList = [];
    await fireStore
        .collection(CollectionName.documents)
        .where('type', isEqualTo: "vendor")
        .where('enable', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            DocumentModel documentModel = DocumentModel.fromJson(
              element.data(),
            );
            documentList.add(documentModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return documentList;
  }

  static Future<DriverDocumentModel?> getDocumentOfDriver() async {
    DriverDocumentModel? driverDocumentModel;
    await fireStore
        .collection(CollectionName.documentsVerify)
        .doc(getCurrentUid())
        .get()
        .then((value) async {
          if (value.exists) {
            driverDocumentModel = DriverDocumentModel.fromJson(value.data()!);
          }
        });
    return driverDocumentModel;
  }

  static Future addRestaurantInbox(InboxModel inboxModel) async {
    return await fireStore
        .collection("chat_store")
        .doc(inboxModel.orderId)
        .set(inboxModel.toJson())
        .then((document) {
          return inboxModel;
        });
  }

  static Future addAdminInbox(InboxModel inboxModel) async {
    return await fireStore
        .collection(CollectionName.chatAdmin)
        .doc(inboxModel.orderId)
        .set(inboxModel.toJson())
        .then((document) {
          return inboxModel;
        });
  }

  static Future addRestaurantChat(ConversationModel conversationModel) async {
    return await fireStore
        .collection("chat_store")
        .doc(conversationModel.orderId)
        .collection("thread")
        .doc(conversationModel.id)
        .set(conversationModel.toJson())
        .then((document) {
          return conversationModel;
        });
  }

  static Future addAdminChat(ConversationModel conversationModel) async {
    return await fireStore
        .collection(CollectionName.chatAdmin)
        .doc(conversationModel.orderId)
        .collection("thread")
        .doc(conversationModel.id)
        .set(conversationModel.toJson())
        .then((document) {
          return conversationModel;
        });
  }

  static Future<bool> uploadDriverDocument(Documents documents) async {
    bool isAdded = false;
    DriverDocumentModel driverDocumentModel = DriverDocumentModel();
    List<Documents> documentsList = [];
    await fireStore
        .collection(CollectionName.documentsVerify)
        .doc(getCurrentUid())
        .get()
        .then((value) async {
          if (value.exists) {
            DriverDocumentModel newDriverDocumentModel =
                DriverDocumentModel.fromJson(value.data()!);
            documentsList = newDriverDocumentModel.documents!;
            var contain = newDriverDocumentModel.documents!.where(
              (element) => element.documentId == documents.documentId,
            );
            if (contain.isEmpty) {
              documentsList.add(documents);

              driverDocumentModel.id = getCurrentUid();
              driverDocumentModel.type = "restaurant";
              driverDocumentModel.documents = documentsList;
            } else {
              var index = newDriverDocumentModel.documents!.indexWhere(
                (element) => element.documentId == documents.documentId,
              );

              driverDocumentModel.id = getCurrentUid();
              driverDocumentModel.type = "restaurant";
              documentsList.removeAt(index);
              documentsList.insert(index, documents);
              driverDocumentModel.documents = documentsList;
              isAdded = false;
            }
          } else {
            documentsList.add(documents);
            driverDocumentModel.id = getCurrentUid();
            driverDocumentModel.type = "restaurant";
            driverDocumentModel.documents = documentsList;
          }
        });

    await fireStore
        .collection(CollectionName.documentsVerify)
        .doc(getCurrentUid())
        .set(driverDocumentModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          isAdded = false;
          log(error.toString());
        });

    return isAdded;
  }

  static Future<DeliveryCharge?> getDelivery() async {
    DeliveryCharge? driverDocumentModel;
    await fireStore
        .collection(CollectionName.settings)
        .doc("DeliveryCharge")
        .get()
        .then((value) async {
          if (value.exists) {
            driverDocumentModel = DeliveryCharge.fromJson(value.data()!);
          }
        });
    return driverDocumentModel;
  }

  static Future<VendorModel> firebaseCreateNewVendor(VendorModel vendor) async {
    DocumentReference documentReference = fireStore
        .collection(CollectionName.vendors)
        .doc();
    vendor.id = documentReference.id;
    await documentReference.set(vendor.toJson());
    Constant.userModel!.vendorID = documentReference.id;
    vendor.fcmToken = Constant.userModel!.fcmToken;
    Constant.vendorAdminCommission = vendor.adminCommission;
    await FireStoreUtils.updateUser(Constant.userModel!);
    return vendor;
  }

  static Future<VendorModel?> updateVendor(VendorModel vendor) async {
    return await fireStore
        .collection(CollectionName.vendors)
        .doc(vendor.id)
        .set(vendor.toJson())
        .then((document) {
          Constant.vendorAdminCommission = vendor.adminCommission;
          return vendor;
        });
  }

  static Future<bool?> deleteUser() async {
    try {
      if (Constant.userModel?.vendorID != null &&
          Constant.userModel?.vendorID?.isNotEmpty == true) {
        await fireStore
            .collection(CollectionName.coupons)
            .where('vendorID', isEqualTo: Constant.userModel!.vendorID)
            .get()
            .then((value) async {
              for (var doc in value.docs) {
                await fireStore
                    .collection(CollectionName.coupons)
                    .doc(doc.reference.id)
                    .delete();
              }
            });
        await fireStore
            .collection(CollectionName.foodsReview)
            .where('VendorId', isEqualTo: Constant.userModel!.vendorID)
            .get()
            .then((value) async {
              for (var doc in value.docs) {
                await fireStore
                    .collection(CollectionName.foodsReview)
                    .doc(doc.reference.id)
                    .delete();
              }
            });

        await fireStore
            .collection(CollectionName.vendorProducts)
            .where('vendorID', isEqualTo: Constant.userModel?.vendorID)
            .get()
            .then((value) async {
              for (var doc in value.docs) {
                await fireStore
                    .collection(CollectionName.favoriteItem)
                    .where('product_id', isEqualTo: doc.reference.id)
                    .get()
                    .then((value0) async {
                      for (var element0 in value0.docs) {
                        await fireStore
                            .collection(CollectionName.favoriteItem)
                            .doc(element0.reference.path)
                            .delete();
                      }
                    });
                await fireStore
                    .collection(CollectionName.vendorProducts)
                    .doc(doc.reference.id)
                    .delete();
              }
            });

        await fireStore
            .collection(CollectionName.vendors)
            .doc(Constant.userModel?.vendorID)
            .delete();
      }

      await fireStore
          .collection(CollectionName.users)
          .doc(FireStoreUtils.getCurrentUid())
          .delete();

      // delete user  from firebase auth
      await FirebaseAuth.instance.currentUser?.delete();
      return true;
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return false;
    }
  }

  static Future<Url> uploadChatImageToFireStorage(
    File image,
    BuildContext context,
  ) async {
    ShowToastDialog.showLoader("Please wait");
    var uniqueID = const Uuid().v4();
    Reference upload = FirebaseStorage.instance.ref().child(
      'images/$uniqueID.png',
    );
    UploadTask uploadTask = upload.putFile(image);
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();
    var metaData = await storageRef.getMetadata();
    ShowToastDialog.closeLoader();
    return Url(
      mime: metaData.contentType ?? 'image',
      url: downloadUrl.toString(),
    );
  }

  static Future<ChatVideoContainer?> uploadChatVideoToFireStorage(
    BuildContext context,
    File video,
  ) async {
    try {
      ShowToastDialog.showLoader("Uploading video...");
      final String uniqueID = const Uuid().v4();
      final Reference videoRef = FirebaseStorage.instance.ref(
        'videos/$uniqueID.mp4',
      );
      final UploadTask uploadTask = videoRef.putFile(
        video,
        SettableMetadata(contentType: 'video/mp4'),
      );
      await uploadTask;
      final String videoUrl = await videoRef.getDownloadURL();
      ShowToastDialog.showLoader("Generating thumbnail...");
      File thumbnail = await VideoCompress.getFileThumbnail(
        video.path,
        quality: 75, // 0 - 100
        position: -1, // Get the first frame
      );

      final String thumbnailID = const Uuid().v4();
      final Reference thumbnailRef = FirebaseStorage.instance.ref(
        'thumbnails/$thumbnailID.jpg',
      );
      final UploadTask thumbnailUploadTask = thumbnailRef.putData(
        thumbnail.readAsBytesSync(),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      await thumbnailUploadTask;
      final String thumbnailUrl = await thumbnailRef.getDownloadURL();
      var metaData = await thumbnailRef.getMetadata();
      ShowToastDialog.closeLoader();

      return ChatVideoContainer(
        videoUrl: Url(
          url: videoUrl.toString(),
          mime: metaData.contentType ?? 'video',
          videoThumbnail: thumbnailUrl,
        ),
        thumbnailUrl: thumbnailUrl,
      );
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error: ${e.toString()}");
      return null;
    }
  }

  static Future<String> uploadImageOfStory(
    File image,
    BuildContext context,
    String extansion,
  ) async {
    final data = await image.readAsBytes();
    final mime = lookupMimeType('', headerBytes: data);

    Reference upload = FirebaseStorage.instance.ref().child(
      'Story/images/${image.path.split('/').last}',
    );
    UploadTask uploadTask = upload.putFile(
      image,
      SettableMetadata(contentType: mime),
    );
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();
    ShowToastDialog.closeLoader();
    return downloadUrl.toString();
  }

  // static Future<File> _compressVideo(File file) async {
  //   MediaInfo? info = await VideoCompress.compressVideo(file.path, quality: VideoQuality.DefaultQuality, deleteOrigin: false, includeAudio: true, frameRate: 24);
  //   if (info != null) {
  //     File compressedVideo = File(info.path!);
  //     return compressedVideo;
  //   } else {
  //     return file;
  //   }
  // }

  // static Future<String?> uploadVideoStory(File video, BuildContext context) async {
  //   var uniqueID = const Uuid().v4();
  //   Reference upload = FirebaseStorage.instance.ref().child('Story/$uniqueID.mp4');
  //   File compressedVideo = await _compressVideo(video);
  //   SettableMetadata metadata = SettableMetadata(contentType: 'video');
  //   UploadTask uploadTask = upload.putFile(compressedVideo, metadata);
  //   var storageRef = (await uploadTask.whenComplete(() {})).ref;
  //   var downloadUrl = await storageRef.getDownloadURL();
  //   ShowToastDialog.closeLoader();
  //   return downloadUrl.toString();
  // }

  static Future<File> _compressVideo(File file) async {
    MediaInfo? info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
      frameRate: 24,
    );
    return info != null ? File(info.path!) : file;
  }

  static Future<String?> uploadVideoStory(
    File video,
    BuildContext context,
  ) async {
    try {
      var uniqueID = const Uuid().v4();
      Reference upload = FirebaseStorage.instance.ref().child(
        'Story/$uniqueID.mp4',
      );

      File compressedVideo = await _compressVideo(video);
      SettableMetadata metadata = SettableMetadata(contentType: 'video/mp4');

      UploadTask uploadTask = upload.putFile(compressedVideo, metadata);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint("Upload progress: ${(progress * 100).toStringAsFixed(2)}%");
      });

      await uploadTask;
      var downloadUrl = await upload.getDownloadURL();

      // optional: delete temp compressed file
      if (compressedVideo.path != video.path) {
        await compressedVideo.delete();
      }

      return downloadUrl.toString();
    } catch (e) {
      debugPrint("Video upload failed: $e");
      return null;
    }
  }

  static Future<String> uploadVideoThumbnailToFireStorage(File file) async {
    var uniqueID = const Uuid().v4();
    Reference upload = FirebaseStorage.instance.ref().child(
      'thumbnails/$uniqueID.png',
    );
    UploadTask uploadTask = upload.putFile(file);
    var downloadUrl = await (await uploadTask.whenComplete(
      () {},
    )).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  static Future<StoryModel?> getStory(String vendorId) async {
    DocumentSnapshot<Map<String, dynamic>> userDocument = await fireStore
        .collection(CollectionName.story)
        .doc(vendorId)
        .get();
    if (userDocument.data() != null && userDocument.exists) {
      return StoryModel.fromJson(userDocument.data()!);
    } else {
      return null;
    }
  }

  static Future<void> addOrUpdateStory(StoryModel storyModel) async {
    try {
      Future.microtask(() async {
        await fireStore
            .collection(CollectionName.story)
            .doc(storyModel.vendorID)
            .set(storyModel.toJson());
      });
    } catch (e) {
      debugPrint("Error adding/updating story: $e");
    }
  }

  // static Future addOrUpdateStory(StoryModel storyModel) async {
  //   await fireStore.collection(CollectionName.story).doc(storyModel.vendorID).set(storyModel.toJson());
  // }

  static Future removeStory(String vendorId) async {
    await fireStore.collection(CollectionName.story).doc(vendorId).delete();
  }

  static Future<WithdrawMethodModel?> getWithdrawMethod() async {
    WithdrawMethodModel? withdrawMethodModel;
    await fireStore
        .collection(CollectionName.withdrawMethod)
        .where("userId", isEqualTo: getCurrentUid())
        .get()
        .then((value) async {
          if (value.docs.isNotEmpty) {
            withdrawMethodModel = WithdrawMethodModel.fromJson(
              value.docs.first.data(),
            );
          }
        });
    return withdrawMethodModel;
  }

  static Future<WithdrawMethodModel?> setWithdrawMethod(
    WithdrawMethodModel withdrawMethodModel,
  ) async {
    if (withdrawMethodModel.id == null) {
      withdrawMethodModel.id = const Uuid().v4();
      withdrawMethodModel.userId = getCurrentUid();
    }
    await fireStore
        .collection(CollectionName.withdrawMethod)
        .doc(withdrawMethodModel.id)
        .set(withdrawMethodModel.toJson())
        .then((value) async {});
    return withdrawMethodModel;
  }

  static Future<EmailTemplateModel?> getEmailTemplates(String type) async {
    EmailTemplateModel? emailTemplateModel;
    await fireStore
        .collection(CollectionName.emailTemplates)
        .where('type', isEqualTo: type)
        .get()
        .then((value) {
          if (value.docs.isNotEmpty) {
            emailTemplateModel = EmailTemplateModel.fromJson(
              value.docs.first.data(),
            );
          }
        });
    return emailTemplateModel;
  }

  static Future<void> sendPayoutMail({
    required String amount,
    required String payoutrequestid,
  }) async {
    EmailTemplateModel? emailTemplateModel =
        await FireStoreUtils.getEmailTemplates(Constant.payoutRequest);

    String body = emailTemplateModel!.subject.toString();
    body = body.replaceAll("{userid}", Constant.userModel!.id.toString());

    String newString = emailTemplateModel.message.toString();
    newString = newString.replaceAll(
      "{username}",
      Constant.userModel!.fullName(),
    );
    newString = newString.replaceAll(
      "{userid}",
      Constant.userModel!.id.toString(),
    );
    newString = newString.replaceAll(
      "{amount}",
      Constant.amountShow(amount: amount),
    );
    newString = newString.replaceAll(
      "{payoutrequestid}",
      payoutrequestid.toString(),
    );
    newString = newString.replaceAll(
      "{usercontactinfo}",
      "${Constant.userModel!.email}\n${Constant.userModel!.phoneNumber}",
    );
    await Constant.sendMail(
      subject: body,
      isAdmin: emailTemplateModel.isSendToAdmin,
      body: newString,
      recipients: [Constant.userModel!.email],
    );
  }

  static Future<NotificationModel?> getNotificationContent(String type) async {
    NotificationModel? notificationModel;
    await fireStore
        .collection(CollectionName.dynamicNotification)
        .where('type', isEqualTo: type)
        .get()
        .then((value) {
          print("------>");
          if (value.docs.isNotEmpty) {
            print(value.docs.first.data());

            notificationModel = NotificationModel.fromJson(
              value.docs.first.data(),
            );
          } else {
            notificationModel = NotificationModel(
              id: "",
              message: "Notification setup is pending",
              subject: "setup notification",
              type: "",
            );
          }
        });
    return notificationModel;
  }

  static Future<bool?> setBookedOrder(DineInBookingModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.bookedTable)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<bool?> setProduct(ProductModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.vendorProducts)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<String> uploadUserImageToFireStorage(
    File image,
    String userID,
  ) async {
    Reference upload = FirebaseStorage.instance.ref().child(
      'images/$userID.png',
    );
    UploadTask uploadTask = upload.putFile(image);
    var downloadUrl = await (await uploadTask.whenComplete(
      () {},
    )).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  static Future<List<SubscriptionPlanModel>> getAllSubscriptionPlans(
    String sectionId,
  ) async {
    List<SubscriptionPlanModel> subscriptionPlanModels = [];
    await fireStore
        .collection(CollectionName.subscriptionPlans)
        .where("isCommissionPlan", isEqualTo: false)
        .where("sectionId", isEqualTo: sectionId)
        .where('isEnable', isEqualTo: true)
        .get()
        .then((value) async {
          if (value.docs.isNotEmpty) {
            for (var element in value.docs) {
              SubscriptionPlanModel subscriptionPlanModel =
                  SubscriptionPlanModel.fromJson(element.data());
              subscriptionPlanModels.add(subscriptionPlanModel);
            }
          }
        });
    return subscriptionPlanModels;
  }

  static Future<List<SubscriptionPlanModel>> getSubscriptionCommissionPlanById(
    String sectionId,
  ) async {
    List<SubscriptionPlanModel> subscriptionPlanModels = [];
    await fireStore
        .collection(CollectionName.subscriptionPlans)
        .where("isCommissionPlan", isEqualTo: true)
        .where("sectionId", isEqualTo: sectionId)
        .where('isEnable', isEqualTo: true)
        .get()
        .then((value) async {
          if (value.docs.isNotEmpty) {
            for (var element in value.docs) {
              print(element.data());
              SubscriptionPlanModel subscriptionPlanModel =
                  SubscriptionPlanModel.fromJson(element.data());
              subscriptionPlanModels.add(subscriptionPlanModel);
            }
          }
        });
    return subscriptionPlanModels;
  }

  static Future<bool?> setSubscriptionTransaction(
    SubscriptionHistoryModel subscriptionPlan,
  ) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.subscriptionHistory)
        .doc(subscriptionPlan.id)
        .set(subscriptionPlan.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<List<SubscriptionHistoryModel>> getSubscriptionHistory() async {
    List<SubscriptionHistoryModel> subscriptionHistoryList = [];
    await fireStore
        .collection(CollectionName.subscriptionHistory)
        .where('user_id', isEqualTo: getCurrentUid())
        .orderBy('createdAt', descending: true)
        .get()
        .then((value) async {
          if (value.docs.isNotEmpty) {
            for (var element in value.docs) {
              SubscriptionHistoryModel subscriptionHistoryModel =
                  SubscriptionHistoryModel.fromJson(element.data());
              subscriptionHistoryList.add(subscriptionHistoryModel);
            }
          }
        });
    return subscriptionHistoryList;
  }

  static Future<AdvertisementModel> firebaseCreateAdvertisement(
    AdvertisementModel model,
  ) async {
    await fireStore
        .collection(CollectionName.advertisements)
        .doc(model.id)
        .set(model.toJson());
    return model;
  }

  static Future<AdvertisementModel> removeAdvertisement(
    AdvertisementModel model,
  ) async {
    await fireStore
        .collection(CollectionName.advertisements)
        .doc(model.id)
        .delete();
    return model;
  }

  static Future<AdvertisementModel> pauseAndResumeAdvertisement(
    AdvertisementModel model,
  ) async {
    await fireStore
        .collection(CollectionName.advertisements)
        .doc(model.id)
        .update(model.toJson());
    return model;
  }

  static Future<List<RatingModel>> getOrderReviewsByVenderId({
    required String venderId,
  }) async {
    List<RatingModel> ratingModelList = [];
    await fireStore
        .collection(CollectionName.foodsReview)
        .where('VendorId', isEqualTo: venderId)
        .get()
        .then((value) {
          print("======>");
          print(value.docs.length);
          if (value.docs.isNotEmpty) {
            for (int i = 0; i < value.docs.length; i++) {
              ratingModelList.add(RatingModel.fromJson(value.docs[i].data()));
            }
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return ratingModelList;
  }

  static Future<List<UserModel>> getAvalibleDrivers() async {
    List<UserModel> driverList = [];
    try {
      log("getAvalibleDrivers :: Starting search");
      log("getAvalibleDrivers :: vendorID=${Constant.userModel?.vendorID}");
      log("getAvalibleDrivers :: role=${Constant.userRoleDriver}");

      // Try with orderBy first (requires index)
      var querySnapshot = await fireStore
          .collection(CollectionName.users)
          .where('vendorID', isEqualTo: Constant.userModel?.vendorID)
          .where('role', isEqualTo: Constant.userRoleDriver)
          .where('active', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      log(
        "getAvalibleDrivers :: Query with orderBy returned ${querySnapshot.docs.length} docs",
      );

      if (querySnapshot.docs.isNotEmpty) {
        for (int i = 0; i < querySnapshot.docs.length; i++) {
          driverList.add(UserModel.fromJson(querySnapshot.docs[i].data()));
        }
      }
    } catch (e) {
      // If index error, try without orderBy and sort in Dart
      if (e.toString().contains('failed-precondition') ||
          e.toString().contains('index')) {
        log(
          'Firestore index not ready for drivers, fetching without orderBy...',
        );
        try {
          // First, try to get all drivers (without vendorID filter to debug)
          var allDriversByRoleSnapshot = await fireStore
              .collection(CollectionName.users)
              .where('role', isEqualTo: Constant.userRoleDriver)
              .get();

          log(
            "getAvalibleDrivers :: Found ${allDriversByRoleSnapshot.docs.length} total drivers (all vendors, role=driver)",
          );

          // Now filter by vendorID, active and isActive in Dart
          for (var doc in allDriversByRoleSnapshot.docs) {
            try {
              Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
              if (data == null) {
                log(
                  "getAvalibleDrivers :: ⚠️ Driver ${doc.id} data is null, skipping",
                );
                continue;
              }

              var vendorID = data['vendorID'];
              var active = data['active'];
              var isActive = data['isActive'];

              // Check if driver belongs to this vendor (or has no vendorID - available for all vendors) and is active
              bool belongsToVendor =
                  vendorID == Constant.userModel?.vendorID ||
                  vendorID == null ||
                  vendorID.toString().isEmpty;

              if (belongsToVendor && active == true && isActive == true) {
                driverList.add(UserModel.fromJson(data));
                log(
                  "getAvalibleDrivers :: ✅ Driver ${doc.id} added to list (vendorID=$vendorID)",
                );
              }
            } catch (e) {
              log(
                "getAvalibleDrivers :: Error processing driver ${doc.id}: $e",
              );
            }
          }

          // If still no drivers found, try without vendorID filter (for debugging)
          if (driverList.isEmpty) {
            log(
              "getAvalibleDrivers :: ⚠️ No drivers found with vendorID filter, checking all active drivers...",
            );
            for (var doc in allDriversByRoleSnapshot.docs) {
              try {
                Map<String, dynamic>? data =
                    doc.data() as Map<String, dynamic>?;
                if (data == null) continue;

                var vendorID = data['vendorID'];
                var active = data['active'];
                var isActive = data['isActive'];

                if (active == true && isActive == true) {
                  log(
                    "getAvalibleDrivers :: Active driver found: ${doc.id}, vendorID=$vendorID (expected: ${Constant.userModel?.vendorID})",
                  );
                }
              } catch (e) {
                log(
                  "getAvalibleDrivers :: Error checking driver ${doc.id}: $e",
                );
              }
            }
          }

          // Sort by createdAt in Dart
          try {
            driverList.sort((a, b) {
              if (a.createdAt == null && b.createdAt == null) return 0;
              if (a.createdAt == null) return 1;
              if (b.createdAt == null) return -1;
              return b.createdAt!.compareTo(a.createdAt!); // descending
            });
          } catch (sortError) {
            log("Error sorting drivers: $sortError");
          }

          log(
            "getAvalibleDrivers :: After filtering: ${driverList.length} active drivers",
          );
        } catch (fallbackError) {
          log(
            "Error fetching drivers without orderBy: ${fallbackError.toString()}",
          );
        }
      } else {
        log("Error fetching drivers: ${e.toString()}");
      }
    }

    log("getAvalibleDrivers :: Found ${driverList.length} drivers");
    return driverList;
  }

  static Future<List<UserModel>> getAllDrivers() async {
    List<UserModel> driverList = [];
    try {
      await fireStore
          .collection(CollectionName.users)
          .where('vendorID', isEqualTo: Constant.userModel?.vendorID)
          .where('role', isEqualTo: Constant.userRoleDriver)
          .orderBy('createdAt', descending: true)
          .get()
          .then((value) {
            if (value.docs.isNotEmpty) {
              for (int i = 0; i < value.docs.length; i++) {
                driverList.add(UserModel.fromJson(value.docs[i].data()));
              }
            }
          });
    } catch (e) {
      log("Error fetching drivers: ${e.toString()}");
    }
    return driverList;
  }

  /// Send order to all available couriers when vendor accepts order
  static Future<void> sendOrderToAllCouriers(OrderModel orderModel) async {
    try {
      log(
        "📦 [sendOrderToAllCouriers] Order ${orderModel.id} courier larga yuborilmoqda...",
      );
      log(
        "📦 [sendOrderToAllCouriers] Vendor ID: ${Constant.userModel?.vendorID}",
      );

      // Get all available couriers
      List<UserModel> courierList = await getAvalibleDrivers();

      log(
        "📦 [sendOrderToAllCouriers] Topilgan courier lar soni: ${courierList.length}",
      );

      if (courierList.isEmpty) {
        log("⚠️ [sendOrderToAllCouriers] Mavjud courier lar topilmadi");
        log(
          "⚠️ [sendOrderToAllCouriers] Tekshirish: vendorID=${Constant.userModel?.vendorID}, role=driver, active=true, isActive=true",
        );
        return;
      }

      log(
        "📦 [sendOrderToAllCouriers] ${courierList.length} ta courier topildi",
      );

      // Update order status to driverPending
      orderModel.status = Constant.driverPending;
      await updateOrder(orderModel);

      // Send order to each courier
      for (UserModel courier in courierList) {
        try {
          log(
            "📦 [sendOrderToAllCouriers] Processing courier ${courier.id}...",
          );

          // Refetch courier data from Firestore to get latest FCM token
          UserModel? freshCourierData = await getUserById(courier.id ?? '');
          if (freshCourierData == null) {
            log(
              "⚠️ [sendOrderToAllCouriers] Courier ${courier.id} ma'lumotlari topilmadi, o'tkazib yuborilmoqda",
            );
            continue;
          }

          // Use fresh data for FCM token check
          String? fcmToken = freshCourierData.fcmToken;
          log(
            "📦 [sendOrderToAllCouriers] Courier ${courier.id} FCM token: ${fcmToken != null ? (fcmToken.isNotEmpty ? 'EXISTS (${fcmToken.length} chars)' : 'EMPTY') : 'NULL'}",
          );
          log(
            "📦 [sendOrderToAllCouriers] Courier details: name=${freshCourierData.firstName} ${freshCourierData.lastName}, email=${freshCourierData.email}, active=${freshCourierData.active}, isActive=${freshCourierData.isActive}",
          );

          // Initialize orderRequestData if null
          freshCourierData.orderRequestData ??= [];

          // Add order ID to courier's orderRequestData if not already present
          if (!freshCourierData.orderRequestData!.contains(orderModel.id)) {
            freshCourierData.orderRequestData!.add(orderModel.id);
            await updateDriverUser(freshCourierData);
            log(
              "✅ [sendOrderToAllCouriers] Order ${orderModel.id} courier ${courier.id} ga qo'shildi",
            );
          } else {
            log(
              "ℹ️ [sendOrderToAllCouriers] Order ${orderModel.id} allaqachon courier ${courier.id} da mavjud",
            );
          }

          // Send notification to courier if FCM token exists
          if (fcmToken != null && fcmToken.isNotEmpty) {
            log(
              "📨 [sendOrderToAllCouriers] Sending notification to courier ${courier.id}...",
            );
            try {
              await SendNotification.sendFcmMessage(
                Constant.newDeliveryOrder,
                fcmToken,
                {'type': 'new_delivery_order', 'orderId': orderModel.id ?? ''},
              );
              log(
                "✅ [sendOrderToAllCouriers] Notification courier ${courier.id} ga muvaffaqiyatli yuborildi",
              );
            } catch (notificationError) {
              log(
                "❌ [sendOrderToAllCouriers] Notification yuborishda xatolik (courier ${courier.id}): $notificationError",
              );
            }
          } else {
            log(
              "⚠️ [sendOrderToAllCouriers] Courier ${courier.id} da FCM token yo'q yoki bo'sh.",
            );
            log(
              "⚠️ [sendOrderToAllCouriers] Eslatma: Driver ilovasida login qilgan bo'lishi va notification permission berilgan bo'lishi kerak. FCM token driver login qilganda avtomatik yangilanadi.",
            );
            log(
              "⚠️ [sendOrderToAllCouriers] Order ${orderModel.id} courier ${courier.id} ga qo'shildi, lekin notification yuborilmadi (FCM token yo'q).",
            );
          }
        } catch (e) {
          log(
            "❌ [sendOrderToAllCouriers] Courier ${courier.id} ga order yuborishda xatolik: $e",
          );
          log("❌ [sendOrderToAllCouriers] Stack trace: ${StackTrace.current}");
        }
      }

      log("✅ [sendOrderToAllCouriers] Barcha courier larga order yuborildi");
    } catch (e) {
      log("❌ [sendOrderToAllCouriers] Xatolik: $e");
    }
  }
}
