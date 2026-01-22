import 'dart:developer';
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

  RxList<String> service = ['Delivery Service', 'Cab Service', 'Parcel Service', 'Rental Service'].obs;
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

  @override
  void onInit() {
    super.onInit();
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

        selectedValue.value = userModel.value.rideType ?? 'ride';
        await getSection();
        await getCarMakes();

        if (userModel.value.sectionId != null) {
          selectedSection.value = sectionList.firstWhere(
            (e) => e.id == userModel.value.sectionId,
            orElse: () => sectionList.first,
          );
        }

        await getVehicleType(selectedSection.value.id.toString());

        if (userModel.value.vehicleId != null) {
          selectedVehicleType.value = cabVehicleType.firstWhere(
            (e) => e.id == userModel.value.vehicleId,
            orElse: () => cabVehicleType.first,
          );
        }

        if (userModel.value.carMakes != null) {
          selectedCarMakes.value = carMakesList.firstWhere(
            (e) => e.name == userModel.value.carMakes,
            orElse: () => carMakesList.first,
          );
          await getCarModel();
        }

        if (userModel.value.carName != null) {
          selectedCarModel.value = carModelList.firstWhere(
            (e) => e.name == userModel.value.carName,
            orElse: () => carModelList.first,
          );
        }


      }
    }  finally {
      isLoading.value = false;
      update();
    }
  }

  Future<void> saveVehicleInformation() async {
    if (userModel.value.isOwner == true) {
      ShowToastDialog.showToast("Update not allowed for Owner type users.");
      return;
    }

    if (carPlatNumberEditingController.value.text.trim().isEmpty) {
      ShowToastDialog.showToast("Please enter car plate number");
      return;
    }

    if (selectedVehicleType.value.id == null) {
      ShowToastDialog.showToast("Please select a vehicle type");
      return;
    }

    if (selectedCarMakes.value.id == null) {
      ShowToastDialog.showToast("Please select a car brand");
      return;
    }

    if (selectedCarModel.value.id == null) {
      ShowToastDialog.showToast("Please select a car model");
      return;
    }

    ShowToastDialog.showLoader("Updating vehicle information...");

    try {
      userModel.value.carNumber = carPlatNumberEditingController.value.text.trim();
      userModel.value.serviceType = getServiceTypeKey(selectedService.value);
      userModel.value.sectionId = selectedSection.value.id;
      userModel.value.vehicleType = selectedVehicleType.value.name;
      userModel.value.vehicleId = selectedVehicleType.value.id;
      userModel.value.carMakes = selectedCarMakes.value.name;
      userModel.value.carName = selectedCarModel.value.name;
      userModel.value.rideType = selectedValue.value;

      bool success = await FireStoreUtils.updateUser(userModel.value);

      ShowToastDialog.closeLoader();

      if (success) {
        ShowToastDialog.showToast("Vehicle information updated successfully.");
      } else {
        ShowToastDialog.showToast("Failed to update. Please try again.");
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error updating vehicle info: $e");
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

  Future<void> getVehicleType(String sectionId) async {
    try {
      if (selectedService.value == "Cab Service") {
        cabVehicleType.value = await FireStoreUtils.getCabVehicleType(sectionId);
      } else if (selectedService.value == "Rental Service") {
        cabVehicleType.value = await FireStoreUtils.getRentalVehicleType(sectionId);
      }
      if (cabVehicleType.isNotEmpty) selectedVehicleType.value = cabVehicleType.first;
    } catch (e) {
      log("Error loading vehicle types: $e");
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
      if (selectedCarMakes.value.name == null || selectedCarMakes.value.name!.isEmpty) {
        carModelList.clear();
        selectedCarModel.value = CarModel();
        return;
      }

      carModelList.value = await FireStoreUtils.getCarModel(selectedCarMakes.value.name!);
      if (carModelList.isNotEmpty) {
        selectedCarModel.value = carModelList.first;
      } else {
        selectedCarModel.value = CarModel();
      }
      update();
    } catch (e) {
      log("Error loading car models: $e");
    }
  }

  String getReadableServiceType(String key) {
    switch (key) {
      case 'cab-service':
        return 'Cab Service';
      case 'parcel_delivery':
        return 'Parcel Service';
      case 'rental-service':
        return 'Rental Service';
      default:
        return 'Delivery Service';
    }
  }

  String getServiceTypeKey(String name) {
    switch (name) {
      case 'Cab Service':
        return 'cab-service';
      case 'Parcel Service':
        return 'parcel_delivery';
      case 'Rental Service':
        return 'rental-service';
      default:
        return 'delivery_service';
    }
  }
}
