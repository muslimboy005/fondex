import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as maths;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/api_products_response.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/cashback_model.dart';
import '../models/cashback_redeem_model.dart';
import '../models/payment_model/cod_setting_model.dart';
import '../models/payment_model/flutter_wave_model.dart';
import '../models/payment_model/mercado_pago_model.dart';
import '../models/payment_model/mid_trans.dart';
import '../models/payment_model/orange_money.dart';
import '../models/payment_model/pay_fast_model.dart';
import '../models/payment_model/pay_stack_model.dart';
import '../models/payment_model/payme_model.dart';
import '../models/payment_model/paytm_model.dart';
import '../models/payment_model/wallet_setting_model.dart';
import '../models/payment_model/xendit.dart';
import '../models/wallet_transaction_model.dart';
import '../payment/MercadoPagoScreen.dart';
import '../payment/PayFastScreen.dart';
import '../payment/getPaytmTxtToken.dart';
import '../payment/midtrans_screen.dart';
import '../payment/orangePayScreen.dart';
import '../payment/paystack/pay_stack_screen.dart';
import '../payment/paystack/pay_stack_url_model.dart';
import '../payment/paystack/paystack_url_genrater.dart';
import '../payment/xenditModel.dart';
import '../payment/xenditScreen.dart';
import '../screen_ui/ecommarce/dash_board_e_commerce_screen.dart';
import '../screen_ui/multi_vendor_service/order_list_screen/order_details_screen.dart';
import '../service/database_helper.dart';
import '../screen_ui/multi_vendor_service/dash_board_screens/dash_board_screen.dart';
import '../screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import '../screen_ui/service_home_screen/service_list_screen.dart';
import '../service/cart_provider.dart';
import '../service/fire_store_utils.dart';
import '../service/send_notification.dart';
import '../service/vendors_products_repository.dart';
import '../themes/show_toast_dialog.dart';
import '../utils/utils.dart';

class CartController extends GetxController {
  RxBool isCashbackApply = false.obs;
  Rx<CashbackModel> bestCashback = CashbackModel().obs;

  final CartProvider cartProvider = CartProvider();
  Rx<TextEditingController> reMarkController = TextEditingController().obs;
  Rx<TextEditingController> couponCodeController = TextEditingController().obs;
  Rx<TextEditingController> tipsController = TextEditingController().obs;

  Rx<ShippingAddress> selectedAddress = ShippingAddress().obs;
  Rx<VendorModel> vendorModel = VendorModel().obs;
  Rx<DeliveryCharge> deliveryChargeModel = DeliveryCharge().obs;
  Rx<UserModel> userModel = UserModel().obs;
  RxList<CouponModel> couponList = <CouponModel>[].obs;
  RxList<CouponModel> allCouponList = <CouponModel>[].obs;
  RxString selectedFoodType = "Delivery".obs;

  RxString selectedPaymentMethod = ''.obs;
  RxBool isOrderPlaced = false.obs;

  RxString deliveryType = "instant".obs;
  Rx<DateTime> scheduleDateTime = DateTime.now().obs;
  RxDouble totalDistance = 0.0.obs;
  RxDouble deliveryCharges = 0.0.obs;
  RxDouble subTotal = 0.0.obs;
  RxDouble couponAmount = 0.0.obs;

  RxDouble specialDiscountAmount = 0.0.obs;
  RxDouble specialDiscount = 0.0.obs;
  RxString specialType = "".obs;

  RxDouble deliveryTips = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  Rx<CouponModel> selectedCouponModel = CouponModel().obs;

  // Product caching - takroriy so'rovlarni kamaytirish
  static final Map<String, ProductModel> _productCache = {};
  static final Map<String, DateTime> _productCacheTime = {};
  static const Duration _cacheExpiry = Duration(minutes: 5); // 5 daqiqa cache

  @override
  void onInit() {
    // TODO: implement onInit
    selectedAddress.value = Constant.selectedLocation;
    getCartData();
    getPaymentSettings();
    super.onInit();
  }

  Future<void> getCartData() async {
    cartProvider.cartStream.listen((event) async {
      cartItem.clear();
      cartItem.addAll(event);

      if (cartItem.isNotEmpty) {
        await FireStoreUtils.getVendorById(
          cartItem.first.vendorID.toString(),
        ).then((value) {
          if (value != null) {
            vendorModel.value = value;
          }
        });
      }
      calculatePrice();
    });
    final rawPref = Preferences.getString(
      Preferences.foodDeliveryType,
      defaultValue: 'Delivery',
    );
    final canon = Utils.canonicalFoodDeliveryType(rawPref);
    if (canon != rawPref) {
      await Preferences.setString(Preferences.foodDeliveryType, canon);
    }
    selectedFoodType.value = canon;

    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((
      value,
    ) {
      if (value != null) {
        userModel.value = value;
      }
    });

    await FireStoreUtils.getDeliveryCharge().then((value) {
      if (value != null) {
        deliveryChargeModel.value = value;
        print(
          "===> Delivery Charge Model: ${deliveryChargeModel.value.toJson()}",
        );
        calculatePrice();
      }
    });

    await FireStoreUtils.getAllVendorPublicCoupons(
      vendorModel.value.id.toString(),
    ).then((value) {
      couponList.value = value;
    });

    await FireStoreUtils.getAllVendorCoupons(
      vendorModel.value.id.toString(),
    ).then((value) {
      allCouponList.value = value;
    });
  }

  /// Klient manzili ↔ vendor o‘rtasidagi masofa (km).
  double _distanceKmVendorToCustomer() {
    try {
      final lat1 = selectedAddress.value.location?.latitude ?? 0;
      final lng1 = selectedAddress.value.location?.longitude ?? 0;
      final lat2 = vendorModel.value.latitude ?? 0;
      final lng2 = vendorModel.value.longitude ?? 0;
      return double.parse(
        Constant.getDistance(
          lat1: lat1.toString(),
          lng1: lng1.toString(),
          lat2: lat2.toString(),
          lng2: lng2.toString(),
        ),
      );
    } catch (e, st) {
      log('⚠️ [CartController] masofa hisobi: $e\n$st');
      return 0.0;
    }
  }

  /// Firestore’dagi tarifda kamida bitta narx (km / minimum / radius) bor-yo‘qligi.
  /// Hammasi 0 bo‘lsa — “sozlanmagan” deb vendor/admin boshqa manbasiga o‘tamiz.
  bool _deliveryTariffHasRates(DeliveryCharge d) {
    final perKm = (d.deliveryChargesPerKm ?? 0).toDouble();
    final minFlat = (d.minimumDeliveryCharges ?? 0).toDouble();
    final within = (d.minimumDeliveryChargesWithinKm ?? 0).toDouble();
    return perKm > 0 || minFlat > 0 || within > 0;
  }

  /// Yetkazib berish narxini hisoblash mantiqi:
  ///   • `minFlat` = minimum_delivery_charges — har doim past chegara (floor).
  ///   • `perKm` = delivery_charges_per_km — har km uchun qo'shimcha narx.
  ///   • `withinKm` = minimum_delivery_charges_within_km — bu radius ichida
  ///     faqat minimum olinadi; undan tashqari uchun `(distance - withinKm) * perKm`
  ///     qo'shiladi.
  ///   • Agar `withinKm == 0` bo'lsa, mantiqan "imtiyozli zona yo'q" deb tushuniladi
  ///     va `distance * perKm` ishlatiladi, lekin minimumdan past tushmaydi.
  /// Avvalgi xato: `withinKm == 0` va distance > 0 holatda `minFlat` umuman
  /// e'tiborga olinmagan; `withinKm > 0` holatda esa per-km masofaning hammasiga
  /// hisoblanib, minimum ham bekor bo'lib qolardi.
  double _computeTariffFee(DeliveryCharge t, double distanceKm) {
    final wKm = (t.minimumDeliveryChargesWithinKm ?? 0).toDouble();
    final perKm = (t.deliveryChargesPerKm ?? 0).toDouble();
    final minFlat = (t.minimumDeliveryCharges ?? 0).toDouble();
    final safeDistance = distanceKm.isNaN || distanceKm < 0 ? 0.0 : distanceKm;

    double fee;
    if (wKm > 0) {
      if (safeDistance <= wKm) {
        fee = minFlat;
      } else {
        fee = minFlat + (safeDistance - wKm) * perKm;
      }
    } else if (perKm > 0) {
      fee = safeDistance * perKm;
    } else {
      fee = minFlat;
    }

    if (fee < minFlat) fee = minFlat;
    if (fee.isNaN || !fee.isFinite || fee < 0) fee = 0;
    return fee;
  }

