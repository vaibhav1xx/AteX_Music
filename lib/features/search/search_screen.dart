import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/focusable_card.dart';
import '../../core/widgets/frosted_glass.dart';
import '../../data/models/track.dart';
import '../../data/repositories/mock_music_repository.dart';
import '../player/providers/player_provider.dart';
import '../player/widgets/album_art_view.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedGenre = 'All';
  String _query = '';

  static const List<String> genres = [
    'All',
    'Synthwave',
    'Cyberpunk',
    'Ambient',
    'Electronic',
    'Lo-Fi',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Track> get _filteredTracks {
    return MockMusicRepository.sampleTracks.where((t) {
      final matchesQuery = _query.isEmpty ||
          t.title.toLowerCase().contains(_query.toLowerCase()) ||
          t.artist.toLowerCase().contains(_query.toLowerCase()) ||
          t.album.toLowerCase().contains(_query.toLowerCase());
      final matchesGenre = _selectedGenre == 'All' || t.genre == _selectedGenre;
      return matchesQuery && matchesGenre;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;
    final results = _filteredTracks;

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
              // Search Input Box
              FrostedGlass(
                height: 52,
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: const Color(0x18FFFFFF),
                borderColor: AppColors.glassBorder,
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.electricCyan, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Search songs, artists, albums, or local folders...',
                          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _query = val),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Genre Filter Chips
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: genres.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 10),
                  itemBuilder: (ctx, index) {
                    final g = genres[index];
                    final isSelected = g == _selectedGenre;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedGenre = g),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.electricCyan : AppColors.cardGlass,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? AppColors.electricCyan : AppColors.glassBorder,
                          ),
                        ),
                        child: Text(
                          g,
                          style: TextStyle(
                            color: isSelected ? AppColors.pureBlack : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Results Count / Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${results.length} Local Tracks Found',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    'Indexed locally',
                    style: TextStyle(
                      color: AppColors.electricCyan,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Results List
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.music_off_rounded, size: 54, color: AppColors.textTertiary),
                            SizedBox(height: 12),
                            Text(
                              'No matching tracks found in local storage.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final track = results[index];
                          return FocusableCard(
                            borderRadius: BorderRadius.circular(14),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            onTap: () => playerNotifier.playTrack(track),
                            child: Row(
                              children: [
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardGlass,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    track.genre,
                                    style: const TextStyle(
                                      color: AppColors.electricCyan,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                Text(
                                  track.durationFormatted,
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
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
