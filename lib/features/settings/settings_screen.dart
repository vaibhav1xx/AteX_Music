import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/atex_monogram.dart';
import '../../data/database/app_database.dart';
import '../../data/services/playlist_file_service.dart';
import '../../data/services/update_checker_service.dart';
import '../library/widgets/duplicate_cleaner_dialog.dart';
import '../stats/stats_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _bit32Audio = true;
  bool _replayGain = true;
  bool _gaplessPlayback = true;
  bool _highContrastTv = true;
  bool _carAutoPlay = true;
  bool _bluetoothMediaKeys = true;
  bool _isCheckingUpdate = false;
  String _currentVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentVersion = '${info.version}+${info.buildNumber}';
        });
      }
    } catch (_) {}
  }

  Future<void> _pickWallpaper() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null) {
          await ref.read(themeProvider.notifier).setCustomWallpaper(path);
          if (mounted) {
            AppToast.show(context, 'Wallpaper updated successfully', icon: LucideIcons.image);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed to pick wallpaper: $e');
      }
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isCheckingUpdate = true);
    final service = UpdateCheckerService();

    try {
      final info = await service.checkForUpdate();
      if (!mounted) return;

      if (info.hasUpdate) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.sidebar,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.subtleHairline),
            ),
            title: Row(
              children: const [
                Icon(LucideIcons.sparkles, color: AppColors.accent, size: 20),
                SizedBox(width: 10),
                Text(
                  'Update Available',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A newer version of AteX Music is available: v${info.latestVersion}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current version: v$_currentVersion',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                if (info.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Release Notes:',
                    style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(
                      child: Text(
                        info.releaseNotes,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  UpdateCheckerService.launchUrlExternal(info.releaseUrl);
                },
                child: const Text('Download Update', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      } else {
        AppToast.show(
          context,
          'AteX Music is up to date (v$_currentVersion)',
          icon: LucideIcons.checkCheck,
          iconColor: Colors.greenAccent,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Unable to reach GitHub updates service',
          icon: LucideIcons.alertCircle,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 36 : 20,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings & Engine',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hardware DAC, SQLite offline engine, and system integration.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Zero-Server & Privacy Guarantee Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const AteXMonogram(size: 38, showGlow: false),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '100% Offline-First Architecture',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Zero servers, no tracking, and no telemetry. All audio tracks, playlists, covers, and .lrc lyrics live strictly on your device.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Listening Analytics & AteX Rewind Card
              _buildSectionHeader('LISTENING ANALYTICS & REWIND'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withAlpha(20),
                      AppColors.card,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5722).withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.flame, color: Color(0xFFFF5722), size: 22),
                  ),
                  title: const Text(
                    'AteX Rewind & Listening Stats',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'View listening time, daily streak, weekly activity chart, and shareable 2026 Rewind card.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StatsScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Appearance, Pro Themes & Wallpapers Section
              _buildSectionHeader('APPEARANCE & THEMES'),
              _buildAppearanceSection(),
              const SizedBox(height: 28),

              // Power-User Library Tools Section
              _buildSectionHeader('POWER-USER LIBRARY TOOLS'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(LucideIcons.copy, color: AppColors.accent, size: 20),
                      title: const Text(
                        'Duplicate Track Finder & Cleaner',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Detects duplicates matching title, artist & duration, and removes redundant copies.',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textMuted),
                      onTap: () => showDuplicateCleanerDialog(context, ref),
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),
                    ListTile(
                      leading: const Icon(LucideIcons.fileUp, color: AppColors.accent, size: 20),
                      title: const Text(
                        'Import Playlist (.m3u / .m3u8 / .json)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Import playlists exported from other media players directly into SQLite.',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textMuted),
                      onTap: () async {
                        final db = ref.read(appDatabaseProvider);
                        final res = await PlaylistFileService.importPlaylist(db);
                        if (context.mounted) {
                          AppToast.show(context, res.message, icon: res.success ? LucideIcons.fileCheck : LucideIcons.alertCircle);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Audio Engine Section
              _buildSectionHeader('STUDIO AUDIO ENGINE'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text('32-Bit Float Audio Output', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Direct hardware DAC pass-through for maximum lossless dynamic range.', style: TextStyle(fontSize: 12)),
                      value: _bit32Audio,
                      onChanged: (val) => setState(() => _bit32Audio = val),
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text('ReplayGain Normalization', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Equalizes loudness across disparate offline FLAC/MP3 files.', style: TextStyle(fontSize: 12)),
                      value: _replayGain,
                      onChanged: (val) => setState(() => _replayGain = val),
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text('Gapless Playback', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Seamless track transitions without micro-stutters.', style: TextStyle(fontSize: 12)),
                      value: _gaplessPlayback,
                      onChanged: (val) => setState(() => _gaplessPlayback = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Car, Bluetooth & Headset Section
              _buildSectionHeader('CARPLAY, ANDROID AUTO & BLUETOOTH'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text('In-Car Media Session Auto-Resume', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Resumes offline queue when CarPlay or Android Auto connects.', style: TextStyle(fontSize: 12)),
                      value: _carAutoPlay,
                      onChanged: (val) => setState(() => _carAutoPlay = val),
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text('Hardware Headset & Bluetooth Keys', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Responds to external headphones, car steering wheels, and speaker buttons.', style: TextStyle(fontSize: 12)),
                      value: _bluetoothMediaKeys,
                      onChanged: (val) => setState(() => _bluetoothMediaKeys = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // TV & Accessibility Section
              _buildSectionHeader('ANDROID TV & DISPLAY'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text('High-Contrast TV Focus Rings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Accessible glowing outlines optimized for remote D-Pad traversal.', style: TextStyle(fontSize: 12)),
                      value: _highContrastTv,
                      onChanged: (val) => setState(() => _highContrastTv = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // In-App Updates Section
              _buildSectionHeader('UPDATES & MAINTENANCE'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(LucideIcons.refreshCw, color: AppColors.accent, size: 20),
                      title: const Text(
                        'Check for Updates',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Current version: v$_currentVersion • GitHub Releases',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      trailing: _isCheckingUpdate
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.cardHover,
                                foregroundColor: AppColors.textPrimary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: _isCheckingUpdate ? null : _checkForUpdates,
                              child: const Text('Check Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                      onTap: _isCheckingUpdate ? null : _checkForUpdates,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Metadata & Architecture
              _buildSectionHeader('SYSTEM IDENTITY & RELEASE'),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const AteXMonogram(size: 44, showGlow: false),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'AteX Music',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '100% Offline-First Zero-Server Player',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.subtleHairline),
                    const SizedBox(height: 14),
                    _buildInfoRow('Application Name', 'AteX Music'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Dart Package', 'atex_music'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Application / Bundle ID', 'com.atex.atex_music'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Engine User-Agent', 'AteXMusic/1.0'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Target Platforms', 'Android, iOS, Windows, macOS, Android TV, Car'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Database Engine', 'SQLite via Drift (Persistent Local v2)'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Audio Backend', 'just_audio + media_kit hardware engine'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Version', '1.0.0 (Flagship Release)'),
                  ],
                ),
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Pro Theme Skins Picker
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Curated Pro Theme Skins',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'Select a hardware-optimized color profile with high contrast and OLED power savings.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: AppThemeSkin.values.map((skin) {
                final isSelected = themeState.skin == skin;
                return GestureDetector(
                  onTap: () => themeNotifier.setSkin(skin),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: skin.canvas,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? skin.accent : AppColors.subtleHairline,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: skin.accent.withAlpha(50),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              skin.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                            if (isSelected)
                              Icon(LucideIcons.check, size: 14, color: skin.accent),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: skin.canvas,
                                border: Border.all(color: Colors.white.withAlpha(40), width: 1),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: skin.card,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: skin.accent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.subtleHairline),

          // 2. Dynamic Album-Art Accent Toggle
          SwitchListTile(
            activeColor: themeState.effectiveAccent,
            title: const Text(
              'Dynamic Album-Art Accent',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Tints the app\'s interactive accent colors dynamically to match the current album artwork.',
              style: TextStyle(fontSize: 12),
            ),
            value: themeState.dynamicAlbumAccent,
            onChanged: (val) => themeNotifier.setDynamicAlbumAccent(val),
          ),
          const Divider(height: 1, color: AppColors.subtleHairline),

          // 3. Custom Background Wallpaper Picker
          if (themeState.customWallpaperPath != null && File(themeState.customWallpaperPath!).existsSync()) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(themeState.customWallpaperPath!),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Custom Background Wallpaper Active',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Personalized canvas wallpaper with hardware blur filter.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cardHover,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _pickWallpaper,
                        child: const Text('Change', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Remove Wallpaper',
                        icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent),
                        onPressed: () => themeNotifier.setCustomWallpaper(null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Blur Intensity Slider
                  Row(
                    children: [
                      const Icon(LucideIcons.sparkles, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        'Wallpaper Blur: ${themeState.wallpaperBlur.round()}px',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  Slider(
                    value: themeState.wallpaperBlur,
                    min: 0.0,
                    max: 30.0,
                    divisions: 30,
                    activeColor: themeState.effectiveAccent,
                    onChanged: (val) => themeNotifier.setWallpaperBlur(val),
                  ),

                  // Dim Opacity Slider
                  Row(
                    children: [
                      const Icon(LucideIcons.sunMedium, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        'Dim Overlay: ${(themeState.wallpaperDim * 100).round()}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  Slider(
                    value: themeState.wallpaperDim,
                    min: 0.0,
                    max: 0.95,
                    divisions: 19,
                    activeColor: themeState.effectiveAccent,
                    onChanged: (val) => themeNotifier.setWallpaperDim(val),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListTile(
              leading: const Icon(LucideIcons.image, color: AppColors.accent, size: 20),
              title: const Text(
                'Custom Background Wallpaper',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Personalize the app background with your own image, adjustable blur & dimming.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardHover,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _pickWallpaper,
                child: const Text('Choose Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              onTap: _pickWallpaper,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
