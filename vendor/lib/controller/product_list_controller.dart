import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/service/vendors_products_api_service.dart';
import 'package:vendor/utils/api_talker.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class ProductListController extends GetxController {
  @override
  void onInit() {
    getUserProfile();
    super.onInit();
  }

  Rx<UserModel> userModel = UserModel().obs;
  RxBool isLoading = true.obs;
  RxBool isLoadingMore = false.obs;
  RxBool hasMoreProducts = false.obs;
  String? _nextPageUrl;

  Future<void> getUserProfile() async {
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value != null) {
        Constant.userModel = value;
        userModel.value = value;
      }
    });
    await getProduct();
    isLoading.value = false;
  }

  RxList<ProductModel> productList = <ProductModel>[].obs;

  Future<void> getProduct() async {
    try {
      _nextPageUrl = null;
      hasMoreProducts.value = false;
      isLoadingMore.value = false;

      final vendorDocId = Constant.userModel?.vendorID?.trim();
      if (vendorDocId == null || vendorDocId.isEmpty) {
        apiTalker.warning(
          '[API] Products list skipped: user.vendorID (Firestore) bo‘sh.',
        );
        productList.value = [];
        return;
      }

      final response =
          await VendorsProductsApiService.fetchVendorProductsFirstPage(
        vendorFirestoreId: vendorDocId,
      );
      productList.value = VendorsProductsApiService.toProductModels(response);
      _nextPageUrl = response.data.next;
      hasMoreProducts.value =
          _nextPageUrl != null && _nextPageUrl!.isNotEmpty;
    } catch (e) {
      apiTalker.warning('Error loading products (API): $e');
      productList.value = [];
      _nextPageUrl = null;
      hasMoreProducts.value = false;
    }
  }

  Future<void> loadMoreProducts() async {
    if (isLoadingMore.value) return;
    if (!hasMoreProducts.value) return;
    if (_nextPageUrl == null || _nextPageUrl!.isEmpty) return;
    isLoadingMore.value = true;
    try {
      final response =
          await VendorsProductsApiService.fetchVendorProductsNextPage(
        _nextPageUrl,
      );
      if (response == null) {
        hasMoreProducts.value = false;
        _nextPageUrl = null;
        return;
      }
      productList.addAll(
        VendorsProductsApiService.toProductModels(response),
      );
      _nextPageUrl = response.data.next;
      hasMoreProducts.value =
          _nextPageUrl != null && _nextPageUrl!.isNotEmpty;
    } catch (e) {
      apiTalker.warning('Error loading more products (API): $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> updateList(int index, bool isPublish) async {
    final productModel = productList[index];
    final newPublish = isPublish ? false : true;

    final apiId = int.tryParse(productModel.id ?? '');
    if (apiId != null) {
      // vendor/category/section endi API'dan string ko'rinishida keladi.
      final vendorId = (productModel.vendorID ?? '').trim();
      final categoryId = (productModel.categoryID ?? '').trim();
      final sectionId = (productModel.sectionId ?? '').trim();
      if (vendorId.isEmpty || categoryId.isEmpty || sectionId.isEmpty) {
        ShowToastDialog.showToast("Mahsulot ma'lumotlari to'liq emas.".tr);
        return;
      }
      ShowToastDialog.showLoader("Please wait..".tr);
      final err = await VendorsProductsApiService.updateProductMultipart(
        id: apiId,
        vendor: vendorId,
        category: categoryId,
        section: sectionId,
        name: productModel.name ?? '',
        description: productModel.description ?? '',
        price: productModel.price ?? '0',
        discountPrice: (productModel.disPrice == null ||
                productModel.disPrice!.isEmpty)
            ? '0.00'
            : productModel.disPrice!,
        quantity: productModel.quantity ?? 0,
        isPublish: newPublish,
      );
      ShowToastDialog.closeLoader();
      if (err != null) {
        ShowToastDialog.showToast(err);
        return;
      }
      productModel.publish = newPublish;
      productList.removeAt(index);
      productList.insert(index, productModel);
      update();
      return;
    }

    if (isPublish == true) {
      productModel.publish = false;
    } else {
      productModel.publish = true;
    }
    productList.removeAt(index);
    productList.insert(index, productModel);
    update();
    await FireStoreUtils.setProduct(productModel);
  }
}
