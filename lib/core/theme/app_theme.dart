import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.oledBlack,
      canvasColor: AppColors.oledBlack,
      primaryColor: AppColors.electricCyan,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.electricCyan,
        onPrimary: AppColors.pureBlack,
        secondary: AppColors.deepCobalt,
        onSecondary: AppColors.textPrimary,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.electricCyan,
        inactiveTrackColor: Color(0x26FFFFFF),
        thumbColor: AppColors.electricCyan,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayColor: Color(0x2900E5FF),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
        trackHeight: 3.5,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
        ),
        bodySmall: TextStyle(
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
