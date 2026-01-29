import 'dart:developer';
import 'package:driver/constant/constant.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymeScreen extends StatefulWidget {
  final String initialURl;

  const PaymeScreen({super.key, required this.initialURl});

  @override
  State<PaymeScreen> createState() => _PaymeScreenState();
}

class _PaymeScreenState extends State<PaymeScreen> {
  WebViewController controller = WebViewController();

  @override
  void initState() {
    log('🔵 [PaymeScreen] initState boshlandi');
    log('🔵 [PaymeScreen] Initial URL: ${widget.initialURl}');
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
              log('✅ [PaymeScreen] Success URL detected, closing with result: true');
              Get.back(result: true);
            }
            if (navigation.url.contains(failureUrl) ||
                navigation.url.contains(pendingUrl)) {
              log('❌ [PaymeScreen] Failure/Pending URL detected, closing with result: false');
              Get.back(result: false);
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialURl));
    log('🔵 [PaymeScreen] WebView controller yaratildi va URL yuklandi');
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
          title: Text('Cancel Payment'.tr),
          content: SingleChildScrollView(child: Text("Cancel Payment?".tr)),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'.tr, style: const TextStyle(color: Colors.red)),
              onPressed: () {
                log('🔵 [PaymeScreen] User to\'lovni bekor qildi');
                Navigator.of(context).pop();
                Get.back(result: false);
              },
            ),
            TextButton(
              child: Text('Continue'.tr, style: const TextStyle(color: Colors.green)),
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

