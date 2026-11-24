import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Official branded emblem for AteX Music.
/// Renders the official white distressed sigil logo mark.
class AteXMonogram extends StatelessWidget {
  final double size;
  final bool showGlow;

  const AteXMonogram({
    super.key,
    this.size = 36,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showGlow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.electricCyan.withAlpha(70),
                  blurRadius: size * 0.4,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: Image.asset(
        'assets/icon/logo_mark.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
