import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/synced_lyric.dart';
import '../providers/player_provider.dart';
import 'album_art_view.dart';

final isNowPlayingSidePanelVisibleProvider = StateProvider<bool>((ref) => false);

/// Spotify-inspired Desktop Right "Now Playing" Side Panel
class NowPlayingSidePanel extends ConsumerWidget {
  const NowPlayingSidePanel({super.key});

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
''';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.currentTrack;
    final notifier = ref.read(playerProvider.notifier);

    // Calculate next track in queue
    final nextTrack = (playerState.queueIndex + 1 < playerState.queue.length)
        ? playerState.queue[playerState.queueIndex + 1]
        : null;

    // Load lyrics snippet
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
    final activeLine = activeIndex >= 0 && activeIndex < lyrics.length
        ? lyrics[activeIndex].text
        : (lyrics.isNotEmpty ? lyrics.first.text : 'No synchronized lyrics available');

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.subtleHairline),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.disc,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Now Playing',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    LucideIcons.x,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => ref
                      .read(isNowPlayingSidePanelVisibleProvider.notifier)
                      .state = false,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.subtleHairline),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Large Square Artwork
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AlbumArtView(
                      imageUrl: track.localCoverPath,
                      localFilePath: track.localCoverPath,
                      size: 248,
                      borderRadius: 10,
                      showShadow: true,
                      placeholderText: track.title,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title, Artist, & Favorite Heart
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        track.isFavorite ? LucideIcons.heart : LucideIcons.heart,
                        color: track.isFavorite
                            ? AppColors.accent
                            : AppColors.textMuted,
                        size: 20,
                      ),
                      onPressed: () => notifier.toggleFavorite(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Live Synced Lyrics Preview Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.subtleHairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            LucideIcons.mic2,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'LIVE LYRICS PREVIEW',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        activeLine,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Next In Queue Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.subtleHairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'NEXT IN QUEUE',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (nextTrack != null)
                            GestureDetector(
                              onTap: () => notifier.next(),
                              child: const Text(
                                'Skip to next',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (nextTrack != null)
                        Row(
                          children: [
                            AlbumArtView(
                              imageUrl: nextTrack.localCoverPath,
                              localFilePath: nextTrack.localCoverPath,
                              size: 44,
                              borderRadius: 6,
                              placeholderText: nextTrack.title,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nextTrack.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    nextTrack.artist,
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
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                LucideIcons.play,
                                size: 16,
                                color: AppColors.accent,
                              ),
                              onPressed: () => notifier.next(),
                            ),
                          ],
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'No more tracks in queue',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
