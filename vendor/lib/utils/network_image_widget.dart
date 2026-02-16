import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/themes/responsive.dart';

class NetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final Widget? errorWidget;
  final BoxFit? fit;
  final double? borderRadius;
  final Color? color;

  const NetworkImageWidget({
    super.key,
    this.height,
    this.width,
    this.fit,
    required this.imageUrl,
    this.borderRadius,
    this.errorWidget,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Handle empty or "null" string URLs
    if (imageUrl.isEmpty || imageUrl == 'null') {
      return errorWidget ??
          Container(
            height: height ?? Responsive.height(8, context),
            width: width ?? Responsive.width(15, context),
            color: Colors.grey.shade300,
            child: Icon(Icons.image, color: Colors.grey.shade600, size: 24),
          );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit ?? BoxFit.fitWidth,
      height: height ?? Responsive.height(8, context),
      width: width ?? Responsive.width(15, context),
      color: color,
      progressIndicatorBuilder: (context, url, downloadProgress) =>
          Constant.loader(),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            height: height ?? Responsive.height(8, context),
            width: width ?? Responsive.width(15, context),
            color: Colors.grey.shade300,
            child: Icon(
              Icons.broken_image,
              color: Colors.grey.shade600,
              size: 24,
            ),
          ),
    );
  }
}
