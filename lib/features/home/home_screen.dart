import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atex_monogram.dart';
import '../../core/widgets/focusable_card.dart';
import '../../core/widgets/frosted_glass.dart';
import '../../data/repositories/mock_music_repository.dart';
import '../player/providers/player_provider.dart';
import '../player/widgets/album_art_view.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback onOpenLibrary;

  const HomeScreen({
    super.key,
    required this.onOpenLibrary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // App Bar / Branded Header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 20,
                isDesktop ? 24 : 16,
                isDesktop ? 32 : 20,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AteXMonogram(size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'AteX Music',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'OFFLINE LOSSLESS ENGINE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.electricCyan,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Offline Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.cardGlass,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.electricCyan,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.tvFocusGlow,
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '100% Offline',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Hero Banner Card
                  FrostedGlass(
                    padding: const EdgeInsets.all(22),
                    borderRadius: BorderRadius.circular(20),
                    backgroundColor: const Color(0x181E293B),
                    borderColor: AppColors.glassBorder,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.deepCobalt.withAlpha(50),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'NO SERVER • ZERO LATENCY',
                                  style: TextStyle(
                                    color: AppColors.electricCyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Local Library Ready',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '7 Lossless local tracks indexed across your device storage.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.electricCyan,
                                  foregroundColor: AppColors.pureBlack,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  playerNotifier.toggleShuffle();
                                  playerNotifier.playTrack(MockMusicRepository.sampleTracks.first);
                                },
                                icon: const Icon(Icons.shuffle_rounded, size: 20),
                                label: const Text(
                                  'Shuffle All Tracks',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isDesktop)
                          const Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: AteXMonogram(size: 96, showGlow: true),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Section 1: Jump Back In
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 20,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Jump Back In',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenLibrary,
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: AppColors.electricCyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Horizontal Tracks Carousel
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 20,
                ),
                itemCount: MockMusicRepository.sampleTracks.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final track = MockMusicRepository.sampleTracks[index];
                  return SizedBox(
                    width: 150,
                    child: FocusableCard(
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.all(12),
                      onTap: () => playerNotifier.playTrack(track),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: AlbumArtView(
                              gradientIndex: track.coverGradientIndex,
                              size: 110,
                              borderRadius: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
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
                  );
                },
              ),
            ),
          ),

          // Section 2: Local Playlists
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 20,
                24,
                isDesktop ? 32 : 20,
                12,
              ),
              child: const Text(
                'Offline Playlists',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // Playlists Grid
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 20,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: isDesktop ? 2.2 : 1.3,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final pl = MockMusicRepository.samplePlaylists[index];
                  return FocusableCard(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.all(12),
                    onTap: () {
                      playerNotifier.playTrack(MockMusicRepository.sampleTracks[index % MockMusicRepository.sampleTracks.length]);
                    },
                    child: Row(
                      children: [
                        AlbumArtView(
                          gradientIndex: pl.coverGradientIndex,
                          size: isDesktop ? 54 : 44,
                          borderRadius: 10,
                          fallbackIcon: Icons.queue_music_rounded,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pl.name,
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
                                '${pl.trackCount} Tracks',
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
                  );
                },
                childCount: MockMusicRepository.samplePlaylists.length,
              ),
            ),
          ),

          // Extra spacing for bottom mini-player
          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }
}
