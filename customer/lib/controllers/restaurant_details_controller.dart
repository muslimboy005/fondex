import 'dart:async';
import 'dart:developer';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/brands_model.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/favourite_item_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import '../models/attributes_model.dart';
import '../service/cart_provider.dart';
import '../service/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class RestaurantDetailsController extends GetxController {
  Rx<TextEditingController> searchEditingController = TextEditingController().obs;

  RxBool isLoading = true.obs;
  Rx<PageController> pageController = PageController().obs;
  RxInt currentPage = 0.obs;

  RxBool isVag = false.obs;
  RxBool isNonVag = false.obs;
  RxBool isMenuOpen = false.obs;

  RxList<FavouriteModel> favouriteList = <FavouriteModel>[].obs;
  RxList<FavouriteItemModel> favouriteItemList = <FavouriteItemModel>[].obs;
  RxList<ProductModel> allProductList = <ProductModel>[].obs;
  RxList<ProductModel> productList = <ProductModel>[].obs;
  RxList<VendorCategoryModel> vendorCategoryList = <VendorCategoryModel>[].obs;

  RxList<CouponModel> couponList = <CouponModel>[].obs;

  // Scroll controller for products list
  ScrollController scrollController = ScrollController();
  
  // Scroll controller for horizontal category list
  ScrollController categoryScrollController = ScrollController();
  
  // Selected category index
  RxInt selectedCategoryIndex = 0.obs;
  
  // Map to store GlobalKeys for each category section
  Map<String, GlobalKey> categoryKeys = {};
  
  // Flag to prevent scroll listener from firing during programmatic scroll
  bool _isScrollingToCategory = false;

  @override
  void onInit() {
    getArgument();
    
    // Add scroll listener to update selected category
    scrollController.addListener(_onScroll);

    super.onInit();
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    categoryScrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    // Don't update if we're programmatically scrolling to a category
    if (_isScrollingToCategory) return;
    
    // Find which category section is currently visible
    for (int i = 0; i < vendorCategoryList.length; i++) {
      final category = vendorCategoryList[i];
      final key = categoryKeys[category.id.toString()];
      
      if (key != null && key.currentContext != null) {
        final RenderBox? renderBox = key.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          // Check if this category section is near the top of the screen (with some offset for the pinned header)
          if (position.dy >= 0 && position.dy <= 250) {
            if (selectedCategoryIndex.value != i) {
              selectedCategoryIndex.value = i;
              _scrollCategoryTabToVisible(i);
            }
            break;
          }
        }
      }
    }
  }
  
  // Auto-scroll the horizontal category tab list to show the selected category
  void _scrollCategoryTabToVisible(int index) {
    if (!categoryScrollController.hasClients) return;
    
    // Approximate width of each category tab (padding + text)
    const double tabWidth = 120.0;
    final double targetPosition = index * tabWidth;
    final double maxScroll = categoryScrollController.position.maxScrollExtent;
    final double viewportWidth = categoryScrollController.position.viewportDimension;
    
    // Calculate the scroll position to center the selected tab
    double scrollTo = targetPosition - (viewportWidth / 2) + (tabWidth / 2);
    scrollTo = scrollTo.clamp(0.0, maxScroll);
    
    categoryScrollController.animateTo(
      scrollTo,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Heights used by lazy product list (must match restaurant_details_screen.dart).
  static const double _kCategoryHeaderHeight = 65.0;
  static const double _kProductRowHeight = 292.0; // card 280 + padding 12
  /// SliverAppBar + category tabs — katta qurilmalarda ham kategoriya tepada chiqishi uchun.
  static const double _kScrollContentTopOffset = 400.0;

  int _getProductCountForCategory(VendorCategoryModel cat) {
    if (cat.id == uncategorizedCategoryId) {
      return productList
          .where((p0) => !vendorCategoryList.any((c) =>
              c.id != uncategorizedCategoryId && c.id == p0.categoryID))
          .length;
    }
    return productList.where((p0) => p0.categoryID == cat.id).length;
  }

  /// Scroll offset so category at [categoryIndex] is at the top (below app bar + tabs).
  double getScrollOffsetForCategoryIndex(int categoryIndex) {
    double offset = _kScrollContentTopOffset;
    for (int i = 0; i < categoryIndex && i < vendorCategoryList.length; i++) {
      final cat = vendorCategoryList[i];
      final count = _getProductCountForCategory(cat);
      if (count == 0) continue;
      offset += _kCategoryHeaderHeight;
      offset += ((count + 1) ~/ 2) * _kProductRowHeight;
    }
    return offset;
  }

  static const Duration _kScrollDuration = Duration(milliseconds: 300);

  void _performScrollToCategory(int index) {
    if (!scrollController.hasClients) return;
    _isScrollingToCategory = true;
    final offset = getScrollOffsetForCategoryIndex(index);
    final maxExtent = scrollController.position.maxScrollExtent;
    scrollController.animateTo(
      offset.clamp(0.0, maxExtent),
      duration: _kScrollDuration,
      curve: Curves.easeInOut,
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 50), () {
        _isScrollingToCategory = false;
      });
    });
  }

  // Scroll to category — sarlavha tepada. Layout tayyor bo‘lgach scroll; ko‘p mahsulotda qayta scroll.
  void scrollToCategory(String categoryId) {
    final index = vendorCategoryList.indexWhere((cat) => cat.id.toString() == categoryId);
    if (index == -1) return;

    selectedCategoryIndex.value = index;
    _scrollCategoryTabToVisible(index);

    final hasManyProducts = productList.length >= 80;

    // 1) Keyingi frame + qisqa kechikish — layout va lazy list tayyor bo‘lsin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        _performScrollToCategory(index);
        // 2) Ko‘p mahsulotli ekranda (270 ta): list to‘liq build bo‘lgach yana bir marta scroll.
        if (hasManyProducts) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (scrollController.hasClients) {
              _performScrollToCategory(index);
            }
          });
        }
      });
    });
  }

  void animateSlider() {
    if (vendorModel.value.photos != null && vendorModel.value.photos!.isNotEmpty) {
      Timer.periodic(const Duration(seconds: 2), (Timer timer) {
        if (currentPage < vendorModel.value.photos!.length - 1) {
          currentPage++;
        } else {
          currentPage.value = 0;
        }

        if (pageController.value.hasClients) {
          pageController.value.animateToPage(currentPage.value, duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
        }
      });
    }
  }

  Rx<VendorModel> vendorModel = VendorModel().obs;

  final CartProvider cartProvider = CartProvider();

  Future<void> getArgument() async {
    cartProvider.cartStream.listen((event) async {
      cartItem.clear();
      cartItem.addAll(event);
    });
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      vendorModel.value = argumentData['vendorModel'];
    }
    animateSlider();
    statusCheck();

    await getProduct();

    isLoading.value = false;
    await getFavouriteList();

    update();
  }

  RxList<BrandsModel> brandList = <BrandsModel>[].obs;

  Future<void> getProduct() async {
    vendorCategoryList.clear();
    categoryKeys.clear();
    final vendorId = vendorModel.value.id?.toString() ?? '';
    if (vendorId.isEmpty) {
      log('getProduct: vendorModel.id is null, cannot load products');
      allProductList.value = [];
      productList.value = [];
      return;
    }
    final value = await FireStoreUtils.getProductByVendorId(vendorId);
    if ((Constant.isSubscriptionModelApplied == true || vendorModel.value.adminCommission?.isEnabled == true) && vendorModel.value.subscriptionPlan != null) {
      if (vendorModel.value.subscriptionPlan?.itemLimit == '-1') {
        allProductList.value = value;
        productList.value = value;
      } else {
        int selectedProduct =
            value.length < int.parse(vendorModel.value.subscriptionPlan?.itemLimit ?? '0') ? (value.isEmpty ? 0 : (value.length)) : int.parse(vendorModel.value.subscriptionPlan?.itemLimit ?? '0');
        allProductList.value = value.sublist(0, selectedProduct);
        productList.value = value.sublist(0, selectedProduct);
      }
    } else {
      allProductList.value = value;
      productList.value = value;
    }

    // Unique kategoriya IDlari — 148 ta alohida so‘rov o‘rniga bir marta parallel yuklash (tezroq)
    final uniqueCategoryIds = productList.map((p) => p.categoryID?.toString() ?? '').where((id) => id.isNotEmpty).toSet().toList();
    final categoryFutures = uniqueCategoryIds.map((id) => FireStoreUtils.getVendorCategoryById(id));
    final results = await Future.wait([
      Future.wait(categoryFutures),
      FireStoreUtils.getBrandList(),
    ]);
    final categoryResults = results[0] as List<VendorCategoryModel?>;
    brandList.value = results[1] as List<BrandsModel>;
    final knownCategoryIds = <String>{};
    for (var cat in categoryResults) {
      if (cat != null) {
        vendorCategoryList.add(cat);
        knownCategoryIds.add(cat.id.toString());
      }
    }

    final hasUncategorized = productList.any((p) => !knownCategoryIds.contains(p.categoryID.toString()));
    if (hasUncategorized) {
      vendorCategoryList.add(VendorCategoryModel(id: uncategorizedCategoryId, title: 'Other', description: ''));
    }

    var seen = <String>{};
    vendorCategoryList.value = vendorCategoryList.where((element) => seen.add(element.id.toString())).toList();

    // Initialize category keys
    for (var category in vendorCategoryList) {
      if (!categoryKeys.containsKey(category.id.toString())) {
        categoryKeys[category.id.toString()] = GlobalKey();
      }
    }
  }

  static const String uncategorizedCategoryId = '__uncategorized__';

  void searchProduct(String name) {
    if (name.isEmpty) {
      productList.clear();
      productList.addAll(allProductList);
    } else {
      isVag.value = false;
      isNonVag.value = false;
      productList.value = allProductList.where((p0) => p0.name!.toLowerCase().contains(name.toLowerCase())).toList();
    }
    update();
  }

  void filterRecord() {
    if (isVag.value == true && isNonVag.value == true) {
      productList.value = allProductList.where((p0) => p0.nonveg == true || p0.nonveg == false).toList();
    } else if (isVag.value == true && isNonVag.value == false) {
      productList.value = allProductList.where((p0) => p0.nonveg == false).toList();
    } else if (isVag.value == false && isNonVag.value == true) {
      productList.value = allProductList.where((p0) => p0.nonveg == true).toList();
    } else if (isVag.value == false && isNonVag.value == false) {
      productList.value = allProductList.where((p0) => p0.nonveg == true || p0.nonveg == false).toList();
    }
  }

  Future<List<ProductModel>> getProductByCategory(VendorCategoryModel vendorCategoryModel) async {
    return productList.where((p0) => p0.categoryID == vendorCategoryModel.id).toList();
  }

  Future<void> getFavouriteList() async {
    if (Constant.userModel != null) {
      await FireStoreUtils.getFavouriteRestaurant().then((value) {
        favouriteList.value = value;
      });

      await FireStoreUtils.getFavouriteItem().then((value) {
        favouriteItemList.value = value;
      });

      await FireStoreUtils.getOfferByVendorId(vendorModel.value.id.toString()).then((value) {
        couponList.value = value;
      });
    }
    await getAttributeData();
    update();
  }

  RxBool isOpen = false.obs;

  void statusCheck() {
    final now = DateTime.now();
    var day = DateFormat('EEEE', 'en_US').format(now);
    var date = DateFormat('dd-MM-yyyy').format(now);
    for (var element in vendorModel.value.workingHours ?? []) {
      if (day == element.day.toString()) {
        if (element.timeslot!.isNotEmpty) {
          for (var element in element.timeslot!) {
            var start = DateFormat("dd-MM-yyyy HH:mm").parse("$date ${element.from}");
            var end = DateFormat("dd-MM-yyyy HH:mm").parse("$date ${element.to}");
            if (isCurrentDateInRange(start, end)) {
              isOpen.value = true;
            }
          }
        }
      }
    }
  }

  String getBrandName(String brandId) {
    String brandName = '';
    for (var element in brandList) {
      if (element.id == brandId) {
        brandName = element.title ?? '';
      }
    }
    return brandName;
  }

  bool isCurrentDateInRange(DateTime startDate, DateTime endDate) {
    print(startDate);
    print(endDate);
    final currentDate = DateTime.now();
    print(currentDate);
    return currentDate.isAfter(startDate) && currentDate.isBefore(endDate);
  }

  RxList<AttributesModel> attributesList = <AttributesModel>[].obs;
  RxList selectedVariants = [].obs;
  RxList selectedIndexVariants = [].obs;
  RxList selectedIndexArray = [].obs;

  RxList selectedAddOns = [].obs;

  RxInt quantity = 1.obs;

  String calculatePrice(ProductModel productModel) {
    String mainPrice = "0";
    String variantPrice = "0";
    String adOnsPrice = "0";

    if (productModel.itemAttribute != null) {
      if (productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).isNotEmpty) {
        variantPrice = Constant.productCommissionPrice(
          vendorModel.value,
          productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).first.variantPrice ?? '0',
        );
      }
    } else {
      String price = Constant.productCommissionPrice(vendorModel.value, productModel.price.toString());
      String disPrice = double.parse(productModel.disPrice.toString()) <= 0 ? "0" : Constant.productCommissionPrice(vendorModel.value, productModel.disPrice.toString());
      if (double.parse(disPrice) <= 0) {
        variantPrice = price;
      } else {
        variantPrice = disPrice;
      }
    }

    for (int i = 0; i < productModel.addOnsPrice!.length; i++) {
      if (selectedAddOns.contains(productModel.addOnsTitle![i]) == true) {
        adOnsPrice = (double.parse(adOnsPrice.toString()) + double.parse(Constant.productCommissionPrice(vendorModel.value, productModel.addOnsPrice![i].toString()))).toString();
      }
    }
    adOnsPrice = (quantity.value * double.parse(adOnsPrice)).toString();
    mainPrice = ((double.parse(variantPrice.toString()) * double.parse(quantity.value.toString())) + double.parse(adOnsPrice.toString())).toString();
    return mainPrice;
  }

  Future<void> getAttributeData() async {
    await FireStoreUtils.getAttributes().then((value) {
      if (value != null) {
        attributesList.value = value;
      }
    });
  }

  Future<void> addToCart({required ProductModel productModel, required String price, required String discountPrice, required bool isIncrement, required int quantity, VariantInfo? variantInfo}) async {
    CartProductModel cartProductModel = CartProductModel();

    String adOnsPrice = "0";
    for (int i = 0; i < productModel.addOnsPrice!.length; i++) {
      if (selectedAddOns.contains(productModel.addOnsTitle![i]) == true && productModel.addOnsPrice![i] != '0') {
        adOnsPrice = (double.parse(adOnsPrice.toString()) + double.parse(Constant.productCommissionPrice(vendorModel.value, productModel.addOnsPrice![i].toString()))).toString();
      }
    }

    if (variantInfo != null) {
      cartProductModel.id = "${productModel.id!}~${variantInfo.variantId.toString()}";
      cartProductModel.name = productModel.name!;
      cartProductModel.photo = productModel.photo!;
      cartProductModel.categoryId = productModel.categoryID!;
      cartProductModel.price = price;
      cartProductModel.discountPrice = discountPrice;
      cartProductModel.vendorID = vendorModel.value.id;
      cartProductModel.quantity = quantity;
      cartProductModel.variantInfo = variantInfo;
      cartProductModel.extrasPrice = adOnsPrice;
      cartProductModel.extras = selectedAddOns.isEmpty ? [] : selectedAddOns;
    } else {
      cartProductModel.id = productModel.id!;
      cartProductModel.name = productModel.name!;
      cartProductModel.photo = productModel.photo!;
      cartProductModel.categoryId = productModel.categoryID!;
      cartProductModel.price = price;
      cartProductModel.discountPrice = discountPrice;
      cartProductModel.vendorID = vendorModel.value.id;
      cartProductModel.quantity = quantity;
      cartProductModel.variantInfo = VariantInfo();
      cartProductModel.extrasPrice = adOnsPrice;
      cartProductModel.extras = selectedAddOns.isEmpty ? [] : selectedAddOns;
    }

    if (isIncrement) {
      await cartProvider.addToCart(Get.context!, cartProductModel, quantity);
    } else {
      await cartProvider.removeFromCart(cartProductModel, quantity);
    }
    log("===> new ${cartItem.length}");
    update();
  }
}
