import 'package:driver/models/car_makes.dart';
import 'package:driver/models/car_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_widget.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/vehicle_information_controller.dart';

class VehicleInformationScreen extends StatelessWidget {
  const VehicleInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetBuilder<VehicleInformationController>(
        init: VehicleInformationController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: controller.isLoading.value
                  ? Constant.loader()
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          buildDropdown<String>(
                            context: context,
                            title: "Service".tr,
                            value: controller.selectedService.value,
                            items: controller.service,
                            isDark: isDark,
                            enabled:
                                controller.userModel.value.ownerId != null && controller.userModel.value.ownerId!.isNotEmpty ? false : true,
                            // keep true for theme styling
                            absorb: true,
                            // new param
                            onChanged: (value) async {
                              if (controller.userModel.value.isOwner == false) {
                                controller.selectedService.value = value!;
                                await controller.getSection();
                                controller.update();
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          buildDropdown<SectionModel>(
                            context: context,
                            title: "Select Section".tr,
                            value: controller.selectedSection.value,
                            items: controller.sectionList,
                            isDark: isDark,
                            enabled:
                                controller.userModel.value.ownerId != null && controller.userModel.value.ownerId!.isNotEmpty ? false : true,
                            // theme visible
                            absorb: true,
                            // make non-editable
                            onChanged: (value) {
                              if (controller.userModel.value.isOwner == false) {
                                controller.selectedSection.value = value!;
                                controller.getVehicleType(controller.selectedSection.value.id.toString());
                                controller.update();
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          buildDropdown<VehicleType>(
                            context: context,
                            title: "Select Vehicle Type".tr,
                            value: controller.selectedVehicleType.value,
                            items: controller.cabVehicleType,
                            isDark: isDark,
                            enabled:
                                controller.userModel.value.ownerId != null && controller.userModel.value.ownerId!.isNotEmpty ? false : true,
                            onChanged: (value) {
                              controller.selectedVehicleType.value = value!;
                              controller.update();
                            },
                          ),
                          const SizedBox(height: 10),
                          buildDropdown<CarMakes>(
                            context: context,
                            title: "Select Car Brand".tr,
                            value: controller.selectedCarMakes.value,
                            items: controller.carMakesList,
                            isDark: isDark,
                            enabled:
                                controller.userModel.value.ownerId != null && controller.userModel.value.ownerId!.isNotEmpty ? false : true,
                            onChanged: (value) {
                              controller.selectedCarMakes.value = value!;
                              controller.getCarModel();
                              controller.update();
                            },
                          ),
                          const SizedBox(height: 10),
                          buildDropdown<CarModel>(
                            context: context,
                            title: "Select Car Model".tr,
                            value: controller.selectedCarModel.value,
                            items: controller.carModelList,
                            isDark: isDark,
                            enabled:
                                controller.userModel.value.ownerId != null && controller.userModel.value.ownerId!.isNotEmpty ? false : true,
                            onChanged: (value) {
                              controller.selectedCarModel.value = value!;
                              controller.update();
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFieldWidget(
                            title: 'Car Plat Number'.tr,
                            controller: controller.carPlatNumberEditingController.value,
                            hintText: 'Enter Car Plat Number'.tr,
                            textInputAction: TextInputAction.next,
                            enable:
                                controller.userModel.value.ownerId != null && controller.userModel.value.ownerId!.isNotEmpty ? false : true,
                          ),
                          const SizedBox(height: 10),
                          controller.selectedService.value == "Cab Service"
                              ? Column(
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
                                          controller.selectedSection.value.rideType == "both" ||
                                                  controller.selectedSection.value.rideType == "ride"
                                              ? Expanded(
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
                                                )
                                              : SizedBox(),
                                          controller.selectedSection.value.rideType == "both" ||
                                                  controller.selectedSection.value.rideType == "intercity"
                                              ? Expanded(
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
                                                )
                                              : SizedBox(),
                                          controller.selectedSection.value.rideType == "both"
                                              ? Expanded(
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
                                                )
                                              : SizedBox(),
                                        ],
                                      ),
                                    )
                                  ],
                                )
                              : SizedBox.shrink()
                        ],
                      ),
                    ),
            ),
            bottomNavigationBar: controller.userModel.value.ownerId != null && controller.userModel.value.ownerId!.isNotEmpty
                ? const SizedBox.shrink()
                : controller.isLoading.value
                    ? const SizedBox.shrink()
                    : InkWell(
                        onTap: () => controller.saveVehicleInformation(),
                        child: Container(
                          color: AppThemeData.primary300,
                          width: Responsive.width(100, context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              "Save".tr,
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
                      ),
          );
        },
      );
    });
  }

  Widget buildDropdown<T>({
    required BuildContext context,
    required String title,
    required T value,
    required List<T> items,
    required bool isDark,
    required bool enabled,
    bool absorb = false,
    required Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: AppThemeData.semiBold,
            fontSize: 14,
            color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
          ),
        ),
        const SizedBox(height: 5),
        AbsorbPointer(
          absorbing: absorb,
          child: DropdownButtonFormField<T>(
            initialValue: value,
            onChanged: enabled ? onChanged : null,
            isExpanded: true,
            dropdownColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            // 👈 dropdown theme
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              filled: true,
              fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400,
                ),
              ),
            ),
            style: TextStyle(
                fontSize: 14,
                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                fontFamily: AppThemeData.medium),
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
            ),
            items: items.map((item) {
              String text = '';
              if (item is String) text = item;
              if (item is SectionModel) text = item.name ?? '';
              if (item is VehicleType) text = item.name ?? '';
              if (item is CarMakes) text = item.name ?? '';
              if (item is CarModel) text = item.name ?? '';
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  text,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                      fontFamily: AppThemeData.medium),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
