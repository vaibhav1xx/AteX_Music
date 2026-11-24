import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/track.dart';
import '../providers/player_provider.dart';
import 'album_art_view.dart';
import 'now_playing_screen.dart';
import 'playback_effects_sheet.dart';
import 'track_info_sheet.dart';

class MiniPlayer extends ConsumerWidget {
  final bool isDesktopDock;

  const MiniPlayer({super.key, this.isDesktopDock = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.currentTrack;

    void openNowPlaying() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const NowPlayingScreen(),
      );
    }

    if (isDesktopDock) {
      return _buildDesktopDock(
        context,
        ref,
        playerState,
        track,
        openNowPlaying,
      );
    }

    return _buildMobileFloatingCard(
      context,
      ref,
      playerState,
      track,
      openNowPlaying,
    );
  }

  Widget _buildMobileFloatingCard(
    BuildContext context,
    WidgetRef ref,
    PlayerState playerState,
    Track track,
    VoidCallback openNowPlaying,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: GestureDetector(
        onTap: openNowPlaying,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.card.withAlpha(240),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.subtleHairline, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(120),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: playerState.progressFraction,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    AlbumArtView(
                      imageUrl: track.localCoverPath,
                      localFilePath: track.localCoverPath,
                      size: 42,
                      borderRadius: 6,
                      placeholderText: track.title,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pro Controls',
                      icon: const Icon(
                        LucideIcons.slidersHorizontal,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => showPlaybackEffectsSheet(context, ref),
                    ),
                    IconButton(
                      icon: Icon(
                        track.isFavorite
                            ? LucideIcons.heart
                            : LucideIcons.heart,
                        color: track.isFavorite
                            ? AppColors.accent
                            : AppColors.textMuted,
                        size: 18,
                      ),
                      onPressed: () =>
                          ref.read(playerProvider.notifier).toggleFavorite(),
                    ),
                    IconButton(
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.playButtonBg,
                        ),
                        child: playerState.isResolving
                            ? const Padding(
                                padding: EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.playButtonIcon,
                                ),
                              )
                            : Icon(
                                playerState.isPlaying
                                    ? LucideIcons.pause
                                    : LucideIcons.play,
                                color: AppColors.playButtonIcon,
                                size: 16,
                              ),
                      ),
                      onPressed: () =>
                          ref.read(playerProvider.notifier).togglePlayPause(),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.skipForward,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                      onPressed: () => ref.read(playerProvider.notifier).next(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDock(
    BuildContext context,
    WidgetRef ref,
    PlayerState playerState,
    Track track,
    VoidCallback openNowPlaying,
  ) {
    final notifier = ref.read(playerProvider.notifier);

    return Container(
      height: 84,
      decoration: const BoxDecoration(
        color: AppColors.playerDock,
        border: Border(
          top: BorderSide(color: AppColors.dockHairline, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Left (30%): 54x54 album art + Title + Artist + Heart toggle
          Expanded(
            flex: 3,
            child: Row(
              children: [
                GestureDetector(
                  onTap: openNowPlaying,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AlbumArtView(
                      imageUrl: track.localCoverPath,
                      localFilePath: track.localCoverPath,
                      size: 54,
                      borderRadius: 8,
                      placeholderText: track.title,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => notifier.toggleFavorite(),
                            child: Icon(
                              LucideIcons.heart,
                              size: 14,
                              color: track.isFavorite
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Center (40%): Controls + Seekbar
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top: Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Shuffle',
                      icon: Icon(
                        LucideIcons.shuffle,
                        size: 15,
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
                        size: 17,
                      ),
                      onPressed: () => notifier.previous(),
                    ),
                    const SizedBox(width: 4),
                    // Crisp 38px circular Play button
                    GestureDetector(
                      onTap: () => notifier.togglePlayPause(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.playButtonBg,
                        ),
                        child: Center(
                          child: playerState.isResolving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.playButtonIcon,
                                  ),
                                )
                              : Icon(
                                  playerState.isPlaying
                                      ? LucideIcons.pause
                                      : LucideIcons.play,
                                  color: AppColors.playButtonIcon,
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Next',
                      icon: const Icon(
                        LucideIcons.skipForward,
                        color: AppColors.textPrimary,
                        size: 17,
                      ),
                      onPressed: () => notifier.next(),
                    ),
                    IconButton(
                      tooltip: 'Repeat',
                      icon: Icon(
                        playerState.repeatMode == PlaybackRepeatMode.one
                            ? LucideIcons.repeat1
                            : LucideIcons.repeat,
                        size: 15,
                        color: playerState.repeatMode != PlaybackRepeatMode.off
                            ? AppColors.accent
                            : AppColors.textMuted,
                      ),
                      onPressed: () => notifier.cycleRepeatMode(),
                    ),
                  ],
                ),
                // Bottom: Seekbar with timestamps
                SizedBox(
                  height: 18,
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(playerState.position),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.0,
                            activeTrackColor: AppColors.accent,
                            inactiveTrackColor: AppColors.subtleHairline,
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 4,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 8,
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
                      ),
                      Text(
                        _formatDuration(playerState.duration),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right (30%): Speed/Effects, Track Inspector, Lyrics, Queue, Volume, Fullscreen
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Speed, Pitch & Sleep Timer',
                  icon: Icon(
                    LucideIcons.slidersHorizontal,
                    size: 16,
                    color:
                        (playerState.speed != 1.0 ||
                            playerState.pitch != 1.0 ||
                            playerState.skipSilence ||
                            playerState.sleepTimerMinutesRemaining != null)
                        ? AppColors.accent
                        : AppColors.textMuted,
                  ),
                  onPressed: () => showPlaybackEffectsSheet(context, ref),
                ),
                IconButton(
                  tooltip: 'Track Info & Audio Inspector',
                  icon: const Icon(
                    LucideIcons.info,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => showTrackInfoSheet(context, track),
                ),
                IconButton(
                  tooltip: 'Lyrics',
                  icon: Icon(
                    LucideIcons.mic2,
                    size: 16,
                    color: playerState.isLyricsVisible
                        ? AppColors.accent
                        : AppColors.textMuted,
                  ),
                  onPressed: () => notifier.toggleLyrics(),
                ),
                IconButton(
                  tooltip: 'Queue',
                  icon: const Icon(
                    LucideIcons.listMusic,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  onPressed: openNowPlaying,
                ),
                const SizedBox(width: 4),
                Icon(
                  playerState.volume > 0
                      ? LucideIcons.volume2
                      : LucideIcons.volumeX,
                  color: AppColors.textMuted,
                  size: 16,
                ),
                SizedBox(
                  width: 72,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: AppColors.subtleHairline,
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 3,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 6,
                      ),
                    ),
                    child: Slider(
                      value: playerState.volume,
                      onChanged: (val) => notifier.setVolume(val),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Full-Screen Now Playing',
                  icon: const Icon(
                    LucideIcons.maximize2,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                  onPressed: openNowPlaying,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