  void _applySingleDeliveryTariff(DeliveryCharge t) {
    deliveryCharges.value = _computeTariffFee(t, totalDistance.value);
  }

  /// Yetkazib berish narxi: admin + vendor tariflari.
  /// Admin `settings/DeliveryCharge` hammasi 0 bo‘lsa, `vendor_can_modify: false` bo‘lsa ham
  /// vendor hujjatidagi [VendorModel.deliveryCharge] ishlatiladi (oldingi xato: 0*masofa=0).
  void _applyDistanceBasedDeliveryCharges() {
    if (vendorModel.value.isSelfDelivery == true &&
        Constant.isSelfDeliveryFeature == true) {
      deliveryCharges.value = 0.0;
      return;
    }

    final g = deliveryChargeModel.value;
    final v = vendorModel.value.deliveryCharge;

    final adminLocksVendorRates = g.vendorCanModify != true;
    final adminHasRates = _deliveryTariffHasRates(g);
    final vendorHasRates = v != null && _deliveryTariffHasRates(v);

    if (adminLocksVendorRates && adminHasRates) {
      _applySingleDeliveryTariff(g);
      return;
    }
    if (vendorHasRates) {
      _applySingleDeliveryTariff(v);
      return;
    }
    if (adminHasRates) {
      _applySingleDeliveryTariff(g);
      return;
    }
    if (v != null) {
      _applySingleDeliveryTariff(v);
    } else {
      _applySingleDeliveryTariff(g);
    }
  }

  Future<void> calculatePrice() async {
    deliveryCharges.value = 0.0;
    subTotal.value = 0.0;
    couponAmount.value = 0.0;
    specialDiscountAmount.value = 0.0;
    taxAmount.value = 0.0;
    totalAmount.value = 0.0;

    if (cartItem.isNotEmpty) {
      if (Constant.sectionConstantModel!.serviceTypeFlag ==
          "ecommerce-service") {
        final flat =
            double.tryParse(
              Constant.sectionConstantModel!.delivery_charge ?? '0',
            ) ??
            0.0;
        if (flat > 0) {
          deliveryCharges.value = flat;
        } else if (selectedFoodType.value == 'Delivery') {
          totalDistance.value = _distanceKmVendorToCustomer();
          _applyDistanceBasedDeliveryCharges();
        } else {
          deliveryCharges.value = 0.0;
        }
      } else {
        if (selectedFoodType.value == 'Delivery') {
          totalDistance.value = _distanceKmVendorToCustomer();
          _applyDistanceBasedDeliveryCharges();
        } else {
          deliveryCharges.value = 0.0;
        }
      }
    }

    for (var element in cartItem) {
      if (double.parse(element.discountPrice.toString()) <= 0) {
        subTotal.value =
            subTotal.value +
            double.parse(element.price.toString()) *
                double.parse(element.quantity.toString()) +
            (double.parse(element.extrasPrice.toString()) *
                double.parse(element.quantity.toString()));
      } else {
        subTotal.value =
            subTotal.value +
            double.parse(element.discountPrice.toString()) *
                double.parse(element.quantity.toString()) +
            (double.parse(element.extrasPrice.toString()) *
                double.parse(element.quantity.toString()));
      }
    }

    if (selectedCouponModel.value.id != null) {
      couponAmount.value = Constant.calculateDiscount(
        amount: subTotal.value.toString(),
        offerModel: selectedCouponModel.value,
      );
    }

    if (vendorModel.value.specialDiscountEnable == true &&
        Constant.specialDiscountOffer == true) {
      final now = DateTime.now();
      var day = DateFormat('EEEE', 'en_US').format(now);
      var date = DateFormat('dd-MM-yyyy').format(now);
      for (var element in vendorModel.value.specialDiscount!) {
        if (day == element.day.toString()) {
          if (element.timeslot!.isNotEmpty) {
            for (var element in element.timeslot!) {
              if (element.discountType == "delivery") {
                var start = DateFormat(
                  "dd-MM-yyyy HH:mm",
                ).parse("$date ${element.from}");
                var end = DateFormat(
                  "dd-MM-yyyy HH:mm",
                ).parse("$date ${element.to}");
                if (isCurrentDateInRange(start, end)) {
                  specialDiscount.value = double.parse(
                    element.discount.toString(),
                  );
                  specialType.value = element.type.toString();
                  if (element.type == "percentage") {
                    specialDiscountAmount.value =
                        subTotal.value * specialDiscount.value / 100;
                  } else {
                    specialDiscountAmount.value = specialDiscount.value;
                  }
                }
              }
            }
          }
        }
      }
    } else {
      specialDiscount.value = double.parse("0");
      specialType.value = "amount";
    }

    for (var element in Constant.taxList) {
      taxAmount.value =
          taxAmount.value +
          Constant.calculateTax(
            amount:
                (subTotal.value -
                        couponAmount.value -
                        specialDiscountAmount.value)
                    .toString(),
            taxModel: element,
          );
    }

    // Keep "To Pay" consistent with the rounded values shown in the UI rows.
    final roundedSubTotal = Constant.roundUpToNearest500(subTotal.value);
    final roundedCoupon = Constant.roundUpToNearest500(couponAmount.value);
    final roundedSpecialDiscount = Constant.roundUpToNearest500(
      specialDiscountAmount.value,
    );
    final roundedDelivery = Constant.roundUpToNearest500(deliveryCharges.value);
    final roundedTips = Constant.roundUpToNearest500(deliveryTips.value);

    totalAmount.value =
        (roundedSubTotal - roundedCoupon - roundedSpecialDiscount) +
        roundedDelivery +
        roundedTips;
    getCashback();
  }

  Future<void> getCashback() async {
    if (Constant.isCashbackActive == true) {
      final paymentMethod = selectedPaymentMethod.value;
      final orderTotal = subTotal.value;
      final now = DateTime.now();

      List<CashbackModel> eligibleCashbacks = [];
      double maxCashbackValue = 0.0;

      final cashbackModelList = await FireStoreUtils.getAllCashbak();

      for (final cashback in cashbackModelList) {
        final startDate = cashback.startDate;
        final endDate = cashback.endDate;

        if (startDate == null || endDate == null) continue;

        final withinDateRange =
            startDate.toDate().isBefore(now) && endDate.toDate().isAfter(now);
        final meetsMinAmount =
            orderTotal >= (cashback.minimumPurchaseAmount ?? 0);
        final allPayment = cashback.allPayment ?? false;
        final paymentMatch =
            allPayment ||
            (cashback.paymentMethods ?? []).contains(paymentMethod);
        final allCustomer = cashback.allCustomer ?? false;
        final customerMatch =
            allCustomer ||
            (cashback.customerIds ?? []).contains(
              FireStoreUtils.getCurrentUid(),
            );

        final redeemData = await FireStoreUtils.getRedeemedCashbacks(
          cashback.id ?? '',
        );
        final underLimit = redeemData.length < (cashback.redeemLimit ?? 0);

        if (withinDateRange &&
            meetsMinAmount &&
            paymentMatch &&
            customerMatch &&
            underLimit) {
          eligibleCashbacks.add(cashback);
        }
      }
      bestCashback.value = CashbackModel();
      for (final cashback in eligibleCashbacks) {
        double cashbackValue = 0.0;

        if (cashback.cashbackType == 'Percent') {
          final percentage = cashback.cashbackAmount ?? 0.0;
          cashbackValue = (percentage / 100.0) * orderTotal;
        } else if (cashback.cashbackType == 'Fixed') {
          cashbackValue = cashback.cashbackAmount ?? 0.0;
        }

        final maxDiscount = cashback.maximumDiscount ?? cashbackValue;
        if (cashbackValue > maxDiscount) cashbackValue = maxDiscount;

        if (cashbackValue > maxCashbackValue) {
          maxCashbackValue = cashbackValue;
          bestCashback.value = cashback;
        }
      }

      if (bestCashback.value.id != null) {
        final cashbackValue = maxCashbackValue;
        isCashbackApply.value = true;
        bestCashback.value.cashbackValue = cashbackValue;
      } else {
        bestCashback.value = CashbackModel();
        isCashbackApply.value = false;
      }
    } else {
      bestCashback.value = CashbackModel();
      isCashbackApply.value = false;
    }
  }

