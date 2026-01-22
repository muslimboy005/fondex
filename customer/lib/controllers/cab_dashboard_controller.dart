import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/cab_service_screens/cab_home_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/profile_screen/profile_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:get/get.dart';
import '../screen_ui/cab_service_screens/my_cab_booking_screen.dart';

class CabDashboardController extends GetxController {
  RxInt selectedIndex = 0.obs;

  RxList pageList = [].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    // Optimizatsiya: getTaxList ni keyinroq yuklash - UI tez ko'rinadi
    if (Constant.walletSetting == false) {
      pageList.value = [CabHomeScreen(), const MyCabBookingScreen(), const ProfileScreen()];
    } else {
      pageList.value = [CabHomeScreen(), const MyCabBookingScreen(), const WalletScreen(), const ProfileScreen()];
    }
    super.onInit();
    
    // Tax list ni background'da yuklash
    _loadTaxListInBackground();
  }

  // Tax list ni background'da yuklash
  Future<void> _loadTaxListInBackground() async {
    if (Constant.sectionConstantModel?.id == null) return;
    
    // Kichik kechikish - UI birinchi ko'rinadi
    await Future.delayed(const Duration(milliseconds: 100));
    
    FireStoreUtils.getTaxList(Constant.sectionConstantModel!.id).then((value) {
      if (value != null) {
        Constant.taxList = value;
      }
    }).catchError((e) {
      print("Error loading tax list: $e");
    });
  }

  // Eski metod - backward compatibility uchun
  Future<void> getTaxList() async {
    await _loadTaxListInBackground();
  }
}
