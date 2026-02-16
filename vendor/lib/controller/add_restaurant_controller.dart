import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/SectionModel.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_category_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/models/zone_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/widget/geoflutterfire/src/geoflutterfire.dart';

class AddRestaurantController extends GetxController {
  RxBool isLoading = true.obs;
  RxBool isAddressEnable = false.obs;
  RxBool isEnableDeliverySettings = true.obs;
  final myKey1 = GlobalKey<DropdownSearchState<VendorCategoryModel>>();

  Rx<TextEditingController> restaurantNameController =
      TextEditingController().obs;
  Rx<TextEditingController> restaurantDescriptionController =
      TextEditingController().obs;
  Rx<TextEditingController> mobileNumberController =
      TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> addressController = TextEditingController().obs;

  Rx<TextEditingController> chargePerKmController = TextEditingController().obs;
  Rx<TextEditingController> minDeliveryChargesController =
      TextEditingController().obs;
  Rx<TextEditingController> minDeliveryChargesWithinKMController =
      TextEditingController().obs;

  LatLng? selectedLocation;

  RxList images = <dynamic>[].obs;

  RxList<VendorCategoryModel> vendorCategoryList = <VendorCategoryModel>[].obs;
  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  Rx<ZoneModel> selectedZone = ZoneModel().obs;

  // Rx<VendorCategoryModel> selectedCategory = VendorCategoryModel().obs;
  RxList selectedService = [].obs;

  RxList<VendorCategoryModel> selectedCategories = <VendorCategoryModel>[].obs;

