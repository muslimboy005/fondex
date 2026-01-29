import 'package:customer/constant/constant.dart';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

class PaymeScreen extends StatefulWidget {
  final String initialURl;
  final int? orderId;
  final String? rideId; // Firestore ride document ID

  const PaymeScreen({
    super.key,
    required this.initialURl,
    this.orderId,
    this.rideId,
  });

  @override
  State<PaymeScreen> createState() => _PaymeScreenState();
}

class _PaymeScreenState extends State<PaymeScreen> {
  WebViewController controller = WebViewController();
  bool _isPaymentCompleted = false;
  bool _isCheckingPayment = false;

  @override
  void initState() {
    print(
      '🔵 [PaymeScreen] initState - orderId: ${widget.orderId}, rideId: ${widget.rideId}, initialURL: ${widget.initialURl}',
    );
    developer.log(
      '🔵 [PaymeScreen] initState - orderId: ${widget.orderId}, rideId: ${widget.rideId}, initialURL: ${widget.initialURl}',
    );
    initController();
    super.initState();
  }

  void initController() {
    print(
      '🔵 [PaymeScreen] initController - Loading URL: ${widget.initialURl}',
    );
    developer.log(
      '🔵 [PaymeScreen] initController - Loading URL: ${widget.initialURl}',
    );

    controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                print('🔵 [PaymeScreen] onProgress: $progress%');
                developer.log('🔵 [PaymeScreen] onProgress: $progress%');
              },
              onPageStarted: (String url) {
                print('🔵 [PaymeScreen] onPageStarted: $url');
                developer.log('🔵 [PaymeScreen] onPageStarted: $url');
              },
              onWebResourceError: (WebResourceError error) {
                print(
                  '❌ [PaymeScreen] onWebResourceError: ${error.description}',
                );
                developer.log(
                  '❌ [PaymeScreen] onWebResourceError: ${error.description}',
                );
              },
              onNavigationRequest: (NavigationRequest navigation) async {
                print(
                  '🔵 [PaymeScreen] onNavigationRequest: ${navigation.url}',
                );
                developer.log(
                  '🔵 [PaymeScreen] onNavigationRequest: ${navigation.url}',
                );

                if (navigation.url.contains(
                  "${Constant.globalUrl}payment/success",
                )) {
                  print('✅ [PaymeScreen] Payment success URL detected');
                  developer.log('✅ [PaymeScreen] Payment success URL detected');
                  setState(() {
                    _isPaymentCompleted = true;
                  });
                  await _checkPaymentStatus();
                  return NavigationDecision.prevent;
                }
                if (navigation.url.contains(
                      "${Constant.globalUrl}payment/failure",
                    ) ||
                    navigation.url.contains(
                      "${Constant.globalUrl}payment/pending",
                    )) {
                  print('❌ [PaymeScreen] Payment failure/pending URL detected');
                  developer.log(
                    '❌ [PaymeScreen] Payment failure/pending URL detected',
                  );
                  Get.back(
                    result: {'success': false, 'order_id': widget.orderId},
                  );
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.initialURl));

