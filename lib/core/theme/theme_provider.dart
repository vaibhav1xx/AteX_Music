import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../data/database/app_database.dart';
import '../../data/models/track.dart';

enum AppThemeSkin {
  studioObsidian(
    id: 'studio_obsidian',
    label: 'Studio Obsidian',
    canvas: Color(0xFF111114),
    sidebar: Color(0xFF09090B),
    card: Color(0xFF16161B),
    cardHover: Color(0xFF1E1E26),
    accent: Color(0xFF38BDF8),
  ),
  pureAmoled(
    id: 'pure_amoled',
    label: 'Pure AMOLED',
    canvas: Color(0xFF000000),
    sidebar: Color(0xFF000000),
    card: Color(0xFF0D0D0D),
    cardHover: Color(0xFF171717),
    accent: Color(0xFFFFFFFF),
  ),
  midnightCobalt(
    id: 'midnight_cobalt',
    label: 'Midnight Cobalt',
    canvas: Color(0xFF0B1020),
    sidebar: Color(0xFF070A14),
    card: Color(0xFF10172D),
    cardHover: Color(0xFF182240),
    accent: Color(0xFF60A5FA),
  ),
  crimsonVinyl(
    id: 'crimson_vinyl',
    label: 'Crimson Vinyl',
    canvas: Color(0xFF140A0C),
    sidebar: Color(0xFF0D0607),
    card: Color(0xFF1D0E12),
    cardHover: Color(0xFF281419),
    accent: Color(0xFFF43F5E),
  ),
  emeraldStudio(
    id: 'emerald_studio',
    label: 'Emerald Studio',
    canvas: Color(0xFF091410),
    sidebar: Color(0xFF050D0A),
    card: Color(0xFF0D1E18),
    cardHover: Color(0xFF132A22),
    accent: Color(0xFF10B981),
  );

  final String id;
  final String label;
  final Color canvas;
  final Color sidebar;
  final Color card;
  final Color cardHover;
  final Color accent;

  const AppThemeSkin({
    required this.id,
    required this.label,
    required this.canvas,
    required this.sidebar,
    required this.card,
    required this.cardHover,
    required this.accent,
  });

  static AppThemeSkin fromId(String? id) {
    return AppThemeSkin.values.firstWhere(
      (s) => s.id == id,
      orElse: () => AppThemeSkin.studioObsidian,
    );
  }
}

class ThemeState {
  final AppThemeSkin skin;
  final bool dynamicAlbumAccent;
  final Color? albumAccentColor;
  final String? customWallpaperPath;
  final double wallpaperBlur;
  final double wallpaperDim;

  const ThemeState({
    this.skin = AppThemeSkin.studioObsidian,
    this.dynamicAlbumAccent = false,
    this.albumAccentColor,
    this.customWallpaperPath,
    this.wallpaperBlur = 15.0,
    this.wallpaperDim = 0.5,
  });

  ThemeState copyWith({
    AppThemeSkin? skin,
    bool? dynamicAlbumAccent,
    Color? albumAccentColor,
    String? customWallpaperPath,
    double? wallpaperBlur,
    double? wallpaperDim,
    bool clearWallpaper = false,
    bool clearAlbumAccent = false,
  }) {
    return ThemeState(
      skin: skin ?? this.skin,
      dynamicAlbumAccent: dynamicAlbumAccent ?? this.dynamicAlbumAccent,
      albumAccentColor: clearAlbumAccent ? null : (albumAccentColor ?? this.albumAccentColor),
      customWallpaperPath: clearWallpaper ? null : (customWallpaperPath ?? this.customWallpaperPath),
      wallpaperBlur: wallpaperBlur ?? this.wallpaperBlur,
      wallpaperDim: wallpaperDim ?? this.wallpaperDim,
    );
  }

  Color get effectiveAccent {
    if (dynamicAlbumAccent && albumAccentColor != null) {
      return albumAccentColor!;
    }
    return skin.accent;
  }

  Color get canvas => skin.canvas;
  Color get sidebar => skin.sidebar;
  Color get card => skin.card;
  Color get cardHover => skin.cardHover;
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  final AppDatabase _database;

  ThemeNotifier(this._database) : super(const ThemeState()) {
    _loadPersistedSettings();
  }

  Future<void> _loadPersistedSettings() async {
    try {
      final themeId = await _database.getSetting('theme_skin_id');
      final dynamicAccentStr = await _database.getSetting('theme_dynamic_accent');
      final wallpaperPath = await _database.getSetting('theme_wallpaper_path');
      final blurStr = await _database.getSetting('theme_wallpaper_blur');
      final dimStr = await _database.getSetting('theme_wallpaper_dim');

      final skin = AppThemeSkin.fromId(themeId);
      final dynamicAccent = dynamicAccentStr == 'true';
      final blur = double.tryParse(blurStr ?? '') ?? 15.0;
      final dim = double.tryParse(dimStr ?? '') ?? 0.5;

      state = state.copyWith(
        skin: skin,
        dynamicAlbumAccent: dynamicAccent,
        customWallpaperPath: wallpaperPath != null && File(wallpaperPath).existsSync() ? wallpaperPath : null,
        wallpaperBlur: blur,
        wallpaperDim: dim,
      );
    } catch (_) {}
  }

  Future<void> setSkin(AppThemeSkin skin) async {
    state = state.copyWith(skin: skin);
    await _database.setSetting('theme_skin_id', skin.id);
  }

  Future<void> setDynamicAlbumAccent(bool enabled) async {
    state = state.copyWith(dynamicAlbumAccent: enabled);
    await _database.setSetting('theme_dynamic_accent', enabled.toString());
  }

  Future<void> setCustomWallpaper(String? path) async {
    if (path == null) {
      state = state.copyWith(clearWallpaper: true);
      await _database.setSetting('theme_wallpaper_path', '');
    } else {
      state = state.copyWith(customWallpaperPath: path);
      await _database.setSetting('theme_wallpaper_path', path);
    }
  }

  Future<void> setWallpaperBlur(double blur) async {
    final clamped = blur.clamp(0.0, 30.0);
    state = state.copyWith(wallpaperBlur: clamped);
    await _database.setSetting('theme_wallpaper_blur', clamped.toString());
  }

  Future<void> setWallpaperDim(double dim) async {
    final clamped = dim.clamp(0.0, 0.95);
    state = state.copyWith(wallpaperDim: clamped);
    await _database.setSetting('theme_wallpaper_dim', clamped.toString());
  }

  Future<void> updateAccentFromTrack(Track track) async {
    if (!state.dynamicAlbumAccent) return;

    if (track.localCoverPath != null && File(track.localCoverPath!).existsSync()) {
      try {
        final palette = await PaletteGenerator.fromImageProvider(
          FileImage(File(track.localCoverPath!)),
          maximumColorCount: 16,
        );
        final dominant = palette.vibrantColor?.color ??
            palette.lightVibrantColor?.color ??
            palette.dominantColor?.color;

        if (dominant != null) {
          state = state.copyWith(albumAccentColor: dominant);
          return;
        }
      } catch (_) {}
    }

    state = state.copyWith(clearAlbumAccent: true);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ThemeNotifier(db);
});
