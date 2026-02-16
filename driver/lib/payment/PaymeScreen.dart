import 'dart:developer';
import 'dart:convert';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

class PaymeScreen extends StatefulWidget {
  final String initialURl;
  final int? orderId;

  const PaymeScreen({super.key, required this.initialURl, this.orderId});

  @override
  State<PaymeScreen> createState() => _PaymeScreenState();
}

class _PaymeScreenState extends State<PaymeScreen> {
  WebViewController controller = WebViewController();
  bool _isPaymentCompleted = false;
  bool _isCheckingPayment = false;

  @override
  void initState() {
    log('🔵 [PaymeScreen] initState boshlandi');
    log('🔵 [PaymeScreen] Initial URL: ${widget.initialURl}');
    log('🔵 [PaymeScreen] Order ID: ${widget.orderId}');
    initController();
    super.initState();
    log('🔵 [PaymeScreen] initState tugadi');
  }

  void initController() {
    log('🔵 [PaymeScreen] initController boshlandi');
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            log('🔵 [PaymeScreen] Loading progress: $progress%');
          },
          onPageStarted: (String url) {
            log('🔵 [PaymeScreen] Page started loading: $url');
          },
          onWebResourceError: (WebResourceError error) {
            log('❌ [PaymeScreen] Web resource error: ${error.description}');
            log('❌ [PaymeScreen] Error code: ${error.errorCode}, URL: ${error.url}');
          },
          onNavigationRequest: (NavigationRequest navigation) async {
            log('🔵 [PaymeScreen] Navigation request: ${navigation.url}');
            debugPrint("Payme URL: ${navigation.url}");

            String successUrl = "${Constant.globalUrl}payment/success";
            String failureUrl = "${Constant.globalUrl}payment/failure";
            String pendingUrl = "${Constant.globalUrl}payment/pending";

            if (navigation.url.contains(successUrl)) {
              log('✅ [PaymeScreen] Success URL detected, checking payment status...');
              setState(() {
                _isPaymentCompleted = true;
              });
              await _checkPaymentStatus();
              return NavigationDecision.prevent;
            }
            if (navigation.url.contains(failureUrl) ||
                navigation.url.contains(pendingUrl)) {
              log('❌ [PaymeScreen] Failure/Pending URL detected, closing with result: false');
              Get.back(result: {'success': false, 'order_id': widget.orderId});
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialURl));
    log('🔵 [PaymeScreen] WebView controller yaratildi va URL yuklandi');
  }

  Future<void> _checkPaymentStatus({
    int retryCount = 0,
    int maxRetries = 2,
  }) async {
    if (_isCheckingPayment) {
      log('⚠️ [PaymeScreen] Payment status check already in progress');
      return;
    }

    setState(() {
      _isCheckingPayment = true;
    });
    ShowToastDialog.showLoader("To'lov holati tekshirilmoqda...".tr);

    log('🔵 [PaymeScreen] _checkPaymentStatus - Starting check for orderId: ${widget.orderId}, retry: $retryCount/$maxRetries');

    if (widget.orderId == null) {
      log('❌ [PaymeScreen] orderId is null, cannot check payment status');
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

      log('🔵 [PaymeScreen] Sending payment status check request (attempt ${retryCount + 1})');
      log('🔵 [PaymeScreen] URL: $url');
      log('🔵 [PaymeScreen] Body: $body');

      final response = await http.post(url, headers: headers, body: body);

      log('🔵 [PaymeScreen] Payment status response received');
      log('🔵 [PaymeScreen] Status Code: ${response.statusCode}');
      log('🔵 [PaymeScreen] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isPaid = data['is_paid'] ?? false;
        final orderId = data['order_id'];
        final amount = data['amount'];
        final userId = data['user_id'];
        final paymentStatus = data['payment_status'] ?? '';

        log('✅ [PaymeScreen] Payment status check completed');
        log('✅ [PaymeScreen] is_paid: $isPaid');
        log('✅ [PaymeScreen] order_id: $orderId');
        log('✅ [PaymeScreen] amount: $amount');
        log('✅ [PaymeScreen] user_id: $userId');
        log('✅ [PaymeScreen] payment_status: $paymentStatus');

        // Agar to'lov paid bo'lsa yoki max retries yetib borsa, natijani qaytar
        if (isPaid == true || retryCount >= maxRetries - 1) {
          log('✅ [PaymeScreen] Final result - is_paid: $isPaid, retries: $retryCount');

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
          // Agar pending bo'lsa va hali retry qoldi bo'lsa, 2 soniyadan keyin qayta tekshir
          log('⏳ [PaymeScreen] Payment is still pending, will retry in 2 seconds...');
          log('⏳ [PaymeScreen] Retry count: ${retryCount + 1}/$maxRetries');

          await Future.delayed(const Duration(seconds: 2));

          setState(() {
            _isCheckingPayment = false;
          });

          // Qayta tekshir
          await _checkPaymentStatus(
            retryCount: retryCount + 1,
            maxRetries: maxRetries,
          );
        }
      } else {
        log('❌ [PaymeScreen] Payment status check failed with status: ${response.statusCode}');
        log('❌ [PaymeScreen] Response: ${response.body}');
        ShowToastDialog.closeLoader();
        setState(() {
          _isCheckingPayment = false;
        });
        Get.back(result: {'success': false, 'order_id': widget.orderId});
      }
    } catch (e, stackTrace) {
      log('❌ [PaymeScreen] Error checking payment status: $e');
      log('❌ [PaymeScreen] Stack trace: $stackTrace');
      ShowToastDialog.closeLoader();
      setState(() {
        _isCheckingPayment = false;
      });
      Get.back(result: {'success': false, 'order_id': widget.orderId});
    }
  }

  @override
  Widget build(BuildContext context) {
    log('🔵 [PaymeScreen] build chaqirildi');
    return WillPopScope(
      onWillPop: () async {
        log('🔵 [PaymeScreen] WillPopScope - back button bosildi');
        _showMyDialog();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Payme Payment".tr),
          centerTitle: false,
          leading: GestureDetector(
            onTap: () {
              _showMyDialog();
            },
            child: const Icon(Icons.arrow_back),
          ),
        ),
        body: WebViewWidget(controller: controller),
      ),
    );
  }

  Future<void> _showMyDialog() async {
    log('🔵 [PaymeScreen] _showMyDialog chaqirildi');
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Orqaga qaytish'),
          content: SingleChildScrollView(
              child: Text("Orqaga qaytishni xohlaysizmi?")),
          actions: <Widget>[
            TextButton(
              child: Text('Ha'.tr, style: const TextStyle(color: Colors.red)),
              onPressed: () async {
                log('🔵 [PaymeScreen] User to\'lovni bekor qildi - tekshirilmoqda');
                Navigator.of(context).pop();
                // Check payment status before closing
                await _checkPaymentStatus();
              },
            ),
            TextButton(
              child:
                  Text('Yo\'q'.tr, style: const TextStyle(color: Colors.green)),
              onPressed: () {
                log('🔵 [PaymeScreen] User to\'lovni davom ettirdi');
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
