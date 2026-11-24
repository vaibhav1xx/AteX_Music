import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/frosted_glass.dart';
import '../../../data/repositories/mock_music_repository.dart';
import '../providers/player_provider.dart';
import 'album_art_view.dart';

/// Full-Screen Now Playing overlay with album art, scrubber, lyrics, and controls.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.currentTrack;
    final notifier = ref.read(playerProvider.notifier);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 700;

    return Scaffold(
      backgroundColor: AppColors.oledBlack.withAlpha(240),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Column(
                    children: [
                      const Text(
                        'PLAYING FROM OFFLINE STORAGE',
                        style: TextStyle(
                          color: AppColors.electricCyan,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 24),
                    color: AppColors.textPrimary,
                    onPressed: () => _showTrackOptions(context, track),
                  ),
                ],
              ),
            ),

            // Main Content Area (Cover or Lyrics)
            Expanded(
              child: isWide
                  ? Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: _buildAlbumArt(track, 320),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 36),
                            child: _buildLyricsView(),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _showLyrics
                          ? _buildLyricsView()
                          : Center(
                              child: _buildAlbumArt(track, (size.width * 0.76).clamp(220.0, 360.0)),
                            ),
                    ),
            ),

            // Bottom Track Info, Scrubber & Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title, Artist, & Favorite
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: AppColors.deepCobalt.withAlpha(50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.deepCobalt.withAlpha(120), width: 1),
                          ),
                          child: Text(
                            track.genre,
                            style: const TextStyle(
                              color: AppColors.electricCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: track.isFavorite ? AppColors.electricCyan : AppColors.textSecondary,
                            size: 28,
                          ),
                          onPressed: () => notifier.toggleFavorite(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Scrubber Bar
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        activeTrackColor: AppColors.electricCyan,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(playerState.position),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          Text(
                            _formatDuration(playerState.duration),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Playback Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          tooltip: 'Shuffle',
                          icon: Icon(
                            Icons.shuffle_rounded,
                            size: 24,
                            color: playerState.isShuffle ? AppColors.electricCyan : AppColors.textSecondary,
                          ),
                          onPressed: () => notifier.toggleShuffle(),
                        ),
                        IconButton(
                          tooltip: 'Previous Track',
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            color: AppColors.textPrimary,
                            size: 38,
                          ),
                          onPressed: () => notifier.previous(),
                        ),
                        // Play/Pause Glowing Button
                        GestureDetector(
                          onTap: () => notifier.togglePlayPause(),
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.brandGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.electricCyan.withAlpha(90),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: AppColors.pureBlack,
                              size: 40,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next Track',
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            color: AppColors.textPrimary,
                            size: 38,
                          ),
                          onPressed: () => notifier.next(),
                        ),
                        IconButton(
                          tooltip: 'Repeat',
                          icon: Icon(
                            playerState.repeatMode == PlaybackRepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            size: 24,
                            color: playerState.repeatMode != PlaybackRepeatMode.off
                                ? AppColors.electricCyan
                                : AppColors.textSecondary,
                          ),
                          onPressed: () => notifier.cycleRepeatMode(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() => _showLyrics = !_showLyrics),
                          icon: Icon(
                            Icons.lyrics_outlined,
                            size: 18,
                            color: _showLyrics ? AppColors.electricCyan : AppColors.textSecondary,
                          ),
                          label: Text(
                            _showLyrics ? 'Hide Lyrics' : 'Synced Lyrics',
                            style: TextStyle(
                              color: _showLyrics ? AppColors.electricCyan : AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          'FLAC • 24-bit 96kHz Lossless',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.queue_music_rounded, size: 20),
                          color: AppColors.textSecondary,
                          tooltip: 'Current Queue',
                          onPressed: () => _showQueueModal(context, playerState),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumArt(dynamic track, double artSize) {
    return Hero(
      tag: 'now_playing_${track.id}',
      child: AlbumArtView(
        gradientIndex: track.coverGradientIndex,
        size: artSize,
        borderRadius: 24,
        showGlow: true,
      ),
    );
  }

  Widget _buildLyricsView() {
    return FrostedGlass(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20),
      backgroundColor: const Color(0x18FFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lyrics_rounded, size: 18, color: AppColors.electricCyan),
              SizedBox(width: 8),
              Text(
                'LOCAL SYNCHRONIZED .LRC LYRICS',
                style: TextStyle(
                  color: AppColors.electricCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: MockMusicRepository.sampleLyrics.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 14),
              itemBuilder: (ctx, index) {
                final line = MockMusicRepository.sampleLyrics[index];
                final isCurrent = index == 3;
                return Text(
                  line,
                  style: TextStyle(
                    color: isCurrent ? AppColors.electricCyan : AppColors.textSecondary.withAlpha(160),
                    fontSize: isCurrent ? 17 : 14,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  ),
                );
              },
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

  void _showTrackOptions(BuildContext context, dynamic track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: AppColors.electricCyan),
                title: const Text('Track File Information'),
                subtitle: Text(track.filePath, style: const TextStyle(fontSize: 11)),
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: AppColors.textPrimary),
                title: const Text('Add to Local Playlist'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
                title: const Text('Share Audio File'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueueModal(BuildContext context, PlayerState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Queue (${state.queue.length} Tracks)',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: state.queue.length,
                itemBuilder: (ctx, i) {
                  final t = state.queue[i];
                  final isCurrent = t.id == state.currentTrack.id;
                  return ListTile(
                    leading: AlbumArtView(gradientIndex: t.coverGradientIndex, size: 40, borderRadius: 8),
                    title: Text(
                      t.title,
                      style: TextStyle(
                        color: isCurrent ? AppColors.electricCyan : AppColors.textPrimary,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(t.artist),
                    trailing: isCurrent
                        ? const Icon(Icons.volume_up_rounded, color: AppColors.electricCyan, size: 20)
                        : Text(t.durationFormatted, style: const TextStyle(color: AppColors.textSecondary)),
                    onTap: () {
                      ref.read(playerProvider.notifier).playTrack(t);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
