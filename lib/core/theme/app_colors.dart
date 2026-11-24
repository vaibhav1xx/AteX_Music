import 'package:flutter/material.dart';

/// Design tokens for AteX Music
/// Deep OLED black (#07090E), translucent frosted glass, electric cyan & cobalt accents.
class AppColors {
  AppColors._();

  // Core Backgrounds
  static const Color oledBlack = Color(0xFF07090E);
  static const Color pureBlack = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF0F141F);
  static const Color surfaceElevated = Color(0xFF161C2C);

  // Frosted Glass Surfaces (translucent ~5% white with subtle borders)
  static const Color cardGlass = Color(0x0DFFFFFF); // rgba(255, 255, 255, 0.05)
  static const Color cardGlassHover = Color(0x1AFFFFFF); // rgba(255, 255, 255, 0.10)
  static const Color cardGlassPressed = Color(0x26FFFFFF); // rgba(255, 255, 255, 0.15)
  static const Color glassBorder = Color(0x1FFFFFFF); // rgba(255, 255, 255, 0.12)
  static const Color glassBorderSubtle = Color(0x0FFFFFFF);

  // Accents
  static const Color electricCyan = Color(0xFF00E5FF);
  static const Color deepCobalt = Color(0xFF2979FF);
  static const Color neonBlue = Color(0xFF00B0FF);
  static const Color vibrantPurple = Color(0xFF7C4DFF);

  // Accent Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [electricCyan, deepCobalt],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x1AFFFFFF),
      Color(0x08FFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E9BAE);
  static const Color textTertiary = Color(0xFF4A5568);

  // Android TV & Keyboard Focus Rings
  static const Color tvFocusBorder = electricCyan;
  static const Color tvFocusGlow = Color(0x6600E5FF);
}
