import 'package:customer/models/section_model.dart';
import 'package:customer/screen_ui/cab_service_screens/cab_dashboard_screen.dart';
import 'package:customer/screen_ui/ecommarce/dash_board_e_commerce_screen.dart';
import 'package:customer/screen_ui/parcel_service/parcel_dashboard_screen.dart';
import 'package:customer/screen_ui/rental_service/rental_dashboard_screen.dart';
import 'package:customer/service/cart_provider.dart';
import 'package:customer/service/database_helper.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/advertisement_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screen_ui/auth_screens/phone_registration_screen.dart';
import '../screen_ui/multi_vendor_service/dash_board_screens/dash_board_screen.dart';
import '../screen_ui/on_demand_service/on_demand_dashboard_screen.dart';
import '../service/notification_service.dart';

class ServiceListController extends GetxController {
  bool _forceUpdateSheetShown = false;
  var isLoading = false.obs;
  var serviceListBanner = <dynamic>[].obs;
  var advertisementList = <AdvertisementModel>[].obs;
  var sectionList = <SectionModel>[].obs;
  var currencyData = CurrencyModel().obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  @override
  void onReady() {
    super.onReady();
    _checkForceUpdateOnHome();
  }

  Future<void> loadData() async {
    isLoading.value = true;

    // fetch currency
    CurrencyModel? currency = await FireStoreUtils.getCurrency();

    currencyData.value =
        currency ??
        CurrencyModel(
          id: "",
          code: "USD",
          decimal: 2,
          isactive: true,
          name: "US Dollar",
          symbol: "\$",
          symbolatright: false,
        );

    // Load sections
    List<SectionModel> sections = await FireStoreUtils.getSections();
    sectionList.assignAll(sections);

    await FireStoreUtils.getSectionBannerList().then((value) {
      serviceListBanner.assignAll(value);
    });

    // Load advertisements
    if (Constant.isEnableAdsFeature == true) {
      List<AdvertisementModel> advertisements =
          await FireStoreUtils.getAllAdvertisement();
      advertisementList.assignAll(advertisements);
    }

    await getZone();
    isLoading.value = false;
  }

  Future<void> getZone() async {
    await FireStoreUtils.getZone().then((value) {
      if (value != null) {
        Constant.zoneList = value;
      }
    });
  }

  Future<void> onServiceTap(
    BuildContext context,
    SectionModel sectionModel,
  ) async {
    try {
      ShowToastDialog.showLoader("Please wait...".tr);
      Constant.sectionConstantModel = sectionModel;
      AppThemeData.primary300 = Color(
        int.tryParse(sectionModel.color?.replaceFirst("#", "0xff") ?? '') ??
            0xff2196F3,
      );
      if (auth.FirebaseAuth.instance.currentUser != null) {
        String uid = auth.FirebaseAuth.instance.currentUser!.uid;
        UserModel? user = await FireStoreUtils.getUserProfile(uid);
        if (user != null && user.role == Constant.userRoleCustomer) {
          user.fcmToken = await NotificationService.getToken();
          await FireStoreUtils.updateUser(user);
          ShowToastDialog.closeLoader();
          await _navigate(sectionModel);
        } else {
          ShowToastDialog.closeLoader();
          Get.offAll(() => const PhoneRegistrationScreen());
        }
      } else {
        ShowToastDialog.closeLoader();
        await _navigate(sectionModel);
      }
    } catch (e) {
      print("Error during service tap: $e");
      ShowToastDialog.closeLoader();
    }
  }

