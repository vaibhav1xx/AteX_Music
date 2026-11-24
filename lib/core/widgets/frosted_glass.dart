import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// High-performance frosted glass container with BackdropFilter blur,
/// translucent background, and subtle 1px border.
class FrostedGlass extends StatelessWidget {
  final Widget child;
  final double blur;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxShadow? glow;

  const FrostedGlass({
    super.key,
    required this.child,
    this.blur = 18.0,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);

    Widget container = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.cardGlass,
            borderRadius: radius,
            border: Border.all(
              color: borderColor ?? AppColors.glassBorder,
              width: borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (glow != null) {
      container = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [glow!],
        ),
        child: container,
      );
    }

    if (margin != null) {
      return Padding(padding: margin!, child: container);
    }
    return container;
  }
}