  Future<void> addToCart({
    required CartProductModel cartProductModel,
    required bool isIncrement,
    required int quantity,
  }) async {
    if (isIncrement) {
      cartProvider.addToCart(Get.context!, cartProductModel, quantity);
    } else {
      cartProvider.removeFromCart(cartProductModel, quantity);
    }
    update();
  }

  List<CartProductModel> tempProduc = [];

  Future<void> placeOrder() async {
    if (selectedPaymentMethod.value == PaymentGateway.wallet.name) {
      if (double.parse(userModel.value.walletAmount.toString()) >=
          totalAmount.value) {
        setOrder();
      } else {
        ShowToastDialog.showToast(
          "You don't have sufficient wallet balance to place order".tr,
        );
      }
    } else {
      setOrder();
    }
  }

  Future<void> setOrder() async {
    ShowToastDialog.showLoader("Please wait...".tr);

    try {
      // 1. Vendor tekshiruvi - birinchi bo'lib (early return)
      if ((Constant.isSubscriptionModelApplied == true ||
              Constant.sectionConstantModel?.adminCommision?.isEnabled ==
                  true) &&
          vendorModel.value.subscriptionPlan != null) {
        final vender = await FireStoreUtils.getVendorById(
          vendorModel.value.id!,
        );
        if (vender?.subscriptionTotalOrders == '0' ||
            vender?.subscriptionTotalOrders == null) {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast(
            "This vendor has reached their maximum order capacity. Please select a different vendor or try again later."
                .tr,
          );
          return;
        }
      }

      // 2. Cart product'larni tayyorlash - optimizatsiya qilingan
      tempProduc.clear();
      tempProduc.addAll(
        cartItem.map((cartProduct) {
          CartProductModel tempCart = cartProduct;
          if (cartProduct.extrasPrice == '0') {
            tempCart.extras = [];
          }
          return tempCart;
        }),
      );

      // Order'ga yoziladigan products ro'yxati: id sifatida API mahsulot
      // raqamini (api_product_id) ishlatamiz. Cart'dagi composite id
      // ("productId~variantId") faqat lokal logika uchun kerak; backend va
      // serverdagi qaytalama integratsiyalar uchun raqamli API id afzal.
      //
      // Shuningdek, har bir narx string'i `Constant.safeNumString` orqali
      // tozalanadi: NaN/Infinity/null → "0.0". Aks holda vendor va driver
      // apps `double.parse("NaN")` ustida buziladi.
      final List<CartProductModel> orderProducts =
          cartItem.map((cartProduct) {
        final clone = CartProductModel.fromJson(cartProduct.toJson());
        if (clone.extrasPrice == '0') {
          clone.extras = [];
        }
        if (clone.apiProductId != null) {
          clone.id = clone.apiProductId.toString();
        }
        clone.price = Constant.safeNumString(clone.price);
        clone.discountPrice = Constant.safeNumString(clone.discountPrice);
        clone.extrasPrice = Constant.safeNumString(clone.extrasPrice);
        return clone;
      }).toList();

      Map<String, dynamic> specialDiscountMap = {
        'special_discount': specialDiscountAmount.value,
        'special_discount_label': specialDiscount.value,
        'specialType': specialType.value,
      };

      // 3. Order model yaratish - optimizatsiya qilingan (bitta joyda)
      final orderId = Constant.getUuid();
      final now = Timestamp.now();
      final adminCommissionEnabled =
          Constant.sectionConstantModel?.adminCommision?.isEnabled ?? false;
      final vendorAdminCommission = vendorModel.value.adminCommission;

      // Order ichidagi vendor nusxasi: agar vendor hujjatida
      // adminCommission.commission = "NaN" bo'lsa, uni "0" ga normallashtirib
      // beramiz — aks holda vendor/driver apps bu qiymatni o'qishda
      // `double.parse("NaN")` orqali NaN olib, hisob-kitob (komissiya, foyda
      // va h.k.) buziladi.
      final orderVendor = vendorModel.value;
      if (orderVendor.adminCommission != null) {
        orderVendor.adminCommission!.amount =
            Constant.safeNumString(orderVendor.adminCommission!.amount,
                fallback: '0');
      }

      // author.fcmToken null bo'lsa, driver/vendor `.toString()` "null" string
      // ga aylantirib FCM ga yuboradi va bildirishnoma yetib bormaydi.
      final orderAuthor = userModel.value;
      orderAuthor.fcmToken ??= '';

      final String safeAdminCommission = adminCommissionEnabled
          ? '0'
          : Constant.safeNumString(
              vendorAdminCommission?.amount ??
                  Constant.sectionConstantModel?.adminCommision?.amount,
              fallback: '0');

      final String safeDeliveryCharge =
          Constant.safeNumString(deliveryCharges.value);
      final String safeTipAmount = Constant.safeNumString(deliveryTips.value);
      final String safeTotalAmount = Constant.safeNumString(totalAmount.value);

      OrderModel orderModel =
          OrderModel()
            ..id = orderId
            ..address = selectedAddress.value
            ..authorID = FireStoreUtils.getCurrentUid()
            ..author = orderAuthor
            ..vendorID = vendorModel.value.id
            ..vendor = orderVendor
            ..adminCommission = safeAdminCommission
            ..adminCommissionType =
                adminCommissionEnabled
                    ? 'fixed'
                    : (vendorAdminCommission?.commissionType ??
                        Constant
                            .sectionConstantModel
                            ?.adminCommision
                            ?.commissionType)
            ..status = Constant.orderPlaced
            ..discount = couponAmount.value.isNaN ? 0 : couponAmount.value
            ..couponId = selectedCouponModel.value.id
            ..taxSetting = Constant.taxList
            ..paymentMethod = selectedPaymentMethod.value
            ..products = orderProducts
            ..sectionId = Constant.sectionConstantModel?.id
            ..specialDiscount = specialDiscountMap
            ..couponCode = selectedCouponModel.value.code
            ..deliveryCharge = safeDeliveryCharge
            ..tipAmount = safeTipAmount
            ..totalAmount = safeTotalAmount
            ..notes = reMarkController.value.text
            ..takeAway = selectedFoodType.value != "Delivery"
            ..createdAt = now
            ..triggerDelivery = now
            ..scheduleTime =
                deliveryType.value == "schedule"
                    ? Timestamp.fromDate(scheduleDateTime.value)
                    : null
            ..cashback =
                bestCashback.value.id == null ? null : bestCashback.value;

      // 4. Parallel operatsiyalar - Wallet transaction va Product updates
      final futures = <Future>[];

      // Wallet transaction (agar kerak bo'lsa)
      if (selectedPaymentMethod.value == PaymentGateway.wallet.name) {
        futures.add(_processWalletTransaction(orderModel));
      }

      // Product quantity update'larni parallel qilish
      futures.add(_updateProductQuantitiesParallel());

      // Cashback (agar kerak bo'lsa)
      if (Constant.isCashbackActive == true && bestCashback.value.id != null) {
        futures.add(_processCashback(orderModel));
      }

      // 5. Barcha parallel operatsiyalarni kutish
      await Future.wait(futures);

      // 6. Order'ni Firestore'ga yozish
      await FireStoreUtils.setOrder(orderModel);

      // 7. Loading tugadi - UI tez ko'rinadi
      ShowToastDialog.closeLoader();
      DatabaseHelper.instance.deleteAllCartProducts();
      Get.off(
        const OrderDetailsScreen(),
        arguments: {"orderModel": orderModel},
      );

      // 8. Background operatsiyalar - Notification va Email
      _sendNotificationAndEmailInBackground(orderModel);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("${'Error placing order'.tr}: ${e.toString()}");
    }
  }

