import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as maths;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/payment_model/flutter_wave_model.dart';
import 'package:customer/models/payment_model/mercado_pago_model.dart';
import 'package:customer/models/payment_model/mid_trans.dart';
import 'package:customer/models/payment_model/orange_money.dart';
import 'package:customer/models/payment_model/pay_fast_model.dart';
import 'package:customer/models/payment_model/pay_stack_model.dart';
import 'package:customer/models/payment_model/paypal_model.dart';
import 'package:customer/models/payment_model/payme_model.dart';
import 'package:customer/models/payment_model/razorpay_model.dart';
import 'package:customer/models/payment_model/stripe_model.dart';
import 'package:customer/models/payment_model/xendit.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/wallet_transaction_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter_paypal/flutter_paypal.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../payment/MercadoPagoScreen.dart';
import '../payment/PayFastScreen.dart';
import '../payment/midtrans_screen.dart';
import '../payment/orangePayScreen.dart';
import '../payment/PaymeScreen.dart';
import '../payment/paystack/pay_stack_screen.dart';
import '../payment/paystack/pay_stack_url_model.dart';
import '../payment/paystack/paystack_url_genrater.dart';
import '../payment/stripe_failed_model.dart';
import '../payment/xenditModel.dart';
import '../payment/xenditScreen.dart';
import '../service/fire_store_utils.dart';
import 'package:customer/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../themes/show_toast_dialog.dart';

class WalletController extends GetxController {
  RxBool isLoading = true.obs;

  Rx<TextEditingController> topUpAmountController = TextEditingController().obs;

  RxList<WalletTransactionModel> walletTransactionList =
      <WalletTransactionModel>[].obs;

