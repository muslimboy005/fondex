import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/preferences.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';

import '../themes/theme_controller.dart';

class CabDashBoardController extends GetxController {
  RxInt drawerIndex = 0.obs;

  @override
  void onInit() {
    // TODO: implement onInit

    getUser();
    getTheme();
    super.onInit();
  }

  Rx<UserModel> userModel = UserModel().obs;

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;

  Future<void> getUser() async {
    final uid = FireStoreUtils.getCurrentUidOrNull();
    if (uid == null || uid.isEmpty) {
      return;
    }
    await updateCurrentLocation();
    FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid).snapshots().listen(
      (event) async {
        if (event.exists) {
          userModel.value = UserModel.fromJson(event.data()!);
          Constant.userModel = UserModel.fromJson(event.data()!);
          if (userModel.value.sectionId != null && userModel.value.sectionId!.isNotEmpty) {
            await FireStoreUtils.getSectionBySectionId(userModel.value.sectionId!).then((sectionValue) {
              if (sectionValue != null) {
                Constant.sectionModel = sectionValue;
              }
            });
          }
        }
      },
    );
  }

  RxString isDarkMode = "Light".obs;
  RxBool isDarkModeSwitch = false.obs;

  void getTheme() {
    bool isDark = Preferences.getBoolean(Preferences.themKey);
    isDarkMode.value = isDark ? "Dark" : "Light";
    isDarkModeSwitch.value = isDark;
  }

  void toggleDarkMode(bool value) {
    isDarkModeSwitch.value = value;
    isDarkMode.value = value ? "Dark" : "Light";
    Preferences.setBoolean(Preferences.themKey, value);
    // Update ThemeController for instant app theme change
    if (Get.isRegistered<ThemeController>()) {
      final themeController = Get.find<ThemeController>();
      themeController.isDark.value = value;
    }
  }

  Location location = Location();

  Future<void> updateCurrentLocation() async {
    final uid = FireStoreUtils.getCurrentUidOrNull();
    if (uid == null || uid.isEmpty) {
      return;
    }
    try {
      PermissionStatus permissionStatus = await location.hasPermission();
      if (permissionStatus == PermissionStatus.granted) {
        location.enableBackgroundMode(enable: true);
        location.changeSettings(accuracy: LocationAccuracy.high, distanceFilter: double.parse(Constant.driverLocationUpdate));

        location.onLocationChanged.listen((locationData) async {
          final currentUid = FireStoreUtils.getCurrentUidOrNull();
          if (currentUid == null || currentUid.isEmpty) {
            return;
          }
          Constant.locationDataFinal = locationData;
          await FireStoreUtils.getUserProfile(currentUid).then((value) async {
            if (value != null) {
              userModel.value = value;
              if (userModel.value.isActive == true) {
                userModel.value.location = UserLocation(latitude: locationData.latitude ?? 0.0, longitude: locationData.longitude ?? 0.0);
                userModel.value.rotation = locationData.heading;
                await FireStoreUtils.updateUser(userModel.value);
              }
            }
          });
        });
      } else {
        location.requestPermission().then((permissionStatus) {
          if (permissionStatus == PermissionStatus.granted) {
            location.enableBackgroundMode(enable: true);
            location.changeSettings(accuracy: LocationAccuracy.high, distanceFilter: double.parse(Constant.driverLocationUpdate));
            location.onLocationChanged.listen((locationData) async {
              final currentUid = FireStoreUtils.getCurrentUidOrNull();
              if (currentUid == null || currentUid.isEmpty) {
                return;
              }
              Constant.locationDataFinal = locationData;
              await FireStoreUtils.getUserProfile(currentUid).then((value) async {
                if (value != null) {
                  userModel.value = value;
                  if (userModel.value.isActive == true) {
                    userModel.value.location =
                        UserLocation(latitude: locationData.latitude ?? 0.0, longitude: locationData.longitude ?? 0.0);
                    userModel.value.rotation = locationData.heading;
                    await FireStoreUtils.updateUser(userModel.value);
                  }
                  ShowToastDialog.closeLoader();
                }
              });
            });
          } else {
            ShowToastDialog.closeLoader();
          }
        });
      }
    } catch (e) {
      print(e);
    }
  }
}
