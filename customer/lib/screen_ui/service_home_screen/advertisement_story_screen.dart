import 'package:customer/models/advertisement_model.dart';
import 'package:customer/widget/story_view/controller/story_controller.dart';
import 'package:customer/widget/story_view/utils.dart';
import 'package:customer/widget/story_view/widgets/story_view.dart';
import 'package:flutter/material.dart';

class AdvertisementStoryScreen extends StatefulWidget {
  final List<AdvertisementModel> advertisementList;
  final int initialIndex;

  const AdvertisementStoryScreen({
    super.key,
    required this.advertisementList,
    this.initialIndex = 0,
  });

  @override
  State<AdvertisementStoryScreen> createState() => _AdvertisementStoryScreenState();
}

class _AdvertisementStoryScreenState extends State<AdvertisementStoryScreen> {
  late StoryController storyController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    storyController = StoryController();
    currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    storyController.dispose();
    super.dispose();
  }

  AdvertisementModel get currentAdvertisement => widget.advertisementList[currentIndex];

  List<StoryItem> _buildStoryItems() {
    List<StoryItem> items = [];
    
    // If advertisement has a video, use video
    if (currentAdvertisement.video != null && currentAdvertisement.video!.isNotEmpty) {
      items.add(
        StoryItem.pageVideo(
          currentAdvertisement.video!,
          controller: storyController,
          duration: const Duration(seconds: 10),
        ),
      );
    } 
    // Otherwise use cover image
    else if (currentAdvertisement.coverImage != null && currentAdvertisement.coverImage!.isNotEmpty) {
      items.add(
        StoryItem.pageImage(
          url: currentAdvertisement.coverImage!,
          controller: storyController,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    // If no media, show a placeholder
    else {
      items.add(
        StoryItem.text(
          title: currentAdvertisement.title ?? 'Advertisement',
          backgroundColor: Colors.black,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.advertisementList.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text('No advertisements available'),
        ),
      );
    }

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe to next advertisement
          if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            if (currentIndex < widget.advertisementList.length - 1) {
              setState(() {
                storyController.dispose();
                storyController = StoryController();
                currentIndex++;
              });
            } else {
              Navigator.pop(context);
            }
          }

          // Swipe to previous advertisement
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            if (currentIndex > 0) {
              setState(() {
                storyController.dispose();
                storyController = StoryController();
                currentIndex--;
              });
            }
          }
        },
        child: Stack(
          children: [
            StoryView(
              key: ValueKey(currentIndex),
              storyItems: _buildStoryItems(),
              onComplete: () {
                if (currentIndex < widget.advertisementList.length - 1) {
                  setState(() {
                    storyController.dispose();
                    storyController = StoryController();
                    currentIndex++;
                  });
                } else {
                  Navigator.pop(context);
                }
              },
              progressPosition: ProgressPosition.top,
              repeat: false,
              controller: storyController,
              onVerticalSwipeComplete: (direction) {
                if (direction == Direction.down) {
                  Navigator.pop(context);
                }
              },
            ),
            // Close button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 16,
                  right: 16,
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Progress indicator dots
            if (widget.advertisementList.length > 1)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.advertisementList.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: currentIndex == index ? 8 : 6,
                        height: currentIndex == index ? 8 : 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: currentIndex == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Title and description at bottom
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (currentAdvertisement.title != null && currentAdvertisement.title!.isNotEmpty)
                        Text(
                          currentAdvertisement.title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (currentAdvertisement.description != null && currentAdvertisement.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          currentAdvertisement.description!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