  Rx<UserModel> userModel = UserModel().obs;
  RxString selectedPaymentMethod = "".obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getPaymentSettings();
    getWalletTransaction();
    super.onInit();
  }

  Rx<PayFastModel> payFastModel = PayFastModel().obs;
  Rx<MercadoPagoModel> mercadoPagoModel = MercadoPagoModel().obs;
  Rx<PayPalModel> payPalModel = PayPalModel().obs;
  Rx<StripeModel> stripeModel = StripeModel().obs;
  Rx<FlutterWaveModel> flutterWaveModel = FlutterWaveModel().obs;
  Rx<PayStackModel> payStackModel = PayStackModel().obs;
  Rx<PaymeModel> paymeModel = PaymeModel().obs;
  Rx<RazorPayModel> razorPayModel = RazorPayModel().obs;
  Rx<MidTrans> midTransModel = MidTrans().obs;
  Rx<OrangeMoney> orangeMoneyModel = OrangeMoney().obs;
  Rx<Xendit> xenditModel = Xendit().obs;

  Future<void> getPaymentSettings() async {
    print("🔵 [WalletController.getPaymentSettings] Boshlandi");
    await FireStoreUtils.getPaymentSettingsData()
        .then((value) {
          print(
            "🔵 [WalletController.getPaymentSettings] FireStoreUtils.getPaymentSettingsData tugadi",
          );

          // PayFast
          try {
            payFastModel.value = PayFastModel.fromJson(
              jsonDecode(Preferences.getString(Preferences.payFastSettings)),
            );
            print(
              "🔵 [WalletController.getPaymentSettings] PayFast: isEnable=${payFastModel.value.isEnable}",
            );
          } catch (e) {
            print(
              "❌ [WalletController.getPaymentSettings] PayFast o'qish xatosi: $e",
            );
          }

          // MercadoPago
          try {
            mercadoPagoModel.value = MercadoPagoModel.fromJson(
              jsonDecode(Preferences.getString(Preferences.mercadoPago)),
            );
            print(
              "🔵 [WalletController.getPaymentSettings] MercadoPago: isEnabled=${mercadoPagoModel.value.isEnabled}",
            );
          } catch (e) {
            print(
              "❌ [WalletController.getPaymentSettings] MercadoPago o'qish xatosi: $e",
            );
          }

          // PayPal
          try {
            payPalModel.value = PayPalModel.fromJson(
              jsonDecode(Preferences.getString(Preferences.paypalSettings)),
            );
            print(
              "🔵 [WalletController.getPaymentSettings] PayPal: isEnabled=${payPalModel.value.isEnabled}",
            );
          } catch (e) {
            print(
              "❌ [WalletController.getPaymentSettings] PayPal o'qish xatosi: $e",
            );
          }

          // Stripe
          try {
            stripeModel.value = StripeModel.fromJson(
              jsonDecode(Preferences.getString(Preferences.stripeSettings)),
            );
            print(
              "🔵 [WalletController.getPaymentSettings] Stripe: isEnabled=${stripeModel.value.isEnabled}",
            );
          } catch (e) {
            print(
              "❌ [WalletController.getPaymentSettings] Stripe o'qish xatosi: $e",
            );
          }

          // FlutterWave
          try {
            flutterWaveModel.value = FlutterWaveModel.fromJson(
              jsonDecode(Preferences.getString(Preferences.flutterWave)),
            );
            print(
              "🔵 [WalletController.getPaymentSettings] FlutterWave: isEnable=${flutterWaveModel.value.isEnable}",
            );
          } catch (e) {
            print(
              "❌ [WalletController.getPaymentSettings] FlutterWave o'qish xatosi: $e",
            );
          }

          // PayStack
          try {
            payStackModel.value = PayStackModel.fromJson(
              jsonDecode(Preferences.getString(Preferences.payStack)),
            );
            print(
              "🔵 [WalletController.getPaymentSettings] PayStack: isEnable=${payStackModel.value.isEnable}",
            );
          } catch (e) {
            print(
              "❌ [WalletController.getPaymentSettings] PayStack o'qish xatosi: $e",
            );
          }

          // RazorPay
          try {
            razorPayModel.value = RazorPayModel.fromJson(
              jsonDecode(Preferences.getString(Preferences.razorpaySettings)),
            );
            print(
              "🔵 [WalletController.getPaymentSettings] RazorPay: isEnabled=${razorPayModel.value.isEnabled}",
            );
          } catch (e) {
            print(
              "❌ [WalletController.getPaymentSettings] RazorPay o'qish xatosi: $e",
            );
          }

          // MidTrans
          try {
            midTransModel.value = MidTrans.fromJson(
              jsonDecode(Preferences.getString(Preferences.midTransSettings)),
            );
            print(
              "🔵 [WalletController.getPaymentSettings] MidTrans: enable=${midTransModel.value.enable}",
            );
          } catch (e) {
            print(
              "❌ [WalletController.getPaymentSettings] MidTrans o'qish xatosi: $e",
            );
          }

          // OrangeMoney
          try {
            orangeMoneyModel.value = OrangeMoney.fromJson(
              json.decode(
                Preferences.getString(Preferences.orangeMoneySettings),
              ),
            );
            print(
              "🔵 [WalletController.getPaymentSettings] OrangeMoney: enable=${orangeMoneyModel.value.enable}",
            );
          } catch (e) {
            print(
              "❌ [WalletController.getPaymentSettings] OrangeMoney o'qish xatosi: $e",
            );
          }

          // Xendit
          try {
            xenditModel.value = Xendit.fromJson(
              jsonDecode(Preferences.getString(Preferences.xenditSettings)),
            );
            print(
              "🔵 [WalletController.getPaymentSettings] Xendit: enable=${xenditModel.value.enable}",
            );
          } catch (e) {
            print(
              "❌ [WalletController.getPaymentSettings] Xendit o'qish xatosi: $e",
            );
          }

          // Payme
          try {
            paymeModel.value = PaymeModel.fromJson(
              jsonDecode(Preferences.getString(Preferences.paymeSettings)),
            );
            print(
              "🔵 [WalletController.getPaymentSettings] Payme: isEnabled=${paymeModel.value.isEnabled ?? paymeModel.value.enable}",
            );
          } catch (e) {
            print(
              "❌ [WalletController.getPaymentSettings] Payme o'qish xatosi: $e",
            );
          }

          Stripe.publishableKey =
              stripeModel.value.clientpublishableKey.toString();
          Stripe.merchantIdentifier = 'GoRide';
          Stripe.instance.applySettings();
          setRef();

          razorPay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccess);
          razorPay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWaller);
          razorPay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentError);

          print("🔵 [WalletController.getPaymentSettings] Tugadi");
        })
        .catchError((e) {
          print("❌ [WalletController.getPaymentSettings] Umumiy xatolik: $e");
        });
  }

  Future<void> getWalletTransaction() async {
    if (Constant.userModel != null) {
      await FireStoreUtils.getWalletTransaction().then((value) {
        if (value != null) {
          walletTransactionList.value = value;
        }
      });
      await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((
        value,
      ) {
        if (value != null) {
          userModel.value = value;
        }
      });
    }
    isLoading.value = false;
  }

  Future<void> walletTopUp() async {
    WalletTransactionModel transactionModel = WalletTransactionModel(
      id: Constant.getUuid(),
      amount: double.parse(topUpAmountController.value.text),
      date: Timestamp.now(),
      paymentMethod: selectedPaymentMethod.value,
      transactionUser: "user",
      userId: FireStoreUtils.getCurrentUid(),
      isTopup: true,
      note: "Wallet Top-up",
      paymentStatus: "success",
    );

    await FireStoreUtils.setWalletTransaction(transactionModel).then((
      value,
    ) async {
      if (value == true) {
        await FireStoreUtils.updateUserWallet(
          amount: topUpAmountController.value.text,
          userId: FireStoreUtils.getCurrentUid(),
        ).then((value) {
          getWalletTransaction();
          Get.back();
        });
      }
    });

    ShowToastDialog.showToast("Amount Top-up successfully".tr);
  }

  // Strip
  Future<void> stripeMakePayment({required String amount}) async {
    log(double.parse(amount).toStringAsFixed(0));
    try {
      Map<String, dynamic>? paymentIntentData = await createStripeIntent(
        amount: amount,
      );
      log("stripe Responce====>$paymentIntentData");
      if (paymentIntentData!.containsKey("error")) {
        Get.back();
        ShowToastDialog.showToast(
          "Something went wrong, please contact admin.".tr,
        );
      } else {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentIntentData['client_secret'],
            allowsDelayedPaymentMethods: false,
            googlePay: const PaymentSheetGooglePay(
              merchantCountryCode: 'US',
              testEnv: true,
              currencyCode: "USD",
            ),
            customFlow: true,
            style: ThemeMode.system,
            appearance: PaymentSheetAppearance(
              colors: PaymentSheetAppearanceColors(
                primary: AppThemeData.primary300,
              ),
            ),
            merchantDisplayName: 'GoRide',
          ),
        );
        displayStripePaymentSheet(amount: amount);
      }
    } catch (e, s) {
      log("$e \n$s");
      ShowToastDialog.showToast("exception:$e \n$s");
    }
  }

  Future<void> displayStripePaymentSheet({required String amount}) async {
    try {
      await Stripe.instance.presentPaymentSheet().then((value) {
        ShowToastDialog.showToast("Payment successfully".tr);
        walletTopUp();
      });
    } on StripeException catch (e) {
      var lo1 = jsonEncode(e);
      var lo2 = jsonDecode(lo1);
      StripePayFailedModel lom = StripePayFailedModel.fromJson(lo2);
      ShowToastDialog.showToast(lom.error.message);
    } catch (e) {
      ShowToastDialog.showToast(e.toString());
    }
  }

  Future createStripeIntent({required String amount}) async {
    try {
      Map<String, dynamic> body = {
        'amount': ((double.parse(amount) * 100).round()).toString(),
        'currency': "USD",
        'payment_method_types[]': 'card',
        "description": "Strip Payment",
        "shipping[name]": userModel.value.fullName(),
        "shipping[address][line1]": "510 Townsend St",
        "shipping[address][postal_code]": "98140",
        "shipping[address][city]": "San Francisco",
        "shipping[address][state]": "CA",
        "shipping[address][country]": "US",
      };
      var stripeSecret = stripeModel.value.stripeSecret;
      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        body: body,
        headers: {
          'Authorization': 'Bearer $stripeSecret',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      log(e.toString());
    }
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
      "auto_return":
          "approved", // Automatically return after payment is approved
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
          walletTopUp();
        } else {
          ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
        }
      });
    } else {
      ShowToastDialog.showToast(
        "Something want wrong please contact administrator".tr,
      );
      print('Error creating preference: ${response.body}');
      return null;
    }
  }

  void paypalPaymentSheet(String amount, context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (BuildContext context) => UsePaypal(
              sandboxMode: payPalModel.value.isLive == true ? false : true,
              clientId: payPalModel.value.paypalClient ?? '',
              secretKey: payPalModel.value.paypalSecret ?? '',
              returnURL: "com.parkme://paypalpay",
              cancelURL: "com.parkme://paypalpay",
              transactions: [
                {
                  "amount": {
                    "total": amount,
                    "currency": "USD",
                    "details": {"subtotal": amount},
                  },
                },
              ],
              note: "Contact us for any questions on your order.",
              onSuccess: (Map params) async {
                walletTopUp();
                ShowToastDialog.showToast("Payment Successful!!".tr);
              },
              onError: (error) {
                Get.back();
                ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
              },
              onCancel: (params) {
                Get.back();
                ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
              },
            ),
      ),
    );
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
            walletTopUp();
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
          walletTopUp();
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
        walletTopUp();
      } else {
        Get.back();
        ShowToastDialog.showToast("Payment Failed".tr);
      }
    });
  }

  ///RazorPay payment function
  final Razorpay razorPay = Razorpay();

  void openCheckout({required amount, required orderId}) async {
    var options = {
      'key': razorPayModel.value.razorpayKey,
      'amount': amount * 100,
      'name': 'GoRide',
      'order_id': orderId,
      "currency": "INR",
      'description': 'wallet Topup',
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
      'prefill': {
        'contact': userModel.value.phoneNumber,
        'email': userModel.value.email,
      },
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      razorPay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void handlePaymentSuccess(PaymentSuccessResponse response) {
    ShowToastDialog.showToast("Payment Successful!!".tr);
    walletTopUp();
  }

  void handleExternalWaller(ExternalWalletResponse response) {
    Get.back();
    ShowToastDialog.showToast("Payment Processing!! via".tr);
  }

  void handlePaymentError(PaymentFailureResponse response) {
    Get.back();
    ShowToastDialog.showToast("Payment Failed!!".tr);
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
            walletTopUp();
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
          walletTopUp();
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

    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.body);

      accessToken = responseData['access_token'];
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
    print(response.statusCode);
    print(response.body);

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

  //PaymePayment
  Future<void> paymeMakePayment({
    required BuildContext context,
    required String amount,
  }) async {
    print('🔵 [PaymePayment] ========== paymeMakePayment STARTED ==========');
    print('🔵 [PaymePayment] amount: $amount');
    print('🔵 [PaymePayment] user phone: ${userModel.value.phoneNumber}');
    log('🔵 [PaymePayment] paymeMakePayment boshlandi, amount: $amount');
    log('🔵 [PaymePayment] user phone: ${userModel.value.phoneNumber}');

    try {
      ShowToastDialog.showLoader("Processing...".tr);

      final url = Uri.parse(
        'https://emart-web.felix-its.uz/wallet-payme-link/',
      );
      final phoneNumber = '+998${userModel.value.phoneNumber}';
      final amountInt = double.parse(amount).ceil().toInt();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      };
      final body = jsonEncode({'phone': phoneNumber, 'amount': amountInt});

      print('🔵 [PaymePayment] Preparing request...');
      print('🔵 [PaymePayment] Request URL: $url');
      print('🔵 [PaymePayment] Request Headers: $headers');
      print('🔵 [PaymePayment] Request Body: $body');
      print('🔵 [PaymePayment] Phone: $phoneNumber');
      print('🔵 [PaymePayment] Amount (int): $amountInt');
      log('🔵 [PaymePayment] Request URL: $url');
      log('🔵 [PaymePayment] Request Headers: $headers');
      log('🔵 [PaymePayment] Request Body: $body');

      print('🔵 [PaymePayment] Sending POST request...');
      log('🔵 [PaymePayment] Sending POST request...');
      final response = await http.post(url, headers: headers, body: body);

      print('🔵 [PaymePayment] Response received');
      print('🔵 [PaymePayment] Response Status: ${response.statusCode}');
      print('🔵 [PaymePayment] Response Headers: ${response.headers}');
      final responseBodyPreview =
          response.body.length > 500
              ? '${response.body.substring(0, 500)}...'
              : response.body;
      print('🔵 [PaymePayment] Response Body: $responseBodyPreview');
      log('🔵 [PaymePayment] Response Status: ${response.statusCode}');
      log('🔵 [PaymePayment] Response Headers: ${response.headers}');
      log(
        '🔵 [PaymePayment] Response Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}',
      );

      ShowToastDialog.closeLoader();

      // Check if response is HTML (redirect to login)
      if (response.body.trim().startsWith('<!DOCTYPE html>') ||
          response.body.trim().startsWith('<html>') ||
          response.body.contains('Redirecting to')) {
        print(
          '❌ [PaymePayment] HTML response received (likely redirect to login)',
        );
        print('❌ [PaymePayment] Response starts with HTML, not JSON');
        log(
          '❌ [PaymePayment] HTML response received (likely redirect to login)',
        );
        ShowToastDialog.showToast(
          "Server authentication error. Please try again.".tr,
        );
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          print('🔵 [PaymePayment] Parsing response JSON');
          log('🔵 [PaymePayment] Parsing response JSON');
          final data = jsonDecode(response.body);
          print('🔵 [PaymePayment] Parsed data: $data');
          log('🔵 [PaymePayment] Parsed data: $data');

          if (data['status'] == true && data['link'] != null) {
            final orderId = data['order_id'];
            final link = data['link'];

            print('✅ [PaymePayment] Payment link received successfully');
            print('✅ [PaymePayment] order_id: $orderId');
            print('✅ [PaymePayment] link: $link');
            log('✅ [PaymePayment] Payment link received successfully');
            log('✅ [PaymePayment] order_id: $orderId');
            log('✅ [PaymePayment] Opening PaymeScreen...');

            Get.to(
              () => PaymeScreen(initialURl: link, orderId: orderId),
            )!.then((result) async {
              print('🔵 [PaymePayment] PaymeScreen closed, result: $result');
              log('🔵 [PaymePayment] PaymeScreen closed, result: $result');

              if (result != null && result is Map) {
                final isPaid = result['is_paid'] ?? false;
                final resultOrderId = result['order_id'];
                final resultAmount = result['amount'];
                final resultUserId = result['user_id'];

                print('🔵 [PaymePayment] Payment result received');
                print('🔵 [PaymePayment] is_paid: $isPaid');
                print('🔵 [PaymePayment] order_id: $resultOrderId');
                print('🔵 [PaymePayment] amount: $resultAmount');
                print('🔵 [PaymePayment] user_id: $resultUserId');
                log('🔵 [PaymePayment] Payment result received');
                log(
                  '🔵 [PaymePayment] is_paid: $isPaid, order_id: $resultOrderId, amount: $resultAmount',
                );

                if (isPaid == true) {
                  print(
                    '✅ [PaymePayment] Payment is confirmed as paid, adding to Firestore',
                  );
                  log(
                    '✅ [PaymePayment] Payment is confirmed as paid, adding to Firestore',
                  );
                  // Push to Firestore wallet collection
                  await _addPaymeWalletTransaction(
                    orderId: resultOrderId?.toString() ?? '',
                    amount: resultAmount?.toString() ?? amount,
                  );
                  print(
                    '✅ [PaymePayment] Wallet transaction added successfully',
                  );
                  log('✅ [PaymePayment] Wallet transaction added successfully');
                  ShowToastDialog.showToast("Payment Successful!!".tr);
                } else {
                  print(
                    '❌ [PaymePayment] Payment is not paid, is_paid: $isPaid',
                  );
                  log('❌ [PaymePayment] Payment is not paid, is_paid: $isPaid');
                  ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
                }
              } else {
                print(
                  '❌ [PaymePayment] Invalid result from PaymeScreen: $result',
                );
                log(
                  '❌ [PaymePayment] Invalid result from PaymeScreen: $result',
                );
                ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
              }
            });
          } else {
            print(
              '❌ [PaymePayment] Invalid response data - status: ${data['status']}, link: ${data['link']}',
            );
            log('❌ [PaymePayment] Invalid response data: $data');
            ShowToastDialog.showToast("Failed to get payment link".tr);
          }
        } catch (e, stackTrace) {
          print('❌ [PaymePayment] JSON parse error: $e');
          print('❌ [PaymePayment] Stack trace: $stackTrace');
          log(
            '❌ [PaymePayment] JSON parse error: $e',
            error: e,
            stackTrace: stackTrace,
          );
          log('❌ [PaymePayment] Response body: ${response.body}');
          ShowToastDialog.showToast("Failed to parse server response".tr);
        }
      } else {
        print('❌ [PaymePayment] Error status: ${response.statusCode}');
        print('❌ [PaymePayment] Error body: ${response.body}');
        log('❌ [PaymePayment] Error status: ${response.statusCode}');
        log('❌ [PaymePayment] Error body: ${response.body}');
        ShowToastDialog.showToast(
          "Something went wrong, please contact admin.".tr,
        );
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Payment error: ${e.toString()}".tr);
      log('❌ [PaymePayment] Exception: $e');
    }
  }

  Future<void> _addPaymeWalletTransaction({
    required String orderId,
    required String amount,
  }) async {
    print('🔵 [PaymePayment] _addPaymeWalletTransaction - Starting');
    print('🔵 [PaymePayment] orderId: $orderId');
    print('🔵 [PaymePayment] amount: $amount');
    log('🔵 [PaymePayment] _addPaymeWalletTransaction - Starting');
    log('🔵 [PaymePayment] orderId: $orderId, amount: $amount');

    try {
      final transactionId = Constant.getUuid();
      final userId = FireStoreUtils.getCurrentUid();
      final transactionAmount = double.parse(amount);

      print('🔵 [PaymePayment] Creating WalletTransactionModel');
      print('🔵 [PaymePayment] transactionId: $transactionId');
      print('🔵 [PaymePayment] userId: $userId');
      print('🔵 [PaymePayment] transactionAmount: $transactionAmount');
      log('🔵 [PaymePayment] Creating WalletTransactionModel');
      log('🔵 [PaymePayment] transactionId: $transactionId, userId: $userId');

      WalletTransactionModel transactionModel = WalletTransactionModel(
        id: transactionId,
        amount: transactionAmount,
        date: Timestamp.now(),
        paymentMethod: "Wallet",
        transactionUser: "user",
        userId: userId,
        isTopup: true,
        note: "tolov qilindin",
        paymentStatus: "success",
        orderId: orderId,
      );

      print(
        '🔵 [PaymePayment] Transaction model created, pushing to Firestore...',
      );
      log(
        '🔵 [PaymePayment] Transaction model created, pushing to Firestore...',
      );

      await FireStoreUtils.setWalletTransaction(transactionModel)
          .then((value) async {
            print('🔵 [PaymePayment] setWalletTransaction result: $value');
            log('🔵 [PaymePayment] setWalletTransaction result: $value');

            if (value == true) {
              print(
                '✅ [PaymePayment] Wallet transaction added to Firestore successfully',
              );
              print('🔵 [PaymePayment] Updating user wallet balance...');
              log(
                '✅ [PaymePayment] Wallet transaction added to Firestore successfully',
              );
              log('🔵 [PaymePayment] Updating user wallet balance...');

              await FireStoreUtils.updateUserWallet(
                    amount: amount,
                    userId: userId,
                  )
                  .then((value) {
                    print(
                      '✅ [PaymePayment] User wallet balance updated: $value',
                    );
                    print(
                      '🔵 [PaymePayment] Refreshing wallet transaction list...',
                    );
                    log('✅ [PaymePayment] User wallet balance updated: $value');
                    log(
                      '🔵 [PaymePayment] Refreshing wallet transaction list...',
                    );
                    getWalletTransaction();
                    print('✅ [PaymePayment] Wallet transaction list refreshed');
                    log('✅ [PaymePayment] Wallet transaction list refreshed');
                  })
                  .catchError((error) {
                    print(
                      '❌ [PaymePayment] Error updating user wallet: $error',
                    );
                    log(
                      '❌ [PaymePayment] Error updating user wallet: $error',
                      error: error,
                    );
                  });
            } else {
              print(
                '❌ [PaymePayment] Failed to add wallet transaction to Firestore',
              );
              log(
                '❌ [PaymePayment] Failed to add wallet transaction to Firestore',
              );
            }
          })
          .catchError((error) {
            print('❌ [PaymePayment] Error setting wallet transaction: $error');
            log(
              '❌ [PaymePayment] Error setting wallet transaction: $error',
              error: error,
            );
          });
    } catch (e, stackTrace) {
      print('❌ [PaymePayment] Exception in _addPaymeWalletTransaction: $e');
      print('❌ [PaymePayment] Stack trace: $stackTrace');
      log(
        '❌ [PaymePayment] Exception in _addPaymeWalletTransaction: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
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
            walletTopUp();
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