  // Wallet transaction'ni alohida metod
  Future<void> _processWalletTransaction(OrderModel orderModel) async {
    WalletTransactionModel transactionModel = WalletTransactionModel(
      id: Constant.getUuid(),
      amount: double.parse(totalAmount.value.toString()),
      date: Timestamp.now(),
      paymentMethod: PaymentGateway.wallet.name,
      transactionUser: "customer",
      userId: FireStoreUtils.getCurrentUid(),
      isTopup: false,
      orderId: orderModel.id,
      note: "Order Amount debited",
      paymentStatus: "success".tr,
    );

    await FireStoreUtils.setWalletTransaction(transactionModel).then((
      value,
    ) async {
      if (value == true) {
        await FireStoreUtils.updateUserWallet(
          amount: "-${totalAmount.value.toString()}",
          userId: FireStoreUtils.getCurrentUid(),
        );
      }
    });
  }

  // Product quantity update'larni parallel qilish - optimizatsiya qilingan
  Future<void> _updateProductQuantitiesParallel() async {
    try {
      // 1. Barcha product'larni parallel olish (cache bilan)
      final productFutures = <Future<ProductModel?>>[];
      final productIds =
          tempProduc.map((p) => p.id!.split('~').first).toSet().toList();

      for (final productId in productIds) {
        productFutures.add(_getProductWithCache(productId));
      }

      final products = await Future.wait(productFutures);
      final productMap = <String, ProductModel>{};

      for (int i = 0; i < productIds.length; i++) {
        if (products[i] != null) {
          productMap[productIds[i]] = products[i]!;
        }
      }

      // 2. Product quantity'larni yangilash (memory'da)
      for (int i = 0; i < tempProduc.length; i++) {
        final productId = tempProduc[i].id!.split('~').first;
        final productModel = productMap[productId];
        if (productModel == null) continue;

        if (tempProduc[i].variantInfo != null) {
          if (productModel.itemAttribute != null) {
            for (
              int j = 0;
              j < productModel.itemAttribute!.variants!.length;
              j++
            ) {
              if (productModel.itemAttribute!.variants![j].variantId ==
                  tempProduc[i].id!.split('~').last) {
                if (productModel.itemAttribute!.variants![j].variantQuantity !=
                    "-1") {
                  productModel.itemAttribute!.variants![j].variantQuantity =
                      (int.parse(
                                productModel
                                    .itemAttribute!
                                    .variants![j]
                                    .variantQuantity
                                    .toString(),
                              ) -
                              tempProduc[i].quantity!)
                          .toString();
                }
              }
            }
          } else {
            if (productModel.quantity != -1) {
              productModel.quantity =
                  (productModel.quantity! - tempProduc[i].quantity!);
            }
          }
        } else {
          if (productModel.quantity != -1) {
            productModel.quantity =
                (productModel.quantity! - tempProduc[i].quantity!);
          }
        }
      }

      // 3. Firestore batch write - barcha product'larni bir vaqtda yangilash
      await _batchUpdateProducts(productMap.values.toList());
    } catch (e) {
      print("Error updating product quantities: $e");
      // Fallback - eski usul
      final productFutures = <Future>[];
      for (int i = 0; i < tempProduc.length; i++) {
        productFutures.add(_updateSingleProductQuantity(i));
      }
      await Future.wait(productFutures);
    }
  }

  // Product'ni cache bilan olish
  Future<ProductModel?> _getProductWithCache(String productId) async {
    // Cache'dan tekshirish
    if (_productCache.containsKey(productId)) {
      final cacheTime = _productCacheTime[productId];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < _cacheExpiry) {
        return _productCache[productId];
      }
    }