    print('🔵 [PaymeScreen] Controller initialized and URL loaded');
    developer.log('🔵 [PaymeScreen] Controller initialized and URL loaded');
  }

  Future<void> _checkPaymentStatus({
    int retryCount = 0,
    int maxRetries = 2,
  }) async {
    if (_isCheckingPayment) {
      print('⚠️ [PaymeScreen] Payment status check already in progress');
      developer.log(
        '⚠️ [PaymeScreen] Payment status check already in progress',
      );
      return;
    }

    setState(() {
      _isCheckingPayment = true;
    });
    ShowToastDialog.showLoader("To'lov holati tekshirilmoqda...".tr);

    print(
      '🔵 [PaymeScreen] _checkPaymentStatus - Starting check for orderId: ${widget.orderId}, retry: $retryCount/$maxRetries',
    );
    developer.log(
      '🔵 [PaymeScreen] _checkPaymentStatus - Starting check for orderId: ${widget.orderId}, retry: $retryCount/$maxRetries',
    );

    if (widget.orderId == null) {
      print('❌ [PaymeScreen] orderId is null, cannot check payment status');
      developer.log(
        '❌ [PaymeScreen] orderId is null, cannot check payment status',
      );
      ShowToastDialog.closeLoader();
      Get.back(result: {'success': false, 'order_id': null});
      setState(() {
        _isCheckingPayment = false;
      });
      return;
    }

    try {
      final url = Uri.parse(
        'https://emart-web.felix-its.uz/api/payment/check-status',
      );
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final body = jsonEncode({'order_id': widget.orderId});

      print(
        '🔵 [PaymeScreen] Sending payment status check request (attempt ${retryCount + 1})',
      );
      print('🔵 [PaymeScreen] URL: $url');
      print('🔵 [PaymeScreen] Headers: $headers');
      print('🔵 [PaymeScreen] Body: $body');
      developer.log(
        '🔵 [PaymeScreen] Sending payment status check request (attempt ${retryCount + 1})',
        name: 'PaymeScreen',
      );
      developer.log('🔵 [PaymeScreen] URL: $url', name: 'PaymeScreen');
      developer.log('🔵 [PaymeScreen] Body: $body', name: 'PaymeScreen');

      final response = await http.post(url, headers: headers, body: body);

      print('🔵 [PaymeScreen] Payment status response received');
      print('🔵 [PaymeScreen] Status Code: ${response.statusCode}');
      print('🔵 [PaymeScreen] Response Body: ${response.body}');
      developer.log(
        '🔵 [PaymeScreen] Payment status response received',
        name: 'PaymeScreen',
      );
      developer.log(
        '🔵 [PaymeScreen] Status Code: ${response.statusCode}',
        name: 'PaymeScreen',
      );
      developer.log(
        '🔵 [PaymeScreen] Response Body: ${response.body}',
        name: 'PaymeScreen',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isPaid = data['is_paid'] ?? false;
        final orderId = data['order_id'];
        final amount = data['amount'];
        final userId = data['user_id'];
        final paymentStatus = data['payment_status'] ?? '';

        print('✅ [PaymeScreen] Payment status check completed');
        print('✅ [PaymeScreen] is_paid: $isPaid');
        print('✅ [PaymeScreen] order_id: $orderId');
        print('✅ [PaymeScreen] amount: $amount');
        print('✅ [PaymeScreen] user_id: $userId');
        print('✅ [PaymeScreen] payment_status: $paymentStatus');
        developer.log(
          '✅ [PaymeScreen] Payment status check completed',
          name: 'PaymeScreen',
        );
        developer.log(
          '✅ [PaymeScreen] is_paid: $isPaid, order_id: $orderId, amount: $amount, status: $paymentStatus',
          name: 'PaymeScreen',
        );

        // Agar to'lov paid bo'lsa yoki max retries yetib borsa, natijani qaytar
        if (isPaid == true || retryCount >= maxRetries - 1) {
          print(
            '✅ [PaymeScreen] Final result - is_paid: $isPaid, retries: $retryCount',
          );
          developer.log(
            '✅ [PaymeScreen] Final result - is_paid: $isPaid, retries: $retryCount',
            name: 'PaymeScreen',
          );

          // Agar to'lov muvaffaqiyatli bo'lsa, Firestore'da paymentStatus ni yangilash
          if (isPaid == true &&
              widget.rideId != null &&
              widget.rideId!.isNotEmpty) {
            await _updateFirestorePaymentStatus(widget.rideId!);
          }

          ShowToastDialog.closeLoader();
          setState(() {
            _isCheckingPayment = false;
          });

          Get.back(
            result: {
              'success': isPaid,
              'order_id': orderId,
              'amount': amount,
              'user_id': userId,
              'is_paid': isPaid,
              'payment_status': paymentStatus,
            },
          );
        } else {
          // Agar pending bo'lsa va hali retry qoldi bo'lsa, 2 soniyadan keyin qayta tekshir (max 2 marta)
          print(
            '⏳ [PaymeScreen] Payment is still pending, will retry in 2 seconds...',
          );
          print('⏳ [PaymeScreen] Retry count: ${retryCount + 1}/$maxRetries');
          developer.log(
            '⏳ [PaymeScreen] Payment is still pending, will retry in 2 seconds...',
            name: 'PaymeScreen',
          );

          await Future.delayed(const Duration(seconds: 2));

          setState(() {
            _isCheckingPayment = false;
          });

          // Qayta tekshir (loading davom etadi)
          await _checkPaymentStatus(
            retryCount: retryCount + 1,
            maxRetries: maxRetries,
          );
        }
      } else {
        print(
          '❌ [PaymeScreen] Payment status check failed with status: ${response.statusCode}',
        );
        print('❌ [PaymeScreen] Response: ${response.body}');
        developer.log(
          '❌ [PaymeScreen] Payment status check failed with status: ${response.statusCode}',
          name: 'PaymeScreen',
        );
        ShowToastDialog.closeLoader();
        setState(() {
          _isCheckingPayment = false;
        });
        Get.back(result: {'success': false, 'order_id': widget.orderId});
      }
    } catch (e, stackTrace) {
      print('❌ [PaymeScreen] Error checking payment status: $e');
      print('❌ [PaymeScreen] Stack trace: $stackTrace');
      developer.log(
        '❌ [PaymeScreen] Error checking payment status: $e',
        name: 'PaymeScreen',
        error: e,
        stackTrace: stackTrace,
      );
      ShowToastDialog.closeLoader();
      setState(() {
        _isCheckingPayment = false;
      });
      Get.back(result: {'success': false, 'order_id': widget.orderId});
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        print(
          '🔵 [PaymeScreen] WillPopScope triggered - isPaymentCompleted: $_isPaymentCompleted',
        );
        developer.log(
          '🔵 [PaymeScreen] WillPopScope triggered - isPaymentCompleted: $_isPaymentCompleted',
        );
        _showMyDialog();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Payme Payment".tr),
          centerTitle: false,
          leading: GestureDetector(
            onTap: () {
              print(
                '🔵 [PaymeScreen] Back button tapped - isPaymentCompleted: $_isPaymentCompleted',
              );
              developer.log(
                '🔵 [PaymeScreen] Back button tapped - isPaymentCompleted: $_isPaymentCompleted',
              );
              _showMyDialog();
            },
            child: const Icon(Icons.arrow_back),
          ),
        ),
        body: WebViewWidget(controller: controller),
      ),
    );
  }

  // Firestore'da paymentStatus ni yangilash
  Future<void> _updateFirestorePaymentStatus(String rideId) async {
    try {
      print(
        '🔵 [PaymeScreen] Updating Firestore paymentStatus for rideId: $rideId',
      );
      developer.log(
        '🔵 [PaymeScreen] Updating Firestore paymentStatus for rideId: $rideId',
        name: 'PaymeScreen',
      );

      await FireStoreUtils.fireStore
          .collection(CollectionName.rides)
          .doc(rideId)
          .update({'paymentStatus': true});

      print('✅ [PaymeScreen] Firestore paymentStatus updated successfully');
      developer.log(
        '✅ [PaymeScreen] Firestore paymentStatus updated successfully',
        name: 'PaymeScreen',
      );
    } catch (e, stackTrace) {
      print('❌ [PaymeScreen] Error updating Firestore paymentStatus: $e');
      developer.log(
        '❌ [PaymeScreen] Error updating Firestore paymentStatus: $e',
        name: 'PaymeScreen',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _showMyDialog() async {
    print(
      '🔵 [PaymeScreen] _showMyDialog - Showing dialog, isPaymentCompleted: $_isPaymentCompleted',
    );
    developer.log(
      '🔵 [PaymeScreen] _showMyDialog - Showing dialog, isPaymentCompleted: $_isPaymentCompleted',
    );

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Orqaga qaytish'),
          content: SingleChildScrollView(
            child: Text(' Orqaga qaytishni xohlaysizmi? '),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ha'.tr, style: const TextStyle(color: Colors.red)),
              onPressed: () async {
                print(
                  '✅ [PaymeScreen] User confirmed to go back - Checking payment status',
                );
                developer.log(
                  '✅ [PaymeScreen] User confirmed to go back - Checking payment status',
                );
                Navigator.of(context).pop();
                // Check payment status before closing
                await _checkPaymentStatus();
              },
            ),
            TextButton(
              child: Text(
                'Yo\'q'.tr,
                style: const TextStyle(color: Colors.green),
              ),
              onPressed: () {
                print('❌ [PaymeScreen] User cancelled - Staying on screen');
                developer.log(
                  '❌ [PaymeScreen] User cancelled - Staying on screen',
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
