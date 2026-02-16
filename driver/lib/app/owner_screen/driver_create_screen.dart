import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/driver_create_controller.dart';
import 'package:driver/models/car_makes.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/text_field_widget.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../models/car_model.dart' show CarModel;
import '../../themes/responsive.dart' show Responsive;

class DriverCreateScreen extends StatelessWidget {
  const DriverCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
        init: DriverCreateController(),
        builder: (controller) {
          return Scaffold(
            appBar: AppBar(
              title: Text(controller.driverModel.value.id != null && controller.driverModel.value.id!.isNotEmpty
                  ? 'Update Driver'.tr
                  : 'Create Driver'.tr),
            ),
            body: controller.isLoading.value
                ? Constant.loader()
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Service".tr,
                                      style: TextStyle(
                                          fontFamily: AppThemeData.semiBold,
                                          fontSize: 14,
                                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                                    ),
                                    const SizedBox(height: 5),
                                    DropdownButtonFormField<String>(
                                      hint: Text(
                                        'Service Type'.tr,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? AppThemeData.grey700 : AppThemeData.grey700,
                                            fontFamily: AppThemeData.regular),
                                      ),
                                      icon: const Icon(Icons.keyboard_arrow_down),
                                      dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                      decoration: InputDecoration(
                                        errorStyle: const TextStyle(color: Colors.red),
                                        isDense: true,
                                        filled: true,
                                        fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide:
                                              BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400, width: 1.2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Colors.red),
                                        ),
                                        disabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                                        ),
                                      ),
                                      initialValue: controller.selectedService.value.isEmpty ? null : controller.selectedService.value,
                                      onChanged: (value) {
                                        controller.selectedService.value = value!;
                                        if (value != "Delivery Service") {
                                          controller.getSection();
                                        }
                                        controller.update();
                                      },
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                          fontFamily: AppThemeData.medium),
                                      items: controller.service.map((item) {
                                        return DropdownMenuItem<String>(value: item, child: Text(item.toString().tr));
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                                controller.selectedService.value == "Cab Service" ||
                                        controller.selectedService.value == "Rental Service" ||
                                        controller.selectedService.value == "Parcel Service"
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Select section".tr,
                                            style: TextStyle(
                                                fontFamily: AppThemeData.semiBold,
                                                fontSize: 14,
                                                color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                                          ),
                                          const SizedBox(height: 5),
                                          DropdownButtonFormField<SectionModel>(
                                            hint: Text(
                                              'Service Type'.tr,
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: isDark ? AppThemeData.grey700 : AppThemeData.grey700,
                                                  fontFamily: AppThemeData.regular),
                                            ),
                                            icon: const Icon(Icons.keyboard_arrow_down),
                                            dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                            decoration: InputDecoration(
                                              errorStyle: const TextStyle(color: Colors.red),
                                              isDense: true,
                                              filled: true,
                                              fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide:
                                                    BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400, width: 1.2),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Colors.red),
                                              ),
                                              disabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                                              ),
                                            ),
                                            initialValue:
                                                controller.selectedSection.value.id == null ? null : controller.selectedSection.value,
                                            onChanged: (value) {
                                              controller.selectedSection.value = value!;
                                              controller.getVehicleType();
                                              controller.update();
                                            },
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                fontFamily: AppThemeData.medium),
                                            items: controller.sectionList.map((item) {
                                              return DropdownMenuItem<SectionModel>(value: item, child: Text(item.name.toString()));
                                            }).toList(),
                                          ),
                                          const SizedBox(height: 10),
                                          controller.selectedService.value == "Cab Service" ||
                                                  controller.selectedService.value == "Rental Service"
                                              ? Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Select Vehicle Type".tr,
                                                      style: TextStyle(
                                                          fontFamily: AppThemeData.semiBold,
                                                          fontSize: 14,
                                                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    DropdownButtonFormField<VehicleType>(
                                                      hint: Text(
                                                        'Vehicle Type'.tr,
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            color: isDark ? AppThemeData.grey700 : AppThemeData.grey700,
                                                            fontFamily: AppThemeData.regular),
                                                      ),
                                                      icon: const Icon(Icons.keyboard_arrow_down),
                                                      dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                                      decoration: InputDecoration(
                                                        errorStyle: const TextStyle(color: Colors.red),
                                                        isDense: true,
                                                        filled: true,
                                                        fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide:
                                                              BorderSide(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                        ),
                                                        enabledBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide:
                                                              BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: BorderSide(
                                                              color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400, width: 1.2),
                                                        ),
                                                        errorBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: const BorderSide(color: Colors.red),
                                                        ),
                                                        disabledBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide:
                                                              BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                                                        ),
                                                      ),
                                                      initialValue: controller.selectedVehicleType.value.id == null
                                                          ? null
                                                          : controller.selectedVehicleType.value,
                                                      onChanged: (value) {
                                                        controller.selectedVehicleType.value = value!;
                                                        controller.update();
                                                      },
                                                      style: TextStyle(
                                                          fontSize: 14,
                                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                          fontFamily: AppThemeData.medium),
                                                      items: controller.cabVehicleType.map((item) {
                                                        return DropdownMenuItem<VehicleType>(
                                                            value: item, child: Text(item.name.toString()));
                                                      }).toList(),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      "Select Car Brand".tr,
                                                      style: TextStyle(
                                                          fontFamily: AppThemeData.semiBold,
                                                          fontSize: 14,
                                                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    DropdownButtonFormField<CarMakes>(
                                                      hint: Text(
                                                        'Car Brand'.tr,
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            color: isDark ? AppThemeData.grey700 : AppThemeData.grey700,
                                                            fontFamily: AppThemeData.regular),
                                                      ),
                                                      icon: const Icon(Icons.keyboard_arrow_down),
                                                      dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                                      decoration: InputDecoration(
                                                        errorStyle: const TextStyle(color: Colors.red),
                                                        isDense: true,
                                                        filled: true,
                                                        fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide:
                                                              BorderSide(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                        ),
                                                        enabledBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide:
                                                              BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: BorderSide(
                                                              color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400, width: 1.2),
                                                        ),
                                                        errorBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: const BorderSide(color: Colors.red),
                                                        ),
                                                        disabledBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide:
                                                              BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                                                        ),
                                                      ),
                                                      initialValue: controller.selectedCarMakes.value.id == null
                                                          ? null
                                                          : controller.selectedCarMakes.value,
                                                      onChanged: (value) {
                                                        controller.selectedCarMakes.value = value!;
                                                        controller.getCarModel();
                                                        controller.update();
                                                      },
                                                      style: TextStyle(
                                                          fontSize: 14,
                                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                          fontFamily: AppThemeData.medium),
                                                      items: controller.carMakesList.map((item) {
                                                        return DropdownMenuItem<CarMakes>(value: item, child: Text(item.name.toString()));
                                                      }).toList(),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      "Select car model".tr,
                                                      style: TextStyle(
                                                          fontFamily: AppThemeData.semiBold,
                                                          fontSize: 14,
                                                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    DropdownButtonFormField<CarModel>(
                                                      hint: Text(
                                                        'Car model'.tr,
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            color: isDark ? AppThemeData.grey700 : AppThemeData.grey700,
                                                            fontFamily: AppThemeData.regular),
                                                      ),
                                                      icon: const Icon(Icons.keyboard_arrow_down),
                                                      dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                                      decoration: InputDecoration(
                                                        errorStyle: const TextStyle(color: Colors.red),
                                                        isDense: true,
                                                        filled: true,
                                                        fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide:
                                                              BorderSide(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                        ),
                                                        enabledBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide:
                                                              BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: BorderSide(
                                                              color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400, width: 1.2),
                                                        ),
                                                        errorBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: const BorderSide(color: Colors.red),
                                                        ),
                                                        disabledBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide:
                                                              BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                                                        ),
                                                      ),
                                                      initialValue: controller.selectedCarModel.value.id == null
                                                          ? null
                                                          : controller.selectedCarModel.value,
                                                      onChanged: (value) {
                                                        controller.selectedCarModel.value = value!;
                                                        controller.update();
                                                      },
                                                      style: TextStyle(
                                                          fontSize: 14,
                                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                          fontFamily: AppThemeData.medium),
                                                      items: controller.carModelList.map((item) {
                                                        return DropdownMenuItem<CarModel>(value: item, child: Text(item.name.toString()));
                                                      }).toList(),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    TextFieldWidget(
                                                      title: 'Car Plat Number'.tr,
                                                      controller: controller.carPlatNumberEditingController.value,
                                                      hintText: 'Enter Car Plat Number'.tr,
                                                      textInputAction: TextInputAction.next,
                                                    ),
                                                  ],
                                                )
                                              : SizedBox()
                                        ],
                                      )
                                    : SizedBox(),
                                controller.selectedService.value == "Cab Service"
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 10, bottom: 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Select Ride Type".tr,
                                              style: TextStyle(
                                                fontFamily: AppThemeData.semiBold,
                                                fontSize: 14,
                                                color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Obx(
                                              () => Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  Expanded(
                                                    child: RadioListTile<String>(
                                                      dense: true,
                                                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                                                      contentPadding: EdgeInsets.zero,
                                                      title: Text('Ride'.tr,
                                                          style: TextStyle(
                                                              fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800)),
                                                      value: 'ride',
                                                      activeColor: AppThemeData.primary300,
                                                      groupValue: controller.selectedValue.value,
                                                      onChanged: (value) {
                                                        controller.selectedValue.value = value!;
                                                      },
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: RadioListTile<String>(
                                                      dense: true,
                                                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                                                      contentPadding: EdgeInsets.zero,
                                                      activeColor: AppThemeData.primary300,
                                                      title: Text('Intercity'.tr,
                                                          style: TextStyle(
                                                              fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800)),
                                                      value: 'intercity',
                                                      groupValue: controller.selectedValue.value,
                                                      onChanged: (value) {
                                                        controller.selectedValue.value = value!;
                                                      },
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: RadioListTile<String>(
                                                      dense: true,
                                                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                                                      contentPadding: EdgeInsets.zero,
                                                      title: Text('Both'.tr,
                                                          style: TextStyle(
                                                              fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800)),
                                                      value: 'both',
                                                      activeColor: AppThemeData.primary300,
                                                      groupValue: controller.selectedValue.value,
                                                      onChanged: (value) {
                                                        controller.selectedValue.value = value!;
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      )
                                    : SizedBox(),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Zone".tr,
                                        style: TextStyle(
                                            fontFamily: AppThemeData.semiBold,
                                            fontSize: 14,
                                            color: isDark ? AppThemeData.grey100 : AppThemeData.grey800)),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    DropdownButtonFormField<ZoneModel>(
                                        hint: Text(
                                          'Select zone'.tr,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? AppThemeData.grey700 : AppThemeData.grey700,
                                            fontFamily: AppThemeData.regular,
                                          ),
                                        ),
                                        dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                        decoration: InputDecoration(
                                          errorStyle: const TextStyle(color: Colors.red),
                                          isDense: true,
                                          filled: true,
                                          fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide:
                                                BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400, width: 1.2),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide:
                                                BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400, width: 1.2),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide:
                                                BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400, width: 1.2),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.red),
                                          ),
                                          disabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide:
                                                BorderSide(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400, width: 1.2),
                                          ),
                                        ),
                                        initialValue: controller.selectedZone.value.id == null ? null : controller.selectedZone.value,
                                        onChanged: (value) {
                                          controller.selectedZone.value = value!;
                                          controller.update();
                                        },
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                            fontFamily: AppThemeData.medium),
                                        items: controller.zoneList.map((item) {
                                          return DropdownMenuItem<ZoneModel>(
                                            value: item,
                                            child: Text(item.name.toString()),
                                          );
                                        }).toList()),
                                  ],
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFieldWidget(
                                        title: 'First Name'.tr,
                                        controller: controller.firstNameEditingController.value,
                                        hintText: 'Enter First Name'.tr,
                                        prefix: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: SvgPicture.asset(
                                            "assets/icons/ic_user.svg",
                                            colorFilter: ColorFilter.mode(
                                              isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    Expanded(
                                      child: TextFieldWidget(
                                        title: 'Last Name'.tr,
                                        controller: controller.lastNameEditingController.value,
                                        hintText: 'Enter Last Name'.tr,
                                        prefix: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: SvgPicture.asset(
                                            "assets/icons/ic_user.svg",
                                            colorFilter: ColorFilter.mode(
                                              isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                TextFieldWidget(
                                  title: 'Email Address'.tr,
                                  textInputType: TextInputType.emailAddress,
                                  controller: controller.emailEditingController.value,
                                  hintText: 'Enter Email Address'.tr,
                                  enable:
                                      controller.driverModel.value.id != null && controller.driverModel.value.id!.isNotEmpty ? false : true,
                                  prefix: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SvgPicture.asset(
                                      "assets/icons/ic_mail.svg",
                                      colorFilter: ColorFilter.mode(
                                        isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                                TextFieldWidget(
                                  title: 'Phone Number'.tr,
                                  controller: controller.phoneNUmberEditingController.value,
                                  hintText: 'Enter Phone Number'.tr,
                                  textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                                  ],
                                  prefix: CountryCodePicker(
                                    onChanged: (value) {
                                      controller.countryCodeEditingController.value.text = value.dialCode ?? Constant.defaultCountryCode;
                                    },
                                    dialogTextStyle: TextStyle(
                                        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: AppThemeData.medium),
                                    dialogBackgroundColor: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                    initialSelection: controller.countryCodeEditingController.value.text,
                                    comparator: (a, b) => b.name!.compareTo(a.name.toString()),
                                    textStyle: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                        fontFamily: AppThemeData.medium),
                                    searchDecoration: InputDecoration(iconColor: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                                    searchStyle: TextStyle(
                                        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: AppThemeData.medium),
                                  ),
                                ),
                                controller.driverModel.value.id != null && controller.driverModel.value.id!.isNotEmpty
                                    ? SizedBox()
                                    : Column(
                                        children: [
                                          TextFieldWidget(
                                            title: 'Password'.tr,
                                            controller: controller.passwordEditingController.value,
                                            hintText: 'Enter Password'.tr,
                                            obscureText: controller.passwordVisible.value,
                                            prefix: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: SvgPicture.asset(
                                                "assets/icons/ic_lock.svg",
                                                colorFilter: ColorFilter.mode(
                                                  isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                  BlendMode.srcIn,
                                                ),
                                              ),
                                            ),
                                            suffix: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: InkWell(
                                                  onTap: () {
                                                    controller.passwordVisible.value = !controller.passwordVisible.value;
                                                  },
                                                  child: controller.passwordVisible.value
                                                      ? SvgPicture.asset(
                                                          "assets/icons/ic_password_show.svg",
                                                          colorFilter: ColorFilter.mode(
                                                            isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                            BlendMode.srcIn,
                                                          ),
                                                        )
                                                      : SvgPicture.asset(
                                                          "assets/icons/ic_password_close.svg",
                                                          colorFilter: ColorFilter.mode(
                                                            isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                            BlendMode.srcIn,
                                                          ),
                                                        )),
                                            ),
                                          ),
                                          TextFieldWidget(
                                            title: 'Confirm Password'.tr,
                                            controller: controller.conformPasswordEditingController.value,
                                            hintText: 'Enter Confirm Password'.tr,
                                            obscureText: controller.conformPasswordVisible.value,
                                            prefix: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: SvgPicture.asset(
                                                "assets/icons/ic_lock.svg",
                                                colorFilter: ColorFilter.mode(
                                                  isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                  BlendMode.srcIn,
                                                ),
                                              ),
                                            ),
                                            suffix: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: InkWell(
                                                  onTap: () {
                                                    controller.conformPasswordVisible.value = !controller.conformPasswordVisible.value;
                                                  },
                                                  child: controller.conformPasswordVisible.value
                                                      ? SvgPicture.asset(
                                                          "assets/icons/ic_password_show.svg",
                                                          colorFilter: ColorFilter.mode(
                                                            isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                            BlendMode.srcIn,
                                                          ),
                                                        )
                                                      : SvgPicture.asset(
                                                          "assets/icons/ic_password_close.svg",
                                                          colorFilter: ColorFilter.mode(
                                                            isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                            BlendMode.srcIn,
                                                          ),
                                                        )),
                                            ),
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          if (controller.firstNameEditingController.value.text.isEmpty) {
                            ShowToastDialog.showToast("Please enter first name".tr);
                            return;
                          } else if (controller.lastNameEditingController.value.text.isEmpty) {
                            ShowToastDialog.showToast("Please enter last name".tr);
                            return;
                          } else if (controller.emailEditingController.value.text.isEmpty) {
                            ShowToastDialog.showToast("Please enter email address".tr);
                            return;
                          } else if (!GetUtils.isEmail(controller.emailEditingController.value.text)) {
                            ShowToastDialog.showToast("Please enter valid email address".tr);
                            return;
                          } else if (controller.phoneNUmberEditingController.value.text.isEmpty) {
                            ShowToastDialog.showToast("Please enter phone number".tr);
                            return;
                          } else if (controller.selectedZone.value.id == null) {
                            ShowToastDialog.showToast("Please select zone".tr);
                            return;
                          }

                          // Fix: use OR (||) instead of AND (&&)
                          if ((controller.driverModel.value.id == null || controller.driverModel.value.id!.isEmpty) &&
                              controller.passwordEditingController.value.text.isEmpty) {
                            ShowToastDialog.showToast("Please enter password".tr);
                            return;
                          } else if ((controller.driverModel.value.id == null || controller.driverModel.value.id!.isEmpty) &&
                              controller.passwordEditingController.value.text.length < 6) {
                            ShowToastDialog.showToast("Password must be at least 6 characters".tr);
                            return;
                          } else if ((controller.driverModel.value.id == null || controller.driverModel.value.id!.isEmpty) &&
                              controller.conformPasswordEditingController.value.text.isEmpty) {
                            ShowToastDialog.showToast("Please enter confirm password".tr);
                            return;
                          } else if (controller.passwordEditingController.value.text !=
                              controller.conformPasswordEditingController.value.text) {
                            ShowToastDialog.showToast("Password and confirm password do not match".tr);
                            return;
                          }

                          //Vehicle validation if service is NOT Parcel Service
                          if (controller.selectedService.value != "Parcel Service") {
                            if (controller.selectedVehicleType.value.id == null) {
                              ShowToastDialog.showToast("Please select vehicle type".tr);
                              return;
                            } else if (controller.selectedCarMakes.value.id == null) {
                              ShowToastDialog.showToast("Please select car brand".tr);
                              return;
                            } else if (controller.selectedCarModel.value.id == null) {
                              ShowToastDialog.showToast("Please select car model".tr);
                              return;
                            } else if (controller.carPlatNumberEditingController.value.text.isEmpty) {
                              ShowToastDialog.showToast("Please enter car plat number".tr);
                              return;
                            } else {
                              //Will work now
                              print("plz come..............");
                              controller.signUp();
                            }
                          } else {
                            //Parcel Service signup
                            print("plz come signUp ..............");
                            controller.signUp();
                          }
                        },
                        child: Container(
                          color: AppThemeData.primary300,
                          width: Responsive.width(100, context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Save'.tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
                                fontSize: 16,
                                fontFamily: AppThemeData.medium,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
          );
        });
  }
}
