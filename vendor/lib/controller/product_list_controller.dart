import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class ProductListController extends GetxController {
  @override
  void onInit() {
    // TODO: implement onInit
    getUserProfile();
    super.onInit();
  }

  Rx<UserModel> userModel = UserModel().obs;
  RxBool isLoading = true.obs;

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
    await FireStoreUtils.getProduct().then((value) {
      if (value != null && value.isNotEmpty) {
        productList.value = value;
      }
    }).catchError((error) {
      // Handle error if needed
      print('Error loading products: $error');
    });
  }

  Future<void> updateList(int index, bool isPublish) async {
    ProductModel productModel = productList[index];
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
