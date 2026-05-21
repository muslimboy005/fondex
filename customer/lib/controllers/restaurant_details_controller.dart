import 'dart:async';
import 'dart:developer';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/brands_model.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/favourite_item_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/api_products_response.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import '../models/attributes_model.dart';
import '../service/cart_provider.dart';
import '../service/fire_store_utils.dart';
import '../service/vendors_products_repository.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class RestaurantDetailsController extends GetxController {
  Rx<TextEditingController> searchEditingController = TextEditingController().obs;

  RxBool isLoading = true.obs;
  Rx<PageController> pageController = PageController().obs;
  RxInt currentPage = 0.obs;

  Timer? _sliderTimer;
  StreamSubscription<List<CartProductModel>>? _cartSub;

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

  // API pagination: products from storage.fondex.uz
  final VendorsProductsRepository _productsRepo = VendorsProductsRepository();
  String? _nextPageUrl;
  RxBool isLoadingMore = false.obs;
  RxBool hasMoreProducts = true.obs;
  bool _didInitForVendor = false;

  // Track product counts per category from the API
  RxMap<String, int> categoryCounts = <String, int>{}.obs;
  // Track if we have fetched ALL products for a specific category
  RxMap<String, bool> categoryFullyLoaded = <String, bool>{}.obs;
  static const int _kProductsPerCategoryLimit = 5;

  @override
  void onInit() {
    // `ProductDetailScreen` kabi joylarda controller yaratilganda
    // `Get.arguments` bo'lmasligi mumkin; `vendorModel` keyinroq beriladi.
    ever<VendorModel>(vendorModel, (_) {
      unawaited(_initializeForVendorIfNeeded());
    });

    getArgument();
    
    // Add scroll listener to update selected category
    scrollController.addListener(_onScroll);

    super.onInit();
  }

  @override
  void onClose() {
    _sliderTimer?.cancel();
    _sliderTimer = null;
    _cartSub?.cancel();
    _cartSub = null;
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    categoryScrollController.dispose();
    pageController.value.dispose();
    searchEditingController.value.dispose();
    super.onClose();
  }

  void _onScroll() {
    // Don't update if we're programmatically scrolling to a category
    if (_isScrollingToCategory) return;

    // No more global pagination on the main screen as per new requirement
    // only fetch 10 products per category initially.
    /*
    if (hasMoreProducts.value && !isLoadingMore.value && _nextPageUrl != null) {
      final pos = scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 400) {
        loadMoreProducts();
      }
    }
    */
    
    // Find which category section is currently visible
    for (int i = 0; i < vendorCategoryList.length; i++) {
      final category = vendorCategoryList[i];
      final key = categoryKeys[category.id.toString()];
      
      if (key != null && key.currentContext != null) {
        final RenderBox? renderBox = key.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          // Check if this category section is near the top of the screen
          // Use a slightly larger range (0-300) for more stable sticky tab detection
          if (position.dy >= 0 && position.dy <= 300) {
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
    const double tabWidth = 100.0; 
    final double targetPosition = index * tabWidth;
    final double maxScroll = categoryScrollController.position.maxScrollExtent;
    final double viewportWidth = categoryScrollController.position.viewportDimension;
    
    // Calculate the scroll position to center the selected tab
    double scrollTo = targetPosition - (viewportWidth / 2) + (tabWidth / 2);
    scrollTo = scrollTo.clamp(0.0, maxScroll);
    
    categoryScrollController.animateTo(
      scrollTo,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  // Each category section now has a fixed height:
  // Padding (24+16) + Header Text (~26) + Horizontal List (290) = ~356
  static const double _kCategorySectionHeight = 356.0;
  static const double _kScrollContentTopOffset = 400.0;

  /// Scroll offset so category at [categoryIndex] is at the top (below app bar + tabs).
  double getScrollOffsetForCategoryIndex(int categoryIndex) {
    double offset = _kScrollContentTopOffset;
    for (int i = 0; i < categoryIndex && i < vendorCategoryList.length; i++) {
        offset += _kCategorySectionHeight;
    }
    return offset;
  }

  static const Duration _kScrollDuration = Duration(milliseconds: 300);

  // Scroll to category — ensure the section header reaches the top.
  void scrollToCategory(String categoryId) {
    final index = vendorCategoryList.indexWhere((cat) => cat.id.toString() == categoryId);
    if (index == -1) return;

    selectedCategoryIndex.value = index;
    _scrollCategoryTabToVisible(index);

    _isScrollingToCategory = true;

    // Use a single, reliable Scrollable.ensureVisible if the context is available.
    final key = categoryKeys[categoryId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: _kScrollDuration,
        alignment: 0.0, // Align exactly at the top of the viewport
        curve: Curves.easeInOut,
      ).then((_) {
        // Reset flag after animation completes
        Future.delayed(const Duration(milliseconds: 100), () {
          _isScrollingToCategory = false;
        });
      });
    } else {
      // Fallback to calculated offset if context not ready (happens if off-screen in some lists)
      final offset = getScrollOffsetForCategoryIndex(index);
      if (scrollController.hasClients) {
        final maxExtent = scrollController.position.maxScrollExtent;
        scrollController.animateTo(
          offset.clamp(0.0, maxExtent),
          duration: _kScrollDuration,
          curve: Curves.easeInOut,
        ).then((_) {
          _isScrollingToCategory = false;
        });
      } else {
        _isScrollingToCategory = false;
      }
    }
  }

  void animateSlider() {
    _sliderTimer?.cancel();
    final photos = vendorModel.value.photos;
    if (photos == null || photos.isEmpty) return;

    _sliderTimer = Timer.periodic(const Duration(seconds: 2), (Timer timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      final len = vendorModel.value.photos?.length ?? 0;
      if (len <= 1) return;

      if (currentPage.value < len - 1) {
        currentPage.value++;
      } else {
        currentPage.value = 0;
      }

      final pc = pageController.value;
      if (!pc.hasClients) return;
      if (pc.positions.length != 1) return;
      pc.animateToPage(
        currentPage.value,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    });
  }

  Rx<VendorModel> vendorModel = VendorModel().obs;

  final CartProvider cartProvider = CartProvider();

  Future<void> _initializeForVendorIfNeeded() async {
    if (_didInitForVendor) return;
    final vendorId = vendorModel.value.id?.trim();
    if (vendorId == null || vendorId.isEmpty) return;

    _didInitForVendor = true;
    animateSlider();
    statusCheck();

    await getProduct();
    isLoading.value = false;
    await getFavouriteList();
    update();
  }

  Future<void> getArgument() async {
    await _cartSub?.cancel();
    _cartSub = cartProvider.cartStream.listen((event) {
      cartItem.clear();
      cartItem.addAll(event);
    });
    dynamic argumentData = Get.arguments;
    log('[RestaurantDetails] getArgument: argumentData origin=${argumentData?.runtimeType}');
    if (argumentData is Map) {
      final passed = argumentData['vendorModel'];
      if (passed is VendorModel) {
        vendorModel.value = passed;
        log('[RestaurantDetails] getArgument: vendorModel from map id=${vendorModel.value.id} title=${vendorModel.value.title}');
      }
    } else if (argumentData is VendorModel) {
      vendorModel.value = argumentData;
      log('[RestaurantDetails] getArgument: vendorModel directly id=${vendorModel.value.id} title=${vendorModel.value.title}');
    }

    // Agar `vendorModel` keyinroq berilsa (`ProductDetailScreen`), init
    // `ever(vendorModel, ...)` orqali avtomatik ishlaydi.
    await _initializeForVendorIfNeeded();
  }

  RxList<BrandsModel> brandList = <BrandsModel>[].obs;

  Future<void> getProduct() async {
    vendorCategoryList.clear();
    categoryKeys.clear();
    _nextPageUrl = null;
    hasMoreProducts.value = false; // Disable global pagination for main screen
    categoryFullyLoaded.clear();
    categoryCounts.clear();

    final vendorIdStr = vendorModel.value.id?.toString() ?? '';
    final sectionIdStr =
        vendorModel.value.sectionId?.toString() ??
            Constant.sectionConstantModel?.id?.toString() ??
            '';
    if (vendorIdStr.isEmpty) {
      allProductList.value = [];
      productList.value = [];
      return;
    }

    try {
      isLoading.value = true;
      update();

      final limitedItems = await _fetchLimitedProductsPerCategory(
        vendorId: vendorIdStr,
        sectionId: sectionIdStr.isNotEmpty ? sectionIdStr : null,
        limitPerCategory: _kProductsPerCategoryLimit,
      );
      await _applyProductsAndCategories(limitedItems);
    } catch (e) {
      log('getProduct error: $e');
      await _getProductFromFirestore();
    } finally {
      isLoading.value = false;
      update();
    }
  }

  Future<List<ProductModel>> _fetchLimitedProductsPerCategory({
    required String vendorId,
    String? sectionId,
    required int limitPerCategory,
  }) async {
    final perCategoryCounter = <String, int>{};
    final limitedItems = <ProductModel>[];

    ApiProductsResponse? response = await _productsRepo.getProducts(
      vendorId: vendorId,
      sectionId: sectionId,
    );

    int pageSafety = 0;
    while (response != null && response.status && pageSafety < 30) {
      final pageItems = response.data.results
          .map((e) => VendorsProductsRepository.toProductModel(e))
          .toList();
      for (final item in pageItems) {
        final catId = item.categoryID?.toString() ?? '';
        if (catId.isEmpty) continue;
        final current = perCategoryCounter[catId] ?? 0;
        if (current >= limitPerCategory) continue;
        perCategoryCounter[catId] = current + 1;
        limitedItems.add(item);
      }

      // APIdagi umumiy count'ni category bo'yicha kuzatib boramiz
      for (var apiItem in response.data.results) {
        final catId = apiItem.category.toString();
        final current = categoryCounts[catId] ?? 0;
        categoryCounts[catId] = current + 1;
      }

      final nextUrl = response.data.next;
      if (nextUrl == null || nextUrl.isEmpty) break;
      response = await _productsRepo.getProductsNextPage(nextUrl);
      pageSafety++;
    }

    for (final entry in perCategoryCounter.entries) {
      categoryFullyLoaded[entry.key] = entry.value >= limitPerCategory;
    }

    _nextPageUrl = null;
    hasMoreProducts.value = false;
    return limitedItems;
  }

  Future<void> _getProductFromFirestore() async {
    final vendorId = vendorModel.value.id?.toString() ?? '';
    if (vendorId.isEmpty) return;
    log('[RestaurantDetails] _getProductFromFirestore: vendorId=$vendorId');
    final value = await FireStoreUtils.getProductByVendorId(vendorId);
    _nextPageUrl = null;
    hasMoreProducts.value = false;
    await _applyProductsAndCategories(value);
  }

  Future<void> _applyProductsAndCategories(List<ProductModel> newItems, {int? totalCount, String? specificCategoryId, bool isAppend = false}) async {
    // 1. Maintain category state if provided
    if (specificCategoryId != null && totalCount != null) {
      log('[RestaurantDetails] Updating category state for $specificCategoryId: count=$totalCount');
      categoryCounts[specificCategoryId] = totalCount;
    }

    // 2. Resolve Subscription Limit
    int limit = -1;
    if ((Constant.isSubscriptionModelApplied == true || vendorModel.value.adminCommission?.isEnabled == true) && vendorModel.value.subscriptionPlan != null) {
      if (vendorModel.value.subscriptionPlan?.itemLimit != '-1') {
        limit = int.tryParse(vendorModel.value.subscriptionPlan?.itemLimit ?? '0') ?? 0;
      }
    }

    List<ProductModel> filteredNewItems = newItems;
    if (limit != -1) {
      final currentTotal = (isAppend || specificCategoryId != null) ? allProductList.length : 0;
      if (currentTotal >= limit) {
        log('[RestaurantDetails] Subscription limit reached: $limit. Skipping new items.');
        hasMoreProducts.value = false;
        if (!isAppend && specificCategoryId == null) {
          allProductList.clear();
          productList.clear();
        }
        return;
      }
      if (currentTotal + newItems.length > limit) {
        log('[RestaurantDetails] Partial subscription limit reached. Taking only ${limit - currentTotal} more.');
        filteredNewItems = newItems.sublist(0, limit - currentTotal);
        hasMoreProducts.value = false;
      }
    }

    // 3. Update main lists safely (NEVER set .value = self)
    if (specificCategoryId != null) {
      // Targeted category fetch: merge skipping duplicates
      final existingIds = productList.map((p) => p.id).toSet();
      final uniqueNewItems = filteredNewItems.where((p) => !existingIds.contains(p.id)).toList();
      log('[RestaurantDetails] Merging category $specificCategoryId: uniqueItemsToAdd=${uniqueNewItems.length}');
      productList.addAll(uniqueNewItems);
      allProductList.addAll(uniqueNewItems);
      
      // Update fully loaded status
      final catProductsCount = productList.where((p) => p.categoryID == specificCategoryId).length;
      if (catProductsCount >= (totalCount ?? 0)) {
        categoryFullyLoaded[specificCategoryId] = true;
      }
    } else if (isAppend) {
      // Global loadMore: simple add
      log('[RestaurantDetails] Appending global products: count=${filteredNewItems.length}');
      productList.addAll(filteredNewItems);
      allProductList.addAll(filteredNewItems);
    } else {
      // Initial load or replacement: assignAll
      log('[RestaurantDetails] Initial/Replacement load: count=${filteredNewItems.length}');
      productList.assignAll(filteredNewItems);
      allProductList.assignAll(filteredNewItems);
    }

    // 4. Extract all unique category IDs from the current results
    final uniqueCategoryIds = productList.map((p) => p.categoryID?.toString() ?? '').where((id) => id.isNotEmpty).toSet().toList();

    // 5. Fetch missing category models from Firestore
    final List<VendorCategoryModel?> categoryResults = await Future.wait(
      uniqueCategoryIds.map((id) => FireStoreUtils.getVendorCategoryById(id)),
    );

    // 6. Build the final category list
    final List<VendorCategoryModel> finalCategoryList = [];
    final knownCategoryIds = <String>{};

    for (var cat in categoryResults) {
      if (cat != null && cat.id != null) {
        finalCategoryList.add(cat);
        knownCategoryIds.add(cat.id.toString());
      }
    }

    // 7. Handle products that don't match any known category
    final hasUncategorized = productList.any((p) => !knownCategoryIds.contains(p.categoryID.toString()));
    if (hasUncategorized) {
      finalCategoryList.add(VendorCategoryModel(id: uncategorizedCategoryId, title: 'Other'.tr, description: ''));
    }

    // 8. Update category list observable
    final seen = <String>{};
    vendorCategoryList.assignAll(finalCategoryList.where((element) => seen.add(element.id.toString())).toList());

    // 9. Ensure every category has a GlobalKey
    for (var category in vendorCategoryList) {
      if (!categoryKeys.containsKey(category.id.toString())) {
        categoryKeys[category.id.toString()] = GlobalKey();
      }
    }

    log('[RestaurantDetails] _applyProductsAndCategories: done. products=${productList.length} categories=${vendorCategoryList.length}');
    update();
  }

  /// Load next page of products from API (pagination).
  Future<void> loadMoreProducts() async {
    if (_nextPageUrl == null || _nextPageUrl!.isEmpty || isLoadingMore.value) return;
    log('[RestaurantDetails] loadMoreProducts: pageUrl=$_nextPageUrl');
    isLoadingMore.value = true;
    update();
    try {
      final response = await _productsRepo.getProductsNextPage(_nextPageUrl);
      if (response == null || !response.status) {
        hasMoreProducts.value = false;
        return;
      }
      _nextPageUrl = response.data.next;
      hasMoreProducts.value = _nextPageUrl != null && _nextPageUrl!.isNotEmpty;
      final newItems = response.data.results
          .map((e) => VendorsProductsRepository.toProductModel(e))
          .toList();
      if (newItems.isEmpty) return;

      // Use centralized method to handle mapping, merging and category resolution
      await _applyProductsAndCategories(newItems, totalCount: response.data.count, isAppend: true);
    } finally {
      isLoadingMore.value = false;
      update();
    }
  }

  /// Fetches products specifically for a single category to ensure it's fully populated.
  Future<void> fetchCategoryProducts(String categoryId) async {
    // Skip if already fully loaded, or if it's the "Other" category (which isn't in API)
    if (categoryId == uncategorizedCategoryId || categoryFullyLoaded[categoryId] == true || isLoadingMore.value) return;

    final vendorIdStr = vendorModel.value.id?.toString() ?? '';
    final sectionIdStr = vendorModel.value.sectionId?.toString() ?? Constant.sectionConstantModel?.id?.toString() ?? '';
    
    log('[RestaurantDetails] fetchCategoryProducts: starting for category=$categoryId');
    isLoadingMore.value = true;
    update();
    
    try {
      ApiProductsResponse? response;
      try {
        // Ba'zi environmentlarda Firestore category ID bilan filter 404 beradi.
        response = await _productsRepo.getProducts(
          vendorId: vendorIdStr,
          sectionId: sectionIdStr,
          category: categoryId,
        );
      } catch (e) {
        log(
          '[RestaurantDetails] fetchCategoryProducts direct category request failed, fallback to vendor request: $e',
        );
      }

      if (response == null || !response.status) {
        response = await _productsRepo.getProducts(
          vendorId: vendorIdStr,
          sectionId: sectionIdStr,
        );
      }

      if (response.status) {
        final List<ProductModel> newItems = response.data.results
            .map((e) => VendorsProductsRepository.toProductModel(e))
            .where((e) => (e.categoryID?.toString() ?? '') == categoryId)
            .toList();

        await _applyProductsAndCategories(
          newItems,
          totalCount: newItems.length,
          specificCategoryId: categoryId,
        );
      }
    } catch (e) {
      log('[RestaurantDetails] fetchCategoryProducts error: $e');
    } finally {
      isLoadingMore.value = false;
      update();
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
    log(
      '[cart][RestaurantDetailsController] start '
      'isIncrement=$isIncrement '
      'productId=${productModel.id} vendorId=${vendorModel.value.id} '
      'qty=$quantity price=$price disPrice=$discountPrice '
      'variantId=${variantInfo?.variantId} variantSku=${variantInfo?.variantSku} '
      'selectedAddOns=${selectedAddOns.join(",")}',
    );
    CartProductModel cartProductModel = CartProductModel();

    String adOnsPrice = "0";
    final addOnPrices = productModel.addOnsPrice ?? const <dynamic>[];
    final addOnTitles = productModel.addOnsTitle ?? const <dynamic>[];
    final addOnCount = addOnPrices.length < addOnTitles.length
        ? addOnPrices.length
        : addOnTitles.length;
    for (int i = 0; i < addOnCount; i++) {
      if (selectedAddOns.contains(addOnTitles[i]) == true && addOnPrices[i] != '0') {
        adOnsPrice = (double.parse(adOnsPrice.toString()) + double.parse(Constant.productCommissionPrice(vendorModel.value, addOnPrices[i].toString()))).toString();
      }
    }

    if (variantInfo != null) {
      cartProductModel.id = "${productModel.id ?? ''}~${variantInfo.variantId.toString()}";
      cartProductModel.apiProductId = productModel.apiId;
      cartProductModel.name = productModel.name ?? '';
      cartProductModel.photo = productModel.photo ?? '';
      cartProductModel.categoryId = productModel.categoryID ?? '';
      cartProductModel.price = price;
      cartProductModel.discountPrice = discountPrice;
      cartProductModel.vendorID = vendorModel.value.id;
      cartProductModel.quantity = quantity;
      cartProductModel.variantInfo = variantInfo;
      cartProductModel.extrasPrice = adOnsPrice;
      cartProductModel.extras = selectedAddOns.isEmpty ? [] : selectedAddOns;
    } else {
      cartProductModel.id = productModel.id ?? '';
      cartProductModel.apiProductId = productModel.apiId;
      cartProductModel.name = productModel.name ?? '';
      cartProductModel.photo = productModel.photo ?? '';
      cartProductModel.categoryId = productModel.categoryID ?? '';
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
    log(
      '[cart][RestaurantDetailsController] done '
      'cartProductId=${cartProductModel.id} apiProductId=${cartProductModel.apiProductId} '
      'finalQty=${cartProductModel.quantity} '
      'extras=${cartProductModel.extras?.length ?? 0}',
    );
    log("===> new ${cartItem.length}");
    update();
  }
}