  RxBool canShowQRCodeButton = false.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getRestaurant();
    super.onInit();
    Future.delayed(const Duration(seconds: 3), () {
      if (userModel.value.subscriptionPlan?.features?.qrCodeGenerate == true) {
        canShowQRCodeButton.value = true;
      }
    });
  }

  Rx<UserModel> userModel = UserModel().obs;
  Rx<VendorModel> vendorModel = VendorModel().obs;
  Rx<DeliveryCharge> deliveryChargeModel = DeliveryCharge().obs;
  RxBool isSelfDelivery = false.obs;
  RxList<SectionModel> sectionsList = <SectionModel>[].obs;
  Rx<SectionModel> selectedSectionModel = SectionModel().obs;

  Future<void> changeSection(SectionModel newSection) async {
    selectedSectionModel.value = newSection;
    // Reload categories and zones for the new section
    vendorCategoryList.value = await FireStoreUtils.getVendorCategoryById(
      selectedSectionModel.value.id.toString(),
    );
    if (vendorCategoryList.isEmpty) {
      ShowToastDialog.showToast("No category for this section".tr);
    }

    await FireStoreUtils.getZone(selectedSectionModel.value.id.toString()).then(
      (value) {
        if (value != null) {
          zoneList.value = value;
        }
      },
    );

    // Clear current selections as they might not be valid for the new section
    selectedCategories.clear();
    selectedZone.value = ZoneModel();
    update();
  }

  void _populateFormFields() {
    print(
      "🔍 DEBUG: Populating form fields for vendor: ${vendorModel.value.title}",
    );
    restaurantNameController.value.text = vendorModel.value.title.toString();
    restaurantDescriptionController.value.text = vendorModel.value.description
        .toString();
    mobileNumberController.value.text = vendorModel.value.phonenumber
        .toString();
    addressController.value.text = vendorModel.value.location.toString();
    isSelfDelivery.value = vendorModel.value.isSelfDelivery ?? false;
    if (addressController.value.text.isNotEmpty) {
      isAddressEnable.value = true;
    }
    if (vendorModel.value.latitude != null &&
        vendorModel.value.longitude != null) {
      selectedLocation = LatLng(
        vendorModel.value.latitude!,
        vendorModel.value.longitude!,
      );
    }
    if (vendorModel.value.photos != null) {
      for (var element in vendorModel.value.photos!) {
        images.add(element);
      }
    }

    // Set selected zone based on vendor's zoneId
    for (var element in zoneList) {
      if (element.id == vendorModel.value.zoneId) {
        selectedZone.value = element;
        print("🔍 DEBUG: Set selectedZone to: ${selectedZone.value.name}");
        break;
      }
    }

    // Set selected categories based on vendor's categoryID
    if (vendorModel.value.categoryID != null &&
        vendorModel.value.categoryID!.isNotEmpty) {
      selectedCategories.value = vendorCategoryList
          .where(
            (category) => vendorModel.value.categoryID!.contains(category.id),
          )
          .toList();
      print(
        "🔍 DEBUG: Set selectedCategories: ${selectedCategories.length} categories",
      );
    }

    // Set selected services based on vendor's filters
    if (vendorModel.value.filters != null) {
      vendorModel.value.filters!.toJson().forEach((key, value) {
        if (value.contains("Yes")) {
          selectedService.add(key);
        }
      });
      print(
        "🔍 DEBUG: Set selectedService: ${selectedService.length} services",
      );
    }
  }

  Future<void> getRestaurant() async {
    try {
      await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((
        model,
      ) {
        if (model != null) {
          userModel.value = model;
        }
      });
      await FireStoreUtils.getSection().then((value) async {
        sectionsList.value = value
            .where(
              (element) =>
                  element.serviceTypeFlag == "ecommerce-service" ||
                  element.serviceTypeFlag == "delivery-service",
            )
            .toList();
      });

      // Set selected section
      // First check if we have an existing vendor to edit
      bool hasExistingVendor =
          Constant.userModel?.vendorID != null &&
          Constant.userModel?.vendorID?.isNotEmpty == true;

      print("🔍 DEBUG: hasExistingVendor = $hasExistingVendor");
      print("🔍 DEBUG: userModel.sectionId = ${userModel.value.sectionId}");

      if (hasExistingVendor) {
        // For existing vendors, load the vendor first to get its sectionId
        print("🔍 DEBUG: Loading existing vendor for section detection");
        await FireStoreUtils.getVendorById(
          Constant.userModel!.vendorID.toString(),
        ).then((value) {
          if (value != null) {
            vendorModel.value = value;
            print(
              "🔍 DEBUG: Loaded vendor sectionId = ${vendorModel.value.sectionId}",
            );

            if (vendorModel.value.sectionId != null &&
                vendorModel.value.sectionId!.isNotEmpty) {
              selectedSectionModel.value = sectionsList.firstWhere(
                (element) => element.id == vendorModel.value.sectionId,
                orElse: () => sectionsList.isNotEmpty
                    ? sectionsList.first
                    : SectionModel(),
              );
              print(
                "🔍 DEBUG: Set selectedSectionModel to vendor's section: ${selectedSectionModel.value.name} (ID: ${selectedSectionModel.value.id})",
              );
            } else {
              print("🔍 DEBUG: Vendor has no sectionId, using fallback");
              selectedSectionModel.value = sectionsList.isNotEmpty
                  ? sectionsList.first
                  : SectionModel();
            }
          } else {
            print("🔍 DEBUG: Failed to load vendor, using user section");
            // Fallback to user section
            if (userModel.value.sectionId != null &&
                userModel.value.sectionId!.isNotEmpty) {
              selectedSectionModel.value = sectionsList.firstWhere(
                (element) => element.id == userModel.value.sectionId,
                orElse: () => sectionsList.isNotEmpty
                    ? sectionsList.first
                    : SectionModel(),
              );
            } else if (sectionsList.isNotEmpty) {
              selectedSectionModel.value = sectionsList.first;
            }
          }
        });
      } else {
        // For new vendors, use user's section
        print("🔍 DEBUG: New vendor, using user section");
        if (userModel.value.sectionId != null &&
            userModel.value.sectionId!.isNotEmpty) {
          selectedSectionModel.value = sectionsList.firstWhere(
            (element) => element.id == userModel.value.sectionId,
            orElse: () =>
                sectionsList.isNotEmpty ? sectionsList.first : SectionModel(),
          );
          print(
            "🔍 DEBUG: Set selectedSectionModel to user's section: ${selectedSectionModel.value.name} (ID: ${selectedSectionModel.value.id})",
          );
        } else if (sectionsList.isNotEmpty) {
          // For new users without sectionId, use the first available section
          selectedSectionModel.value = sectionsList.first;
          print(
            "🔍 DEBUG: User has no sectionId, using first available: ${selectedSectionModel.value.name} (ID: ${selectedSectionModel.value.id})",
          );
        }
      }

      // Load categories and zones based on selected section
      if (selectedSectionModel.value.id != null) {
        vendorCategoryList.value = await FireStoreUtils.getVendorCategoryById(
          selectedSectionModel.value.id.toString(),
        );
        if (vendorCategoryList.isEmpty) {
          ShowToastDialog.showToast("No category for this section".tr);
        }

        await FireStoreUtils.getZone(
          selectedSectionModel.value.id.toString(),
        ).then((value) {
          if (value != null) {
            zoneList.value = value;
          }
        });
      }

      if (Constant.userModel?.vendorID != null &&
          Constant.userModel?.vendorID?.isNotEmpty == true) {
        // Only load vendor if we haven't already loaded it for section detection
        if (vendorModel.value.id == null) {
          print("🔍 DEBUG: Loading vendor data for form population");
          await FireStoreUtils.getVendorById(
            Constant.userModel!.vendorID.toString(),
          ).then((value) {
            if (value != null) {
              vendorModel.value = value;
              print(
                "🔍 DEBUG: Vendor loaded with sectionId: ${vendorModel.value.sectionId}",
              );
              _populateFormFields();
            }
          });
        } else {
          print("🔍 DEBUG: Vendor already loaded, populating form fields");
          _populateFormFields();
        }
      }

      await FireStoreUtils.getDelivery().then((value) {
        if (value != null) {
          deliveryChargeModel.value = value;
          isEnableDeliverySettings.value =
              deliveryChargeModel.value.vendorCanModify ?? false;
          if (value.vendorCanModify == true) {
            if (vendorModel.value.deliveryCharge != null) {
              chargePerKmController.value.text = vendorModel
                  .value
                  .deliveryCharge!
                  .deliveryChargesPerKm
                  .toString();
              minDeliveryChargesController.value.text = vendorModel
                  .value
                  .deliveryCharge!
                  .minimumDeliveryCharges
                  .toString();
              minDeliveryChargesWithinKMController.value.text = vendorModel
                  .value
                  .deliveryCharge!
                  .minimumDeliveryChargesWithinKm
                  .toString();
            }
          } else {
            chargePerKmController.value.text = deliveryChargeModel
                .value
                .deliveryChargesPerKm
                .toString();
            minDeliveryChargesController.value.text = deliveryChargeModel
                .value
                .minimumDeliveryCharges
                .toString();
            minDeliveryChargesWithinKMController.value.text =
                deliveryChargeModel.value.minimumDeliveryChargesWithinKm
                    .toString();
          }
        }
      });
    } catch (e) {
      print(e);
    }

    isLoading.value = false;
  }

  Future<void> saveDetails() async {
    // Validation checks
    if (restaurantNameController.value.text.isEmpty) {
      Get.snackbar(
        "Error".tr,
        "Please enter store name".tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (restaurantDescriptionController.value.text.isEmpty) {
      Get.snackbar(
        "Error".tr,
        "Please enter Description".tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (mobileNumberController.value.text.isEmpty) {
      Get.snackbar(
        "Error".tr,
        "Please enter phone number".tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (addressController.value.text.isEmpty) {
      Get.snackbar(
        "Error".tr,
        "Please enter address".tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (selectedZone.value.id == null) {
      Get.snackbar(
        "Error".tr,
        "Please select zone".tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (selectedCategories.isEmpty) {
      Get.snackbar(
        "Error".tr,
        "Please select category".tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (selectedLocation == null) {
      Get.snackbar(
        "Error".tr,
        "Please select location".tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (selectedZone.value.area == null) {
      Get.snackbar(
        "Error".tr,
        "Please select zone".tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Check if location is within zone
    if (!Constant.isPointInPolygon(
      selectedLocation!,
      selectedZone.value.area!,
    )) {
      Get.snackbar(
        "Error".tr,
        "The chosen area is outside the selected zone.".tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Show loading
    ShowToastDialog.showLoader("Please wait...".tr);

    try {
      print("🔍 DEBUG: Starting save process...");
      filter();

      // Parse delivery charges with error handling
      num deliveryChargesPerKm;
      num minimumDeliveryCharges;
      num minimumDeliveryChargesWithinKm;

      try {
        String chargePerKmText = chargePerKmController.value.text.trim().isEmpty
            ? "0"
            : chargePerKmController.value.text.trim();
        String minDeliveryText =
            minDeliveryChargesController.value.text.trim().isEmpty
            ? "0"
            : minDeliveryChargesController.value.text.trim();
        String minDeliveryWithinText =
            minDeliveryChargesWithinKMController.value.text.trim().isEmpty
            ? "0"
            : minDeliveryChargesWithinKMController.value.text.trim();

        print(
          "🔍 DEBUG: Parsing delivery charges - perKm: '$chargePerKmText', min: '$minDeliveryText', within: '$minDeliveryWithinText'",
        );

        deliveryChargesPerKm = num.parse(chargePerKmText);
        minimumDeliveryCharges = num.parse(minDeliveryText);
        minimumDeliveryChargesWithinKm = num.parse(minDeliveryWithinText);
      } catch (parseError) {
        print("🔍 DEBUG: Parse error for delivery charges: $parseError");
        throw Exception("Invalid delivery charge format: $parseError");
      }

      DeliveryCharge deliveryChargeModel = DeliveryCharge(
        vendorCanModify: true,
        deliveryChargesPerKm: deliveryChargesPerKm,
        minimumDeliveryCharges: minimumDeliveryCharges,
        minimumDeliveryChargesWithinKm: minimumDeliveryChargesWithinKm,
      );
      print("🔍 DEBUG: DeliveryCharge model created successfully");

      if (vendorModel.value.id == null) {
        vendorModel.value = VendorModel();
        vendorModel.value.createdAt = Timestamp.now();
      }

      // Upload images
      print("🔍 DEBUG: Uploading ${images.length} images...");
      for (int i = 0; i < images.length; i++) {
        if (images[i].runtimeType == XFile) {
          print("🔍 DEBUG: Uploading image ${i + 1}/${images.length}");
          String url = await Constant.uploadUserImageToFireStorage(
            File(images[i].path),
            "profileImage/${FireStoreUtils.getCurrentUid()}",
            File(images[i].path).path.split('/').last,
          );
          images.removeAt(i);
          images.insert(i, url);
          print("🔍 DEBUG: Image ${i + 1} uploaded successfully: $url");
        }
      }
      print("🔍 DEBUG: All images uploaded");

      // Set vendor data
      vendorModel.value.id = Constant.userModel?.vendorID;
      if (Constant.userModel != null) {
        vendorModel.value.author = Constant.userModel!.id;
        vendorModel.value.authorName = Constant.userModel!.firstName;
        vendorModel.value.authorProfilePic =
            Constant.userModel!.profilePictureURL;
      }

      vendorModel.value.categoryID = selectedCategories
          .map((e) => e.id ?? '')
          .toList();
      vendorModel.value.categoryTitle = selectedCategories
          .map((e) => e.title ?? '')
          .toList();

      if (selectedLocation != null) {
        vendorModel.value.g = G(
          geohash: Geoflutterfire()
              .point(
                latitude: selectedLocation!.latitude,
                longitude: selectedLocation!.longitude,
              )
              .hash,
          geopoint: GeoPoint(
            selectedLocation!.latitude,
            selectedLocation!.longitude,
          ),
        );
      }

      vendorModel.value.description =
          restaurantDescriptionController.value.text;
      vendorModel.value.phonenumber = mobileNumberController.value.text;
      vendorModel.value.filters = Filters.fromJson(filters);
      vendorModel.value.location = addressController.value.text;

      if (selectedLocation != null) {
        vendorModel.value.latitude = selectedLocation!.latitude;
        vendorModel.value.longitude = selectedLocation!.longitude;
      }

      vendorModel.value.photos = images;
      if (selectedSectionModel.value.id != null) {
        vendorModel.value.sectionId = selectedSectionModel.value.id;
      }

      if (images.isNotEmpty) {
        vendorModel.value.photo = images.first;
      } else {
        vendorModel.value.photo = null;
      }

      vendorModel.value.deliveryCharge = deliveryChargeModel;
      vendorModel.value.title = restaurantNameController.value.text;
      vendorModel.value.zoneId = selectedZone.value.id;
      vendorModel.value.isSelfDelivery = isSelfDelivery.value;

      if ((selectedSectionModel.value.adminCommision?.isEnabled == true) ||
          Constant.isSubscriptionModelApplied == true) {
        vendorModel.value.subscriptionPlanId =
            userModel.value.subscriptionPlanId;
        vendorModel.value.subscriptionPlan = userModel.value.subscriptionPlan;
        vendorModel.value.subscriptionExpiryDate =
            userModel.value.subscriptionExpiryDate;
        vendorModel.value.subscriptionTotalOrders =
            userModel.value.subscriptionPlan?.orderLimit;
      }

      // Save vendor data
      print("🔍 DEBUG: Saving vendor data...");
      print(
        "🔍 DEBUG: vendorID exists: ${Constant.userModel!.vendorID!.isNotEmpty}",
      );

      if (Constant.userModel!.vendorID!.isNotEmpty) {
        // Update existing vendor
        print("🔍 DEBUG: Updating existing vendor...");
        await FireStoreUtils.updateVendor(vendorModel.value);
        print("🔍 DEBUG: Vendor updated successfully");
      } else {
        // Create new vendor
        print("🔍 DEBUG: Creating new vendor...");
        if (selectedSectionModel.value.adminCommision != null) {
          vendorModel.value.adminCommission =
              selectedSectionModel.value.adminCommision!;
        }
        vendorModel.value.workingHours = [
          WorkingHours(
            day: 'Monday',
            timeslot: [Timeslot(from: '00:00', to: '23:59')],
          ),
          WorkingHours(
            day: 'Tuesday',
            timeslot: [Timeslot(from: '00:00', to: '23:59')],
          ),
          WorkingHours(
            day: 'Wednesday',
            timeslot: [Timeslot(from: '00:00', to: '23:59')],
          ),
          WorkingHours(
            day: 'Thursday',
            timeslot: [Timeslot(from: '00:00', to: '23:59')],
          ),
          WorkingHours(
            day: 'Friday',
            timeslot: [Timeslot(from: '00:00', to: '23:59')],
          ),
          WorkingHours(
            day: 'Saturday',
            timeslot: [Timeslot(from: '00:00', to: '23:59')],
          ),
          WorkingHours(
            day: 'Sunday',
            timeslot: [Timeslot(from: '00:00', to: '23:59')],
          ),
        ];

        await FireStoreUtils.firebaseCreateNewVendor(vendorModel.value);
        print("🔍 DEBUG: New vendor created successfully");
      }

      print(
        "🔍 DEBUG: Save process completed successfully, showing success message",
      );

      // Success: close loader, show success snackbar, navigate back
      ShowToastDialog.closeLoader();
      print("🔍 DEBUG: Loader closed, about to show success snackbar");

      // Small delay to ensure loader is closed before showing snackbar
      await Future.delayed(Duration(milliseconds: 500));

      print("🔍 DEBUG: Showing success snackbar");
      try {
        Get.snackbar(
          "Success".tr,
          "Store details save successfully".tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
        print("🔍 DEBUG: Get.snackbar called successfully");
      } catch (snackbarError) {
        print("🔍 DEBUG: Get.snackbar failed: $snackbarError");
        // Fallback: show regular toast
        ShowToastDialog.showToast("Store details save successfully".tr);
      }

      // Small delay before navigation to ensure snackbar is visible
      await Future.delayed(Duration(seconds: 1));
      print("🔍 DEBUG: Navigating back");

      try {
        // Check if we can navigate back
        if (Get.isDialogOpen == true) {
          print("🔍 DEBUG: Dialog is open, closing it first");
          Get.back(); // Close dialog first
          await Future.delayed(Duration(milliseconds: 300));
        }

        if (Get.isBottomSheetOpen == true) {
          print("🔍 DEBUG: Bottom sheet is open, closing it first");
          Get.back(); // Close bottom sheet first
          await Future.delayed(Duration(milliseconds: 300));
        }

        print(
          "🔍 DEBUG: Checking navigation stack before back: ${Get.routeTree.toString()}",
        );
        print("🔍 DEBUG: Current route: ${Get.currentRoute}");

        // Force navigation using multiple approaches
        print("🔍 DEBUG: Attempting forced navigation...");

        // Try Get.close() with different counts
        bool navigationSuccessful = false;
        for (int i = 1; i <= 5 && !navigationSuccessful; i++) {
          try {
            print("🔍 DEBUG: Trying Get.close($i)...");
            Get.close(i);
            await Future.delayed(Duration(milliseconds: 300));

            // Check if navigation worked
            String currentRoute = Get.currentRoute;
            print("🔍 DEBUG: Route after Get.close($i): $currentRoute");

            if (currentRoute != '/AddRestaurantScreen') {
              print("🔍 DEBUG: Navigation successful with Get.close($i)");
              navigationSuccessful = true;
            }
          } catch (e) {
            print("🔍 DEBUG: Get.close($i) failed: $e");
          }
        }

        // If Get.close didn't work, try more aggressive approaches
        if (!navigationSuccessful) {
          try {
            print("🔍 DEBUG: Trying Navigator.pop() with Get.context...");
            if (Get.context != null) {
              Navigator.of(Get.context!).pop();
              print("🔍 DEBUG: Navigator.pop() called successfully");
              navigationSuccessful = true;
            } else {
              print(
                "🔍 DEBUG: Get.context is null, cannot use Navigator.pop()",
              );
            }
          } catch (e) {
            print("🔍 DEBUG: Navigator.pop() failed: $e");
          }

          if (!navigationSuccessful) {
            try {
              print(
                "🔍 DEBUG: Trying Get.until() to remove AddRestaurantScreen...",
              );
              Get.until(
                (route) => route.settings.name != '/AddRestaurantScreen',
              );
              print("🔍 DEBUG: Get.until() called");
              navigationSuccessful = true;
            } catch (e2) {
              print("🔍 DEBUG: Get.until() failed: $e2");
            }
          }

          if (!navigationSuccessful) {
            try {
              print("🔍 DEBUG: Last resort - Get.offAll() to force close...");
              Get.offAll(() => SizedBox()); // Empty widget to force close
              print("🔍 DEBUG: Get.offAll() called as last resort");
              navigationSuccessful = true;
            } catch (e3) {
              print("🔍 DEBUG: All navigation methods failed completely: $e3");
            }
          }
        }

        // Additional check after navigation
        await Future.delayed(Duration(milliseconds: 500));
        print(
          "🔍 DEBUG: Navigation verification - Current route after back: ${Get.currentRoute}",
        );
      } catch (navError) {
        print("🔍 DEBUG: Navigation failed: $navError");
        // Fallback: try to navigate using Navigator
        try {
          print("🔍 DEBUG: Trying fallback navigation");
          // This won't work in this context, but let's log it
          print("🔍 DEBUG: Fallback navigation not available in controller");
        } catch (fallbackError) {
          print("🔍 DEBUG: Fallback navigation also failed: $fallbackError");
        }
      }
    } catch (e) {
      // Error: close loader, show error snackbar, don't navigate
      print("🔍 DEBUG: Save failed with error: $e");
      ShowToastDialog.closeLoader();
      Get.snackbar(
        "Error".tr,
        "Failed to save store details. Please try again.".tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    }
  }

  Map<String, dynamic> filters = {};

  void filter() {
    if (selectedService.contains('Good for Breakfast')) {
      filters['Good for Breakfast'] = 'Yes';
    } else {
      filters['Good for Breakfast'] = 'No';
    }
    if (selectedService.contains('Good for Lunch')) {
      filters['Good for Lunch'] = 'Yes';
    } else {
      filters['Good for Lunch'] = 'No';
    }

    if (selectedService.contains('Good for Dinner')) {
      filters['Good for Dinner'] = 'Yes';
    } else {
      filters['Good for Dinner'] = 'No';
    }

    if (selectedService.contains('Takes Reservations')) {
      filters['Takes Reservations'] = 'Yes';
    } else {
      filters['Takes Reservations'] = 'No';
    }

    if (selectedService.contains('Vegetarian Friendly')) {
      filters['Vegetarian Friendly'] = 'Yes';
    } else {
      filters['Vegetarian Friendly'] = 'No';
    }

    if (selectedService.contains('Live Music')) {
      filters['Live Music'] = 'Yes';
    } else {
      filters['Live Music'] = 'No';
    }

    if (selectedService.contains('Outdoor Seating')) {
      filters['Outdoor Seating'] = 'Yes';
    } else {
      filters['Outdoor Seating'] = 'No';
    }

    if (selectedService.contains('Free Wi-Fi')) {
      filters['Free Wi-Fi'] = 'Yes';
    } else {
      filters['Free Wi-Fi'] = 'No';
    }
  }

  final ImagePicker _imagePicker = ImagePicker();

  Future pickFile({required ImageSource source}) async {
    try {
      XFile? image = await _imagePicker.pickImage(source: source);
      if (image == null) return;
      images.add(image);
      Get.back();
    } on PlatformException catch (e) {
      ShowToastDialog.showToast("${"Failed to Pick :".tr} \n $e");
    }
  }
}
