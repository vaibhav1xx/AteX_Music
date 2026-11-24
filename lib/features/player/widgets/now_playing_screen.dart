import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/track_action_menu.dart';
import '../../../data/models/synced_lyric.dart';
import '../../../data/models/track.dart';
import '../providers/player_provider.dart';
import 'album_art_view.dart';
import 'audio_visualizer.dart';
import 'playback_effects_sheet.dart';
import 'track_info_sheet.dart';

enum NowPlayingViewMode { cover, visualizer, lyrics }

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastActiveIndex = -1;
  bool _mobileShowLyrics = false;
  String? _lastTrackId;
  NowPlayingViewMode _viewMode = NowPlayingViewMode.cover;

  static const String _defaultLrc = '''
[00:00.00] (Instrumental Intro)
[00:08.50] Deep within the night skyline
[00:15.20] Digital audio flowing in high fidelity
[00:23.40] Zero latency, offline clarity
[00:31.80] Resonating clean on every device
[00:40.10] Studio obsidian depth beneath the lights
[00:48.50] We find our rhythm in lossless frequencies
[00:56.90] Infinite sound, pure music memory
[01:05.30] Electric cyan cutting through the deep dark
[01:13.70] Playing clean without a single server spark
[01:22.00] (Solo Groove)
[01:45.00] AteX Music • 100% Offline Flagship Audio
''';

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _autoScrollLyrics(int activeIndex) {
    if (activeIndex != _lastActiveIndex && _lyricsScrollController.hasClients) {
      _lastActiveIndex = activeIndex;
      final targetOffset = (activeIndex * 48.0) - 100.0;
      _lyricsScrollController.animateTo(
        targetOffset.clamp(
          0.0,
          _lyricsScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.currentTrack;
    final notifier = ref.read(playerProvider.notifier);
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;

    final themeState = ref.watch(themeProvider);
    final effectiveAccent = themeState.effectiveAccent;

    if (_lastTrackId != track.id) {
      _lastTrackId = track.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(themeProvider.notifier).updateAccentFromTrack(track);
        }
      });
    }

    // Parse lyrics from local file if available or default LRC
    String lrcText = _defaultLrc;
    if (track.localLyricsPath != null &&
        File(track.localLyricsPath!).existsSync()) {
      try {
        lrcText = File(track.localLyricsPath!).readAsStringSync();
      } catch (_) {}
    }
    final lyrics = SyncedLyricLine.parseLrc(lrcText);
    final activeIndex = SyncedLyricLine.getActiveIndex(
      lyrics,
      playerState.position,
    );
    _autoScrollLyrics(activeIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full-bleed blurred album artwork backdrop
          Positioned.fill(child: _buildBackdrop(track)),

          // Deep dark gradient vignette over backdrop
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withAlpha(210),
                    Colors.black.withAlpha(235),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 2. Foreground UI
          SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          LucideIcons.chevronDown,
                          size: 24,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Column(
                        children: [
                          Text(
                            'PLAYING FROM OFFLINE ENGINE',
                            style: TextStyle(
                              color: effectiveAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.album,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Speed & Sleep Timer',
                            icon: Icon(
                              LucideIcons.slidersHorizontal,
                              size: 19,
                              color:
                                  (playerState.speed != 1.0 ||
                                      playerState.pitch != 1.0 ||
                                      playerState.skipSilence ||
                                      playerState.sleepTimerMinutesRemaining !=
                                          null)
                                  ? effectiveAccent
                                  : AppColors.textPrimary,
                            ),
                            onPressed: () =>
                                showPlaybackEffectsSheet(context, ref),
                          ),
                          IconButton(
                            tooltip: 'Track Inspector & Options',
                            icon: const Icon(
                              LucideIcons.moreVertical,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () =>
                                showTrackActionMenu(context, ref, track),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Togglable Segmented Control: [ Cover Art | Visualizer | Synced Lyrics ]
                _buildModeSegmentedControl(effectiveAccent),

                // Main Content (Dual column on desktop; switchable on mobile)
                Expanded(
                  child: isDesktop
                      ? Row(
                          children: [
                            // Left: Album Art or Audio Visualizer
                            Expanded(
                              flex: 5,
                              child: Center(
                                child:
                                    _viewMode == NowPlayingViewMode.visualizer
                                    ? AudioVisualizerView(
                                        isPlaying: playerState.isPlaying,
                                        position: playerState.position,
                                        accentColor: effectiveAccent,
                                        track: track,
                                        size: 360,
                                      )
                                    : _buildCoverArea(track, 360),
                              ),
                            ),
                            // Right: Karaoke Synced Lyrics
                            Expanded(
                              flex: 6,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 48,
                                  top: 20,
                                  bottom: 20,
                                ),
                                child: _buildLyricsList(
                                  lyrics,
                                  activeIndex,
                                  effectiveAccent,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: switch (_viewMode) {
                            NowPlayingViewMode.visualizer => Center(
                              child: AudioVisualizerView(
                                isPlaying: playerState.isPlaying,
                                position: playerState.position,
                                accentColor: effectiveAccent,
                                track: track,
                                size: (MediaQuery.sizeOf(context).width * 0.82)
                                    .clamp(260.0, 360.0),
                              ),
                            ),
                            NowPlayingViewMode.lyrics => _buildLyricsList(
                              lyrics,
                              activeIndex,
                              effectiveAccent,
                            ),
                            NowPlayingViewMode.cover => Center(
                              child: _buildCoverArea(
                                track,
                                (MediaQuery.sizeOf(context).width * 0.78).clamp(
                                  240.0,
                                  360.0,
                                ),
                              ),
                            ),
                          },
                        ),
                ),

                // Bottom Controls & Scrub Area
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Track Title, Artist, Heart
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Track Info & Audio Inspector',
                              icon: const Icon(
                                LucideIcons.info,
                                size: 20,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () =>
                                  showTrackInfoSheet(context, track),
                            ),
                            IconButton(
                              icon: Icon(
                                track.isFavorite
                                    ? LucideIcons.heart
                                    : LucideIcons.heart,
                                color: track.isFavorite
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                                size: 22,
                              ),
                              onPressed: () => notifier.toggleFavorite(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Seekbar Slider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.5,
                            activeTrackColor: AppColors.accent,
                            inactiveTrackColor: Colors.white.withAlpha(30),
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 10,
                            ),
                          ),
                          child: Slider(
                            value: playerState.position.inSeconds
                                .toDouble()
                                .clamp(
                                  0.0,
                                  playerState.duration.inSeconds.toDouble(),
                                ),
                            max: playerState.duration.inSeconds > 0
                                ? playerState.duration.inSeconds.toDouble()
                                : 1.0,
                            onChanged: (val) {
                              notifier.seekTo(Duration(seconds: val.toInt()));
                            },
                          ),
                        ),

                        // Elapsed & Total Timestamps
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(playerState.position),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                _formatDuration(playerState.duration),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Transport Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              tooltip: 'Shuffle',
                              icon: Icon(
                                LucideIcons.shuffle,
                                size: 20,
                                color: playerState.isShuffle
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                              ),
                              onPressed: () => notifier.toggleShuffle(),
                            ),
                            IconButton(
                              tooltip: 'Previous',
                              icon: const Icon(
                                LucideIcons.skipBack,
                                color: AppColors.textPrimary,
                                size: 28,
                              ),
                              onPressed: () => notifier.previous(),
                            ),
                            // Crisp White Circular Play Button
                            GestureDetector(
                              onTap: () => notifier.togglePlayPause(),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.playButtonBg,
                                ),
                                child: Center(
                                  child: playerState.isResolving
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.playButtonIcon,
                                          ),
                                        )
                                      : Icon(
                                          playerState.isPlaying
                                              ? LucideIcons.pause
                                              : LucideIcons.play,
                                          color: AppColors.playButtonIcon,
                                          size: 26,
                                        ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next',
                              icon: const Icon(
                                LucideIcons.skipForward,
                                color: AppColors.textPrimary,
                                size: 28,
                              ),
                              onPressed: () => notifier.next(),
                            ),
                            IconButton(
                              tooltip: 'Repeat',
                              icon: Icon(
                                playerState.repeatMode == PlaybackRepeatMode.one
                                    ? LucideIcons.repeat1
                                    : LucideIcons.repeat,
                                size: 20,
                                color:
                                    playerState.repeatMode !=
                                        PlaybackRepeatMode.off
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                              ),
                              onPressed: () => notifier.cycleRepeatMode(),
                            ),
                          ],
                        ),

                        if (!isDesktop) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: () => setState(
                                  () => _mobileShowLyrics = !_mobileShowLyrics,
                                ),
                                icon: Icon(
                                  LucideIcons.mic2,
                                  size: 16,
                                  color: _mobileShowLyrics
                                      ? AppColors.accent
                                      : AppColors.textMuted,
                                ),
                                label: Text(
                                  _mobileShowLyrics
                                      ? 'Show Artwork'
                                      : 'Karaoke Lyrics',
                                  style: TextStyle(
                                    color: _mobileShowLyrics
                                        ? AppColors.accent
                                        : AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop(Track track) {
    if (track.localCoverPath != null &&
        track.localCoverPath!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: track.localCoverPath!,
        fit: BoxFit.cover,
        imageBuilder: (context, imageProvider) {
          return ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Image(image: imageProvider, fit: BoxFit.cover),
          );
        },
        errorWidget: (context, url, error) =>
            Container(color: AppColors.sidebar),
      );
    } else if (track.localCoverPath != null &&
        File(track.localCoverPath!).existsSync()) {
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Image.file(File(track.localCoverPath!), fit: BoxFit.cover),
      );
    }
    return Container(color: AppColors.sidebar);
  }

  Widget _buildCoverArea(Track track, double size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AlbumArtView(
          imageUrl: track.localCoverPath,
          localFilePath: track.localCoverPath,
          size: size,
          borderRadius: 16,
          showShadow: true,
          placeholderText: track.title,
        ),
      ],
    );
  }

  Widget _buildModeSegmentedControl(Color accent) {
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 10),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentItem(
            NowPlayingViewMode.cover,
            LucideIcons.disc,
            'Cover',
            accent,
          ),
          _buildSegmentItem(
            NowPlayingViewMode.visualizer,
            LucideIcons.activity,
            'Visualizer',
            accent,
          ),
          _buildSegmentItem(
            NowPlayingViewMode.lyrics,
            LucideIcons.mic2,
            'Lyrics',
            accent,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(
    NowPlayingViewMode mode,
    IconData icon,
    String label,
    Color accent,
  ) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.black : Colors.white.withAlpha(180),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white.withAlpha(180),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsList(
    List<SyncedLyricLine> lines,
    int activeIndex, [
    Color? accent,
  ]) {
    final effectiveAccent = accent ?? AppColors.accent;
    if (lines.isEmpty) {
      return const Center(
        child: Text(
          'No synced lyrics available for this track',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      controller: _lyricsScrollController,
      itemCount: lines.length,
      padding: const EdgeInsets.symmetric(vertical: 40),
      itemBuilder: (context, index) {
        final line = lines[index];
        final isActive = index == activeIndex;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            line.text,
            style: TextStyle(
              color: isActive
                  ? effectiveAccent
                  : AppColors.textMuted.withAlpha(140),
              fontSize: isActive ? 22 : 16,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              letterSpacing: isActive ? -0.4 : 0,
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
