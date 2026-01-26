import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/owner_order_list_controller.dart';
import '../../models/cab_order_model.dart';
import '../../models/rental_order_model.dart';
import '../../models/user_model.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../cab_screen/cab_order_details.dart';
import '../parcel_screen/parcel_order_details.dart';
import '../rental_service/rental_order_details_screen.dart';
import '../../themes/theme_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OwnerOrderListScreen extends StatelessWidget {
  const OwnerOrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<OwnerOrderListController>(
      init: OwnerOrderListController(),
      builder: (controller) {
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Select Service Type".tr,
                    style: TextStyle(
                        color: isDark
                            ? AppThemeData.grey50
                            : AppThemeData.greyDark50)),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  initialValue: controller.selectedService.value,
                  style: TextStyle(
                    color: themeController.isDark.value
                        ? AppThemeData.grey50
                        : AppThemeData.grey900,
                    fontFamily: AppThemeData.semiBold,
                  ),
                  dropdownColor: themeController.isDark.value
                      ? AppThemeData.grey800
                      : AppThemeData.grey50,
                  items: controller.serviceList.map((service) {
                    return DropdownMenuItem<String>(
                      value: service,
                      child: Text(
                        service,
                        style: TextStyle(
                          color: themeController.isDark.value
                              ? AppThemeData.grey50
                              : AppThemeData.grey900,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    controller.selectedService.value = value!;
                    controller.selectedDriver.value = null;
                    controller.isDriverSelected.value = false;
                  },
                  decoration: _dropdownDecoration(themeController.isDark.value),
                ),
                const SizedBox(height: 16),
                Text("Select Driver".tr,
                    style: TextStyle(
                        color: isDark
                            ? AppThemeData.grey50
                            : AppThemeData.greyDark50)),
                const SizedBox(height: 5),
                Obx(() => DropdownButtonFormField<UserModel?>(
                      initialValue: controller.selectedDriver.value,
                      hint: Text("Select Driver".tr,
                          style: TextStyle(
                            color: themeController.isDark.value
                                ? AppThemeData.grey50
                                : AppThemeData.grey900,
                            fontFamily: AppThemeData.semiBold,
                          )),
                      items: [
                        DropdownMenuItem<UserModel?>(
                          value: null,
                          child: Text("All Drivers".tr),
                        ),
                        ...controller.filteredDrivers.map((driver) {
                          return DropdownMenuItem<UserModel?>(
                            value: driver,
                            child: Text(
                              "${driver.firstName ?? ''} ${driver.lastName ?? ''}",
                              style: TextStyle(
                                color: themeController.isDark.value
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900,
                              ),
                            ),
                          );
                        }),
                      ],
                      onChanged: (UserModel? value) {
                        controller.selectedDriver.value = value;
                      },
                      dropdownColor:
                          isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                      decoration:
                          _dropdownDecoration(themeController.isDark.value),
                    )),
                const SizedBox(height: 16),

                // --- Search Button ---
                RoundedButtonFill(
                  title: "Search",
                  height: 5.5,
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey50,
                  onPress: controller.searchOrders,
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: Obx(() {
                    switch (controller.serviceKey.value) {
                      case 'cab-service':
                        return cabListView(controller, isDark);
                      case 'parcel_delivery':
                        return parcleListView(controller, isDark);
                      case 'rental-service':
                        return rentalListView(controller, isDark);
                      default:
                        return Center(
                            child: Text("Service type not supported".tr));
                    }
                  }),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _dropdownDecoration(bool isDark) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: isDark ? AppThemeData.grey800 : AppThemeData.grey50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppThemeData.primary300, width: 1.2),
      ),
    );
  }

  DefaultTabController cabListView(
      OwnerOrderListController controller, bool isDark) {
    return DefaultTabController(
      length: controller.cabTabTitles.length,
      initialIndex:
          controller.cabTabTitles.indexOf(controller.cabSelectedTab.value),
      child: Column(
        children: [
          // TabBar
          TabBar(
            onTap: (index) {
              controller.cabSelectedTab(controller.cabTabTitles[index]);
            },
            // isScrollable: true,
            indicatorColor: AppThemeData.primary300,
            labelColor: AppThemeData.primary300,
            dividerColor: Colors.transparent,
            unselectedLabelColor: AppThemeData.primary300.withOpacity(0.60),
            labelStyle: AppThemeData.boldTextStyle(fontSize: 14),
            unselectedLabelStyle: AppThemeData.mediumTextStyle(fontSize: 14),
            tabs: controller.cabTabTitles
                .map((title) => Tab(child: Center(child: Text(title))))
                .toList(),
          ),

          // Body: loader or TabBarView
          Expanded(
            child: controller.isLoadingCab.value
                ? Constant.loader()
                : TabBarView(
                    children: controller.cabTabTitles.map((title) {
                      final orders = controller.getCabOrdersForTab(title);

                      if (orders.isEmpty) {
                        return Center(
                          child: Text(
                            "No orders found".tr,
                            style: AppThemeData.mediumTextStyle(
                                color: isDark
                                    ? AppThemeData.greyDark900
                                    : AppThemeData.grey900),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 10),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          CabOrderModel order = orders[index];
                          return GestureDetector(
                            onTap: () {
                              Get.to(() => CabOrderDetails(),
                                  arguments: {"cabOrderModel": order});
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppThemeData.greyDark50
                                    : AppThemeData.grey50,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                    color: isDark
                                        ? AppThemeData.greyDark200
                                        : AppThemeData.grey200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Icon(Icons.stop_circle_outlined,
                                          color: AppThemeData.primary300),
                                      DottedBorder(
                                        options: CustomPathDottedBorderOptions(
                                          color: Colors.grey.shade400,
                                          strokeWidth: 2,
                                          dashPattern: [4, 4],
                                          customPath: (size) => Path()
                                            ..moveTo(size.width / 2, 0)
                                            ..lineTo(
                                                size.width / 2, size.height),
                                        ),
                                        child: const SizedBox(
                                            width: 20, height: 55),
                                      ),
                                      Icon(Icons.radio_button_checked,
                                          color: Colors.red),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            // Source Location Name
                                            Expanded(
                                              child: Text(
                                                order.sourceLocationName
                                                    .toString(),
                                                style: AppThemeData
                                                    .semiBoldTextStyle(
                                                        fontSize: 16,
                                                        color: isDark
                                                            ? AppThemeData
                                                                .greyDark900
                                                            : AppThemeData
                                                                .grey900),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                    color:
                                                        AppThemeData.warning300,
                                                    width: 1),
                                                color: AppThemeData.warning50,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 12),
                                              child: Text(
                                                order.status.toString(),
                                                style:
                                                    AppThemeData.boldTextStyle(
                                                        fontSize: 14,
                                                        color: AppThemeData
                                                            .warning500),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 15),
                                        DottedBorder(
                                          options:
                                              CustomPathDottedBorderOptions(
                                            color: Colors.grey.shade400,
                                            strokeWidth: 2,
                                            dashPattern: [4, 4],
                                            customPath: (size) => Path()
                                              ..moveTo(
                                                  0,
                                                  size.height /
                                                      2) // start from left center
                                              ..lineTo(
                                                  size.width,
                                                  size.height /
                                                      2), // draw to right center
                                          ),
                                          child: const SizedBox(
                                              width: 295, height: 3),
                                        ),
                                        SizedBox(height: 15),
                                        Text(
                                          order.destinationLocationName
                                              .toString(),
                                          style: AppThemeData.semiBoldTextStyle(
                                              fontSize: 16,
                                              color: isDark
                                                  ? AppThemeData.greyDark900
                                                  : AppThemeData.grey900),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  DefaultTabController parcleListView(
      OwnerOrderListController controller, bool isDark) {
    return DefaultTabController(
      length: controller.parcelTabTitles.length,
      initialIndex: controller.parcelTabTitles
          .indexOf(controller.parcelSelectedTab.value),
      child: Column(
        children: [
          // TabBar
          TabBar(
            onTap: (index) {
              controller.parcelSelectedTab(controller.parcelTabTitles[index]);
            },
            indicatorColor: AppThemeData.parcelService500,
            labelColor: AppThemeData.parcelService500,
            dividerColor: Colors.transparent,
            unselectedLabelColor: AppThemeData.grey500,
            labelStyle: AppThemeData.boldTextStyle(fontSize: 16),
            unselectedLabelStyle: AppThemeData.mediumTextStyle(fontSize: 16),
            tabs: controller.parcelTabTitles
                .map((title) => Tab(child: Text(title)))
                .toList(),
          ),

          // Body: loader or TabBarView
          Expanded(
            child: controller.isLoadingParcel.value
                ? Constant.loader()
                : TabBarView(
                    children: controller.parcelTabTitles.map((title) {
                      // filter by tab using controller helper
                      final orders = controller.getParcelOrdersForTab(title);

                      if (orders.isEmpty) {
                        return Center(
                          child: Text(
                            "No orders found".tr,
                            style: AppThemeData.mediumTextStyle(
                                color: isDark
                                    ? AppThemeData.greyDark900
                                    : AppThemeData.grey900),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 10),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return GestureDetector(
                            onTap: () {
                              Get.to(() => const ParcelOrderDetails(),
                                  arguments: order);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppThemeData.greyDark50
                                    : AppThemeData.grey50,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isDark
                                      ? AppThemeData.greyDark200
                                      : AppThemeData.grey200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(
                                      "Order Date:${order.isSchedule == true ? controller.formatDate(order.createdAt!) : controller.formatDate(order.senderPickupDateTime!)}",
                                      style: AppThemeData.mediumTextStyle(
                                          fontSize: 14,
                                          color: AppThemeData.info400),
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        children: [
                                          Image.asset(
                                              "assets/images/image_parcel.png",
                                              height: 32,
                                              width: 32),
                                          DottedBorder(
                                            options:
                                                CustomPathDottedBorderOptions(
                                              color: Colors.grey.shade400,
                                              strokeWidth: 2,
                                              dashPattern: [4, 4],
                                              customPath: (size) => Path()
                                                ..moveTo(size.width / 2, 0)
                                                ..lineTo(size.width / 2,
                                                    size.height),
                                            ),
                                            child: const SizedBox(
                                                width: 20, height: 95),
                                          ),
                                          Image.asset(
                                              "assets/images/image_parcel.png",
                                              height: 32,
                                              width: 32),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _infoSection(
                                              "Pickup Address (Sender):".tr,
                                              order.sender?.name ?? '',
                                              order.sender?.address ?? '',
                                              order.sender?.phone ?? '',
                                              // order.senderPickupDateTime != null
                                              //     ? "Pickup Time: ${controller.formatDate(order.senderPickupDateTime!)}"
                                              //     : '',
                                              order.status,
                                              isDark,
                                            ),
                                            const SizedBox(height: 16),
                                            _infoSection(
                                              "Delivery Address (Receiver):".tr,
                                              order.receiver?.name ?? '',
                                              order.receiver?.address ?? '',
                                              order.receiver?.phone ?? '',
                                              // order.receiverPickupDateTime != null
                                              //     ? "Delivery Time: ${controller.formatDate(order.receiverPickupDateTime!)}"
                                              //     : '',
                                              null,
                                              isDark,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, String name, String address, String phone,
      String? status, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppThemeData.semiBoldTextStyle(
                    fontSize: 16,
                    color: isDark
                        ? AppThemeData.greyDark900
                        : AppThemeData.grey900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (status != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppThemeData.info50,
                  border: Border.all(color: AppThemeData.info300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status,
                    style: AppThemeData.boldTextStyle(
                        fontSize: 14, color: AppThemeData.info500)),
              ),
            ],
          ],
        ),
        Text(name,
            style: AppThemeData.semiBoldTextStyle(
                fontSize: 14,
                color:
                    isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        Text(address,
            style: AppThemeData.mediumTextStyle(
                fontSize: 14,
                color:
                    isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        Text(phone,
            style: AppThemeData.mediumTextStyle(
                fontSize: 14,
                color:
                    isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        //Text(time, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
      ],
    );
  }

  DefaultTabController rentalListView(
      OwnerOrderListController controller, bool isDark) {
    return DefaultTabController(
      length: controller.rentalTabTitles.length,
      initialIndex: controller.rentalTabTitles
          .indexOf(controller.rentalSelectedTab.value),
      child: Column(
        children: [
          // TabBar
          TabBar(
            onTap: (index) {
              controller.rentalSelectedTab(controller.rentalTabTitles[index]);
            },
            indicatorColor: AppThemeData.parcelService500,
            labelColor: AppThemeData.parcelService500,
            dividerColor: Colors.transparent,
            unselectedLabelColor: AppThemeData.grey500,
            labelStyle: AppThemeData.boldTextStyle(fontSize: 16),
            unselectedLabelStyle: AppThemeData.mediumTextStyle(fontSize: 16),
            tabs: controller.rentalTabTitles
                .map((title) => Tab(child: Text(title)))
                .toList(),
          ),

          // Body: loader or TabBarView
          Expanded(
            child: controller.isLoadingRental.value
                ? Constant.loader()
                : TabBarView(
                    children: controller.rentalTabTitles.map((title) {
                      // filter by tab using controller helper
                      final orders = controller.getRentalOrdersForTab(title);

                      if (orders.isEmpty) {
                        return Center(
                          child: Text(
                            "No orders found".tr,
                            style: AppThemeData.mediumTextStyle(
                                color: isDark
                                    ? AppThemeData.greyDark900
                                    : AppThemeData.grey900),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 10),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          RentalOrderModel order = orders[index]; //use this
                          return InkWell(
                            onTap: () {
                              Get.to(() => RentalOrderDetailsScreen(),
                                  arguments: {"rentalOrder": order.id});
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color: isDark
                                    ? AppThemeData.greyDark50
                                    : AppThemeData.grey50,
                                border: Border.all(
                                    color: isDark
                                        ? AppThemeData.greyDark200
                                        : AppThemeData.grey200),
                              ),
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 5),
                                          child: Image.asset(
                                              "assets/icons/pickup.png",
                                              height: 18,
                                              width: 18)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        //prevents overflow
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  //text wraps if too long
                                                  child: Text(
                                                    order.sourceLocationName ??
                                                        "-",
                                                    style: AppThemeData
                                                        .semiBoldTextStyle(
                                                            fontSize: 16,
                                                            color: isDark
                                                                ? AppThemeData
                                                                    .greyDark900
                                                                : AppThemeData
                                                                    .grey900),
                                                    overflow: TextOverflow
                                                        .ellipsis, //safe cutoff
                                                    maxLines: 2,
                                                  ),
                                                ),
                                                if (order.status != null) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 6,
                                                        horizontal: 12),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          AppThemeData.info50,
                                                      border: Border.all(
                                                          color: AppThemeData
                                                              .info300),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Text(
                                                        order.status ?? '',
                                                        style: AppThemeData
                                                            .boldTextStyle(
                                                                fontSize: 14,
                                                                color: AppThemeData
                                                                    .info500)),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (order.bookingDateTime != null)
                                              Text(
                                                Constant.timestampToDateTime(
                                                    order.bookingDateTime!),
                                                style: AppThemeData
                                                    .mediumTextStyle(
                                                        fontSize: 12,
                                                        color: isDark
                                                            ? AppThemeData
                                                                .greyDark600
                                                            : AppThemeData
                                                                .grey600),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text("Vehicle Type :".tr,
                                      style: AppThemeData.boldTextStyle(
                                          fontSize: 16,
                                          color: isDark
                                              ? AppThemeData.greyDark900
                                              : AppThemeData.grey900)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 10),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                            imageUrl: order.rentalVehicleType
                                                    ?.rentalVehicleIcon ??
                                                Constant.placeHolderImage,
                                            height: 60,
                                            width: 60,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Center(
                                              child: CircularProgressIndicator
                                                  .adaptive(
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        AppThemeData
                                                            .primary300),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Image.network(
                                              Constant.placeHolderImage,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "${order.rentalVehicleType!.name}",
                                                  style: AppThemeData
                                                      .semiBoldTextStyle(
                                                          fontSize: 18,
                                                          color: isDark
                                                              ? AppThemeData
                                                                  .greyDark900
                                                              : AppThemeData
                                                                  .grey900),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 2.0),
                                                  child: Text(
                                                    "${order.rentalVehicleType!.shortDescription}",
                                                    style: AppThemeData
                                                        .mediumTextStyle(
                                                            fontSize: 14,
                                                            color: isDark
                                                                ? AppThemeData
                                                                    .greyDark600
                                                                : AppThemeData
                                                                    .grey600),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text("Package info :".tr,
                                      style: AppThemeData.boldTextStyle(
                                          fontSize: 16,
                                          color: isDark
                                              ? AppThemeData.greyDark900
                                              : AppThemeData.grey900)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 10),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                order.rentalPackageModel!.name
                                                    .toString(),
                                                style: AppThemeData
                                                    .semiBoldTextStyle(
                                                        fontSize: 18,
                                                        color: isDark
                                                            ? AppThemeData
                                                                .greyDark900
                                                            : AppThemeData
                                                                .grey900),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                order.rentalPackageModel!
                                                    .description
                                                    .toString(),
                                                style: AppThemeData
                                                    .mediumTextStyle(
                                                        fontSize: 14,
                                                        color: isDark
                                                            ? AppThemeData
                                                                .greyDark600
                                                            : AppThemeData
                                                                .grey600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          Constant.amountShow(
                                              amount: order
                                                  .rentalPackageModel!.baseFare
                                                  .toString()),
                                          style: AppThemeData.boldTextStyle(
                                              fontSize: 18,
                                              color: isDark
                                                  ? AppThemeData.greyDark900
                                                  : AppThemeData.grey900),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