  Future<void> _checkForceUpdateOnHome() async {
    if (_forceUpdateSheetShown) return;
    try {
      final minRequiredVersion =
          await FireStoreUtils.getCustomerMinRequiredVersion();
      if (minRequiredVersion.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      if (_compareVersions(currentVersion, minRequiredVersion) >= 0) {
        return;
      }

      _forceUpdateSheetShown = true;
      _showForceUpdateBottomSheet(minRequiredVersion);
    } catch (e) {
      print('Force update check error: $e');
    }
  }

  int _compareVersions(String current, String minimum) {
    final currentParts =
        RegExp(r'\d+')
            .allMatches(current)
            .map((match) => int.tryParse(match.group(0) ?? '0') ?? 0)
            .toList();
    final minimumParts =
        RegExp(r'\d+')
            .allMatches(minimum)
            .map((match) => int.tryParse(match.group(0) ?? '0') ?? 0)
            .toList();

    final maxLength = currentParts.length > minimumParts.length
        ? currentParts.length
        : minimumParts.length;

    for (int i = 0; i < maxLength; i++) {
      final currentValue = i < currentParts.length ? currentParts[i] : 0;
      final minimumValue = i < minimumParts.length ? minimumParts[i] : 0;
      if (currentValue > minimumValue) return 1;
      if (currentValue < minimumValue) return -1;
    }
    return 0;
  }

  void _showForceUpdateBottomSheet(String minRequiredVersion) {
    if (Get.isBottomSheetOpen == true) return;

    Get.bottomSheet(
      PopScope(
        canPop: false,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New version is available'.tr,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${'Please update the app to continue'.tr} ($minRequiredVersion).',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openStoreForUpdate,
                    child: Text('Update'.tr),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isDismissible: false,
      enableDrag: false,
      barrierColor: Colors.black54,
    );
  }

  Future<void> _openStoreForUpdate() async {
    final String url = GetPlatform.isIOS
        ? Constant.customerAppStoreUrl
        : Constant.customerGooglePlayUrl;

    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      print('Unable to open store url: $url');
    }
  }

  Future<void> _navigate(SectionModel sectionModel) async {
    // Optimizatsiya: getTaxList ni keyinroq yuklash - navigation'dan keyin
    // Bu loading vaqtini kamaytiradi

    // Navigation birinchi bo'lib bajariladi
    if (sectionModel.serviceTypeFlag == "ecommerce-service" ||
        sectionModel.serviceTypeFlag == "delivery-service") {
      if (cartItem.isNotEmpty) {
        showAlertDialog(Get.context!, UserModel(), sectionModel);
      } else {
        if (sectionModel.serviceTypeFlag == "ecommerce-service") {
          Get.to(DashBoardEcommerceScreen());
        } else if (sectionModel.serviceTypeFlag == "cab-service") {
          Get.to(CabDashboardScreen());
          // Tax list ni background'da yuklash
          _loadTaxListInBackground(sectionModel.id ?? "");
        } else if (sectionModel.serviceTypeFlag == "rental-service") {
          Get.to(RentalDashboardScreen());
          _loadTaxListInBackground(sectionModel.id ?? "");
        } else if (sectionModel.serviceTypeFlag == "parcel_delivery") {
          Get.to(ParcelDashboardScreen());
          _loadTaxListInBackground(sectionModel.id ?? "");
        } else if (sectionModel.serviceTypeFlag == "ondemand-service") {
          Get.to(OnDemandDashboardScreen());
        } else {
          Get.to(() => DashBoardScreen());
        }
      }
    } else {
      if (sectionModel.serviceTypeFlag == "ecommerce-service") {
        Get.to(DashBoardEcommerceScreen());
      } else if (sectionModel.serviceTypeFlag == "cab-service") {
        Get.to(CabDashboardScreen());
        // Tax list ni background'da yuklash
        _loadTaxListInBackground(sectionModel.id ?? "");
      } else if (sectionModel.serviceTypeFlag == "rental-service") {
        Get.to(RentalDashboardScreen());
        _loadTaxListInBackground(sectionModel.id ?? "");
      } else if (sectionModel.serviceTypeFlag == "parcel_delivery") {
        Get.to(ParcelDashboardScreen());
        _loadTaxListInBackground(sectionModel.id ?? "");
      } else if (sectionModel.serviceTypeFlag == "ondemand-service") {
        Get.to(OnDemandDashboardScreen());
      } else {
        Get.to(() => DashBoardScreen());
      }
    }
  }

  // Tax list ni background'da yuklash
  Future<void> _loadTaxListInBackground(String sectionId) async {
    if (sectionId.isEmpty) return;

    FireStoreUtils.getTaxList(sectionId)
        .then((value) {
          if (value != null) {
            Constant.taxList = value;
          }
        })
        .catchError((e) {
          print("Error loading tax list: $e");
        });
  }

  final CartProvider cartProvider = CartProvider();

  // Search functionality
  var searchQuery = ''.obs;
  var searchResults = <SectionModel>[].obs;

  void onSearchTextChanged(String text) {
    searchQuery.value = text;
    if (text.isEmpty) {
      searchResults.clear();
      return;
    }

    searchResults.clear();
    final query = text.toLowerCase();

    for (var section in sectionList) {
      if (section.name?.toLowerCase().contains(query) ?? false) {
        searchResults.add(section);
      }
    }
  }

  void showAlertDialog(
    BuildContext context,
    UserModel user,
    SectionModel sectionModel,
  ) {
    Get.defaultDialog(
      title: "Alert!",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "If you select this Section/Service, your previously added items will be removed from the cart."
                .tr,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: RoundedButtonFill(
                  height: 5.5,
                  title: "Cancel".tr,
                  onPress: () {
                    Get.back();
                  },
                  color: AppThemeData.grey900,
                  textColor: AppThemeData.surface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RoundedButtonFill(
                  title: "OK".tr,
                  height: 5.5,
                  onPress: () async {
                    DatabaseHelper.instance.deleteAllCartProducts();
                    cartProvider.clearDatabase();
                    Get.back();
                    if (sectionModel.serviceTypeFlag == "ecommerce-service") {
                      Get.off(() => DashBoardEcommerceScreen());
                    } else {
                      Get.to(() => DashBoardScreen());
                    }
                  },
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.surface,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [], // 👈 keep this empty since we put buttons in content
    );
  }
}
