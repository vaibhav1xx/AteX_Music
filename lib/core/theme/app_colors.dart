import 'package:flutter/material.dart';

/// Studio Obsidian Design Tokens (Apple Music / Tidal / Spotify Desktop Caliber)
class AppColors {
  AppColors._();

  // Obsidian Surfaces
  static const Color sidebar = Color(0xFF09090B); // Clean dark sidebar
  static const Color canvas = Color(0xFF111114); // Main deep canvas
  static const Color card = Color(0xFF16161B); // Borderless card surface
  static const Color cardHover = Color(0xFF1E1E26); // Elevated card hover
  static const Color cardActive = Color(0xFF252530);
  static const Color playerDock = Color(0xFF0C0C0F); // 84px bottom player dock
  static const Color dockHairline = Color(0xFF222228); // Subtle 1px dock top hairline
  static const Color surfaceElevated = Color(0xFF18181D);

  // Border & Hairlines
  static const Color subtleHairline = Color(0xFF1F1F24);
  static const Color pillFill = Color(0x1AFFFFFF); // Translucent active tab pill

  // Primary Buttons (Spotify / Apple Music style)
  static const Color playButtonBg = Color(0xFFFFFFFF); // Crisp white
  static const Color playButtonIcon = Color(0xFF09090B); // Pure black

  // Accent (Restrained: active seekbar, active tab, active karaoke lyric lines)
  static const Color accent = Color(0xFF38BDF8); // Electric sky blue
  static const Color accentGlow = Color(0x3338BDF8);

  // Typography
  static const Color textPrimary = Color(0xFFF4F4F5); // Crisp primary text
  static const Color textSecondary = Color(0xFFA1A1AA); // Muted artist/metadata text
  static const Color textMuted = Color(0xFF71717A); // Tertiary timestamps/labels

  // Legacy backwards-compatibility aliases
  static const Color electricCyan = accent;
  static const Color deepCobalt = Color(0xFF0284C7);
  static const Color oledBlack = canvas;
  static const Color pureBlack = Color(0xFF000000);
  static const Color surfaceDark = canvas;
  static const Color cardGlass = card;
  static const Color cardGlassHover = cardHover;
  static const Color glassBorder = subtleHairline;
  static const Color glassBorderSubtle = dockHairline;
  static const Color tvFocusBorder = accent;
  static const Color tvFocusGlow = accentGlow;
}
