import 'dart:async';
import 'dart:developer';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/themes/custom_dialog_box.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'database_helper.dart';

class CartProvider with ChangeNotifier {
  final _cartStreamController = StreamController<List<CartProductModel>>.broadcast();
  List<CartProductModel> _cartItems = [];

  Stream<List<CartProductModel>> get cartStream => _cartStreamController.stream;

  CartProvider() {
    _initCart();
  }

  Future<void> _initCart() async {
    _cartItems = await DatabaseHelper.instance.fetchCartProducts();
    _cartStreamController.sink.add(_cartItems);
  }

  Future<void> addToCart(BuildContext context, CartProductModel product, int quantity) async {
    log(
      '[cart][CartProvider.add] start productId=${product.id} '
      'vendorId=${product.vendorID} qty=$quantity',
    );
    _cartItems = await DatabaseHelper.instance.fetchCartProducts();
    log(
      '[cart][CartProvider.add] db fetched count=${_cartItems.length}',
    );
    if ((_cartItems.where((item) => item.id == product.id)).isNotEmpty) {
      var index = _cartItems.indexWhere((item) => item.id == product.id);
      log('[cart][CartProvider.add] update existing index=$index');
      final existing = _cartItems[index];
      existing.quantity = quantity;
      existing.price = product.price ?? existing.price;
      existing.discountPrice = product.discountPrice ?? existing.discountPrice;
      if (product.name != null && product.name!.isNotEmpty) {
        existing.name = product.name;
      }
      if (product.photo != null && product.photo!.isNotEmpty) {
        existing.photo = product.photo;
      }
      if (product.categoryId != null && product.categoryId!.isNotEmpty) {
        existing.categoryId = product.categoryId;
      }
      if (product.apiProductId != null) {
        existing.apiProductId = product.apiProductId;
      }
      if (product.variantInfo != null) {
        existing.variantInfo = product.variantInfo;
      }
      if (product.extras != null && product.extras!.isNotEmpty) {
        existing.extras = product.extras;
        existing.extrasPrice = product.extrasPrice;
      } else {
        existing.extras = [];
        existing.extrasPrice = "0";
      }
      await DatabaseHelper.instance.updateCartProduct(existing);
    } else {
      if (_cartItems.isEmpty || _cartItems.where((item) => item.vendorID == product.vendorID).isNotEmpty) {
        log('[cart][CartProvider.add] insert new item');
        product.quantity = quantity;
        _cartItems.add(product);
        cartItem.add(product);
        await DatabaseHelper.instance.insertCartProduct(product);
        log("===> insert");
      } else {
        log(
          '[cart][CartProvider.add] blocked by different vendor. '
          'existingVendor=${_cartItems.first.vendorID} newVendor=${product.vendorID}',
        );
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return CustomDialogBox(
              title: "Alert".tr,
              descriptions: "Your cart already contains items from another restaurant. Would you like to replace them with items from this restaurant instead?".tr,
              positiveString: "Add".tr,
              negativeString: "Cancel".tr,
              positiveClick: () async {
                log('[cart][CartProvider.add] replace cart confirmed');
                cartItem.clear();
                _cartItems.clear();
                DatabaseHelper.instance.deleteAllCartProducts();
                addToCart(context, product, quantity);
                Get.back();
              },
              negativeClick: () {
                log('[cart][CartProvider.add] replace cart cancelled');
                Get.back();
              },
              img: null,
            );
          },
        );
      }
    }
    _initCart();
    log('[cart][CartProvider.add] finish streamCount=${cartItem.length}');
  }

  Future<void> removeFromCart(CartProductModel product, int quantity) async {
    log(
      '[cart][CartProvider.remove] start productId=${product.id} qty=$quantity',
    );
    _cartItems = await DatabaseHelper.instance.fetchCartProducts();
    var index = _cartItems.indexWhere((item) => item.id == product.id);
    log('[cart][CartProvider.remove] foundIndex=$index');
    if (index >= 0) {
      _cartItems[index].quantity = quantity;
      if (_cartItems[index].quantity == 0) {
        log('[cart][CartProvider.remove] delete productId=${product.id}');
        await DatabaseHelper.instance.deleteCartProduct(product.id!);
        _cartItems.removeAt(index);
        cartItem.removeWhere((item) => item.id == product.id);
      } else {
        log('[cart][CartProvider.remove] update qty=${_cartItems[index].quantity}');
        await DatabaseHelper.instance.updateCartProduct(_cartItems[index]);
      }
    }
    _initCart();
    log('[cart][CartProvider.remove] finish streamCount=${cartItem.length}');
  }

  Future<void> clearDatabase() async {
    _cartItems.clear();
    cartItem.clear();
    _cartStreamController.sink.add(_cartItems);
  }
}
