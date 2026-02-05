import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/restaurant_details_controller.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/favourite_item_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../controllers/theme_controller.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../cart_screen/cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel productModel;
  final VendorModel vendorModel;

  const ProductDetailScreen({
    super.key,
    required this.productModel,
    required this.vendorModel,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isDescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    // Initialize controller
    final controller = Get.put(
      RestaurantDetailsController(),
      tag: 'product_detail_${widget.productModel.id}',
    );
    controller.vendorModel.value = widget.vendorModel;

    // Initialize variants if exists
    if (widget.productModel.itemAttribute != null &&
        widget.productModel.itemAttribute!.attributes != null &&
        widget.productModel.itemAttribute!.attributes!.isNotEmpty) {
      controller.selectedVariants.clear();
      controller.selectedIndexVariants.clear();
      controller.selectedIndexArray.clear();
      for (
        var i = 0;
        i < widget.productModel.itemAttribute!.attributes!.length;
        i++
      ) {
        var element = widget.productModel.itemAttribute!.attributes![i];
        if (element.attributeOptions != null &&
            element.attributeOptions!.isNotEmpty) {
          controller.selectedVariants.add(element.attributeOptions![0]);
          controller.selectedIndexVariants.add(
            '$i _${element.attributeOptions![0]}',
          );
          controller.selectedIndexArray.add('${i}_0');
        }
      }
    }

    // Check if product is in cart and sync quantity
    _syncCartQuantity(controller);

    // Calculate price
    String price = "0.0";
    String disPrice = "0.0";
    if (widget.productModel.itemAttribute != null &&
        widget.productModel.itemAttribute!.variants != null &&
        widget.productModel.itemAttribute!.variants!.isNotEmpty) {
      var matchingVariant = widget.productModel.itemAttribute!.variants!.where(
        (element) =>
            element.variantSku == controller.selectedVariants.join('-'),
      );
      if (matchingVariant.isNotEmpty) {
        price = Constant.productCommissionPrice(
          widget.vendorModel,
          matchingVariant.first.variantPrice ?? '0',
        );
        disPrice = "0";
      }
    } else {
      price = Constant.productCommissionPrice(
        widget.vendorModel,
        widget.productModel.price.toString(),
      );
      disPrice =
          double.parse(widget.productModel.disPrice.toString()) <= 0
              ? "0"
              : Constant.productCommissionPrice(
                widget.vendorModel,
                widget.productModel.disPrice.toString(),
              );
    }

    return Scaffold(
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      body: Obx(() {
        return CustomScrollView(
          slivers: [
            // App Bar with Image
            SliverAppBar(
              expandedHeight: Responsive.height(35, context),
              floating: false,
              pinned: true,
              backgroundColor:
                  isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              leading: InkWell(
                onTap: () => Get.back(),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppThemeData.grey800.withOpacity(0.8)
                            : AppThemeData.grey50.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                  ),
                ),
              ),
              actions: [
                InkWell(
                  onTap: () async {
                    if (controller.favouriteItemList
                        .where((p0) => p0.productId == widget.productModel.id)
                        .isNotEmpty) {
                      FavouriteItemModel favouriteModel = FavouriteItemModel(
                        productId: widget.productModel.id,
                        storeId: widget.vendorModel.id,
                        userId: FireStoreUtils.getCurrentUid(),
                      );
                      controller.favouriteItemList.removeWhere(
                        (item) => item.productId == widget.productModel.id,
                      );
                      await FireStoreUtils.removeFavouriteItem(favouriteModel);
                    } else {
                      FavouriteItemModel favouriteModel = FavouriteItemModel(
                        productId: widget.productModel.id,
                        storeId: widget.vendorModel.id,
                        userId: FireStoreUtils.getCurrentUid(),
                      );
                      controller.favouriteItemList.add(favouriteModel);
                      await FireStoreUtils.setFavouriteItem(favouriteModel);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppThemeData.grey800.withOpacity(0.8)
                              : AppThemeData.grey50.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child:
                        controller.favouriteItemList
                                .where(
                                  (p0) =>
                                      p0.productId == widget.productModel.id,
                                )
                                .isNotEmpty
                            ? SvgPicture.asset(
                              "assets/icons/ic_like_fill.svg",
                              height: 24,
                              width: 24,
                            )
                            : SvgPicture.asset(
                              "assets/icons/ic_like.svg",
                              height: 24,
                              width: 24,
                            ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkImageWidget(
                      imageUrl: widget.productModel.photo.toString(),
                      fit: BoxFit.cover,
                    ),
                    // Discount badge
                    if (double.parse(widget.productModel.disPrice ?? "0") > 0)
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeData.primary300,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${"Discount".tr} -${_calculateDiscountPercent(widget.productModel)}%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: AppThemeData.semiBold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating and orders
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            "assets/icons/ic_star.svg",
                            colorFilter: const ColorFilter.mode(
                              AppThemeData.warning300,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            Constant.calculateReview(
                              reviewCount:
                                  widget.productModel.reviewsCount
                                      ?.toStringAsFixed(0) ??
                                  "0",
                              reviewSum:
                                  widget.productModel.reviewsSum?.toString() ??
                                  "0",
                            ),
                            style: TextStyle(
                              color:
                                  isDark
                                      ? AppThemeData.grey50
                                      : AppThemeData.grey900,
                              fontFamily: AppThemeData.semiBold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "• ${widget.productModel.reviewsCount?.toStringAsFixed(0) ?? "0"}+ ${"orders".tr}",
                            style: TextStyle(
                              color:
                                  isDark
                                      ? AppThemeData.grey400
                                      : AppThemeData.grey500,
                              fontFamily: AppThemeData.regular,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Product name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        widget.productModel.name ?? "",
                        style: TextStyle(
                          fontSize: 22,
                          color:
                              isDark
                                  ? AppThemeData.grey50
                                  : AppThemeData.grey900,
                          fontFamily: AppThemeData.bold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    // Price
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Text(
                            Constant.amountShow(
                              amount:
                                  double.parse(disPrice) > 0 ? disPrice : price,
                            ),
                            style: TextStyle(
                              fontSize: 20,
                              color: AppThemeData.primary300,
                              fontFamily: AppThemeData.bold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (double.parse(disPrice) > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              Constant.amountShow(amount: price),
                              style: TextStyle(
                                fontSize: 16,
                                decoration: TextDecoration.lineThrough,
                                color:
                                    isDark
                                        ? AppThemeData.grey500
                                        : AppThemeData.grey400,
                                fontFamily: AppThemeData.regular,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Description section
                    _buildDescriptionSection(isDark),

                    // Product info section
                    _buildProductInfoSection(isDark, controller),

                    // Variants section
                    if (widget.productModel.itemAttribute != null &&
                        widget.productModel.itemAttribute!.attributes != null &&
                        widget
                            .productModel
                            .itemAttribute!
                            .attributes!
                            .isNotEmpty)
                      _buildVariantsSection(isDark, controller, context),

                    // Addons section
                    if (widget.productModel.addOnsTitle != null &&
                        widget.productModel.addOnsTitle!.isNotEmpty)
                      _buildAddonsSection(isDark, controller),

                    // Similar products section
                    _buildSimilarProductsSection(isDark, context),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        // Recalculate price when variants change
        String currentPrice = price;
        String currentDisPrice = disPrice;
        if (widget.productModel.itemAttribute != null &&
            widget.productModel.itemAttribute!.variants != null &&
            widget.productModel.itemAttribute!.variants!.isNotEmpty) {
          var matchingVariant = widget.productModel.itemAttribute!.variants!
              .where(
                (element) =>
                    element.variantSku == controller.selectedVariants.join('-'),
              );
          if (matchingVariant.isNotEmpty) {
            currentPrice = Constant.productCommissionPrice(
              widget.vendorModel,
              matchingVariant.first.variantPrice ?? '0',
            );
            currentDisPrice = "0";
          }
        }
        return _buildBottomBar(
          isDark,
          controller,
          context,
          currentPrice,
          currentDisPrice,
        );
      }),
    );
  }

  String _calculateDiscountPercent(ProductModel product) {
    if (product.price == null || product.disPrice == null) return "0";
    double originalPrice = double.tryParse(product.price!) ?? 0;
    double discountPrice = double.tryParse(product.disPrice!) ?? 0;
    if (originalPrice <= 0) return "0";
    double percent = ((originalPrice - discountPrice) / originalPrice) * 100;
    return percent.toStringAsFixed(0);
  }

  Widget _buildDescriptionSection(bool isDark) {
    final description = widget.productModel.description ?? "";
    if (description.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSectionCard(
      isDark: isDark,
      title: "Description".tr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate if text exceeds 5 lines
          final textPainter = TextPainter(
            text: TextSpan(
              text: description,
              style: TextStyle(
                color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                fontFamily: AppThemeData.regular,
                height: 1.5,
                fontSize: 14,
              ),
            ),
            maxLines: 5,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout(maxWidth: constraints.maxWidth);

          final needsExpansion = textPainter.didExceedMaxLines;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: TextStyle(
                  color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                  fontFamily: AppThemeData.regular,
                  height: 1.5,
                  fontSize: 14,
                ),
                maxLines: _isDescriptionExpanded ? null : 5,
                overflow:
                    _isDescriptionExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
              ),
              if (needsExpansion)
                InkWell(
                  onTap: () {
                    setState(() {
                      _isDescriptionExpanded = !_isDescriptionExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _isDescriptionExpanded
                          ? "Qisqartirish".tr
                          : "Ko'proq o'qish".tr,
                      style: TextStyle(
                        color: AppThemeData.primary300,
                        fontFamily: AppThemeData.semiBold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
              fontFamily: AppThemeData.semiBold,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildProductInfoSection(
    bool isDark,
    RestaurantDetailsController controller,
  ) {
    List<Map<String, String>> infoItems = [];

    // Product type
    // if (Constant.sectionConstantModel?.isProductDetails == true) {
    //   infoItems.add({
    //     "label": "Product Type".tr,
    //     "value": widget.productModel.nonveg == true ? "Non Veg".tr : "Veg".tr,
    //   });
    // }

    // Calories
    if (widget.productModel.calories != null &&
        widget.productModel.calories! > 0) {
      infoItems.add({
        "label": "Calories".tr,
        "value": "${widget.productModel.calories} ${"kcal".tr}",
      });
    }

    // Weight/Grams
    if (widget.productModel.grams != null && widget.productModel.grams! > 0) {
      infoItems.add({
        "label": "Weight".tr,
        "value": "${widget.productModel.grams} ${"g".tr}",
      });
    }

    // Proteins
    if (widget.productModel.proteins != null &&
        widget.productModel.proteins! > 0) {
      infoItems.add({
        "label": "Proteins".tr,
        "value": "${widget.productModel.proteins} ${"g".tr}",
      });
    }

    // Fats
    if (widget.productModel.fats != null && widget.productModel.fats! > 0) {
      infoItems.add({
        "label": "Fats".tr,
        "value": "${widget.productModel.fats} ${"g".tr}",
      });
    }

    // Product specification
    if (widget.productModel.productSpecification != null &&
        widget.productModel.productSpecification!.isNotEmpty) {
      widget.productModel.productSpecification!.forEach((key, value) {
        infoItems.add({"label": key, "value": value.toString()});
      });
    }

    // Brand
    if (widget.productModel.brandId != null &&
        widget.productModel.brandId!.isNotEmpty) {
      String brandName = controller.getBrandName(widget.productModel.brandId!);
      if (brandName.isNotEmpty) {
        infoItems.add({"label": "Brand".tr, "value": brandName});
      }
    }

    if (infoItems.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children:
            infoItems.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item["label"]!,
                      style: TextStyle(
                        color:
                            isDark
                                ? AppThemeData.grey400
                                : AppThemeData.grey500,
                        fontFamily: AppThemeData.regular,
                      ),
                    ),
                    Text(
                      item["value"]!,
                      style: TextStyle(
                        color:
                            isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                        fontFamily: AppThemeData.semiBold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildVariantsSection(
    bool isDark,
    RestaurantDetailsController controller,
    BuildContext context,
  ) {
    return Column(
      children: List.generate(
        widget.productModel.itemAttribute!.attributes!.length,
        (index) {
          String title = "";
          for (var element in controller.attributesList) {
            if (widget
                    .productModel
                    .itemAttribute!
                    .attributes![index]
                    .attributeId ==
                element.id) {
              title = element.title.toString();
            }
          }
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                    fontFamily: AppThemeData.semiBold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "Required • Select any 1 option".tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                    fontFamily: AppThemeData.regular,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    widget
                        .productModel
                        .itemAttribute!
                        .attributes![index]
                        .attributeOptions!
                        .length,
                    (i) {
                      String option =
                          widget
                              .productModel
                              .itemAttribute!
                              .attributes![index]
                              .attributeOptions![i];
                      bool isSelected = controller.selectedVariants.contains(
                        option,
                      );
                      return InkWell(
                        onTap: () {
                          _onVariantSelected(controller, index, i);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppThemeData.primary300
                                    : (isDark
                                        ? AppThemeData.grey800
                                        : AppThemeData.grey100),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            option,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? AppThemeData.grey100
                                          : AppThemeData.grey800),
                              fontFamily: AppThemeData.medium,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onVariantSelected(
    RestaurantDetailsController controller,
    int attributeIndex,
    int optionIndex,
  ) {
    String option =
        widget
            .productModel
            .itemAttribute!
            .attributes![attributeIndex]
            .attributeOptions![optionIndex];

    if (controller.selectedIndexVariants
        .where((element) => element.contains('$attributeIndex _'))
        .isEmpty) {
      controller.selectedVariants.insert(attributeIndex, option);
      controller.selectedIndexVariants.add('$attributeIndex _$option');
      controller.selectedIndexArray.add('${attributeIndex}_$optionIndex');
    } else {
      controller.selectedIndexArray.remove(
        '${attributeIndex}_${widget.productModel.itemAttribute!.attributes![attributeIndex].attributeOptions?.indexOf(controller.selectedIndexVariants.where((element) => element.contains('$attributeIndex _')).first.replaceAll('$attributeIndex _', ''))}',
      );
      controller.selectedVariants.removeAt(attributeIndex);
      controller.selectedIndexVariants.remove(
        controller.selectedIndexVariants
            .where((element) => element.contains('$attributeIndex _'))
            .first,
      );
      controller.selectedVariants.insert(attributeIndex, option);
      controller.selectedIndexVariants.add('$attributeIndex _$option');
      controller.selectedIndexArray.add('${attributeIndex}_$optionIndex');
    }

    controller.quantity.value = 1;
    controller.update();
    controller.calculatePrice(widget.productModel);

    // Sync cart quantity when variant changes
    _syncCartQuantity(controller);
  }

  Widget _buildAddonsSection(
    bool isDark,
    RestaurantDetailsController controller,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Addons".tr,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
              fontFamily: AppThemeData.semiBold,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Divider(),
          ...List.generate(widget.productModel.addOnsTitle!.length, (index) {
            String title = widget.productModel.addOnsTitle![index];
            String addonPrice = widget.productModel.addOnsPrice![index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color:
                            isDark
                                ? AppThemeData.grey100
                                : AppThemeData.grey800,
                        fontFamily: AppThemeData.medium,
                      ),
                    ),
                  ),
                  Text(
                    Constant.amountShow(
                      amount: Constant.productCommissionPrice(
                        widget.vendorModel,
                        addonPrice,
                      ),
                    ),
                    style: TextStyle(
                      color:
                          isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                      fontFamily: AppThemeData.medium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: controller.selectedAddOns.contains(title),
                      activeColor: AppThemeData.primary300,
                      onChanged: (value) {
                        if (value == true) {
                          controller.selectedAddOns.add(title);
                        } else {
                          controller.selectedAddOns.remove(title);
                        }
                        controller.update();
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSimilarProductsSection(bool isDark, BuildContext context) {
    return FutureBuilder<List<ProductModel>>(
      future: FireStoreUtils.getProductByVendorId(
        widget.vendorModel.id.toString(),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox();
        }

        List<ProductModel> similarProducts =
            snapshot.data!
                .where(
                  (p) =>
                      p.id != widget.productModel.id &&
                      p.categoryID == widget.productModel.categoryID,
                )
                .take(10)
                .toList();

        if (similarProducts.isEmpty) {
          // If no same category products, show other products
          similarProducts =
              snapshot.data!
                  .where((p) => p.id != widget.productModel.id)
                  .take(10)
                  .toList();
        }

        if (similarProducts.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "Similar Products".tr,
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                  fontFamily: AppThemeData.semiBold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: similarProducts.length,
                itemBuilder: (context, index) {
                  ProductModel product = similarProducts[index];
                  return _buildSimilarProductCard(isDark, product, context);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSimilarProductCard(
    bool isDark,
    ProductModel product,
    BuildContext context,
  ) {
    String productPrice = Constant.productCommissionPrice(
      widget.vendorModel,
      product.price.toString(),
    );

    return InkWell(
      onTap: () {
        Get.off(
          () => ProductDetailScreen(
            productModel: product,
            vendorModel: widget.vendorModel,
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: NetworkImageWidget(
                imageUrl: product.photo.toString(),
                height: 95,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.vendorModel.title ?? "",
                      style: TextStyle(
                        fontSize: 9,
                        color:
                            isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                        fontFamily: AppThemeData.regular,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.name ?? "",
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                        fontFamily: AppThemeData.semiBold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Constant.amountShow(amount: productPrice),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppThemeData.primary300,
                        fontFamily: AppThemeData.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProductId(RestaurantDetailsController controller) {
    String productId = widget.productModel.id ?? "";
    if (widget.productModel.itemAttribute != null &&
        widget.productModel.itemAttribute!.variants != null &&
        widget.productModel.itemAttribute!.variants!.isNotEmpty) {
      var matchingVariant = widget.productModel.itemAttribute!.variants!.where(
        (element) =>
            element.variantSku == controller.selectedVariants.join('-'),
      );
      if (matchingVariant.isNotEmpty) {
        String variantId = matchingVariant.first.variantId ?? "";
        productId = "${widget.productModel.id}~$variantId";
      }
    }
    return productId;
  }

  void _syncCartQuantity(RestaurantDetailsController controller) {
    // Find product in cart
    String productId = _getProductId(controller);

    // Find in cart
    var cartProduct = cartItem.where((p) => p.id == productId).toList();
    if (cartProduct.isNotEmpty) {
      // Product is in cart, sync quantity and addons
      controller.quantity.value = cartProduct.first.quantity ?? 1;

      // Sync addons if exists
      if (cartProduct.first.extras != null &&
          cartProduct.first.extras!.isNotEmpty) {
        controller.selectedAddOns.clear();
        for (var extra in cartProduct.first.extras!) {
          controller.selectedAddOns.add(extra.toString());
        }
      }
    } else {
      // Product not in cart, set default quantity
      controller.quantity.value = 1;
    }
  }

  Widget _buildBottomBar(
    bool isDark,
    RestaurantDetailsController controller,
    BuildContext context,
    String price,
    String disPrice,
  ) {
    // Check if product is in cart
    String productId = _getProductId(controller);
    bool isInCart = cartItem.where((p) => p.id == productId).isNotEmpty;

    // Sync quantity when cart changes
    if (isInCart) {
      var cartProduct = cartItem.where((p) => p.id == productId).toList();
      if (cartProduct.isNotEmpty &&
          controller.quantity.value != cartProduct.first.quantity) {
        controller.quantity.value = cartProduct.first.quantity ?? 1;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Quantity selector (only show if in cart)
          if (isInCart)
            Container(
              height: Responsive.height(5.5, context),
              decoration: BoxDecoration(
                color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                borderRadius: BorderRadius.circular(200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      _decrementQuantity(controller, price, disPrice);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.remove,
                        color:
                            isDark
                                ? AppThemeData.grey100
                                : AppThemeData.grey800,
                      ),
                    ),
                  ),
                  Obx(
                    () => Text(
                      "${controller.quantity.value} ${"pcs".tr}",
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isDark
                                ? AppThemeData.grey100
                                : AppThemeData.grey800,
                        fontFamily: AppThemeData.semiBold,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      _incrementQuantity(controller);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.add,
                        color:
                            isDark
                                ? AppThemeData.grey100
                                : AppThemeData.grey800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (isInCart) const SizedBox(width: 12),
          // Add to cart or View cart button
          Expanded(
            flex: 2,
            child: RoundedButtonFill(
              title: isInCart ? "View Cart".tr : "Add to Cart".tr,
              height: 5.5,
              color: AppThemeData.primary300,
              textColor: AppThemeData.grey50,
              fontSizes: 16,
              onPress: () {
                if (isInCart) {
                  // Navigate to cart screen
                  Get.to(() => const CartScreen());
                } else {
                  // Add to cart
                  _addToCart(context, controller, price, disPrice);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _incrementQuantity(RestaurantDetailsController controller) {
    if (widget.productModel.itemAttribute == null) {
      if (controller.quantity.value < (widget.productModel.quantity ?? 0) ||
          (widget.productModel.quantity ?? 0) == -1) {
        controller.quantity.value += 1;
        // Update cart immediately
        _updateCartQuantity(controller);
      } else {
        ShowToastDialog.showToast("Out of stock".tr);
      }
    } else {
      var matchingVariant = widget.productModel.itemAttribute!.variants!.where(
        (element) =>
            element.variantSku == controller.selectedVariants.join('-'),
      );
      if (matchingVariant.isNotEmpty) {
        int totalQuantity = int.parse(
          matchingVariant.first.variantQuantity.toString(),
        );
        if (controller.quantity.value < totalQuantity || totalQuantity == -1) {
          controller.quantity.value += 1;
          // Update cart immediately
          _updateCartQuantity(controller);
        } else {
          ShowToastDialog.showToast("Out of stock".tr);
        }
      }
    }
  }

  void _decrementQuantity(
    RestaurantDetailsController controller,
    String price,
    String disPrice,
  ) {
    if (controller.quantity.value > 1) {
      controller.quantity.value -= 1;
      // Update cart immediately
      _updateCartQuantity(controller);
    } else {
      // Remove from cart if quantity is 1
      _removeFromCart(controller);
    }
  }

  void _updateCartQuantity(RestaurantDetailsController controller) {
    String finalPrice = "0";
    String finalDisPrice = "0";

    if (widget.productModel.itemAttribute != null &&
        widget.productModel.itemAttribute!.variants != null &&
        widget.productModel.itemAttribute!.variants!.isNotEmpty) {
      var matchingVariant = widget.productModel.itemAttribute!.variants!.where(
        (element) =>
            element.variantSku == controller.selectedVariants.join('-'),
      );
      if (matchingVariant.isNotEmpty) {
        finalPrice = Constant.productCommissionPrice(
          widget.vendorModel,
          matchingVariant.first.variantPrice ?? '0',
        );
        finalDisPrice = "0";
      }
    } else {
      finalPrice = Constant.productCommissionPrice(
        widget.vendorModel,
        widget.productModel.price.toString(),
      );
      finalDisPrice =
          double.parse(widget.productModel.disPrice.toString()) <= 0
              ? "0"
              : Constant.productCommissionPrice(
                widget.vendorModel,
                widget.productModel.disPrice.toString(),
              );
    }

    controller.addToCart(
      productModel: widget.productModel,
      price: finalPrice,
      discountPrice: finalDisPrice,
      isIncrement: true,
      quantity: controller.quantity.value,
    );
  }

  void _removeFromCart(RestaurantDetailsController controller) {
    String productId = _getProductId(controller);
    var cartProduct = cartItem.where((p) => p.id == productId).toList();
    if (cartProduct.isNotEmpty) {
      controller.addToCart(
        productModel: widget.productModel,
        price: cartProduct.first.price ?? "0",
        discountPrice: cartProduct.first.discountPrice ?? "0",
        isIncrement: false,
        quantity: 0,
      );
      controller.quantity.value = 1;
    }
  }

  Future<void> _addToCart(
    BuildContext context,
    RestaurantDetailsController controller,
    String price,
    String disPrice,
  ) async {
    try {
      if (widget.productModel.itemAttribute == null) {
        await controller.addToCart(
          productModel: widget.productModel,
          price: price,
          discountPrice: double.parse(disPrice) > 0 ? disPrice : "0",
          isIncrement: true,
          quantity: controller.quantity.value,
        );
      } else {
        String variantPrice = "0";
        var matchingVariant = widget.productModel.itemAttribute!.variants!
            .where(
              (e) => e.variantSku == controller.selectedVariants.join('-'),
            );
        if (matchingVariant.isNotEmpty) {
          variantPrice = Constant.productCommissionPrice(
            widget.vendorModel,
            matchingVariant.first.variantPrice ?? '0',
          );

          Map<String, String> mapData = {};
          for (var element in widget.productModel.itemAttribute!.attributes!) {
            mapData.addEntries([
              MapEntry(
                controller.attributesList
                    .firstWhere((e) => e.id == element.attributeId)
                    .title
                    .toString(),
                controller.selectedVariants[widget
                    .productModel
                    .itemAttribute!
                    .attributes!
                    .indexOf(element)],
              ),
            ]);
          }

          VariantInfo variantInfo = VariantInfo(
            variantPrice: matchingVariant.first.variantPrice ?? '0',
            variantSku: controller.selectedVariants.join('-'),
            variantOptions: mapData,
            variantImage: matchingVariant.first.variantImage ?? '',
            variantId: matchingVariant.first.variantId ?? '0',
          );

          await controller.addToCart(
            productModel: widget.productModel,
            price: variantPrice,
            discountPrice: "0",
            isIncrement: true,
            variantInfo: variantInfo,
            quantity: controller.quantity.value,
          );
        } else {
          ShowToastDialog.showToast("Please select variant".tr);
          return;
        }
      }
      ShowToastDialog.showToast("Added to cart".tr);
    } catch (e) {
      ShowToastDialog.showToast("${'Error adding to cart'.tr}: ${e.toString()}");
    }
  }
}
