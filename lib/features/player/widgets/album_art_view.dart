import 'package:flutter/material.dart';

class AlbumArtView extends StatelessWidget {
  final int gradientIndex;
  final double size;
  final double borderRadius;
  final bool showGlow;
  final IconData? fallbackIcon;

  const AlbumArtView({
    super.key,
    required this.gradientIndex,
    this.size = 52,
    this.borderRadius = 12,
    this.showGlow = false,
    this.fallbackIcon,
  });

  static const List<List<Color>> gradients = [
    [Color(0xFF00E5FF), Color(0xFF2979FF)], // Electric Cyan -> Cobalt
    [Color(0xFF00F2FE), Color(0xFF4FACFE)], // Azure
    [Color(0xFFFF0844), Color(0xFFFFB199)], // Crimson Cyber
    [Color(0xFF8A2387), Color(0xFFE94057)], // Deep Purple & Pink
    [Color(0xFF11998E), Color(0xFF38EF7D)], // Neon Mint Emerald
    [Color(0xFFF12711), Color(0xFFF5AF19)], // Solar Flare
  ];

  @override
  Widget build(BuildContext context) {
    final colors = gradients[gradientIndex % gradients.length];

    Widget art = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withAlpha(40),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background subtle pattern circle
          Positioned(
            right: -size * 0.2,
            bottom: -size * 0.2,
            child: Container(
              width: size * 0.8,
              height: size * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(25),
              ),
            ),
          ),
          Icon(
            fallbackIcon ?? Icons.graphic_eq_rounded,
            size: size * 0.44,
            color: Colors.white.withAlpha(230),
          ),
        ],
      ),
    );

    if (showGlow) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: colors.first.withAlpha(90),
              blurRadius: size * 0.35,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: art,
      );
    }

    return art;
  }
}
