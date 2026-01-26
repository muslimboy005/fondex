import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/product_screens/add_product_screen.dart';
import 'package:vendor/app/verification_screen/verification_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/product_list_controller.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: ProductListController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            title: Text(
              "Manage Products".tr,
              style: TextStyle(
                color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                fontSize: 18,
                fontFamily: AppThemeData.medium,
              ),
            ),
            actions: [
              (Constant.isStoreVerification == true &&
                          controller.userModel.value.isDocumentVerify ==
                              false) ||
                      (controller.userModel.value.vendorID == null ||
                          controller.userModel.value.vendorID!.isEmpty)
                  ? const SizedBox()
                  : InkWell(
                      onTap: () {
                        if ((Constant.isSubscriptionModelApplied == true ||
                                Constant
                                        .selectedSection!
                                        .adminCommision
                                        ?.isEnabled ==
                                    true) &&
                            Constant.userModel?.subscriptionPlan?.itemLimit !=
                                '-1' &&
                            int.parse(
                                  Constant
                                                  .userModel
                                                  ?.subscriptionPlan
                                                  ?.itemLimit !=
                                              null &&
                                          Constant
                                                  .userModel
                                                  ?.subscriptionPlan
                                                  ?.itemLimit
                                                  .toString() !=
                                              "null"
                                      ? "${Constant.userModel?.subscriptionPlan?.itemLimit}"
                                      : '0',
                                ) <=
                                controller.productList.length) {
                          ShowToastDialog.showToast(
                            "Your current subscription plan has reached its maximum product limit. Upgrade now to add more products."
                                .tr,
                          );
                        } else {
                          Get.to(const AddProductScreen())!.then((value) {
                            if (value == true) {
                              controller.getProduct();
                            }
                          });
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add,
                              color: isDark
                                  ? AppThemeData.grey900
                                  : AppThemeData.grey50,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "Add".tr,
                              style: TextStyle(
                                color: isDark
                                    ? AppThemeData.grey900
                                    : AppThemeData.grey50,
                                fontSize: 18,
                                fontFamily: AppThemeData.medium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : Constant.isStoreVerification == true &&
                    controller.userModel.value.isDocumentVerify == false
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: ShapeDecoration(
                          color: isDark
                              ? AppThemeData.grey700
                              : AppThemeData.grey200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(120),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: SvgPicture.asset(
                            "assets/icons/ic_document.svg",
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Document Verification in Pending".tr,
                        style: TextStyle(
                          color: isDark
                              ? AppThemeData.grey100
                              : AppThemeData.grey800,
                          fontSize: 22,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Your documents are being reviewed. We will notify you once the verification is complete."
                            .tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? AppThemeData.grey50
                              : AppThemeData.grey500,
                          fontSize: 16,
                          fontFamily: AppThemeData.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      RoundedButtonFill(
                        title: "View Status".tr,
                        width: 55,
                        height: 5.5,
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey50,
                        onPress: () async {
                          Get.to(const VerificationScreen());
                        },
                      ),
                    ],
                  ),
                )
              : controller.userModel.value.vendorID == null ||
                    controller.userModel.value.vendorID!.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: ShapeDecoration(
                          color: isDark
                              ? AppThemeData.grey700
                              : AppThemeData.grey200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(120),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: SvgPicture.asset(
                            "assets/icons/ic_building_two.svg",
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Add Your First Store".tr,
                        style: TextStyle(
                          color: isDark
                              ? AppThemeData.grey100
                              : AppThemeData.grey800,
                          fontSize: 22,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Get started by adding your store details to manage your menu, orders, and reservations."
                            .tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? AppThemeData.grey50
                              : AppThemeData.grey500,
                          fontSize: 16,
                          fontFamily: AppThemeData.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      RoundedButtonFill(
                        title: "Add Store".tr,
                        width: 55,
                        height: 5.5,
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey50,
                        onPress: () async {
                          Get.to(const AddRestaurantScreen());
                        },
                      ),
                    ],
                  ),
                )
              : controller.productList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: ShapeDecoration(
                          color: isDark
                              ? AppThemeData.grey700
                              : AppThemeData.grey200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(120),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: SvgPicture.asset(
                            "assets/icons/ic_menu.svg",
                            colorFilter: ColorFilter.mode(
                              isDark
                                  ? AppThemeData.grey400
                                  : AppThemeData.grey500,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No Products Available".tr,
                        style: TextStyle(
                          color: isDark
                              ? AppThemeData.grey100
                              : AppThemeData.grey800,
                          fontSize: 22,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Your menu is currently empty. Create your first product to start showcasing your offerings."
                            .tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? AppThemeData.grey50
                              : AppThemeData.grey500,
                          fontSize: 16,
                          fontFamily: AppThemeData.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      RoundedButtonFill(
                        title: "Add Product".tr,
                        width: 55,
                        height: 5.5,
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey50,
                        onPress: () async {
                          if ((Constant.isSubscriptionModelApplied == true ||
                                  Constant
                                          .selectedSection!
                                          .adminCommision
                                          ?.isEnabled ==
                                      true) &&
                              Constant.userModel?.subscriptionPlan?.itemLimit !=
                                  '-1' &&
                              int.parse(
                                    Constant
                                                    .userModel
                                                    ?.subscriptionPlan
                                                    ?.itemLimit !=
                                                null &&
                                            Constant
                                                    .userModel
                                                    ?.subscriptionPlan
                                                    ?.itemLimit
                                                    .toString() !=
                                                "null"
                                        ? "${Constant.userModel?.subscriptionPlan?.itemLimit}"
                                        : '0',
                                  ) <=
                                  controller.productList.length) {
                            ShowToastDialog.showToast(
                              "Your current subscription plan has reached its maximum product limit. Upgrade now to add more products."
                                  .tr,
                            );
                          } else {
                            Get.to(const AddProductScreen())!.then((value) {
                              if (value == true) {
                                controller.getProduct();
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: ListView.builder(
                    itemCount: controller.productList.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      String price = "0.0";
                      String disPrice = "0.0";
                      List<String> selectedVariants = [];
                      List<String> selectedIndexVariants = [];
                      List<String> selectedIndexArray = [];
                      if (controller.productList[index].itemAttribute != null) {
                        if (controller
                            .productList[index]
                            .itemAttribute!
                            .attributes!
                            .isNotEmpty) {
                          for (var element
                              in controller
                                  .productList[index]
                                  .itemAttribute!
                                  .attributes!) {
                            if (element.attributeOptions!.isNotEmpty) {
                              selectedVariants.add(
                                controller
                                    .productList[index]
                                    .itemAttribute!
                                    .attributes![controller
                                        .productList[index]
                                        .itemAttribute!
                                        .attributes!
                                        .indexOf(element)]
                                    .attributeOptions![0]
                                    .toString(),
                              );
                              selectedIndexVariants.add(
                                '${controller.productList[index].itemAttribute!.attributes!.indexOf(element)} _${controller.productList[index].itemAttribute!.attributes![0].attributeOptions![0].toString()}',
                              );
                              selectedIndexArray.add(
                                '${controller.productList[index].itemAttribute!.attributes!.indexOf(element)}_0',
                              );
                            }
                          }
                        }
                        if (controller
                            .productList[index]
                            .itemAttribute!
                            .variants!
                            .where(
                              (element) =>
                                  element.variantSku ==
                                  selectedVariants.join('-'),
                            )
                            .isNotEmpty) {
                          price =
                              controller
                                  .productList[index]
                                  .itemAttribute!
                                  .variants!
                                  .where(
                                    (element) =>
                                        element.variantSku ==
                                        selectedVariants.join('-'),
                                  )
                                  .first
                                  .variantPrice ??
                              '0';
                          disPrice = '0';
                        }
                      } else {
                        price = controller.productList[index].price.toString();
                        disPrice = controller.productList[index].disPrice
                            .toString();
                      }

                      bool isDisplayItemAlert = false;
                      if ((Constant.isSubscriptionModelApplied == true ||
                          Constant.selectedSection!.adminCommision?.isEnabled ==
                              true)) {
                        if (controller
                                .userModel
                                .value
                                .subscriptionPlan
                                ?.itemLimit ==
                            '-1') {
                          isDisplayItemAlert = false;
                        } else {
                          isDisplayItemAlert =
                              (index <
                                      int.parse(
                                        controller
                                                .userModel
                                                .value
                                                .subscriptionPlan
                                                ?.itemLimit ??
                                            '0',
                                      ) ==
                                  true)
                              ? false
                              : true;
                        }
                      }

                      return InkWell(
                        onTap: () {
                          Get.to(
                            const AddProductScreen(),
                            arguments: {
                              "productModel": controller.productList[index],
                            },
                          )!.then((value) {
                            if (value == true) {
                              controller.getProduct();
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Container(
                            decoration: ShapeDecoration(
                              color: isDark
                                  ? AppThemeData.grey900
                                  : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(16),
                                        ),
                                        child: Stack(
                                          children: [
                                            NetworkImageWidget(
                                              imageUrl: controller
                                                  .productList[index]
                                                  .photo
                                                  .toString(),
                                              fit: BoxFit.cover,
                                              height: Responsive.height(
                                                12,
                                                context,
                                              ),
                                              width: Responsive.width(
                                                24,
                                                context,
                                              ),
                                            ),
                                            Container(
                                              height: Responsive.height(
                                                12,
                                                context,
                                              ),
                                              width: Responsive.width(
                                                24,
                                                context,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: const Alignment(
                                                    -0.00,
                                                    -1.00,
                                                  ),
                                                  end: const Alignment(0, 1),
                                                  colors: [
                                                    Colors.black.withOpacity(0),
                                                    const Color(0xFF111827),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              controller.productList[index].name
                                                  .toString(),
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: isDark
                                                    ? AppThemeData.grey50
                                                    : AppThemeData.grey900,
                                                fontFamily:
                                                    AppThemeData.semiBold,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            double.parse(disPrice) <= 0
                                                ? Text(
                                                    Constant.amountShow(
                                                      amount: price,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: isDark
                                                          ? AppThemeData.grey50
                                                          : AppThemeData
                                                                .grey900,
                                                      fontFamily:
                                                          AppThemeData.semiBold,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  )
                                                : Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        Constant.amountShow(
                                                          amount: disPrice,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color: isDark
                                                              ? AppThemeData
                                                                    .grey50
                                                              : AppThemeData
                                                                    .grey900,
                                                          fontFamily:
                                                              AppThemeData
                                                                  .semiBold,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        Constant.amountShow(
                                                          amount: price,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          decoration:
                                                              TextDecoration
                                                                  .lineThrough,
                                                          decorationColor:
                                                              isDark
                                                              ? AppThemeData
                                                                    .grey500
                                                              : AppThemeData
                                                                    .grey400,
                                                          color: isDark
                                                              ? AppThemeData
                                                                    .grey500
                                                              : AppThemeData
                                                                    .grey400,
                                                          fontFamily:
                                                              AppThemeData
                                                                  .semiBold,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            Row(
                                              children: [
                                                SvgPicture.asset(
                                                  "assets/icons/ic_star.svg",
                                                  colorFilter:
                                                      const ColorFilter.mode(
                                                        AppThemeData.warning300,
                                                        BlendMode.srcIn,
                                                      ),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  "${Constant.calculateReview(reviewCount: controller.productList[index].reviewsCount!.toStringAsFixed(0), reviewSum: controller.productList[index].reviewsSum.toString())} (${controller.productList[index].reviewsCount!.toStringAsFixed(0)})",
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppThemeData.grey50
                                                        : AppThemeData.grey900,
                                                    fontFamily:
                                                        AppThemeData.regular,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              controller
                                                  .productList[index]
                                                  .description
                                                  .toString(),
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? AppThemeData.grey50
                                                    : AppThemeData.grey900,
                                                fontFamily:
                                                    AppThemeData.regular,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            Get.to(
                                              const AddProductScreen(),
                                              arguments: {
                                                "productModel": controller
                                                    .productList[index],
                                              },
                                            )!.then((value) {
                                              if (value == true) {
                                                controller.getProduct();
                                              }
                                            });
                                          },
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.edit,
                                                size: 18,
                                                color: isDark
                                                    ? AppThemeData.primary300
                                                    : AppThemeData.primary300,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                "Edit".tr,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: isDark
                                                      ? AppThemeData.primary300
                                                      : AppThemeData.primary300,
                                                  fontSize: 14,
                                                  fontFamily: AppThemeData.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            ShowToastDialog.showLoader(
                                              "Please wait..".tr,
                                            );
                                            await FireStoreUtils.deleteProduct(
                                              controller.productList[index],
                                            ).then((value) {
                                              controller.getProduct();
                                              ShowToastDialog.closeLoader();
                                            });
                                          },
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              SvgPicture.asset(
                                                "assets/icons/ic_delete-one.svg",
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                "Delete".tr,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: isDark
                                                      ? AppThemeData.danger300
                                                      : AppThemeData.danger300,
                                                  fontSize: 14,
                                                  fontFamily: AppThemeData.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                "Publish".tr,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color: isDark
                                                      ? AppThemeData.grey100
                                                      : AppThemeData.grey800,
                                                  fontSize: 14,
                                                  fontFamily: AppThemeData.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Transform.scale(
                                              scale: 0.6,
                                              child: CupertinoSwitch(
                                                value:
                                                    controller
                                                        .productList[index]
                                                        .publish ??
                                                    false,
                                                onChanged: (value) async {
                                                  controller.updateList(
                                                    index,
                                                    controller
                                                        .productList[index]
                                                        .publish!,
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Visibility(
                                    visible: isDisplayItemAlert,
                                    child: Text(
                                      "This product will not be displayed to customers due to your current subscription limitations."
                                          .tr,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isDark
                                            ? AppThemeData.danger300
                                            : AppThemeData.danger300,
                                        fontSize: 12,
                                        fontFamily: AppThemeData.regular,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
