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
    pageList.value =
        sectionModel.value.dineInActive != null &&
            sectionModel.value.dineInActive == true
        ? [
            const HomeScreen(),
            const DineInOrderScreen(),
            const ProductListScreen(),
            const WalletScreen(),
            const ProfileScreen(),
          ]
        : [
            const HomeScreen(),
            const ProductListScreen(),
            const WalletScreen(),
            const ProfileScreen(),
          ];

    // Ensure selectedIndex is within valid range after page list changes
    if (selectedIndex.value >= pageList.length) {
      selectedIndex.value = pageList.length - 1;
    }
  }

  Future<void> getVendor() async {
    if (Constant.userModel?.vendorID != null) {
      await FireStoreUtils.getVendorById(
        Constant.userModel!.vendorID.toString(),
      ).then((value) async {
        if (value != null) {
          vendorModel.value = value;
          Constant.vendorAdminCommission = value.adminCommission;
          // Dokon (vendor) mavjud bo'lsa, section har doim VENDOR ning sectionId dan olinadi (dokon turi edit qilinganda ham to'g'ri bo'ladi)
          if (vendorModel.value.sectionId != null &&
              vendorModel.value.sectionId!.isNotEmpty) {
            await FireStoreUtils.getSectionById(
              vendorModel.value.sectionId.toString(),
            ).then((sectionValue) {
              if (sectionValue != null) {
                sectionModel.value = sectionValue;
                Constant.selectedSection = sectionModel.value;
                Constant.userModel!.sectionId = sectionValue.id;
              }
            });
          }
        }
      });
    }

    // Vendor yo'q yoki vendor.sectionId bo'sh bo'lsagina userModel.sectionId dan foydalanamiz (yangi vendor hali saqlanmagan holat)
    final useUserSection = vendorModel.value.sectionId == null ||
        vendorModel.value.sectionId!.isEmpty;
    if (useUserSection &&
        Constant.userModel!.sectionId != null &&
        Constant.userModel!.sectionId!.isNotEmpty) {
      await FireStoreUtils.getSectionById(
        Constant.userModel!.sectionId.toString(),
      ).then((value) {
        if (value != null) {
          sectionModel.value = value;
          Constant.selectedSection = sectionModel.value;
        } else {
          sectionModel.value = SectionModel();
        }
      });
    } else if (useUserSection) {
      sectionModel.value = SectionModel();
    }
    setPage();
    isLoading.value = false;
  }

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;
}
