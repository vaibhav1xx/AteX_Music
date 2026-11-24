import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/frosted_glass.dart';
import '../providers/player_provider.dart';
import 'album_art_view.dart';
import 'now_playing_screen.dart';

/// Frosted Mini-Player widget.
/// Displayed as a floating frosted card on mobile (under 700px) or as a dock on desktop.
class MiniPlayer extends ConsumerWidget {
  final bool isDesktopDock;

  const MiniPlayer({
    super.key,
    this.isDesktopDock = false,
  });

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
      return _buildDesktopDock(context, ref, playerState, track, openNowPlaying);
    }

    return _buildMobileFloatingCard(context, ref, playerState, track, openNowPlaying);
  }

  Widget _buildMobileFloatingCard(
    BuildContext context,
    WidgetRef ref,
    PlayerState playerState,
    dynamic track,
    VoidCallback openNowPlaying,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: GestureDetector(
        onTap: openNowPlaying,
        child: FrostedGlass(
          height: 64,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: const Color(0x22121724),
          borderColor: AppColors.glassBorder,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tiny top progress indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: playerState.progressFraction,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.electricCyan),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    AlbumArtView(
                      gradientIndex: track.coverGradientIndex,
                      size: 42,
                      borderRadius: 10,
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
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: track.isFavorite ? AppColors.electricCyan : AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => ref.read(playerProvider.notifier).toggleFavorite(),
                    ),
                    IconButton(
                      icon: Icon(
                        playerState.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                        color: AppColors.electricCyan,
                        size: 36,
                      ),
                      onPressed: () => ref.read(playerProvider.notifier).togglePlayPause(),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: AppColors.textPrimary,
                        size: 24,
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
    dynamic track,
    VoidCallback openNowPlaying,
  ) {
    final notifier = ref.read(playerProvider.notifier);

    return FrostedGlass(
      height: 90,
      borderRadius: BorderRadius.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      backgroundColor: const Color(0x330B0F19),
      borderColor: AppColors.glassBorderSubtle,
      child: Row(
        children: [
          // Left: Track Info & Favorite
          SizedBox(
            width: 220,
            child: Row(
              children: [
                GestureDetector(
                  onTap: openNowPlaying,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AlbumArtView(
                      gradientIndex: track.coverGradientIndex,
                      size: 48,
                      borderRadius: 10,
                      showGlow: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                  tooltip: 'Favorite',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: track.isFavorite ? AppColors.electricCyan : AppColors.textSecondary,
                    size: 18,
                  ),
                  onPressed: () => notifier.toggleFavorite(),
                ),
              ],
            ),
          ),

          // Center: Player Controls & Scrubber Bar
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Controls Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Shuffle',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(
                        Icons.shuffle_rounded,
                        size: 18,
                        color: playerState.isShuffle ? AppColors.electricCyan : AppColors.textSecondary,
                      ),
                      onPressed: () => notifier.toggleShuffle(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Previous',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                      onPressed: () => notifier.previous(),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: playerState.isPlaying ? 'Pause' : 'Play',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      icon: Icon(
                        playerState.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                        color: AppColors.electricCyan,
                        size: 36,
                      ),
                      onPressed: () => notifier.togglePlayPause(),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Next',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                      onPressed: () => notifier.next(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Repeat',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(
                        playerState.repeatMode == PlaybackRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        size: 18,
                        color: playerState.repeatMode != PlaybackRepeatMode.off
                            ? AppColors.electricCyan
                            : AppColors.textSecondary,
                      ),
                      onPressed: () => notifier.cycleRepeatMode(),
                    ),
                  ],
                ),
                // Scrubber Bar Row
                SizedBox(
                  height: 24,
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(playerState.position),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.5,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                          ),
                          child: Slider(
                            value: playerState.position.inSeconds
                                .toDouble()
                                .clamp(0.0, playerState.duration.inSeconds.toDouble()),
                            max: playerState.duration.inSeconds.toDouble(),
                            onChanged: (val) {
                              notifier.seekTo(Duration(seconds: val.toInt()));
                            },
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(playerState.duration),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right: Volume & Expand Full Screen
          SizedBox(
            width: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Lyrics',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(
                    Icons.lyrics_outlined,
                    color: playerState.isLyricsVisible ? AppColors.electricCyan : AppColors.textSecondary,
                    size: 18,
                  ),
                  onPressed: () => notifier.toggleLyrics(),
                ),
                const Icon(
                  Icons.volume_up_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                SizedBox(
                  width: 70,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                    ),
                    child: Slider(
                      value: playerState.volume,
                      onChanged: (val) => notifier.setVolume(val),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Expand Now Playing',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(
                    Icons.open_in_full_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
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
