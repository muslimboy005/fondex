import 'package:get/get.dart';
import 'package:vendor/app/Home_screen/home_screen.dart';
import 'package:vendor/app/dine_in_order_screen/dine_in_order_screen.dart';
import 'package:vendor/app/product_screens/product_list_screen.dart';
import 'package:vendor/app/profile_screen/profile_screen.dart';
import 'package:vendor/app/wallet_screen/wallet_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/SectionModel.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class DashBoardController extends GetxController {
  RxBool isLoading = true.obs;
  RxInt selectedIndex = 0.obs;
  RxList pageList = [].obs;
  Rx<VendorModel> vendorModel = VendorModel().obs;
  Rx<SectionModel> sectionModel = SectionModel().obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getVendor();

    super.onInit();
  }

  void setPage() {
    pageList.value = sectionModel.value.dineInActive != null && sectionModel.value.dineInActive == true
        ? [const HomeScreen(), const DineInOrderScreen(), const ProductListScreen(), const WalletScreen(), const ProfileScreen()]
        : [const HomeScreen(), const ProductListScreen(), const WalletScreen(), const ProfileScreen()];
  }

  Future<void> getVendor() async {
    if (Constant.userModel?.vendorID != null) {
      await FireStoreUtils.getVendorById(Constant.userModel!.vendorID.toString()).then((value) async {
        if (value != null) {
          vendorModel.value = value;
          Constant.vendorAdminCommission = value.adminCommission;
          await FireStoreUtils.getSectionById(vendorModel.value.sectionId.toString()).then((value) {
            if (value != null) {
              sectionModel.value = value;
              Constant.selectedSection = sectionModel.value;
            }
          });
        }
      });
    }

    await FireStoreUtils.getSectionById(Constant.userModel!.sectionId.toString()).then((value) {
      if (value != null) {
        sectionModel.value = value;
        Constant.selectedSection = sectionModel.value;
      } else {
        sectionModel.value = SectionModel();
      }
    });
    setPage();
    isLoading.value = false;
  }

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;
}
