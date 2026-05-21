import 'dart:developer';

import 'package:customer/constant/constant.dart';
import 'package:get/get.dart';

import '../models/api_products_response.dart';
import '../models/product_model.dart';
import '../service/vendors_products_repository.dart';

class CategoryProductListController extends GetxController {
  final VendorsProductsRepository _productsRepo = VendorsProductsRepository();

  var isLoading = true.obs;
  var isLoadingMore = false.obs;
  var productList = <ProductModel>[].obs;
  var hasMoreProducts = true.obs;
  var totalCount = 0.obs;

  String _vendorId = '';
  String _categoryId = '';
  String _sectionId = '';
  String? _nextPageUrl;

  /// Backend ba'zida `category` query bilan 404 qaytaradi — unda vendor+section
  /// dan olib, kategoriya bo'yicha lokal filtrlash ishlatiladi.
  bool _clientSideCategoryFilter = false;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null) {
      _vendorId = (args['vendorId'] ?? '').toString().trim();
      _categoryId = (args['categoryId'] ?? '').toString().trim();
      _sectionId = (args['sectionId'] ?? '').toString().trim();
      if (_sectionId.isEmpty) {
        _sectionId =
            Constant.sectionConstantModel?.id?.toString().trim() ?? '';
      }
      getProducts(isInitial: true);
    }
  }

  List<ProductModel> _filterByCategory(List<ProductModel> items) {
    if (_categoryId.isEmpty) return items;
    return items
        .where((p) => (p.categoryID?.toString() ?? '') == _categoryId)
        .toList();
  }

  Future<void> getProducts({bool isInitial = false}) async {
    if (isInitial) {
      isLoading.value = true;
      _nextPageUrl = null;
      _clientSideCategoryFilter = false;
      productList.clear();
    } else {
      if (isLoadingMore.value || !hasMoreProducts.value || _nextPageUrl == null) {
        return;
      }
      isLoadingMore.value = true;
    }
    update();

    try {
      ApiProductsResponse? response;

      if (isInitial) {
        try {
          response = await _productsRepo.getProducts(
            vendorId: _vendorId,
            sectionId: _sectionId.isNotEmpty ? _sectionId : null,
            category: _categoryId.isNotEmpty ? _categoryId : null,
          );
        } catch (e) {
          if (_categoryId.isEmpty) rethrow;
          log(
            'CategoryProductListController: filtered request failed, '
            'using vendor+section + local category filter: $e',
          );
          _clientSideCategoryFilter = true;
          response = await _productsRepo.getProducts(
            vendorId: _vendorId,
            sectionId: _sectionId.isNotEmpty ? _sectionId : null,
          );
        }
      } else {
        response = await _productsRepo.getProductsNextPage(_nextPageUrl);
      }

      if (response != null && response.status) {
        var newItems = response.data.results
            .map((e) => VendorsProductsRepository.toProductModel(e))
            .toList();

        if (_clientSideCategoryFilter) {
          newItems = _filterByCategory(newItems);
        }

        if (isInitial) {
          productList.assignAll(newItems);
        } else {
          productList.addAll(newItems);
        }

        totalCount.value = _clientSideCategoryFilter
            ? productList.length
            : response.data.count;
        _nextPageUrl = response.data.next;
        hasMoreProducts.value =
            _nextPageUrl != null && _nextPageUrl!.isNotEmpty;
      } else if (!isInitial) {
        hasMoreProducts.value = false;
      }
    } catch (e) {
      log('CategoryProductListController Error: $e');
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
      update();
    }
  }
}
