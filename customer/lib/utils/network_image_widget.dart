import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constant/constant.dart';

class NetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final Widget? errorWidget;
  final BoxFit? fit;
  final double? borderRadius;
  final Color? color;
  /// Limit cached image size in memory (pixels). Use for lists with many images to avoid OOM.
  final int? memCacheWidth;
  final int? memCacheHeight;

  const NetworkImageWidget({
    super.key,
    this.height,
    this.width,
    this.fit,
    required this.imageUrl,
    this.borderRadius,
    this.errorWidget,
    this.color,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit ?? BoxFit.fitWidth,
      height: height,
      width: width,
      color: color,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      progressIndicatorBuilder:
          (context, url, downloadProgress) => Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(value: downloadProgress.progress))),
      errorWidget: (context, url, error) => errorWidget ?? Image.network(Constant.placeHolderImage, fit: fit ?? BoxFit.fitWidth, height: height, width: width),
    );
  }
}
