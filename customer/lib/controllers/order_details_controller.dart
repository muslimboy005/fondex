import 'package:customer/constant/constant.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/order_model.dart';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:customer/service/yandex_geocoding_service.dart';

import '../service/cart_provider.dart';

class OrderDetailsController extends GetxController {
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  Rx<OrderModel> orderModel = OrderModel().obs;

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderModel.value = argumentData['orderModel'];
    }
    calculatePrice();
    await _resolveDeliveryAddress();
    update();
  }

  RxDouble subTotal = 0.0.obs;
  RxDouble specialDiscountAmount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  RxString deliveryAddressTitle = ''.obs;
  RxString deliveryAddressSubtitle = ''.obs;

  double _toDouble(dynamic value) {
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }

  double _lineUnitPrice(CartProductModel element) {
    final inferredSingle = _inferredSingleProductUnitPrice();
    if (inferredSingle != null) return inferredSingle;
    final variantPrice = _toDouble(element.variantInfo?.variantPrice);
    if (variantPrice > 0) return variantPrice;
    final discountPrice = _toDouble(element.discountPrice);
    if (discountPrice > 0) return discountPrice;
    return _toDouble(element.price);
  }

  double lineUnitPrice(CartProductModel element) => _lineUnitPrice(element);

  double lineOriginalUnitPrice(CartProductModel element) {
    final variantPrice = _toDouble(element.variantInfo?.variantPrice);
    if (variantPrice > 0) return variantPrice;
    return _toDouble(element.price);
  }

  bool _isNullish(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty || v.toLowerCase() == 'null';
  }

  Future<void> _resolveDeliveryAddress() async {
    final address = orderModel.value.address;
    final rawTitle = address?.addressAs?.trim();
    final rawSubtitle = address?.getFullAddress().trim();

    deliveryAddressTitle.value = _isNullish(rawTitle)
        ? "Delivery Address".tr
        : rawTitle!;
    deliveryAddressSubtitle.value = _isNullish(rawSubtitle) ? '' : rawSubtitle!;

    final lat = address?.location?.latitude ?? orderModel.value.latitude;
    final lng = address?.location?.longitude ?? orderModel.value.longitude;
    if (_isNullish(deliveryAddressSubtitle.value) && lat != null && lng != null) {
      // Prefer human-readable address from Yandex; show coordinates only if geocoding fails.
      deliveryAddressSubtitle.value = "Address loading...".tr;
      update();
      try {
        final geocoder = YandexGeocodingService(
          apiKey: Constant.yandexGeocodeApiKey,
        );
        final place = await geocoder
            .reverseGeocode(lat, lng)
            .timeout(const Duration(seconds: 12));
        String reverse = place?.formattedAddress.trim() ?? '';
        if (_isNullish(reverse) || reverse == 'Unknown location') {
          reverse = (await geocoder.reverseGeocodeRawText(lat, lng))?.trim() ?? '';
        }
        log(
          '🔵 [OrderDetailsAddress] lat=$lat lng=$lng reverse="$reverse" placeLocality="${place?.locality}"',
        );
        if (!_isNullish(reverse) && reverse != 'Unknown location') {
          deliveryAddressSubtitle.value = reverse;
          if (_isNullish(rawTitle)) {
            deliveryAddressTitle.value =
                (place?.locality ?? place?.subLocality ?? "Delivery Address".tr)
                    .toString();
          }
          update();
        } else {
          deliveryAddressSubtitle.value =
              "${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}";
          update();
        }
      } catch (e, st) {
        log('❌ [OrderDetailsAddress] geocode error: $e\n$st');
        deliveryAddressSubtitle.value =
            "${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}";
        update();
      }
    } else if (_isNullish(deliveryAddressSubtitle.value)) {
      deliveryAddressSubtitle.value = "Address not found".tr;
    }
  }

  double? _inferredSingleProductUnitPrice() {
    final products = orderModel.value.products ?? const <CartProductModel>[];
    if (products.length != 1) return null;
    final qty = _toDouble(products.first.quantity);
    if (qty <= 0) return null;

    final rawTotal = _toDouble(orderModel.value.totalAmount);
    if (rawTotal <= 0) return null;

    final delivery = _toDouble(orderModel.value.deliveryCharge);
    final tip = _toDouble(orderModel.value.tipAmount);
    final inferredSubtotal = rawTotal - delivery - tip;
    if (inferredSubtotal <= 0) return null;
    return inferredSubtotal / qty;
  }

  Future<void> calculatePrice() async {
    subTotal.value = 0.0;
    specialDiscountAmount.value = 0.0;
    taxAmount.value = 0.0;
    totalAmount.value = 0.0;

    for (final element in orderModel.value.products ?? <CartProductModel>[]) {
      final qty = _toDouble(element.quantity);
      final extras = _toDouble(element.extrasPrice);
      subTotal.value =
          subTotal.value + (_lineUnitPrice(element) * qty) + (extras * qty);
    }

    if (orderModel.value.specialDiscount != null && orderModel.value.specialDiscount!['special_discount'] != null) {
      specialDiscountAmount.value = double.parse(orderModel.value.specialDiscount!['special_discount'].toString());
    }

    if (orderModel.value.taxSetting != null) {
      for (var element in orderModel.value.taxSetting!) {
        taxAmount.value = taxAmount.value +
            Constant.calculateTax(amount: (subTotal.value - double.parse(orderModel.value.discount.toString()) - specialDiscountAmount.value).toString(), taxModel: element);
      }
    }

    // Keep total aligned with the rounded values shown in summary rows.
    final roundedSubTotal = Constant.roundUpToNearest500(subTotal.value);
    final roundedDiscount = Constant.roundUpToNearest500(
      _toDouble(orderModel.value.discount),
    );
    final roundedSpecialDiscount = Constant.roundUpToNearest500(
      specialDiscountAmount.value,
    );
    final roundedDelivery = Constant.roundUpToNearest500(
      _toDouble(orderModel.value.deliveryCharge),
    );
    final roundedTip = Constant.roundUpToNearest500(
      _toDouble(orderModel.value.tipAmount),
    );

    totalAmount.value =
        (roundedSubTotal - roundedDiscount - roundedSpecialDiscount) +
        roundedDelivery +
        roundedTip;

    isLoading.value = false;
  }

  final CartProvider cartProvider = CartProvider();

  void addToCart({required CartProductModel cartProductModel}) {
    cartProvider.addToCart(Get.context!, cartProductModel, cartProductModel.quantity!);
    update();
  }
}
