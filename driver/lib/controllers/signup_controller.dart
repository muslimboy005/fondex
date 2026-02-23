import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/app/auth_screen/auth_screen.dart';
import 'package:driver/app/cab_screen/cab_dashboard_screen.dart';
import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/app/owner_screen/owner_dashboard_screen.dart';
import 'package:driver/app/parcel_screen/parcel_dashboard_screen.dart';
import 'package:driver/app/rental_service/rental_dashboard_screen.dart';
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
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SignupController extends GetxController {
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

  RxString type = "".obs;

  Rx<UserModel> userModel = UserModel().obs;

  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  Rx<ZoneModel> selectedZone = ZoneModel().obs;
  RxList<String> service = ['Delivery Service', 'Cab Service', 'Parcel Service', 'Rental Service'].obs; // Option 2
  RxString selectedService = 'Delivery Service'.obs; // Default selected option

  RxList<SectionModel> sectionList = <SectionModel>[].obs;
  Rx<SectionModel> selectedSection = SectionModel().obs;

  RxList<VehicleType> cabVehicleType = <VehicleType>[].obs;
  Rx<VehicleType> selectedVehicleType = VehicleType().obs;

  // RxList<VehicleType> rentalVehicleType = <VehicleType>[].obs;
  // Rx<VehicleType> selectedRentalVehicleType = VehicleType().obs;

  RxList<CarMakes> carMakesList = <CarMakes>[].obs;
  Rx<CarMakes> selectedCarMakes = CarMakes().obs;

  RxList<CarModel> carModelList = <CarModel>[].obs;
  Rx<CarModel> selectedCarModel = CarModel().obs;

  RxString selectedValue = "Individual".obs;

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      type.value = argumentData['type'];
      userModel.value = argumentData['userModel'];
      if (type.value == "mobileNumber") {
        phoneNUmberEditingController.value.text = userModel.value.phoneNumber ?? "";
        countryCodeEditingController.value.text = userModel.value.countryCode ?? "+1";
        emailEditingController.value.text = userModel.value.email ?? "";
        // Password is not shown/asked, it's default "123456" in Firebase
      }
    }

    await FireStoreUtils.getZone().then((value) {
      if (value != null) {
        zoneList.value = value;
      }
    });
  }

  Future<void> getSection() async {
    ShowToastDialog.showLoader("Please wait".tr);
    await FireStoreUtils.getSections(selectedService.value == "Cab Service"
            ? "cab-service"
            : selectedService.value == "Parcel Service"
                ? "parcel_delivery"
                : selectedService.value == "Rental Service"
                    ? "rental-service"
                    : "")
        .then((value) {
      sectionList.value = value;
      // Default tanlanmasin – faqat foydalanuvchi tanlaganda
    });
    await getVehicleType();
    ShowToastDialog.closeLoader();
  }

  Future<void> getVehicleType() async {
    ShowToastDialog.showLoader("Please wait".tr);
    cabVehicleType.clear();
    carMakesList.clear();
    carModelList.clear();
    selectedCarMakes.value = CarMakes();
    selectedCarModel.value = CarModel();
    if (selectedService.value == "Cab Service") {
      final sectionId = selectedSection.value.id?.toString() ?? '';
      if (sectionId.isEmpty) {
        ShowToastDialog.closeLoader();
        return;
      }
      await FireStoreUtils.getCabVehicleType(sectionId).then((value) {
        cabVehicleType.value = value;
        // Default tanlanmasin – faqat foydalanuvchi tanlaganda
      });
    } else if (selectedService.value == "Rental Service") {
      await FireStoreUtils.getRentalVehicleType(
              selectedSection.value.id.toString())
          .then((value) {
        cabVehicleType.value = value;
        // Default tanlanmasin – faqat foydalanuvchi tanlaganda
      });
      await FireStoreUtils.getCarMakes().then((value) {
        carMakesList.value = value;
      });
    }
    ShowToastDialog.closeLoader();
  }

  /// Cab: transport turi tanlangandan keyin shu turga tegishli markalarni car_model dan olish
  Future<void> getCarMakesForCab() async {
    final vehicleTypeId = selectedVehicleType.value.id?.toString() ?? '';
    if (vehicleTypeId.isEmpty) return;
    carMakesList.clear();
    carModelList.clear();
    selectedCarMakes.value = CarMakes();
    selectedCarModel.value = CarModel();
    final list = await FireStoreUtils.getCarMakesByVehicleTypeId(vehicleTypeId);
    carMakesList.value = list;
    // Default tanlanmasin – faqat foydalanuvchi tanlaganda
  }

  /// Cab: marka tanlangandan keyin shu tur + markaga tegishli modellarni olish
  Future<void> getCarModelsForCab() async {
    final vehicleTypeId = selectedVehicleType.value.id?.toString() ?? '';
    final carMakeId = selectedCarMakes.value.id?.toString() ?? '';
    if (vehicleTypeId.isEmpty || carMakeId.isEmpty) return;
    carModelList.clear();
    selectedCarModel.value = CarModel();
    final list = await FireStoreUtils.getCarModelsByVehicleTypeAndMake(
        vehicleTypeId, carMakeId);
    carModelList.value = list;
    // Default tanlanmasin – faqat foydalanuvchi tanlaganda
  }

  Future<void> getCarModel() async {
    if (selectedService.value == "Cab Service") {
      ShowToastDialog.showLoader("Please wait".tr);
      await getCarModelsForCab();
      ShowToastDialog.closeLoader();
      return;
    }
    ShowToastDialog.showLoader("Please wait".tr);
    carModelList.clear();
    selectedCarModel.value = CarModel();
    await FireStoreUtils
        .getCarModel(selectedCarMakes.value.name.toString())
        .then((value) {
      carModelList.value = value;
    });
    ShowToastDialog.closeLoader();
  }

  Future<void> signUpWithEmailAndPassword() async {
    signUp();
  }

  Future<void> signUp() async {
    if (selectedService.value == "Cab Service") {
      final sectionOk = selectedSection.value.id != null && selectedSection.value.id!.isNotEmpty;
      final vehicleOk = selectedVehicleType.value.id != null && selectedVehicleType.value.id!.isNotEmpty;
      final makeOk = selectedCarMakes.value.id != null && selectedCarMakes.value.id!.isNotEmpty;
      final modelOk = selectedCarModel.value.id != null && selectedCarModel.value.id!.isNotEmpty;
      if (!sectionOk || !vehicleOk || !makeOk || !modelOk) {
        ShowToastDialog.showToast("Please select Section, Vehicle Type, Car Brand and Car Model.".tr);
        return;
      }
    }
    if (selectedService.value == "Rental Service") {
      final sectionOk = selectedSection.value.id != null && selectedSection.value.id!.isNotEmpty;
      final vehicleOk = selectedVehicleType.value.id != null && selectedVehicleType.value.id!.isNotEmpty;
      final makeOk = selectedCarMakes.value.id != null && selectedCarMakes.value.id!.isNotEmpty;
      final modelOk = selectedCarModel.value.id != null && selectedCarModel.value.id!.isNotEmpty;
      if (!sectionOk || !vehicleOk || !makeOk || !modelOk) {
        ShowToastDialog.showToast("Please select Section, Vehicle Type, Car Brand and Car Model.".tr);
        return;
      }
    }
    if (selectedService.value == "Parcel Service") {
      final sectionOk = selectedSection.value.id != null && selectedSection.value.id!.isNotEmpty;
      if (!sectionOk) {
        ShowToastDialog.showToast("Please select Section.".tr);
        return;
      }
    }
    ShowToastDialog.showLoader("Please wait".tr);
    if (type.value == "mobileNumber") {
      userModel.value.firstName = firstNameEditingController.value.text.toString();
      userModel.value.lastName = lastNameEditingController.value.text.toString();
      userModel.value.email = emailEditingController.value.text.toString().toLowerCase();
      userModel.value.phoneNumber = phoneNUmberEditingController.value.text.toString();
      userModel.value.role = Constant.userRoleDriver;
      userModel.value.fcmToken = await NotificationService.getToken();
      userModel.value.active = Constant.autoApproveDriver == true ? true : false;
      userModel.value.isActive = false;
      userModel.value.isDocumentVerify = selectedValue.value == "Company"
          ? Constant.isOwnerVerification == true
              ? false
              : true
          : Constant.isDriverVerification == true
              ? false
              : true;
      userModel.value.countryCode = countryCodeEditingController.value.text;
      userModel.value.createdAt = Timestamp.now();
      userModel.value.zoneId = selectedZone.value.id;
      userModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
      userModel.value.provider = type.value;
      userModel.value.carNumber = carPlatNumberEditingController.value.text.toString();
      userModel.value.isOwner = selectedValue.value == "Company" ? true : false;
      userModel.value.serviceType = selectedService.value == "Cab Service"
          ? "cab-service"
          : selectedService.value == "Parcel Service"
              ? "parcel_delivery"
              : selectedService.value == "Rental Service"
                  ? "rental-service"
                  : "delivery-service";

      if (selectedService.value == "Cab Service") {
        userModel.value.vehicleId = selectedVehicleType.value.id;
        userModel.value.vehicleType = selectedVehicleType.value.name;
        userModel.value.sectionId = selectedSection.value.id;
        userModel.value.carMakes = selectedCarMakes.value.name;
        userModel.value.carName = selectedCarModel.value.name;
        userModel.value.rideType = selectedSection.value.rideType;
      } else if (selectedService.value == "Rental Service") {
        userModel.value.vehicleId = selectedVehicleType.value.id;
        userModel.value.vehicleType = selectedVehicleType.value.name;
        userModel.value.carMakes = selectedCarMakes.value.name;
        userModel.value.carName = selectedCarModel.value.name;
        userModel.value.sectionId = selectedSection.value.id;
      } else if (selectedService.value == "Parcel Service") {
        userModel.value.sectionId = selectedSection.value.id;
      }

      log(userModel.value.toJson().toString());

      await FireStoreUtils.updateUser(userModel.value).then(
        (value) async {
          if (Constant.autoApproveDriver == true) {
            if (userModel.value.isOwner == true) {
              Get.offAll(OwnerDashboardScreen());
            } else {
              if (userModel.value.serviceType == "delivery-service") {
                Get.offAll(const DashBoardScreen());
              } else if (userModel.value.serviceType == "cab-service") {
                Get.offAll(const CabDashboardScreen());
              } else if (userModel.value.serviceType == "parcel_delivery") {
                Get.offAll(const ParcelDashboardScreen());
              } else if (userModel.value.serviceType == "rental-service") {
                Get.offAll(const RentalDashboardScreen());
              }
            }
          } else {
            ShowToastDialog.showToast("Thank you for sign up, your application is under approval so please wait till that approve.".tr);
            Get.offAll(const AuthScreen());
          }
        },
      );
    } else {
      try {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailEditingController.value.text.trim(),
          password: passwordEditingController.value.text.trim(),
        );
        if (credential.user != null) {
          userModel.value.id = credential.user!.uid;
          userModel.value.firstName = firstNameEditingController.value.text.toString();
          userModel.value.lastName = lastNameEditingController.value.text.toString();
          userModel.value.email = emailEditingController.value.text.toString().toLowerCase();
          userModel.value.phoneNumber = phoneNUmberEditingController.value.text.toString();
          userModel.value.role = Constant.userRoleDriver;
          userModel.value.isActive = false;
          userModel.value.fcmToken = await NotificationService.getToken();
          userModel.value.active = Constant.autoApproveDriver == true ? true : false;
          userModel.value.isDocumentVerify = Constant.isDriverVerification == true ? false : true;
          userModel.value.countryCode = countryCodeEditingController.value.text;
          userModel.value.createdAt = Timestamp.now();
          userModel.value.zoneId = selectedZone.value.id;
          userModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
          userModel.value.provider = 'email';
          userModel.value.carNumber = carPlatNumberEditingController.value.text.toString();
          userModel.value.isOwner = selectedValue.value == "Company" ? true : false;
          userModel.value.serviceType = selectedService.value == "Cab Service"
              ? "cab-service"
              : selectedService.value == "Parcel Service"
                  ? "parcel_delivery"
                  : selectedService.value == "Rental Service"
                      ? "rental-service"
                      : "delivery-service";

          if (selectedService.value == "Cab Service") {
            userModel.value.carMakes = selectedCarMakes.value.name;
            userModel.value.carName = selectedCarModel.value.name;
            userModel.value.vehicleType = selectedVehicleType.value.name;
            userModel.value.sectionId = selectedSection.value.id;
            userModel.value.vehicleId = selectedVehicleType.value.id;
            userModel.value.rideType = "ride";
          } else if (selectedService.value == "Rental Service") {
            userModel.value.carMakes = selectedCarMakes.value.name;
            userModel.value.carName = selectedCarModel.value.name;
            userModel.value.vehicleType = selectedVehicleType.value.name;
            userModel.value.vehicleId = selectedVehicleType.value.id;
            userModel.value.sectionId = selectedSection.value.id;
          } else if (selectedService.value == "Parcel Service") {
            userModel.value.sectionId = selectedSection.value.id;
          }

          await FireStoreUtils.updateUser(userModel.value).then(
            (value) async {
              if (Constant.autoApproveDriver == true) {
                if (userModel.value.isOwner == true) {
                  Get.offAll(OwnerDashboardScreen());
                } else {
                  if (userModel.value.serviceType == "delivery-service") {
                    Get.offAll(const DashBoardScreen());
                  } else if (userModel.value.serviceType == "cab-service") {
                    Get.offAll(const CabDashboardScreen());
                  } else if (userModel.value.serviceType == "parcel_delivery") {
                    Get.offAll(const ParcelDashboardScreen());
                  } else if (userModel.value.serviceType == "rental-service") {
                    Get.offAll(const RentalDashboardScreen());
                  }
                }
              } else {
                ShowToastDialog.showToast("Thank you for sign up, your application is under approval so please wait till that approve.".tr);
                Get.offAll(const AuthScreen());
              }
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
        print(e);
      } catch (e) {
        print(e);
        ShowToastDialog.showToast(e.toString());
      }
    }

    ShowToastDialog.closeLoader();
  }
}
