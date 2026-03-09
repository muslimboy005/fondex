import 'dart:developer';
import 'package:driver/app/splash_screen.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/car_makes.dart';
import 'package:driver/models/car_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VehicleInformationController extends GetxController {
  Rx<TextEditingController> carPlatNumberEditingController = TextEditingController().obs;

  Rx<UserModel> userModel = UserModel().obs;

  RxList<String> service = ['Delivery Service', 'Cab Service'].obs;
  RxString selectedService = ''.obs;
  RxString selectedValue = 'ride'.obs;

  RxList<SectionModel> sectionList = <SectionModel>[].obs;
  Rx<SectionModel> selectedSection = SectionModel().obs;

  RxList<VehicleType> cabVehicleType = <VehicleType>[].obs;
  Rx<VehicleType> selectedVehicleType = VehicleType().obs;

  RxList<CarMakes> carMakesList = <CarMakes>[].obs;
  Rx<CarMakes> selectedCarMakes = CarMakes().obs;

  RxList<CarModel> carModelList = <CarModel>[].obs;
  Rx<CarModel> selectedCarModel = CarModel().obs;

  RxBool isLoading = false.obs;

  /// Bitta instance – dropdown value ro‘yxatdagi element bilan bir xil bo‘lishi kerak
  late final VehicleType placeholderVehicleType;
  late final CarMakes placeholderCarMakes;
  late final CarModel placeholderCarModel;

  bool get isPlaceholderVehicleType =>
      selectedVehicleType.value.id == null ||
      selectedVehicleType.value.id.toString().isEmpty;

  bool get isPlaceholderCarMakes =>
      selectedCarMakes.value.id == null ||
      selectedCarMakes.value.id.toString().isEmpty;
  bool get isPlaceholderCarModel =>
      selectedCarModel.value.id == null ||
      selectedCarModel.value.id.toString().isEmpty;

  @override
  void onInit() {
    super.onInit();
    placeholderVehicleType = VehicleType(id: null, name: 'Select Vehicle Type'.tr);
    placeholderCarMakes = CarMakes(id: '', name: 'Select Car Brand'.tr, isActive: true);
    placeholderCarModel = CarModel(id: null, name: 'Select car model'.tr, isActive: true);
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      isLoading.value = true;

      UserModel? model = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
      if (model != null) {
        userModel.value = model;
        carPlatNumberEditingController.value.text = userModel.value.carNumber ?? '';

        selectedService.value = getReadableServiceType(userModel.value.serviceType!);
        if (!service.contains(selectedService.value)) {
          selectedService.value = 'Delivery Service';
        }
        selectedValue.value = userModel.value.rideType ?? 'ride';

        await getSection();

        if (userModel.value.sectionId != null && sectionList.isNotEmpty) {
          selectedSection.value = sectionList.firstWhere(
            (e) => e.id == userModel.value.sectionId,
            orElse: () => sectionList.first,
          );
        }

        await getVehicleType(selectedSection.value.id.toString());

        if (userModel.value.vehicleId != null &&
            userModel.value.vehicleId!.toString().trim().isNotEmpty &&
            cabVehicleType.isNotEmpty) {
          final matchList = cabVehicleType
              .where((e) => e.id != null && e.id == userModel.value.vehicleId)
              .toList();
          if (matchList.isNotEmpty) {
            selectedVehicleType.value = matchList.first;
          } else {
            selectedVehicleType.value = placeholderVehicleType;
          }
        } else {
          selectedVehicleType.value = placeholderVehicleType;
        }

        if (selectedService.value == "Cab Service") {
          await getCarMakesForCab();
          if (userModel.value.carMakes != null && carMakesList.isNotEmpty) {
            final list = carMakesList.where((e) =>
                (e.id != null && e.id.toString().isNotEmpty) &&
                e.name == userModel.value.carMakes).toList();
            if (list.isNotEmpty) selectedCarMakes.value = list.first;
          }
          await getCarModel();
          if (userModel.value.carName != null && carModelList.isNotEmpty) {
            final list = carModelList.where((e) =>
                (e.id != null && e.id.toString().isNotEmpty) &&
                e.name == userModel.value.carName).toList();
            if (list.isNotEmpty) selectedCarModel.value = list.first;
          }
        } else if (selectedService.value == "Rental Service") {
          await getCarMakes();
          if (userModel.value.carMakes != null && carMakesList.isNotEmpty) {
            selectedCarMakes.value = carMakesList.firstWhere(
              (e) => e.name == userModel.value.carMakes,
              orElse: () => carMakesList.first,
            );
          }
          await getCarModel();
          if (userModel.value.carName != null && carModelList.isNotEmpty) {
            final list = carModelList.where((e) =>
                (e.id != null && e.id.toString().isNotEmpty) &&
                e.name == userModel.value.carName).toList();
            if (list.isNotEmpty) selectedCarModel.value = list.first;
          }
        }
      }
    } finally {
      isLoading.value = false;
      update();
    }
  }

  /// Splash va boshqalarda tekshirish uchun bitta format (defis)
  static String _normalizeServiceType(String? s) {
    if (s == null || s.isEmpty) return '';
    return s.replaceAll('_', '-');
  }

  Future<void> saveVehicleInformation() async {
    if (userModel.value.isOwner == true) {
      ShowToastDialog.showToast("Update not allowed for Owner type users.".tr);
      return;
    }

    final bool isDelivery = selectedService.value == 'Delivery Service';

    if (!isDelivery) {
      if (carPlatNumberEditingController.value.text.trim().isEmpty) {
        ShowToastDialog.showToast("Please enter car plate number".tr);
        return;
      }
      if (isPlaceholderVehicleType) {
        ShowToastDialog.showToast("Please select a vehicle type".tr);
        return;
      }
      if (isPlaceholderCarMakes) {
        ShowToastDialog.showToast("Please select a car brand".tr);
        return;
      }
      if (isPlaceholderCarModel) {
        ShowToastDialog.showToast("Please select a car model".tr);
        return;
      }
    }

    ShowToastDialog.showLoader("Updating vehicle information...".tr);

    try {
      final String newServiceType = getServiceTypeKey(selectedService.value);
      final String? oldServiceType = userModel.value.serviceType;

      userModel.value.serviceType = newServiceType;
      userModel.value.sectionId = selectedSection.value.id;

      if (!isDelivery) {
        userModel.value.carNumber = carPlatNumberEditingController.value.text.trim();
        userModel.value.vehicleType = selectedVehicleType.value.name;
        userModel.value.vehicleId = selectedVehicleType.value.id;
        userModel.value.carMakes = selectedCarMakes.value.name;
        userModel.value.carName = selectedCarModel.value.name;
        userModel.value.rideType = selectedValue.value;
      }
      // Delivery ga o'tganda avtomobil ma'lumotlarini null qilmaymiz – mavjud qiymatlar saqlanadi

      bool success = await FireStoreUtils.updateUser(userModel.value);

      ShowToastDialog.closeLoader();

      if (success) {
        ShowToastDialog.showToast("Vehicle information updated successfully.".tr);
        final String oldNorm = _normalizeServiceType(oldServiceType);
        final String newNorm = _normalizeServiceType(newServiceType);
        if (oldNorm != newNorm) {
          Get.offAll(() => const SplashScreen());
        }
      } else {
        ShowToastDialog.showToast("Failed to update. Please try again.".tr);
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("${'Error updating vehicle info'.tr}: $e");
      log("Error updating vehicle info: $e");
    }
  }

  Future<void> getSection() async {
    try {
      String key = getServiceTypeKey(selectedService.value);
      final value = await FireStoreUtils.getSections(key);
      sectionList.value = value;
      if (sectionList.isNotEmpty) {
        selectedSection.value = sectionList.first;
      }
    } catch (e) {
      log("Error loading sections: $e");
    }
  }

  /// Xizmat turi o'zgarganda: section va transport ma'lumotlarini qayta yuklash
  Future<void> onServiceTypeChanged() async {
    await getSection();
    if (sectionList.isEmpty) return;
    selectedSection.value = sectionList.first;
    await getVehicleType(selectedSection.value.id.toString());
    update();
  }

  Future<void> getVehicleType(String sectionId) async {
    try {
      if (selectedService.value == "Cab Service") {
        cabVehicleType.value = await FireStoreUtils.getCabVehicleType(sectionId);
      } else if (selectedService.value == "Rental Service") {
        cabVehicleType.value = await FireStoreUtils.getRentalVehicleType(sectionId);
      } else {
        cabVehicleType.value = [placeholderVehicleType];
        selectedVehicleType.value = placeholderVehicleType;
        carMakesList.value = [placeholderCarMakes];
        selectedCarMakes.value = placeholderCarMakes;
        carModelList.value = [placeholderCarModel];
        selectedCarModel.value = placeholderCarModel;
        update();
        return;
      }
      final list = cabVehicleType.toList();
      cabVehicleType.assignAll([placeholderVehicleType, ...list]);
      selectedVehicleType.value = placeholderVehicleType;
      if (selectedService.value == "Cab Service") {
        await getCarMakesForCab();
        await getCarModel();
      }
    } catch (e) {
      log("Error loading vehicle types: $e");
    }
  }

  /// Cab: transport turi tanlanganda shu turga tegishli markalarni yuklash (default tanlanmasin)
  Future<void> getCarMakesForCab() async {
    try {
      final vehicleTypeId = selectedVehicleType.value.id?.toString() ?? '';
      if (vehicleTypeId.isEmpty) {
        carMakesList.value = [placeholderCarMakes];
        selectedCarMakes.value = placeholderCarMakes;
        carModelList.value = [placeholderCarModel];
        selectedCarModel.value = placeholderCarModel;
        update();
        return;
      }
      final list = await FireStoreUtils.getCarMakesByVehicleTypeId(vehicleTypeId);
      carMakesList.value = [placeholderCarMakes, ...list];
      selectedCarMakes.value = placeholderCarMakes;
      carModelList.value = [placeholderCarModel];
      selectedCarModel.value = placeholderCarModel;
      update();
    } catch (e) {
      log("Error loading car makes for cab: $e");
    }
  }

  Future<void> getCarMakes() async {
    try {
      carMakesList.value = await FireStoreUtils.getCarMakes();
      if (carMakesList.isNotEmpty) selectedCarMakes.value = carMakesList.first;
    } catch (e) {
      log("Error loading car makes: $e");
    }
  }

  Future<void> getCarModel() async {
    try {
      if (isPlaceholderCarMakes) {
        carModelList.value = [placeholderCarModel];
        selectedCarModel.value = placeholderCarModel;
        update();
        return;
      }

      if (selectedService.value == "Cab Service") {
        final vehicleTypeId = selectedVehicleType.value.id?.toString() ?? '';
        final carMakeId = selectedCarMakes.value.id?.toString() ?? '';
        if (vehicleTypeId.isEmpty || carMakeId.isEmpty) {
          carModelList.value = [placeholderCarModel];
          selectedCarModel.value = placeholderCarModel;
          update();
          return;
        }
        final list = await FireStoreUtils.getCarModelsByVehicleTypeAndMake(
          vehicleTypeId,
          carMakeId,
        );
        carModelList.value = [placeholderCarModel, ...list];
        selectedCarModel.value = placeholderCarModel;
      } else {
        final list = await FireStoreUtils.getCarModel(selectedCarMakes.value.name!);
        carModelList.value = list.isNotEmpty
            ? [placeholderCarModel, ...list]
            : [placeholderCarModel];
        selectedCarModel.value = placeholderCarModel;
      }
      update();
    } catch (e) {
      log("Error loading car models: $e");
    }
  }

  String getReadableServiceType(String key) {
    switch (key) {
      case 'cab-service':
      case 'cab_service':
        return 'Cab Service';
      case 'parcel_delivery':
        return 'Parcel Service';
      case 'rental-service':
      case 'rental_service':
        return 'Rental Service';
      case 'delivery-service':
      case 'delivery_service':
      default:
        return 'Delivery Service';
    }
  }

  /// Firestore va boshqalarda doim defis formatida: delivery-service, cab-service
  String getServiceTypeKey(String name) {
    switch (name) {
      case 'Cab Service':
        return 'cab-service';
      case 'Parcel Service':
        return 'parcel_delivery';
      case 'Rental Service':
        return 'rental-service';
      default:
        return 'delivery-service';
    }
  }
}
