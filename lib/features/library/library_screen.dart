import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/focusable_card.dart';
import '../../data/repositories/mock_music_repository.dart';
import '../player/providers/player_provider.dart';
import '../player/widgets/album_art_view.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 20,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Tab Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Library',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.electricCyan,
                      side: const BorderSide(color: AppColors.glassBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Local file scanner ready. Pass 2 integrates native storage.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Scan Storage', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.electricCyan,
                labelColor: AppColors.electricCyan,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Tracks'),
                  Tab(text: 'Albums'),
                  Tab(text: 'Playlists'),
                  Tab(text: 'Local Folders'),
                ],
              ),
              const SizedBox(height: 16),

              // Tab View Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Tracks List
                    ListView.separated(
                      itemCount: MockMusicRepository.sampleTracks.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final track = MockMusicRepository.sampleTracks[index];
                        return FocusableCard(
                          borderRadius: BorderRadius.circular(14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          onTap: () => playerNotifier.playTrack(track),
                          child: Row(
                            children: [
                              Text(
                                '${index + 1}'.padLeft(2, '0'),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 14),
                              AlbumArtView(
                                gradientIndex: track.coverGradientIndex,
                                size: 44,
                                borderRadius: 10,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${track.artist} • ${track.album}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                track.durationFormatted,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: track.isFavorite ? AppColors.electricCyan : AppColors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () {
                                  playerNotifier.toggleFavorite();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Tab 2: Albums Grid
                    GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 4 : 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: 4,
                      itemBuilder: (ctx, index) {
                        final albumNames = ['Vektor Horizons', 'Subsurface Echoes', 'Binary Midnight', 'Dark Prism'];
                        final artists = ['Cyberstrider', 'Aura Protocol', 'Glitch Noir', 'Kroma Void'];
                        return FocusableCard(
                          borderRadius: BorderRadius.circular(16),
                          padding: const EdgeInsets.all(12),
                          onTap: () {
                            playerNotifier.playTrack(MockMusicRepository.sampleTracks[index % MockMusicRepository.sampleTracks.length]);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: AlbumArtView(
                                  gradientIndex: index,
                                  size: isDesktop ? 140 : 110,
                                  borderRadius: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                albumNames[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                artists[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Tab 3: Playlists List
                    ListView.separated(
                      itemCount: MockMusicRepository.samplePlaylists.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        final pl = MockMusicRepository.samplePlaylists[index];
                        return FocusableCard(
                          borderRadius: BorderRadius.circular(14),
                          padding: const EdgeInsets.all(12),
                          onTap: () {
                            playerNotifier.playTrack(MockMusicRepository.sampleTracks[index % MockMusicRepository.sampleTracks.length]);
                          },
                          child: Row(
                            children: [
                              AlbumArtView(
                                gradientIndex: pl.coverGradientIndex,
                                size: 50,
                                borderRadius: 10,
                                fallbackIcon: Icons.playlist_play_rounded,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pl.name,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      pl.description,
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
                              Text(
                                '${pl.trackCount} Tracks',
                                style: const TextStyle(
                                  color: AppColors.electricCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Tab 4: Local Folders
                    ListView(
                      children: [
                        _buildFolderTile(
                          context,
                          title: 'Internal Music',
                          path: '/storage/emulated/0/Music',
                          trackCount: 4,
                        ),
                        const SizedBox(height: 10),
                        _buildFolderTile(
                          context,
                          title: 'Lossless Audio Downloads',
                          path: '/storage/emulated/0/Download/AteX',
                          trackCount: 3,
                        ),
                        const SizedBox(height: 10),
                        _buildFolderTile(
                          context,
                          title: 'User Audio Library (Desktop)',
                          path: 'C:\\Users\\Music\\AteX',
                          trackCount: 7,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderTile(BuildContext context, {required String title, required String path, required int trackCount}) {
    return FocusableCard(
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardGlass,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.folder_special_rounded, color: AppColors.electricCyan, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  path,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$trackCount files',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
