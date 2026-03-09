import 'package:customer/constant/constant.dart';
import '../screen_ui/multi_vendor_service/favourite_screens/favourite_screen.dart';
import '../screen_ui/multi_vendor_service/home_screen/home_screen.dart';
import '../screen_ui/multi_vendor_service/home_screen/home_screen_two.dart';
import '../screen_ui/multi_vendor_service/order_list_screen/order_screen.dart';
import '../screen_ui/multi_vendor_service/profile_screen/profile_screen.dart';
import '../screen_ui/multi_vendor_service/cart_screen/cart_screen.dart';
import '../service/fire_store_utils.dart';
import 'package:get/get.dart';

class DashBoardController extends GetxController {
  RxInt selectedIndex = 0.obs;

  RxList pageList = [].obs;

  @override
  void onInit() {
    getTaxList();
    if (Constant.sectionConstantModel!.theme == "theme_2") {
      if (Constant.walletSetting == false) {
        pageList.value = [const HomeScreen(), const FavouriteScreen(), const OrderScreen(), const ProfileScreen()];
      } else {
        pageList.value = [const HomeScreen(), const FavouriteScreen(), const CartScreen(showBackButton: false), const OrderScreen(), const ProfileScreen()];
      }
    } else {
      if (Constant.walletSetting == false) {
        pageList.value = [const HomeScreenTwo(), const FavouriteScreen(), const OrderScreen(), const ProfileScreen()];
      } else {
        pageList.value = [const HomeScreenTwo(), const FavouriteScreen(), const CartScreen(showBackButton: false), const OrderScreen(), const ProfileScreen()];
      }
    }
    final tab = Get.arguments?['tab'];
    if (tab == 'orders') {
      selectedIndex.value = Constant.walletSetting == true ? 3 : 2;
    }
    super.onInit();
  }

  Future<void> getTaxList() async {
    await FireStoreUtils.getTaxList(Constant.sectionConstantModel!.id).then((value) {
      if (value != null) {
        Constant.taxList = value;
      }
    });
  }

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;
}
