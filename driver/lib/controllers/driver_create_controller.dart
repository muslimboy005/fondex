import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/car_makes.dart';
import 'package:driver/models/car_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DriverCreateController extends GetxController {
  // Add your methods and properties here

  RxBool isLoading = true.obs;

  Rx<TextEditingController> firstNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> lastNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;
  Rx<TextEditingController> phoneNUmberEditingController = TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController = TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> passwordEditingController = TextEditingController().obs;
  Rx<TextEditingController> conformPasswordEditingController = TextEditingController().obs;
  Rx<TextEditingController> carPlatNumberEditingController = TextEditingController().obs;

  RxBool passwordVisible = true.obs;
  RxBool conformPasswordVisible = true.obs;

  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  Rx<ZoneModel> selectedZone = ZoneModel().obs;
  RxList<String> service = ['Cab Service', 'Parcel Service', 'Rental Service'].obs; // Option 2
  RxString selectedService = 'Cab Service'.obs;

  RxString selectedValue = 'ride'.obs;

  RxList<SectionModel> sectionList = <SectionModel>[].obs;
  Rx<SectionModel> selectedSection = SectionModel().obs;

  RxList<VehicleType> cabVehicleType = <VehicleType>[].obs;
  Rx<VehicleType> selectedVehicleType = VehicleType().obs;

  RxList<CarMakes> carMakesList = <CarMakes>[].obs;
  Rx<CarMakes> selectedCarMakes = CarMakes().obs;

  RxList<CarModel> carModelList = <CarModel>[].obs;
  Rx<CarModel> selectedCarModel = CarModel().obs;

  Rx<UserModel> driverModel = UserModel().obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArguments();
    super.onInit();
    ever(isLoading, (loading) async {
      if (loading == false && driverModel.value.id == null) {
        await getSection();
      }
    });
  }

  Future<void> signUp() async {
    if (driverModel.value.id != null && driverModel.value.id!.isNotEmpty) {
      await updateDriver();
    } else {
      try {
        ShowToastDialog.showLoader("Please wait".tr);
        
        // Check if SecondaryApp already exists to avoid duplicate app error
        FirebaseApp? secondaryApp;
        try {
          secondaryApp = Firebase.app('SecondaryApp');
        } catch (e) {
          // SecondaryApp doesn't exist, initialize it
          secondaryApp = await Firebase.initializeApp(
            name: 'SecondaryApp',
            options: Firebase.app().options,
          );
        }

        FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

        final credential = await secondaryAuth.createUserWithEmailAndPassword(
          email: emailEditingController.value.text.trim(),
          password: passwordEditingController.value.text.trim(),
        );
        if (credential.user != null) {
          driverModel.value.id = credential.user!.uid;
          driverModel.value.firstName = firstNameEditingController.value.text.toString();
          driverModel.value.lastName = lastNameEditingController.value.text.toString();
          driverModel.value.email = emailEditingController.value.text.toString().toLowerCase();
          driverModel.value.phoneNumber = phoneNUmberEditingController.value.text.toString();
          driverModel.value.role = Constant.userRoleDriver;
          driverModel.value.fcmToken = await NotificationService.getToken();
          driverModel.value.active = true;
          driverModel.value.isActive = false;
          driverModel.value.isDocumentVerify = true;
          driverModel.value.countryCode = countryCodeEditingController.value.text;
          driverModel.value.createdAt = Timestamp.now();
          driverModel.value.zoneId = selectedZone.value.id;
          driverModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
          driverModel.value.provider = 'email';
          driverModel.value.carNumber = carPlatNumberEditingController.value.text.toString();
          driverModel.value.isOwner = false;
          driverModel.value.ownerId = FireStoreUtils.getCurrentUid();
          driverModel.value.serviceType = selectedService.value == "Cab Service"
              ? "cab-service"
              : selectedService.value == "Parcel Service"
                  ? "parcel_delivery"
                  : selectedService.value == "Rental Service"
                      ? "rental-service"
                      : "delivery-service";

          if (selectedService.value == "Cab Service") {
            driverModel.value.carMakes = selectedCarMakes.value.name;
            driverModel.value.carName = selectedCarModel.value.name;
            driverModel.value.vehicleType = selectedVehicleType.value.name;
            driverModel.value.sectionId = selectedSection.value.id;
            driverModel.value.vehicleId = selectedVehicleType.value.id;
            driverModel.value.rideType = selectedValue.value;
          } else if (selectedService.value == "Rental Service") {
            driverModel.value.carMakes = selectedCarMakes.value.name;
            driverModel.value.carName = selectedCarModel.value.name;
            driverModel.value.vehicleType = selectedVehicleType.value.name;
            driverModel.value.vehicleId = selectedVehicleType.value.id;
            driverModel.value.sectionId = selectedSection.value.id;
          } else if (selectedService.value == "Parcel Service") {
            driverModel.value.sectionId = selectedSection.value.id;
          }

          await FireStoreUtils.updateUser(driverModel.value).then(
            (value) async {
              ShowToastDialog.showToast("Driver created successfully".tr);
              Get.back(result: true);
            },
          );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          ShowToastDialog.showToast("The password provided is too weak.".tr);
        } else if (e.code == 'email-already-in-use') {
          ShowToastDialog.showToast("The account already exists for that email.".tr);
        } else if (e.code == 'invalid-email') {
          ShowToastDialog.showToast("Enter email is Invalid".tr);
        }
      } catch (e) {
        ShowToastDialog.showToast(e.toString());
      }
    }
  }

  Future<void> updateDriver() async {
    ShowToastDialog.showLoader("Please wait".tr);
    driverModel.value.firstName = firstNameEditingController.value.text.toString();
    driverModel.value.lastName = lastNameEditingController.value.text.toString();
    driverModel.value.email = emailEditingController.value.text.toString().toLowerCase();
    driverModel.value.phoneNumber = phoneNUmberEditingController.value.text.toString();
    driverModel.value.role = Constant.userRoleDriver;
    driverModel.value.fcmToken = await NotificationService.getToken();
    driverModel.value.active = true;
    driverModel.value.isActive = false;
    driverModel.value.isDocumentVerify = true;
    driverModel.value.countryCode = countryCodeEditingController.value.text;
    driverModel.value.createdAt = Timestamp.now();
    driverModel.value.zoneId = selectedZone.value.id;
    driverModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
    driverModel.value.provider = 'email';
    driverModel.value.carNumber = carPlatNumberEditingController.value.text.toString();
    driverModel.value.isOwner = false;
    driverModel.value.ownerId = FireStoreUtils.getCurrentUid();
    driverModel.value.serviceType = selectedService.value == "Cab Service"
        ? "cab-service"
        : selectedService.value == "Parcel Service"
            ? "parcel_delivery"
            : selectedService.value == "Rental Service"
                ? "rental-service"
                : "delivery-service";

    if (selectedService.value == "Cab Service") {
      driverModel.value.carMakes = selectedCarMakes.value.name;
      driverModel.value.carName = selectedCarModel.value.name;
      driverModel.value.vehicleType = selectedVehicleType.value.name;
      driverModel.value.sectionId = selectedSection.value.id;
      driverModel.value.vehicleId = selectedVehicleType.value.id;
      driverModel.value.rideType = selectedValue.value;
    } else if (selectedService.value == "Rental Service") {
      driverModel.value.carMakes = selectedCarMakes.value.name;
      driverModel.value.carName = selectedCarModel.value.name;
      driverModel.value.vehicleType = selectedVehicleType.value.name;
      driverModel.value.vehicleId = selectedVehicleType.value.id;
      driverModel.value.sectionId = selectedSection.value.id;
    } else if (selectedService.value == "Parcel Service") {
      driverModel.value.sectionId = selectedSection.value.id;
    }

    await FireStoreUtils.updateUser(driverModel.value).then(
      (value) async {
        ShowToastDialog.showToast("Driver update successfully".tr);
        Get.back(result: true);
      },
    );
  }

  Future<void> getArguments() async {
    await FireStoreUtils.getZone().then((value) {
      if (value != null) {
        zoneList.value = value;
      }
    });

    await FireStoreUtils.getCarMakes().then((value) {
      carMakesList.value = value;
    });

    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      driverModel.value = argumentData['driverModel'] as UserModel;

      firstNameEditingController.value.text = driverModel.value.firstName ?? "";
      lastNameEditingController.value.text = driverModel.value.lastName ?? "";
      emailEditingController.value.text = driverModel.value.email ?? "";
      phoneNUmberEditingController.value.text = driverModel.value.phoneNumber ?? "";
      countryCodeEditingController.value.text = driverModel.value.countryCode ?? "+91";
      carPlatNumberEditingController.value.text = driverModel.value.carNumber ?? "";

      selectedValue.value = driverModel.value.rideType ?? '';
      selectedService.value = driverModel.value.serviceType == "cab-service"
          ? "Cab Service"
          : driverModel.value.serviceType == "parcel_delivery"
              ? "Parcel Service"
              : driverModel.value.serviceType == "rental-service"
                  ? "Rental Service"
                  : "Parcel Service";


      await getSection();

      selectedZone.value = ZoneModel();
      for (var element in zoneList) {
        if (element.id == driverModel.value.zoneId) {
          selectedZone.value = element;
          break;
        }
      }

      selectedCarMakes.value = CarMakes();
      for (var element in carMakesList) {
        if (element.name == driverModel.value.carMakes) {
          selectedCarMakes.value = element;
          break;
        }
      }

      if (selectedCarMakes.value.id != null) {
        await getCarModel();

        selectedCarModel.value = CarModel();
        for (var element in carModelList) {
          if (element.name == driverModel.value.carName) {
            selectedCarModel.value = element;
            break;
          }
        }
      }
    }

    isLoading.value = false;
  }

  Future<void> getSection() async {
    ShowToastDialog.showLoader("Please wait");
    await FireStoreUtils.getSections(selectedService.value == "Cab Service"
            ? "cab-service"
            : selectedService.value == "Parcel Service"
                ? "parcel_delivery"
                : selectedService.value == "Rental Service"
                    ? "rental-service"
                    : "")
        .then((value) {
      sectionList.value = value;
      print("Section List Length: ${sectionList.length}");
      if (sectionList.isNotEmpty) {
        selectedSection.value = sectionList.first;
      }
    });
    await getVehicleType();
    ShowToastDialog.closeLoader();
  }

  Future<void> getVehicleType() async {
    ShowToastDialog.showLoader("Please wait");
    cabVehicleType.clear();
    if (selectedService.value == "Cab Service") {
      await FireStoreUtils.getCabVehicleType(selectedSection.value.id.toString()).then((value) {
        cabVehicleType.value = value;

        if (driverModel.value.vehicleId != null && driverModel.value.vehicleId!.isNotEmpty) {
          selectedVehicleType.value = VehicleType();
          for (var element in cabVehicleType) {
            if (element.id == driverModel.value.vehicleId) {
              selectedVehicleType.value = element;
              break;
            }
          }
        } else {
          if (cabVehicleType.isNotEmpty) {
            selectedVehicleType.value = cabVehicleType.first;
          }
        }
      });
    } else if (selectedService.value == "Rental Service") {
      await FireStoreUtils.getRentalVehicleType(selectedSection.value.id.toString()).then((value) {
        cabVehicleType.value = value;
        if (driverModel.value.vehicleId != null && driverModel.value.vehicleId!.isNotEmpty) {
          selectedVehicleType.value = VehicleType();
          for (var element in cabVehicleType) {
            if (element.id == driverModel.value.vehicleId) {
              selectedVehicleType.value = element;
              break;
            }
          }
        } else {
          if (cabVehicleType.isNotEmpty) {
            selectedVehicleType.value = cabVehicleType.first;
          }
        }
      });
    }
    ShowToastDialog.closeLoader();
  }

  Future<void> getCarModel() async {
    ShowToastDialog.showLoader("Please wait");
    carModelList.clear();
    selectedCarModel.value = CarModel();
    await FireStoreUtils.getCarModel(selectedCarMakes.value.name.toString()).then((value) {
      carModelList.value = value;
    });
    ShowToastDialog.closeLoader();
  }
}