    // Firestore'dan olish
    final product = await FireStoreUtils.getProductById(productId);
    if (product != null) {
      _productCache[productId] = product;
      _productCacheTime[productId] = DateTime.now();
    }
    return product;
  }

  // Firestore batch write - barcha product'larni bir vaqtda yangilash
  Future<void> _batchUpdateProducts(List<ProductModel> products) async {
    if (products.isEmpty) return;

    try {
      final firestore = FirebaseFirestore.instance;
      const maxBatchSize = 500; // Firestore batch limit

      // Batch'larni guruhlash
      for (int i = 0; i < products.length; i += maxBatchSize) {
        final batch = firestore.batch();
        final endIndex =
            (i + maxBatchSize < products.length)
                ? i + maxBatchSize
                : products.length;

        for (int j = i; j < endIndex; j++) {
          final product = products[j];
          final productRef = firestore
              .collection(CollectionName.vendorProducts)
              .doc(product.id);
          batch.set(productRef, product.toJson());
        }

        // Batch'ni yuborish
        await batch.commit();
      }
    } catch (e) {
      print("Error in batch update: $e");
      // Fallback - individual updates
      for (final product in products) {
        await FireStoreUtils.setProduct(product);
      }
    }
  }

  // Bitta product quantity'ni yangilash (fallback uchun)
  Future<void> _updateSingleProductQuantity(int index) async {
    try {
      final productId = tempProduc[index].id!.split('~').first;
      final productModel = await _getProductWithCache(productId);
      if (productModel == null) return;

      if (tempProduc[index].variantInfo != null) {
        if (productModel.itemAttribute != null) {
          for (
            int j = 0;
            j < productModel.itemAttribute!.variants!.length;
            j++
          ) {
            if (productModel.itemAttribute!.variants![j].variantId ==
                tempProduc[index].id!.split('~').last) {
              if (productModel.itemAttribute!.variants![j].variantQuantity !=
                  "-1") {
                productModel.itemAttribute!.variants![j].variantQuantity =
                    (int.parse(
                              productModel
                                  .itemAttribute!
                                  .variants![j]
                                  .variantQuantity
                                  .toString(),
                            ) -
                            tempProduc[index].quantity!)
                        .toString();
              }
            }
          }
        } else {
          if (productModel.quantity != -1) {
            productModel.quantity =
                (productModel.quantity! - tempProduc[index].quantity!);
          }
        }
      } else {
        if (productModel.quantity != -1) {
          productModel.quantity =
              (productModel.quantity! - tempProduc[index].quantity!);
        }
      }

      await FireStoreUtils.setProduct(productModel);
    } catch (e) {
      print("Error updating product quantity: $e");
    }
  }

  // Cashback'ni alohida metod
  Future<void> _processCashback(OrderModel orderModel) async {
    CashbackRedeemModel cashbackRedeemModel = CashbackRedeemModel(
      id: Constant.getUuid(),
      cashbackId: bestCashback.value.id,
      userId: FireStoreUtils.getCurrentUid(),
      orderId: orderModel.id,
      createdAt: Timestamp.now(),
    );
    await FireStoreUtils.setCashbackRedeemModel(cashbackRedeemModel);
  }

  // Notification va Email'ni background'da yuborish
  Future<void> _sendNotificationAndEmailInBackground(
    OrderModel orderModel,
  ) async {
    try {
      // Notification
      await FireStoreUtils.getUserProfile(
        orderModel.vendor!.author.toString(),
      ).then((value) async {
        if (value != null) {
          final type = orderModel.scheduleTime != null ? Constant.scheduleOrder : Constant.newOrderPlaced;
          final data = <String, dynamic>{
            'orderId': orderModel.id ?? '',
            'amount': '${orderModel.products?.length ?? 0} ta mahsulot',
            'address': orderModel.address?.getFullAddress() ?? '',
          };

          // CallKit-style incoming-order push (high priority + VoIP for iOS).
          await SendNotification.sendCallKitNotification(
            type: type,
            token: value.fcmToken ?? '',
            voipToken: value.voipToken,
            iosBundleId: 'felix.fondex.store',
            data: data,
          );

          // Keep the legacy notification call as a fallback (shows in the
          // tray if CallKit fails or the vendor dismisses without acting).
          await SendNotification.sendFcmMessage(type, value.fcmToken ?? '', data);
        }
      });

      // Email
      await Constant.sendOrderEmail(orderModel: orderModel);
    } catch (e) {
      print("Error sending notification/email: $e");
    }
  }

  Rx<WalletSettingModel> walletSettingModel = WalletSettingModel().obs;
  Rx<CodSettingModel> cashOnDeliverySettingModel = CodSettingModel().obs;
  Rx<PayFastModel> payFastModel = PayFastModel().obs;
  Rx<MercadoPagoModel> mercadoPagoModel = MercadoPagoModel().obs;
  Rx<FlutterWaveModel> flutterWaveModel = FlutterWaveModel().obs;
  Rx<PayStackModel> payStackModel = PayStackModel().obs;
  Rx<PaytmModel> paytmModel = PaytmModel().obs;
  Rx<PaymeModel> paymeModel = PaymeModel().obs;
  Rx<MidTrans> midTransModel = MidTrans().obs;
  Rx<OrangeMoney> orangeMoneyModel = OrangeMoney().obs;
  Rx<Xendit> xenditModel = Xendit().obs;

  Future<void> getPaymentSettings() async {
    print("🔵 [CartController.getPaymentSettings] Boshlandi");
    await FireStoreUtils.getPaymentSettingsData().then((value) {
      print(
        "🔵 [CartController.getPaymentSettings] FireStoreUtils.getPaymentSettingsData tugadi",
      );

      // PayStack
      try {
        payStackModel.value = PayStackModel.fromJson(
          jsonDecode(Preferences.getString(Preferences.payStack)),
        );
        print(
          "🔵 [CartController.getPaymentSettings] PayStack: isEnable=${payStackModel.value.isEnable}",
        );
      } catch (e) {
        print(
          "❌ [CartController.getPaymentSettings] PayStack o'qish xatosi: $e",
        );
      }

      // MercadoPago
      try {
        mercadoPagoModel.value = MercadoPagoModel.fromJson(
          jsonDecode(Preferences.getString(Preferences.mercadoPago)),
        );
        print(
          "🔵 [CartController.getPaymentSettings] MercadoPago: isEnabled=${mercadoPagoModel.value.isEnabled}",
        );
      } catch (e) {
        print(
          "❌ [CartController.getPaymentSettings] MercadoPago o'qish xatosi: $e",
        );
      }

      // FlutterWave
      try {
        flutterWaveModel.value = FlutterWaveModel.fromJson(
          jsonDecode(Preferences.getString(Preferences.flutterWave)),
        );
        print(
          "🔵 [CartController.getPaymentSettings] FlutterWave: isEnable=${flutterWaveModel.value.isEnable}",
        );
      } catch (e) {
        print(
          "❌ [CartController.getPaymentSettings] FlutterWave o'qish xatosi: $e",
        );
      }

      // Paytm
      try {
        paytmModel.value = PaytmModel.fromJson(
          jsonDecode(Preferences.getString(Preferences.paytmSettings)),
        );
        print(
          "🔵 [CartController.getPaymentSettings] Paytm: isEnabled=${paytmModel.value.isEnabled}",
        );
      } catch (e) {
        print("❌ [CartController.getPaymentSettings] Paytm o'qish xatosi: $e");
      }

      // Payme
      try {
        paymeModel.value = PaymeModel.fromJson(
          jsonDecode(Preferences.getString(Preferences.paymeSettings)),
        );
        print(
          "🔵 [CartController.getPaymentSettings] Payme: isEnabled=${paymeModel.value.isEnabled ?? paymeModel.value.enable}",
        );
      } catch (e) {
        print("❌ [CartController.getPaymentSettings] Payme o'qish xatosi: $e");
      }

      // PayFast
      try {
        payFastModel.value = PayFastModel.fromJson(
          jsonDecode(Preferences.getString(Preferences.payFastSettings)),
        );
        print(
          "🔵 [CartController.getPaymentSettings] PayFast: isEnable=${payFastModel.value.isEnable}",
        );
      } catch (e) {
        print(
          "❌ [CartController.getPaymentSettings] PayFast o'qish xatosi: $e",
        );
      }

      // MidTrans
      try {
        midTransModel.value = MidTrans.fromJson(
          jsonDecode(Preferences.getString(Preferences.midTransSettings)),
        );
        print(
          "🔵 [CartController.getPaymentSettings] MidTrans: enable=${midTransModel.value.enable}",
        );
      } catch (e) {
        print(
          "❌ [CartController.getPaymentSettings] MidTrans o'qish xatosi: $e",
        );
      }

      // OrangeMoney
      try {
        orangeMoneyModel.value = OrangeMoney.fromJson(
          jsonDecode(Preferences.getString(Preferences.orangeMoneySettings)),
        );
        print(
          "🔵 [CartController.getPaymentSettings] OrangeMoney: enable=${orangeMoneyModel.value.enable}",
        );
      } catch (e) {
        print(
          "❌ [CartController.getPaymentSettings] OrangeMoney o'qish xatosi: $e",
        );
      }

      // Xendit
      try {
        xenditModel.value = Xendit.fromJson(
          jsonDecode(Preferences.getString(Preferences.xenditSettings)),
        );
        print(
          "🔵 [CartController.getPaymentSettings] Xendit: enable=${xenditModel.value.enable}",
        );
      } catch (e) {
        print("❌ [CartController.getPaymentSettings] Xendit o'qish xatosi: $e");
      }

      // Wallet
      try {
        walletSettingModel.value = WalletSettingModel.fromJson(
          jsonDecode(Preferences.getString(Preferences.walletSettings)),
        );
        print(
          "🔵 [CartController.getPaymentSettings] Wallet: isEnabled=${walletSettingModel.value.isEnabled}",
        );
      } catch (e) {
        print("❌ [CartController.getPaymentSettings] Wallet o'qish xatosi: $e");
      }

      // COD
      try {
        cashOnDeliverySettingModel.value = CodSettingModel.fromJson(
          jsonDecode(Preferences.getString(Preferences.codSettings)),
        );
        print(
          "🔵 [CartController.getPaymentSettings] COD: isEnabled=${cashOnDeliverySettingModel.value.isEnabled}",
        );
      } catch (e) {
        print("❌ [CartController.getPaymentSettings] COD o'qish xatosi: $e");
      }

      print(
        "🔵 [CartController.getPaymentSettings] Payment method tanlash boshlandi",
      );
      if (cashOnDeliverySettingModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.cod.name;
        print("🔵 [CartController.getPaymentSettings] Tanlangan: COD (naqt)");
      } else if (walletSettingModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.wallet.name;
        print("🔵 [CartController.getPaymentSettings] Tanlangan: Wallet");
      } else if (payStackModel.value.isEnable == true) {
        selectedPaymentMethod.value = PaymentGateway.payStack.name;
        print("🔵 [CartController.getPaymentSettings] Tanlangan: PayStack");
      } else if (mercadoPagoModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.mercadoPago.name;
        print("🔵 [CartController.getPaymentSettings] Tanlangan: MercadoPago");
      } else if (flutterWaveModel.value.isEnable == true) {
        selectedPaymentMethod.value = PaymentGateway.flutterWave.name;
        print("🔵 [CartController.getPaymentSettings] Tanlangan: FlutterWave");
      } else if (payFastModel.value.isEnable == true) {
        selectedPaymentMethod.value = PaymentGateway.payFast.name;
        print("🔵 [CartController.getPaymentSettings] Tanlangan: PayFast");
      } else if (midTransModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.midTrans.name;
        print("🔵 [CartController.getPaymentSettings] Tanlangan: MidTrans");
      } else if (orangeMoneyModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.orangeMoney.name;
        print("🔵 [CartController.getPaymentSettings] Tanlangan: OrangeMoney");
      } else if (xenditModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.xendit.name;
        print("🔵 [CartController.getPaymentSettings] Tanlangan: Xendit");
      } else if (paymeModel.value.isEnabled == true ||
          paymeModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.payme.name;
        print("🔵 [CartController.getPaymentSettings] Tanlangan: Payme");
      } else {
        print(
          "⚠️ [CartController.getPaymentSettings] Hech qanday payment method active emas!",
        );
      }
      print(
        "🔵 [CartController.getPaymentSettings] Tanlangan payment method: ${selectedPaymentMethod.value}",
      );
      setRef();
    });
  }

  //mercadoo
  Future<Null> mercadoPagoMakePayment({
    required BuildContext context,
    required String amount,
  }) async {
    final headers = {
      'Authorization': 'Bearer ${mercadoPagoModel.value.accessToken}',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      "items": [
        {
          "title": "Test",
          "description": "Test Payment",
          "quantity": 1,
          "currency_id": "BRL", // or your preferred currency
          "unit_price": double.parse(amount),
        },
      ],
      "payer": {"email": userModel.value.email},
      "back_urls": {
        "failure": "${Constant.globalUrl}payment/failure",
        "pending": "${Constant.globalUrl}payment/pending",
        "success": "${Constant.globalUrl}payment/success",
      },
      "auto_return": "approved",
      // Automatically return after payment is approved
    });

    final response = await http.post(
      Uri.parse("https://api.mercadopago.com/checkout/preferences"),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      Get.to(MercadoPagoScreen(initialURl: data['init_point']))!.then((value) {
        if (value) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          placeOrder();
        } else {
          ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
        }
      });
    } else {
      print('Error creating preference: ${response.body}');
      return null;
    }
  }

  ///PayStack Payment Method
  Future<void> payStackPayment(String totalAmount) async {
    await PayStackURLGen.payStackURLGen(
      amount: (double.parse(totalAmount) * 100).toString(),
      currency: "ZAR",
      secretKey: payStackModel.value.secretKey.toString(),
      userModel: userModel.value,
    ).then((value) async {
      if (value != null) {
        PayStackUrlModel payStackModel0 = value;
        Get.to(
          PayStackScreen(
            secretKey: payStackModel.value.secretKey.toString(),
            callBackUrl: payStackModel.value.callbackURL.toString(),
            initialURl: payStackModel0.data.authorizationUrl,
            amount: totalAmount,
            reference: payStackModel0.data.reference,
          ),
        )!.then((value) {
          if (value) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            placeOrder();
          } else {
            ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
          }
        });
      } else {
        ShowToastDialog.showToast(
          "Something went wrong, please contact admin.".tr,
        );
      }
    });
  }

  //flutter wave Payment Method
  Future<Null> flutterWaveInitiatePayment({
    required BuildContext context,
    required String amount,
  }) async {
    final url = Uri.parse('https://api.flutterwave.com/v3/payments');
    final headers = {
      'Authorization': 'Bearer ${flutterWaveModel.value.secretKey}',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      "tx_ref": _ref,
      "amount": amount,
      "currency": "NGN",
      "redirect_url": "${Constant.globalUrl}payment/success",
      "payment_options": "ussd, card, barter, payattitude",
      "customer": {
        "email": userModel.value.email.toString(),
        "phonenumber": userModel.value.phoneNumber, // Add a real phone number
        "name": userModel.value.fullName(), // Add a real customer name
      },
      "customizations": {
        "title": "Payment for Services",
        "description": "Payment for XYZ services",
      },
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      Get.to(MercadoPagoScreen(initialURl: data['data']['link']))!.then((
        value,
      ) {
        if (value) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          placeOrder();
        } else {
          ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
        }
      });
    } else {
      print('Payment initialization failed: ${response.body}');
      return null;
    }
  }

  String? _ref;

  void setRef() {
    maths.Random numRef = maths.Random();
    int year = DateTime.now().year;
    int refNumber = numRef.nextInt(20000);
    if (Platform.isAndroid) {
      _ref = "AndroidRef$year$refNumber";
    } else if (Platform.isIOS) {
      _ref = "IOSRef$year$refNumber";
    }
  }

  // payFast
  void payFastPayment({required BuildContext context, required String amount}) {
    PayStackURLGen.getPayHTML(
      payFastSettingData: payFastModel.value,
      amount: amount.toString(),
      userModel: userModel.value,
    ).then((String? value) async {
      bool isDone = await Get.to(
        PayFastScreen(htmlData: value!, payFastSettingData: payFastModel.value),
      );
      if (isDone) {
        Get.back();
        ShowToastDialog.showToast("Payment successfully".tr);
        placeOrder();
      } else {
        Get.back();
        ShowToastDialog.showToast("Payment Failed".tr);
      }
    });
  }

  /// Payme backend storage API `id` raqamini kutadi (Firestore UUID emas).
  static int? _paymeStorageProductIdSync(CartProductModel e) {
    if (e.apiProductId != null) return e.apiProductId;
    final raw = e.id;
    if (raw == null || raw.isEmpty) return null;
    final base = raw.contains('~') ? raw.split('~').first : raw;
    return int.tryParse(base);
  }

  /// POST /wallet-payme-link uchun variant (`attribute_id`) — `variantInfo` yoki `id~variant`.
  static String? _paymeAttributeIdForLine(CartProductModel e) {
    final fromVariant = e.variantInfo?.variantId?.trim();
    if (fromVariant != null && fromVariant.isNotEmpty) {
      return fromVariant;
    }
    final raw = e.id;
    if (raw != null && raw.contains('~')) {
      final rest = raw.split('~').skip(1).join('~').trim();
      if (rest.isNotEmpty) return rest;
    }
    return null;
  }

  static Map<String, dynamic> _paymeProductLineMap(
    CartProductModel e,
    int productIdNum,
  ) {
    final line = <String, dynamic>{
      'product_id': productIdNum,
      'quantity': e.quantity ?? 1,
    };
    final aid = _paymeAttributeIdForLine(e);
    if (aid != null && aid.isNotEmpty) {
      line['attribute_id'] = aid;
    }
    return line;
  }

  /// Savatda faqat Firestore UUID bo'lsa, storage API dan raqamli `id` ni topadi.
  Future<List<Map<String, dynamic>>?> _buildPaymeProductsPayload(
    String vendorId,
  ) async {
    final out = <Map<String, dynamic>>[];
    final needsLookup = <CartProductModel>[];

    for (final e in cartItem) {
      if (e.id == null || e.id!.isEmpty) {
        log('⚠️ [PaymePayment] skip line: empty cart product id');
        continue;
      }
      final sync = _paymeStorageProductIdSync(e);
      if (sync != null) {
        out.add(_paymeProductLineMap(e, sync));
      } else {
        needsLookup.add(e);
      }
    }

    if (needsLookup.isEmpty) {
      return out.isEmpty ? null : out;
    }

    final sectionId = Constant.sectionConstantModel?.id?.toString();
    if (sectionId == null || sectionId.isEmpty) {
      log(
        '❌ [PaymePayment] section id yo\'q — API dan product id olinmaydi',
      );
      return null;
    }

    try {
      final repo = VendorsProductsRepository();
      final byFirestore = <String, int>{};

      ApiProductsResponse pageResp = await repo.getProducts(
        vendorId: vendorId,
        sectionId: sectionId,
      );

      for (;;) {
        if (!pageResp.status) break;
        for (final item in pageResp.data.results) {
          final fid = item.firestoreId;
          if (fid != null && fid.isNotEmpty) {
            byFirestore[fid] = item.id;
          }
        }
        final next = pageResp.data.next;
        if (next == null || next.isEmpty) break;
        final nextPage = await repo.getProductsNextPage(next);
        if (nextPage == null || !nextPage.status) break;
        pageResp = nextPage;
      }

      for (final e in needsLookup) {
        final raw = e.id!;
        final base = raw.contains('~') ? raw.split('~').first : raw;
        final pid = byFirestore[base];
        if (pid == null) {
          log(
            '❌ [PaymePayment] firestore_id=$base uchun storage API da id topilmadi (vendor=$vendorId)',
          );
          return null;
        }
        out.add(_paymeProductLineMap(e, pid));
      }

      return out.isEmpty ? null : out;
    } catch (e, st) {
      log('❌ [PaymePayment] storage API lookup: $e\n$st');
      return null;
    }
  }

  void _navigateToMyOrdersAfterPayme() {
    Get.offAll(() => const ServiceListScreen());
    if (Constant.sectionConstantModel?.serviceTypeFlag == "ecommerce-service") {
      Get.to(
        () => const DashBoardEcommerceScreen(),
        arguments: {'tab': 'orders'},
      );
    } else {
      Get.to(() => const DashBoardScreen(), arguments: {'tab': 'orders'});
    }
  }

  //PaymePayment (multi-vendor cart: type product + vendor_id + products; then My Orders)
  Future<void> paymeMakePayment({
    required BuildContext context,
    required String amount,
  }) async {
    log('🔵 [PaymePayment] paymeMakePayment boshlandi, amount: $amount');
    try {
      if (cartItem.isEmpty) {
        log('❌ [PaymePayment] cartItem bosh');
        ShowToastDialog.showToast(
          "Something went wrong, please contact admin.".tr,
        );
        return;
      }
      final String? vendorId =
          vendorModel.value.id?.isNotEmpty == true
              ? vendorModel.value.id
              : cartItem.first.vendorID;
      if (vendorId == null || vendorId.isEmpty) {
        log('❌ [PaymePayment] vendorId yo\'q');
        ShowToastDialog.showToast(
          "Something went wrong, please contact admin.".tr,
        );
        return;
      }

      ShowToastDialog.showLoader("Processing...".tr);
      try {
        final products = await _buildPaymeProductsPayload(vendorId);
        if (products == null || products.isEmpty) {
          log(
            '❌ [PaymePayment] products ro\'yxati bo\'sh yoki id lar aniqlanmadi',
          );
          ShowToastDialog.showToast(
            "Something went wrong, please contact admin.".tr,
          );
          return;
        }

        final url = Uri.parse(
          'https://web.fondex.uz/wallet-payme-link/',
        );
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        };
        // Backend wallet-payme-link: delivery_charge alohida yuboriladi (totalAmount bilan bir xil yaxlitlash).
        final int deliveryChargePayme =
            Constant.roundUpToNearest500(deliveryCharges.value).toInt();
        final double customerLatitude =
            selectedAddress.value.location?.latitude ?? 0;
        final double customerLongitude =
            selectedAddress.value.location?.longitude ?? 0;
        final Map<String, dynamic> paymePayload = <String, dynamic>{
          'phone': '+998${userModel.value.phoneNumber}',
          'latitude': customerLatitude,
          'longitude': customerLongitude,
          'amount': double.parse(amount).ceil().toInt(),
          'delivery_charge': deliveryChargePayme,
          'type': 'product',
          'vendor_id': vendorId,
          'products': products,
        };
        final body = jsonEncode(paymePayload);

        log('🔵 [PaymePayment] Request URL: $url');
        log(
          '🔵 [PaymePayment] delivery_charge (payload): $deliveryChargePayme',
        );
        log('🔵 [PaymePayment] Request Body: $body');

        final response = await http.post(url, headers: headers, body: body);

        log('🔵 [PaymePayment] Response Status: ${response.statusCode}');
        log(
          '🔵 [PaymePayment] Response Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}',
        );

        // Check if response is HTML (redirect to login)
        if (response.body.trim().startsWith('<!DOCTYPE html>') ||
            response.body.trim().startsWith('<html>') ||
            response.body.contains('Redirecting to')) {
          ShowToastDialog.showToast(
            "Server authentication error. Please try again.".tr,
          );
          log(
            '❌ [PaymePayment] HTML response received (likely redirect to login)',
          );
          return;
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          try {
            final data = jsonDecode(response.body);
            if (data['status'] == true && data['link'] != null) {
              final uri = Uri.parse(data['link'].toString());
              final launched = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (launched) {
                ShowToastDialog.showToast("Payme opens in your browser".tr);
                Future.microtask(_navigateToMyOrdersAfterPayme);
              } else {
                ShowToastDialog.showToast("Could not open Payme link".tr);
              }
            } else {
              final msg = data['message']?.toString();
              ShowToastDialog.showToast(
                (msg != null && msg.isNotEmpty)
                    ? msg
                    : "Failed to get payment link".tr,
              );
              log('❌ [PaymePayment] Invalid response data: $data');
            }
          } catch (e) {
            ShowToastDialog.showToast("Failed to parse server response".tr);
            log('❌ [PaymePayment] JSON parse error: $e');
            log('❌ [PaymePayment] Response body: ${response.body}');
          }
        } else {
          try {
            final data = jsonDecode(response.body);
            final msg = data['message']?.toString();
            if (msg != null && msg.isNotEmpty) {
              ShowToastDialog.showToast(msg);
            } else {
              ShowToastDialog.showToast(
                "Something went wrong, please contact admin.".tr,
              );
            }
          } catch (_) {
            ShowToastDialog.showToast(
              "Something went wrong, please contact admin.".tr,
            );
          }
          log('❌ [PaymePayment] Error status: ${response.statusCode}');
          log('❌ [PaymePayment] Error body: ${response.body}');
        }
      } finally {
        ShowToastDialog.closeLoader();
      }
    } catch (e, st) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("${'Payment error'.tr}: ${e.toString()}");
      log('❌ [PaymePayment] Exception: $e\n$st');
    }
  }

  ///Paytm payment function
  Future<void> getPaytmCheckSum(context, {required double amount}) async {
    final String orderId = DateTime.now().millisecondsSinceEpoch.toString();
    String getChecksum = "${Constant.globalUrl}payments/getpaytmchecksum";

    final response = await http.post(
      Uri.parse(getChecksum),
      headers: {},
      body: {
        "mid": paytmModel.value.paytmMID.toString(),
        "order_id": orderId,
        "key_secret": paytmModel.value.pAYTMMERCHANTKEY.toString(),
      },
    );

    final data = jsonDecode(response.body);
    await verifyCheckSum(
      checkSum: data["code"],
      amount: amount,
      orderId: orderId,
    ).then((value) {
      initiatePayment(amount: amount, orderId: orderId).then((value) {
        String callback = "";
        if (paytmModel.value.isSandboxEnabled == true) {
          callback =
              "${callback}https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
        } else {
          callback =
              "${callback}https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
        }

        GetPaymentTxtTokenModel result = value;
        startTransaction(
          context,
          txnTokenBy: result.body.txnToken ?? '',
          orderId: orderId,
          amount: amount,
          callBackURL: callback,
          isStaging: paytmModel.value.isSandboxEnabled,
        );
      });
    });
  }

  Future<void> startTransaction(
    context, {
    required String txnTokenBy,
    required orderId,
    required double amount,
    required callBackURL,
    required isStaging,
  }) async {
    // try {
    //   var response = AllInOneSdk.startTransaction(
    //     paytmModel.value.paytmMID.toString(),
    //     orderId,
    //     amount.toString(),
    //     txnTokenBy,
    //     callBackURL,
    //     isStaging,
    //     true,
    //     true,
    //   );
    //
    //   response.then((value) {
    //     if (value!["RESPMSG"] == "Txn Success") {
    //       print("txt done!!");
    //       ShowToastDialog.showToast("Payment Successful!!");
    //       placeOrder();
    //     }
    //   }).catchError((onError) {
    //     if (onError is PlatformException) {
    //       Get.back();
    //
    //       ShowToastDialog.showToast(onError.message.toString());
    //     } else {
    //       log("======>>2");
    //       Get.back();
    //       ShowToastDialog.showToast(onError.message.toString());
    //     }
    //   });
    // } catch (err) {
    //   Get.back();
    //   ShowToastDialog.showToast(err.toString());
    // }
  }

  Future verifyCheckSum({
    required String checkSum,
    required double amount,
    required orderId,
  }) async {
    String getChecksum = "${Constant.globalUrl}payments/validatechecksum";
    final response = await http.post(
      Uri.parse(getChecksum),
      headers: {},
      body: {
        "mid": paytmModel.value.paytmMID.toString(),
        "order_id": orderId,
        "key_secret": paytmModel.value.pAYTMMERCHANTKEY.toString(),
        "checksum_value": checkSum,
      },
    );
    final data = jsonDecode(response.body);
    return data['status'];
  }

  Future<GetPaymentTxtTokenModel> initiatePayment({
    required double amount,
    required orderId,
  }) async {
    String initiateURL = "${Constant.globalUrl}payments/initiatepaytmpayment";
    String callback = "";
    if (paytmModel.value.isSandboxEnabled == true) {
      callback =
          "${callback}https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    } else {
      callback =
          "${callback}https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    }
    final response = await http.post(
      Uri.parse(initiateURL),
      headers: {},
      body: {
        "mid": paytmModel.value.paytmMID,
        "order_id": orderId,
        "key_secret": paytmModel.value.pAYTMMERCHANTKEY,
        "amount": amount.toString(),
        "currency": "INR",
        "callback_url": callback,
        "custId": FireStoreUtils.getCurrentUid(),
        "issandbox": paytmModel.value.isSandboxEnabled == true ? "1" : "2",
      },
    );
    log(response.body);
    final data = jsonDecode(response.body);
    if (data["body"]["txnToken"] == null ||
        data["body"]["txnToken"].toString().isEmpty) {
      Get.back();
      ShowToastDialog.showToast(
        "something went wrong, please contact admin.".tr,
      );
    }
    return GetPaymentTxtTokenModel.fromJson(data);
  }

  bool isCurrentDateInRange(DateTime startDate, DateTime endDate) {
    final currentDate = DateTime.now();
    return currentDate.isAfter(startDate) && currentDate.isBefore(endDate);
  }

  //Midtrans payment
  Future<void> midtransMakePayment({
    required String amount,
    required BuildContext context,
  }) async {
    await createPaymentLink(amount: amount).then((url) {
      ShowToastDialog.closeLoader();
      if (url != '') {
        Get.to(() => MidtransScreen(initialURl: url))!.then((value) {
          if (value == true) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            placeOrder();
          } else {
            ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
          }
        });
      }
    });
  }

  Future<String> createPaymentLink({required var amount}) async {
    var ordersId = const Uuid().v1();
    final url = Uri.parse(
      midTransModel.value.isSandbox!
          ? 'https://api.sandbox.midtrans.com/v1/payment-links'
          : 'https://api.midtrans.com/v1/payment-links',
    );

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': generateBasicAuthHeader(
          midTransModel.value.serverKey!,
        ),
      },
      body: jsonEncode({
        'transaction_details': {
          'order_id': ordersId,
          'gross_amount': double.parse(amount.toString()).toInt(),
        },
        'usage_limit': 2,
        "callbacks": {
          "finish": "https://www.google.com?merchant_order_id=$ordersId",
        },
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      return responseData['payment_url'];
    } else {
      ShowToastDialog.showToast(
        "something went wrong, please contact admin.".tr,
      );
      return '';
    }
  }

  String generateBasicAuthHeader(String apiKey) {
    String credentials = '$apiKey:';
    String base64Encoded = base64Encode(utf8.encode(credentials));
    return 'Basic $base64Encoded';
  }

  //Orangepay payment
  static String accessToken = '';
  static String payToken = '';
  static String orderId = '';
  static String amount = '';

  Future<void> orangeMakePayment({
    required String amount,
    required BuildContext context,
  }) async {
    reset();
    var id = const Uuid().v4();
    var paymentURL = await fetchToken(
      context: context,
      orderId: id,
      amount: amount,
      currency: 'USD',
    );
    ShowToastDialog.closeLoader();
    if (paymentURL.toString() != '') {
      Get.to(
        () => OrangeMoneyScreen(
          initialURl: paymentURL,
          accessToken: accessToken,
          amount: amount,
          orangePay: orangeMoneyModel.value,
          orderId: orderId,
          payToken: payToken,
        ),
      )!.then((value) {
        if (value == true) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          placeOrder();
          ();
        }
      });
    } else {
      ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
    }
  }

  Future fetchToken({
    required String orderId,
    required String currency,
    required BuildContext context,
    required String amount,
  }) async {
    String apiUrl = 'https://api.orange.com/oauth/v3/token';
    Map<String, String> requestBody = {'grant_type': 'client_credentials'};

    var response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Authorization': "Basic ${orangeMoneyModel.value.auth!}",
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: requestBody,
    );

    // Handle the response

    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.body);

      accessToken = responseData['access_token'];
      // ignore: use_build_context_synchronously
      return await webpayment(
        context: context,
        amountData: amount,
        currency: currency,
        orderIdData: orderId,
      );
    } else {
      ShowToastDialog.showToast(
        "Something went wrong, please contact admin.".tr,
      );
      return '';
    }
  }

  Future webpayment({
    required String orderIdData,
    required BuildContext context,
    required String currency,
    required String amountData,
  }) async {
    orderId = orderIdData;
    amount = amountData;
    String apiUrl =
        orangeMoneyModel.value.isSandbox! == true
            ? 'https://api.orange.com/orange-money-webpay/dev/v1/webpayment'
            : 'https://api.orange.com/orange-money-webpay/cm/v1/webpayment';
    Map<String, String> requestBody = {
      "merchant_key": orangeMoneyModel.value.merchantKey ?? '',
      "currency": orangeMoneyModel.value.isSandbox == true ? "OUV" : currency,
      "order_id": orderId,
      "amount": amount,
      "reference": 'Y-Note Test',
      "lang": "en",
      "return_url": orangeMoneyModel.value.returnUrl!.toString(),
      "cancel_url": orangeMoneyModel.value.cancelUrl!.toString(),
      "notif_url": orangeMoneyModel.value.notifUrl!.toString(),
    };

    var response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(requestBody),
    );

    // Handle the response
    if (response.statusCode == 201) {
      Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData['message'] == 'OK') {
        payToken = responseData['pay_token'];
        return responseData['payment_url'];
      } else {
        return '';
      }
    } else {
      ShowToastDialog.showToast(
        "Something went wrong, please contact admin.".tr,
      );
      return '';
    }
  }

  static void reset() {
    accessToken = '';
    payToken = '';
    orderId = '';
    amount = '';
  }

  //XenditPayment
  Future<void> xenditPayment(context, amount) async {
    await createXenditInvoice(amount: amount).then((model) {
      ShowToastDialog.closeLoader();
      if (model.id != null) {
        Get.to(
          () => XenditScreen(
            initialURl: model.invoiceUrl ?? '',
            transId: model.id ?? '',
            apiKey: xenditModel.value.apiKey!.toString(),
          ),
        )!.then((value) {
          if (value == true) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            placeOrder();
            ();
          } else {
            ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
          }
        });
      }
    });
  }

  Future<XenditModel> createXenditInvoice({required var amount}) async {
    const url = 'https://api.xendit.co/v2/invoices';
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': generateBasicAuthHeader(
        xenditModel.value.apiKey!.toString(),
      ),
      // 'Cookie': '__cf_bm=yERkrx3xDITyFGiou0bbKY1bi7xEwovHNwxV1vCNbVc-1724155511-1.0.1.1-jekyYQmPCwY6vIJ524K0V6_CEw6O.dAwOmQnHtwmaXO_MfTrdnmZMka0KZvjukQgXu5B.K_6FJm47SGOPeWviQ',
    };

    final body = jsonEncode({
      'external_id': const Uuid().v1(),
      'amount': amount,
      'payer_email': 'customer@domain.com',
      'description': 'Test - VA Successful invoice payment',
      'currency': 'IDR', //IDR, PHP, THB, VND, MYR
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        XenditModel model = XenditModel.fromJson(jsonDecode(response.body));
        return model;
      } else {
        return XenditModel();
      }
    } catch (e) {
      return XenditModel();
    }
  }
}
