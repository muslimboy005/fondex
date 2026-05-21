import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/category_product_list_controller.dart';
import 'package:customer/controllers/restaurant_details_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/theme_controller.dart';
import 'restaurant_details_screen.dart';

RestaurantDetailsController? _findRestaurantDetailsForCategoryList(
  String? tag,
) {
  if (tag != null && tag.isNotEmpty) {
    try {
      return Get.find<RestaurantDetailsController>(tag: tag);
    } catch (_) {}
  }
  try {
    return Get.find<RestaurantDetailsController>();
  } catch (_) {
    return null;
  }
}

class CategoryProductListScreen extends StatelessWidget {
  const CategoryProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    final String categoryName = Get.arguments['categoryName'] ?? 'Category'.tr;

    return GetX(
      init: CategoryProductListController(),
      builder: (CategoryProductListController categoryController) {
        final String? restaurantTag =
            Get.arguments['restaurantDetailsTag'] as String?;
        final RestaurantDetailsController? restaurantController =
            _findRestaurantDetailsForCategoryList(restaurantTag);

        final String effectiveTag = restaurantTag ?? '';

        return Scaffold(
          backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          appBar: AppBar(
            backgroundColor:
                isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            elevation: 0,
            leading: InkWell(
              onTap: () => Get.back(),
              child: Icon(
                Icons.arrow_back,
                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
              ),
            ),
            title: Text(
              categoryName,
              style: TextStyle(
                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                fontFamily: AppThemeData.semiBold,
                fontSize: 18,
              ),
            ),
            centerTitle: false,
          ),
          body:
              restaurantController == null
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Unable to load restaurant context. Go back and open this category from the restaurant menu."
                            .tr,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                  : NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (scrollInfo.metrics.pixels >=
                          scrollInfo.metrics.maxScrollExtent - 200) {
                        categoryController.getProducts();
                      }
                      return true;
                    },
                    child:
                        categoryController.isLoading.value
                            ? Constant.loader()
                            : categoryController.productList.isEmpty
                            ? Constant.showEmptyView(
                              message:
                                  "No products found for this category".tr,
                            )
                            : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount:
                                        categoryController.productList.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          childAspectRatio: 0.68,
                                        ),
                                    itemBuilder: (context, index) {
                                      final product =
                                          categoryController.productList[index];
                                      return ProductListView.buildProductCard(
                                        context: context,
                                        controller: restaurantController,
                                        controllerTag: effectiveTag,
                                        productModel: product,
                                        isDark: isDark,
                                      );
                                    },
                                  ),
                                  if (categoryController.isLoadingMore.value)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Constant.loader(),
                                    ),
                                ],
                              ),
                            ),
                  ),
        );
      },
    );
  }
}
