import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/track.dart';
import '../providers/player_provider.dart';
import 'album_art_view.dart';
import 'now_playing_screen.dart';
import 'now_playing_side_panel.dart';
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

  // =========================================================================
  // MOBILE FLOATING MINI-PLAYER (58px, softly tinted + bottom 2px cyan line)
  // =========================================================================
  Widget _buildMobileFloatingCard(
    BuildContext context,
    WidgetRef ref,
    PlayerState playerState,
    Track track,
    VoidCallback openNowPlaying,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: GestureDetector(
        onTap: openNowPlaying,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.card.withAlpha(245),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.subtleHairline, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(140),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      // 42x42 album art
                      AlbumArtView(
                        imageUrl: track.localCoverPath,
                        localFilePath: track.localCoverPath,
                        size: 42,
                        borderRadius: 6,
                        placeholderText: track.title,
                      ),
                      const SizedBox(width: 10),
                      // Title & Artist
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
                                fontWeight: FontWeight.w700,
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
                      // Favorite toggle
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                      const SizedBox(width: 10),
                      // Play/Pause button
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                      const SizedBox(width: 8),
                      // Next track button
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          LucideIcons.skipForward,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                        onPressed: () =>
                            ref.read(playerProvider.notifier).next(),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom 2px #38BDF8 Electric Cyan progress line
              SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: playerState.progressFraction,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent, // #38BDF8
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // DESKTOP DOCK (80px on #09090B with 56x56 art & #38BDF8 seekbar)
  // =========================================================================
  Widget _buildDesktopDock(
    BuildContext context,
    WidgetRef ref,
    PlayerState playerState,
    Track track,
    VoidCallback openNowPlaying,
  ) {
    final notifier = ref.read(playerProvider.notifier);
    final isSidePanelOpen = ref.watch(isNowPlayingSidePanelVisibleProvider);

    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: AppColors.playerDock, // Deep Obsidian #09090B
        border: Border(
          top: BorderSide(color: AppColors.dockHairline, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Left: 56x56 rounded-square art + title + artist + favorite toggle
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
                      size: 56,
                      borderRadius: 8,
                      placeholderText: track.title,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
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
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => notifier.toggleFavorite(),
                            child: Icon(
                              LucideIcons.heart,
                              size: 15,
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Center: Shuffle, Previous, circular #FFFFFF Play/Pause button with black icon,
          // Next, Repeat + sleek #38BDF8 seekbar with live timestamps
          Expanded(
            flex: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top: Playback Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Shuffle',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(
                        LucideIcons.skipBack,
                        color: AppColors.textPrimary,
                        size: 17,
                      ),
                      onPressed: () => notifier.previous(),
                    ),
                    const SizedBox(width: 4),
                    // Circular #FFFFFF Play/Pause button with pure black icon
                    GestureDetector(
                      onTap: () => notifier.togglePlayPause(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.playButtonBg, // Crisp White #FFFFFF
                        ),
                        child: Center(
                          child: playerState.isResolving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.playButtonIcon,
                                  ),
                                )
                              : Icon(
                                  playerState.isPlaying
                                      ? LucideIcons.pause
                                      : LucideIcons.play,
                                  color: AppColors.playButtonIcon, // Black
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Next',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(
                        LucideIcons.skipForward,
                        color: AppColors.textPrimary,
                        size: 17,
                      ),
                      onPressed: () => notifier.next(),
                    ),
                    IconButton(
                      tooltip: 'Repeat',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                // Bottom: Sleek #38BDF8 Electric Cyan Seekbar with timestamps
                SizedBox(
                  height: 14,
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
                            activeTrackColor: AppColors.accent, // #38BDF8
                            inactiveTrackColor: AppColors.subtleHairline,
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 3.5,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 7,
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

          // Right: Synced Lyrics toggle, Queue toggle, Now Playing panel toggle,
          // Volume slider, Full-Screen expand (wrapped in FittedBox to eliminate overflows)
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Speed, Pitch & Sleep Timer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Track Info & Audio Inspector',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(
                      LucideIcons.info,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => showTrackInfoSheet(context, track),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Synced Lyrics',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(
                      LucideIcons.mic2,
                      size: 16,
                      color: playerState.isLyricsVisible
                          ? AppColors.accent
                          : AppColors.textMuted,
                    ),
                    onPressed: () => notifier.toggleLyrics(),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Queue',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(
                      LucideIcons.listMusic,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    onPressed: openNowPlaying,
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: isSidePanelOpen
                        ? 'Hide Now Playing Panel'
                        : 'Show Now Playing Panel',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(
                      LucideIcons.panelRightClose,
                      size: 16,
                      color: isSidePanelOpen
                          ? AppColors.accent
                          : AppColors.textMuted,
                    ),
                    onPressed: () {
                      ref
                              .read(isNowPlayingSidePanelVisibleProvider.notifier)
                              .state =
                          !isSidePanelOpen;
                    },
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
                    width: 60,
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
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Full-Screen Now Playing',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
