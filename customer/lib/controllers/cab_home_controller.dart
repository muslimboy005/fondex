import 'package:customer/models/banner_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:get/get.dart';

class CabHomeController extends GetxController {
  RxBool isLoading = true.obs;
  RxBool isInitialLoading = true.obs; // 2 bosqichli loading
  RxList<BannerModel> bannerTopHome = <BannerModel>[].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getData();
    super.onInit();
  }

  // Optimizatsiya qilingan - banner'lar background'da yuklanadi
  Future<void> getData() async {
    // Initial loading tez tugaydi
    isInitialLoading.value = false;
    isLoading.value = false;
    
    // Banner'lar background'da yuklanadi
    FireStoreUtils.getHomeTopBanner().then((value) {
      bannerTopHome.value = value;
    }).catchError((e) {
      print("Error loading banners: $e");
    });
  }
}
