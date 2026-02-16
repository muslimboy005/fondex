import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/responsive.dart';

import 'app_them_data.dart';

class RoundedButtonFill extends StatelessWidget {
  final String title;
  final double? width;
  final double? height;
  final double? fontSizes;
  final double? radius;
  final Color? color;
  final Color? textColor;
  final Widget? icon;
  final bool? isRight;
  final bool? isCenter;
  final Function()? onPress;

  const RoundedButtonFill({
    super.key,
    required this.title,
    this.radius,
    this.height,
    required this.onPress,
    this.width,
    this.color,
    this.isCenter,
    this.icon,
    this.fontSizes,
    this.textColor,
    this.isRight,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onPress?.call();
      },
      child: Container(
        width: width != null ? Responsive.width(width!, context) : null,
        height: Responsive.height(height ?? 6, context),
        decoration: ShapeDecoration(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius ?? 50),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isRight == false)
              Padding(
                padding: const EdgeInsets.only(right: 10, left: 10),
                child: icon,
              ),
            isCenter == true
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        title.tr,
                        textAlign: TextAlign.center,
                        style: AppThemeData.semiBoldTextStyle(
                          fontSize: fontSizes ?? 16,
                          color: textColor ?? AppThemeData.grey50,
                        ),
                      ),
                    ),
                  )
                : Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 8,
                          right: isRight == null ? 8 : 30,
                        ),
                        child: Text(
                          title.tr,
                          textAlign: TextAlign.center,
                          style: AppThemeData.semiBoldTextStyle(
                            fontSize: fontSizes ?? 16,
                            color: textColor ?? AppThemeData.grey50,
                          ),
                        ),
                      ),
                    ),
                  ),
            if (isRight == true)
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: icon,
              ),
          ],
        ),
      ),
    );
  }
}
