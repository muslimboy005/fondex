import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/service_list_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../utils/network_image_widget.dart';
import '../../models/advertisement_model.dart';
import 'advertisement_story_screen.dart';

class ServiceListScreen extends StatelessWidget {
  const ServiceListScreen({super.key});

  void _showSearchBottomSheet(
    BuildContext context,
    ServiceListController controller,
    ThemeController themeController,
  ) {
    final TextEditingController searchController = TextEditingController();
    final FocusNode focusNode = FocusNode();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Auto-focus when bottom sheet opens
        WidgetsBinding.instance.addPostFrameCallback((_) {
          focusNode.requestFocus();
        });

        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color:
                themeController.isDark.value
                    ? AppThemeData.grey900
                    : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      themeController.isDark.value
                          ? AppThemeData.grey700
                          : AppThemeData.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        themeController.isDark.value
                            ? AppThemeData.grey800
                            : AppThemeData.grey100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color:
                            themeController.isDark.value
                                ? AppThemeData.grey400
                                : AppThemeData.grey600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          focusNode: focusNode,
                          autofocus: true,
                          style: AppThemeData.regularTextStyle(
                            fontSize: 16,
                            color:
                                themeController.isDark.value
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900,
                          ),
                          decoration: InputDecoration(
                            hintText: "Search for something".tr,
                            hintStyle: AppThemeData.regularTextStyle(
                              fontSize: 16,
                              color:
                                  themeController.isDark.value
                                      ? AppThemeData.grey400
                                      : AppThemeData.grey600,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            controller.onSearchTextChanged(value);
                          },
                        ),
                      ),
                      Obx(() {
                        if (controller.searchQuery.value.isNotEmpty) {
                          return GestureDetector(
                            onTap: () {
                              searchController.clear();
                              controller.onSearchTextChanged('');
                              focusNode.requestFocus();
                            },
                            child: Icon(
                              Icons.close,
                              color:
                                  themeController.isDark.value
                                      ? AppThemeData.grey400
                                      : AppThemeData.grey600,
                              size: 20,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Search Results
              Expanded(
                child: Obx(() {
                  if (controller.searchQuery.value.isEmpty) {
                    return Center(
                      child: Text(
                        "Search for something".tr,
                        style: AppThemeData.regularTextStyle(
                          fontSize: 16,
                          color:
                              themeController.isDark.value
                                  ? AppThemeData.grey400
                                  : AppThemeData.grey600,
                        ),
                      ),
                    );
                  }

                  if (controller.searchResults.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color:
                                themeController.isDark.value
                                    ? AppThemeData.grey700
                                    : AppThemeData.grey300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Nothing found".tr,
                            style: AppThemeData.semiBoldTextStyle(
                              fontSize: 20,
                              color:
                                  themeController.isDark.value
                                      ? AppThemeData.grey50
                                      : AppThemeData.grey900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              "We have no results for your query. Try other words"
                                  .tr,
                              textAlign: TextAlign.center,
                              style: AppThemeData.regularTextStyle(
                                fontSize: 14,
                                color:
                                    themeController.isDark.value
                                        ? AppThemeData.grey400
                                        : AppThemeData.grey600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: controller.searchResults.length,
                    itemBuilder: (context, index) {
                      final section = controller.searchResults[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          controller.onServiceTap(context, section);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color:
                                themeController.isDark.value
                                    ? AppThemeData.grey800
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  section.name ?? '',
                                  style: AppThemeData.semiBoldTextStyle(
                                    fontSize: 16,
                                    color:
                                        themeController.isDark.value
                                            ? AppThemeData.grey50
                                            : AppThemeData.grey900,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color:
                                    themeController.isDark.value
                                        ? AppThemeData.grey400
                                        : AppThemeData.grey600,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return GetX(
      init: ServiceListController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor:
              themeController.isDark.value
                  ? AppThemeData.grey900
                  : AppThemeData.grey50,
          appBar: AppBar(
            elevation: 0,
            automaticallyImplyLeading: false,
            backgroundColor:
                themeController.isDark.value
                    ? AppThemeData.grey900
                    : Colors.white,
            titleSpacing: 20,
            centerTitle: false,
            title: Row(
              children: [
                Image.asset(
                  "assets/images/main_logo.png",
                  width: 32,
                  height: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  "Fondex",
                  style: AppThemeData.semiBoldTextStyle(
                    fontSize: 32,
                    color:
                        themeController.isDark.value
                            ? AppThemeData.grey50
                            : AppThemeData.grey900,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            // actions: [
            //   IconButton(
            //     onPressed: () {},
            //     icon: Icon(Icons.menu),
            //     iconSize: 29,
            //     color:
            //         themeController.isDark.value
            //             ? AppThemeData.grey50
            //             : AppThemeData.grey900,
            //   ),
            // ],
          ),
          body:
              controller.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        // Advertisement Section
                        controller.advertisementList.isEmpty
                            ? const SizedBox()
                            : AdvertisementView(
                              advertisementList: controller.advertisementList,
                            ),
                        const SizedBox(height: 20),

                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GestureDetector(
                            onTap:
                                () => _showSearchBottomSheet(
                                  context,
                                  controller,
                                  themeController,
                                ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    themeController.isDark.value
                                        ? AppThemeData.grey800
                                        : AppThemeData.grey100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search,
                                    color:
                                        themeController.isDark.value
                                            ? AppThemeData.grey400
                                            : AppThemeData.grey600,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Search for something".tr,
                                    style: AppThemeData.regularTextStyle(
                                      fontSize: 16,
                                      color:
                                          themeController.isDark.value
                                              ? AppThemeData.grey400
                                              : AppThemeData.grey600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Main Service Cards (2x2 Grid)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        MainServiceCard(
                                          title:
                                              controller.sectionList.isNotEmpty
                                                  ? controller
                                                          .sectionList[0]
                                                          .name ??
                                                      ''
                                                  : '',
                                          imageUrl:
                                              controller.sectionList.isNotEmpty
                                                  ? controller
                                                          .sectionList[0]
                                                          .sectionImage ??
                                                      ''
                                                  : '',
                                          gradient: [
                                            const Color(0xFFF5F5F5),
                                            const Color(0xFFE8E8E8),
                                          ],
                                          onTap:
                                              () =>
                                                  controller
                                                              .sectionList
                                                              .length >
                                                          1
                                                      ? controller.onServiceTap(
                                                        context,
                                                        controller
                                                            .sectionList[0],
                                                      )
                                                      : null,
                                        ),
                                        const SizedBox(height: 12),
                                        MainServiceCard(
                                          title:
                                              controller.sectionList.length > 1
                                                  ? controller
                                                          .sectionList[1]
                                                          .name ??
                                                      ''
                                                  : '',
                                          imageUrl:
                                              controller.sectionList.length > 1
                                                  ? controller
                                                          .sectionList[1]
                                                          .sectionImage ??
                                                      ''
                                                  : '',
                                          gradient: [
                                            const Color(0xFFF5F5F5),
                                            const Color(0xFFE8E8E8),
                                          ],
                                          onTap:
                                              () =>
                                                  controller
                                                              .sectionList
                                                              .length >
                                                          1
                                                      ? controller.onServiceTap(
                                                        context,
                                                        controller
                                                            .sectionList[1],
                                                      )
                                                      : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: MainServiceCard(
                                      title:
                                          controller.sectionList.length > 2
                                              ? controller
                                                      .sectionList[2]
                                                      .name ??
                                                  ''
                                              : '',
                                      imageUrl:
                                          controller.sectionList.length > 2
                                              ? controller
                                                      .sectionList[2]
                                                      .sectionImage ??
                                                  ''
                                              : '',
                                      gradient: [
                                        const Color(0xFFFDB64A),
                                        const Color(0xFFE89B2A),
                                      ],
                                      onTap:
                                          () =>
                                              controller.sectionList.length > 2
                                                  ? controller.onServiceTap(
                                                    context,
                                                    controller.sectionList[2],
                                                  )
                                                  : null,
                                      isLarge: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Other Services Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "Other services".tr,
                            style: AppThemeData.semiBoldTextStyle(
                              fontSize: 20,
                              color:
                                  themeController.isDark.value
                                      ? AppThemeData.grey50
                                      : AppThemeData.grey900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Service List Items
                        ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount:
                              controller.sectionList.length > 3
                                  ? controller.sectionList.length - 3
                                  : 0,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final section = controller.sectionList[index + 3];
                            return ServiceListItem(
                              title: section.name ?? '',
                              subtitle: "More than 1000 products".tr,
                              imageUrl: section.sectionImage ?? '',
                              onTap:
                                  () =>
                                      controller.onServiceTap(context, section),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
        );
      },
    );
  }
}

class AdvertisementView extends StatelessWidget {
  final List<AdvertisementModel> advertisementList;
  final RxInt currentPage = 0.obs;
  final ScrollController scrollController = ScrollController();

  AdvertisementView({super.key, required this.advertisementList});

  void onScroll(BuildContext context) {
    if (scrollController.hasClients && advertisementList.isNotEmpty) {
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth =
          (screenWidth * 0.8) + 12; // 80% of screen width + spacing
      final offset = scrollController.offset;
      final index = (offset / itemWidth).round();

      if (index != currentPage.value && index < advertisementList.length) {
        currentPage.value = index;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    scrollController.addListener(() => onScroll(context));

    if (advertisementList.isEmpty) {
      return const SizedBox();
    }

    return Column(
      children: [
        SizedBox(
          height: 80,
          child: ListView.separated(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: advertisementList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final advertisement = advertisementList[index];
              final imageUrl =
                  advertisement.profileImage ??
                  'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_640.png';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AdvertisementStoryScreen(
                            advertisementList: List.from(advertisementList),
                            initialIndex: index,
                          ),
                    ),
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF6B35),
                      width: 2,
                    ),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                      onError:
                          (error, stackTrace) => Icon(
                            Icons.image,
                            size: 48,
                            color: AppThemeData.grey400,
                          ),
                      alignment: Alignment.center,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: AppThemeData.grey100,
                  ),
                ),
              );
            },
          ),
        ),
        // if (advertisementList.length > 1) ...[
        //   const SizedBox(height: 12),
        //   Obx(() {
        //     return Row(
        //       mainAxisAlignment: MainAxisAlignment.center,
        //       children: List.generate(advertisementList.length, (index) {
        //         final isSelected = currentPage.value == index;
        //         return Container(
        //           margin: const EdgeInsets.symmetric(horizontal: 3),
        //           width: isSelected ? 8 : 6,
        //           height: isSelected ? 8 : 6,
        //           decoration: BoxDecoration(
        //             shape: BoxShape.circle,
        //             color:
        //                 isSelected
        //                     ? AppThemeData.grey900
        //                     : AppThemeData.grey300,
        //           ),
        //         );
        //       }),
        //     );
        //   }),
        // ],
      ],
    );
  }
}

class MainServiceCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final List<Color> gradient;
  final VoidCallback? onTap;
  final bool isLarge;

  const MainServiceCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.gradient,
    this.onTap,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isLarge ? 276 : 132,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppThemeData.semiBoldTextStyle(
                            fontSize: isLarge ? 28 : 16,
                            color:
                                isLarge
                                    ? Colors.white
                                    : gradient[0].computeLuminance() > 0.5
                                    ? AppThemeData.grey900
                                    : Colors.white,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color:
                              isLarge
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_outward,
                          size: 18,
                          color: isLarge ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (imageUrl.isNotEmpty)
              Positioned(
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(16),
                  ),
                  child:
                      imageUrl.startsWith('assets/')
                          ? SizedBox(
                            width: isLarge ? 360 : 100,
                            height: isLarge ? 340 : 90,
                            child: Image.asset(
                              imageUrl,
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomRight,
                            ),
                          )
                          : NetworkImageWidget(
                            imageUrl: imageUrl,
                            width: isLarge ? 200 : 100,
                            height: isLarge ? 150 : 90,
                            fit: BoxFit.contain,
                          ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ServiceListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onTap;

  const ServiceListItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              themeController.isDark.value
                  ? AppThemeData.grey800
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppThemeData.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  imageUrl.isNotEmpty
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: NetworkImageWidget(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                        ),
                      )
                      : const Icon(Icons.image, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppThemeData.semiBoldTextStyle(
                      fontSize: 16,
                      color:
                          themeController.isDark.value
                              ? AppThemeData.grey50
                              : AppThemeData.grey900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppThemeData.regularTextStyle(
                      fontSize: 14,
                      color:
                          themeController.isDark.value
                              ? AppThemeData.grey400
                              : AppThemeData.grey600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color:
                  themeController.isDark.value
                      ? AppThemeData.grey400
                      : AppThemeData.grey600,
            ),
          ],
        ),
      ),
    );
  }
}
