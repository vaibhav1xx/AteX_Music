import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/atex_monogram.dart';
import '../../data/database/app_database.dart';
import '../../data/models/track.dart';
import '../../data/scanner/music_scanner.dart';
import '../../data/services/playlist_file_service.dart';
import '../../data/services/update_checker_service.dart';
import '../library/widgets/duplicate_cleaner_dialog.dart';
import '../player/providers/player_provider.dart';
import '../player/widgets/playback_effects_sheet.dart';
import '../stats/stats_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isCheckingUpdate = false;
  bool _isScanningFolders = false;
  bool _isCalculatingCache = false;
  double _cacheSizeBytes = 0;
  String _currentVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _calculateStorageUsage();
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

  Future<void> _calculateStorageUsage() async {
    if (_isCalculatingCache) return;
    setState(() => _isCalculatingCache = true);

    int totalBytes = 0;
    try {
      // 1. Calculate offline media storage (AteX_Music/Media)
      final docs = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(docs.path, 'AteX_Music', 'Media'));
      if (mediaDir.existsSync()) {
        for (final entity in mediaDir.listSync(recursive: true)) {
          if (entity is File) {
            totalBytes += entity.lengthSync();
          }
        }
      }

      // 2. Calculate temporary cache files
      final temp = await getTemporaryDirectory();
      if (temp.existsSync()) {
        for (final entity in temp.listSync(recursive: true)) {
          if (entity is File) {
            totalBytes += entity.lengthSync();
          }
        }
      }
    } catch (e) {
      debugPrint('Storage calculation error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _cacheSizeBytes = totalBytes.toDouble();
          _isCalculatingCache = false;
        });
      }
    }
  }

  Future<void> _clearStorageCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.subtleHairline),
        ),
        title: const Text(
          'Clear Storage Cache?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will remove downloaded offline audio streams, covers, and cached temporary media. Your playlists and track listings in SQLite will be preserved.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear Storage',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final mediaDir = Directory(p.join(docs.path, 'AteX_Music', 'Media'));
        if (mediaDir.existsSync()) {
          mediaDir.deleteSync(recursive: true);
          mediaDir.createSync(recursive: true);
        }

        final temp = await getTemporaryDirectory();
        if (temp.existsSync()) {
          for (final entity in temp.listSync(recursive: false)) {
            try {
              entity.deleteSync(recursive: true);
            } catch (_) {}
          }
        }

        await _calculateStorageUsage();
        if (mounted) {
          AppToast.show(
            context,
            'Storage cache cleared successfully',
            icon: LucideIcons.trash2,
          );
        }
      } catch (e) {
        if (mounted) {
          AppToast.show(context, 'Failed to clear cache: $e');
        }
      }
    }
  }

  Future<void> _triggerFolderScan() async {
    setState(() => _isScanningFolders = true);
    final scanner = ref.read(musicScannerProvider);
    final db = ref.read(appDatabaseProvider);

    try {
      final res = await scanner.scanAndImport(db);
      if (mounted) {
        AppToast.show(
          context,
          res.statusMessage,
          icon: res.success ? LucideIcons.check : LucideIcons.alertCircle,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Folder scan error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isScanningFolders = false);
        _calculateStorageUsage();
      }
    }
  }

  Future<void> _exportLibraryM3u() async {
    final db = ref.read(appDatabaseProvider);
    final tracks = await db.getAllTracks();
    final domainTracks = tracks.map((d) => Track.fromDb(d)).toList();
    final res = await PlaylistFileService.exportToM3u(
      'AteX_Full_Library',
      domainTracks,
    );
    if (mounted) {
      AppToast.show(context, res.message, icon: LucideIcons.fileCheck);
    }
  }

  Future<void> _exportLibraryJson() async {
    final db = ref.read(appDatabaseProvider);
    final tracks = await db.getAllTracks();
    final domainTracks = tracks.map((d) => Track.fromDb(d)).toList();
    final res = await PlaylistFileService.exportToJson(
      'AteX_Library_Backup',
      domainTracks,
    );
    if (mounted) {
      AppToast.show(context, res.message, icon: LucideIcons.fileCheck);
    }
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
            AppToast.show(
              context,
              'Wallpaper updated successfully',
              icon: LucideIcons.image,
            );
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
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A newer version of AteX Music is available: v${info.latestVersion}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current version: v$_currentVersion',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (info.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Release Notes:',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Later',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  UpdateCheckerService.launchUrlExternal(info.releaseUrl);
                },
                child: const Text(
                  'Download Update',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
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

  String _formatBytes(double bytes) {
    if (bytes <= 0) return '0.0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      final gb = mb / 1024;
      return '${gb.toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);

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
                'Native audio DSP, offline storage management, and personalized visuals.',
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
                    colors: [AppColors.accent.withAlpha(20), AppColors.card],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5722).withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.flame,
                      color: Color(0xFFFF5722),
                      size: 22,
                    ),
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
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
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

              // Real Audio Playback & DSP Controls Section
              _buildSectionHeader('AUDIO PLAYBACK & DSP ENGINE'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Skip Silence Toggle (Wired to JustAudio)
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text(
                        'Skip Silence',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Automatically skips silent passages and dead space between tracks.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: playerState.skipSilence,
                      onChanged: (val) => playerNotifier.setSkipSilence(val),
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),

                    // Playback Speed Selector (Wired to JustAudio)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Playback Speed',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${playerState.speed}x',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                              final isSel =
                                  (playerState.speed - speed).abs() < 0.05;
                              return ChoiceChip(
                                label: Text(
                                  '${speed}x',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                selected: isSel,
                                selectedColor: AppColors.accent,
                                labelStyle: TextStyle(
                                  color: isSel
                                      ? Colors.black
                                      : AppColors.textPrimary,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                                onSelected: (_) =>
                                    playerNotifier.setSpeed(speed),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),

                    // Playback Pitch Selector (Wired to JustAudio)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Pitch Shifting',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${playerState.pitch}x',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [0.8, 0.9, 1.0, 1.1, 1.2].map((pitch) {
                              final isSel =
                                  (playerState.pitch - pitch).abs() < 0.05;
                              return ChoiceChip(
                                label: Text(
                                  '${pitch}x',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                selected: isSel,
                                selectedColor: AppColors.accent,
                                labelStyle: TextStyle(
                                  color: isSel
                                      ? Colors.black
                                      : AppColors.textPrimary,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                                onSelected: (_) =>
                                    playerNotifier.setPitch(pitch),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),

                    // Pro Audio Effects & Equalizer Sheet Button
                    ListTile(
                      leading: const Icon(
                        LucideIcons.slidersHorizontal,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      title: const Text(
                        'Playback Effects & Equalizer Studio',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Fine-tune speed, pitch sliders, and audio processing presets.',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      onTap: () => showPlaybackEffectsSheet(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Sleep Timer Section
              _buildSectionHeader('SLEEP TIMER'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              LucideIcons.moon,
                              color: AppColors.accent,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Auto-Pause Sleep Timer',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (playerState.sleepTimerMinutesRemaining != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.accent,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${playerState.sleepTimerMinutesRemaining}m remaining',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Gradually stops music playback after selected duration.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text(
                            'Off',
                            style: TextStyle(fontSize: 12),
                          ),
                          selected:
                              playerState.sleepTimerMinutesRemaining == null,
                          selectedColor: AppColors.accent,
                          labelStyle: TextStyle(
                            color:
                                playerState.sleepTimerMinutesRemaining == null
                                ? Colors.black
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => playerNotifier.cancelSleepTimer(),
                        ),
                        ...[15, 30, 45, 60, 90].map((mins) {
                          final isSel =
                              playerState.sleepTimerMinutesRemaining != null &&
                              (playerState.sleepTimerMinutesRemaining! <=
                                      mins &&
                                  playerState.sleepTimerMinutesRemaining! >
                                      mins - 15);
                          return ChoiceChip(
                            label: Text(
                              '${mins}m',
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: isSel,
                            selectedColor: AppColors.accent,
                            labelStyle: TextStyle(
                              color: isSel
                                  ? Colors.black
                                  : AppColors.textPrimary,
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            onSelected: (_) {
                              playerNotifier.setSleepTimer(mins);
                              AppToast.show(
                                context,
                                'Sleep timer set for $mins minutes',
                                icon: LucideIcons.moon,
                              );
                            },
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
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
                      leading: _isScanningFolders
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          : const Icon(
                              LucideIcons.folderDown,
                              color: AppColors.accent,
                              size: 20,
                            ),
                      title: const Text(
                        'Scan Device Audio Folders',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Index all local audio files (MP3, FLAC, M4A, WAV, OGG) into SQLite storage.',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cardHover,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isScanningFolders
                            ? null
                            : _triggerFolderScan,
                        child: Text(
                          _isScanningFolders ? 'Scanning...' : 'Scan Now',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      onTap: _isScanningFolders ? null : _triggerFolderScan,
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),
                    ListTile(
                      leading: const Icon(
                        LucideIcons.copy,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      title: const Text(
                        'Duplicate Track Finder & Cleaner',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Detects duplicates matching title, artist & duration, and removes redundant copies.',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      onTap: () => showDuplicateCleanerDialog(context, ref),
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),
                    ListTile(
                      leading: const Icon(
                        LucideIcons.fileUp,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      title: const Text(
                        'Import Playlist (.m3u / .m3u8 / .json)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Import playlists exported from other media players directly into SQLite.',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      onTap: () async {
                        final db = ref.read(appDatabaseProvider);
                        final res = await PlaylistFileService.importPlaylist(
                          db,
                        );
                        if (context.mounted) {
                          AppToast.show(
                            context,
                            res.message,
                            icon: res.success
                                ? LucideIcons.fileCheck
                                : LucideIcons.alertCircle,
                          );
                        }
                      },
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),
                    ListTile(
                      leading: const Icon(
                        LucideIcons.fileDown,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      title: const Text(
                        'Export Library to M3U8 Playlist',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Backup your complete library track paths into a portable .m3u8 file.',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(
                        LucideIcons.share,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      onTap: _exportLibraryM3u,
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),
                    ListTile(
                      leading: const Icon(
                        LucideIcons.databaseBackup,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      title: const Text(
                        'Export Library Metadata to JSON',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Structured JSON export containing song titles, artists, albums, and timestamps.',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(
                        LucideIcons.share,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      onTap: _exportLibraryJson,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Storage & Cache Cleaner Section (Real MB Calculation)
              _buildSectionHeader('STORAGE & CACHE CLEANER'),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withAlpha(25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                LucideIcons.hardDrive,
                                color: AppColors.accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Offline Media & Cache',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isCalculatingCache
                                      ? 'Calculating disk usage...'
                                      : '${_formatBytes(_cacheSizeBytes)} storage used',
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Recalculate Storage',
                          icon: const Icon(
                            LucideIcons.refreshCw,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          onPressed: _isCalculatingCache
                              ? null
                              : _calculateStorageUsage,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Includes downloaded full-length songs, high-res covers, .lrc synced lyrics, and temporary cached files.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(
                            color: Colors.redAccent,
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _cacheSizeBytes <= 0
                            ? null
                            : _clearStorageCache,
                        icon: const Icon(LucideIcons.trash2, size: 16),
                        label: const Text(
                          'Clear Media Cache & Free Space',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
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
                      leading: const Icon(
                        LucideIcons.refreshCw,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      title: const Text(
                        'Check for Updates',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Current version: v$_currentVersion • GitHub Releases',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: _isCheckingUpdate
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.cardHover,
                                foregroundColor: AppColors.textPrimary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: _isCheckingUpdate
                                  ? null
                                  : _checkForUpdates,
                              child: const Text(
                                'Check Now',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                      onTap: _isCheckingUpdate ? null : _checkForUpdates,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Metadata & System Invariants (AGENTS.md Compliance)
              _buildSectionHeader('SYSTEM IDENTITY & METADATA'),
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
                    _buildInfoRow(
                      'Application / Bundle ID',
                      'com.atex.atex_music',
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow('Engine User-Agent', 'AteXMusic/1.0'),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      'Target Platforms',
                      'Android, iOS, Windows, macOS, Android TV, Car',
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      'Database Engine',
                      'SQLite via Drift (Persistent Local v2)',
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      'Audio Backend',
                      'just_audio + media_kit hardware engine',
                    ),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Select a hardware-optimized color profile with high contrast and OLED power savings.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
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
                        color: isSelected
                            ? skin.accent
                            : AppColors.subtleHairline,
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
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                LucideIcons.check,
                                size: 14,
                                color: skin.accent,
                              ),
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
                                border: Border.all(
                                  color: Colors.white.withAlpha(40),
                                  width: 1,
                                ),
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
          if (themeState.customWallpaperPath != null &&
              File(themeState.customWallpaperPath!).existsSync()) ...[
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
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Personalized canvas wallpaper with hardware blur filter.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cardHover,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _pickWallpaper,
                        child: const Text(
                          'Change',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Remove Wallpaper',
                        icon: const Icon(
                          LucideIcons.trash2,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => themeNotifier.setCustomWallpaper(null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Blur Intensity Slider
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.sparkles,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Wallpaper Blur: ${themeState.wallpaperBlur.round()}px',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
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
                      const Icon(
                        LucideIcons.sunMedium,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dim Overlay: ${(themeState.wallpaperDim * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
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
              leading: const Icon(
                LucideIcons.image,
                color: AppColors.accent,
                size: 20,
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _pickWallpaper,
                child: const Text(
                  'Choose Image',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
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
