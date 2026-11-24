import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import '../../data/database/app_database.dart';
import '../../data/models/radio_station.dart';
import '../../data/models/track.dart';
import '../../data/scanner/music_scanner.dart';
import '../../data/services/music_charts_service.dart';
import '../../data/services/podcast_service.dart';
import '../../data/services/radio_service.dart';
import '../player/providers/player_provider.dart';
import '../player/widgets/album_art_view.dart';
import '../podcast/widgets/podcast_episodes_sheet.dart';

enum HomeCategory { all, music, radio, podcasts }

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenLibrary;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenStats;

  const HomeScreen({
    super.key,
    required this.onOpenLibrary,
    this.onOpenSearch,
    this.onOpenStats,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  HomeCategory _selectedCategory = HomeCategory.all;
  bool _isScanning = false;

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _triggerScan() async {
    setState(() => _isScanning = true);
    final scanner = ref.read(musicScannerProvider);
    final db = ref.read(appDatabaseProvider);

    try {
      final result = await scanner.scanAndImport(db);
      if (!mounted) return;
      AppToast.show(
        context,
        result.statusMessage,
        icon: result.success ? LucideIcons.check : LucideIcons.alertCircle,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, 'Scan error: $e', icon: LucideIcons.alertCircle);
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;
    final selectedCountry = ref.watch(regionCountryProvider);
    final isIndia = selectedCountry == 'in';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Subtle top ambient gradient wash (tinted softly by Electric Cyan #38BDF8)
          Positioned(
            top: -120,
            left: 0,
            right: 0,
            height: 380,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.1,
                    colors: [
                      AppColors.accent.withAlpha(45),
                      const Color(0xFF0369A1).withAlpha(20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          CustomScrollView(
            slivers: [
              // Header Row: Time-of-day greeting + India/Global toggle + Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 32 : 18,
                    isDesktop ? 24 : 16,
                    isDesktop ? 32 : 18,
                    12,
                  ),
                  child: Row(
                    children: [
                      // Greeting
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getTimeGreeting(),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Discover Indian-first audio, keyless radio & podcasts',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // India / Global Storefront Toggle
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.subtleHairline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildRegionButton(
                              label: 'India 🇮🇳',
                              isSelected: isIndia,
                              onTap: () =>
                                  ref
                                          .read(regionCountryProvider.notifier)
                                          .state =
                                      'in',
                            ),
                            _buildRegionButton(
                              label: 'Global 🌐',
                              isSelected: !isIndia,
                              onTap: () =>
                                  ref
                                          .read(regionCountryProvider.notifier)
                                          .state =
                                      'us',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Import Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cardHover,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 12 : 10,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 34),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _isScanning ? null : _triggerScan,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              )
                            : const Icon(
                                LucideIcons.folderDown,
                                size: 15,
                                color: AppColors.accent,
                              ),
                        label: Text(
                          _isScanning
                              ? '...'
                              : (isDesktop ? 'Import Music' : 'Import'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Category Pills (All, Music, Radio, Podcasts)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 18,
                    vertical: 6,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryPill(HomeCategory.all, 'All'),
                        const SizedBox(width: 8),
                        _buildCategoryPill(HomeCategory.music, 'Music'),
                        const SizedBox(width: 8),
                        _buildCategoryPill(HomeCategory.radio, 'Live Radio'),
                        const SizedBox(width: 8),
                        _buildCategoryPill(HomeCategory.podcasts, 'Podcasts'),
                      ],
                    ),
                  ),
                ),
              ),

              // Content according to selected Category
              if (_selectedCategory == HomeCategory.all ||
                  _selectedCategory == HomeCategory.music)
                ..._buildMusicSection(isDesktop),

              if (_selectedCategory == HomeCategory.all ||
                  _selectedCategory == HomeCategory.radio)
                ..._buildRadioSection(isDesktop),

              if (_selectedCategory == HomeCategory.all ||
                  _selectedCategory == HomeCategory.podcasts)
                ..._buildPodcastSection(isDesktop),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegionButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill(HomeCategory cat, String label) {
    final isSelected = _selectedCategory == cat;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.subtleHairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.textPrimary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // MUSIC SECTION: Quick Picks 2-Row Grid + Indian-First Shelves
  // =========================================================================
  List<Widget> _buildMusicSection(bool isDesktop) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final dbTracksAsync = ref.watch(allTracksStreamProvider);
    final trendingSongsAsync = ref.watch(trendingSongsProvider);
    final bollywoodHitsAsync = ref.watch(bollywoodHitsProvider);
    final punjabiHitsAsync = ref.watch(punjabiHitsProvider);
    final desiHipHopAsync = ref.watch(desiHipHopProvider);
    final trendingAlbumsAsync = ref.watch(trendingAlbumsProvider);

    final localTracks =
        dbTracksAsync.valueOrNull?.map((d) => d.toDomain()).toList() ?? [];
    final trendingSongs = trendingSongsAsync.valueOrNull ?? [];
    final bollywoodHits = bollywoodHitsAsync.valueOrNull ?? [];
    final punjabiHits = punjabiHitsAsync.valueOrNull ?? [];
    final desiHipHop = desiHipHopAsync.valueOrNull ?? [];
    final trendingAlbums = trendingAlbumsAsync.valueOrNull ?? [];

    // Signature 6-track 2-row Quick Picks
    final quickPicks = localTracks.isNotEmpty
        ? localTracks.take(6).toList()
        : trendingSongs.take(6).toList();

    final isIndia = ref.watch(regionCountryProvider) == 'in';

    return [
      // 1. Signature 2-Row Quick Picks Grid
      if (quickPicks.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 32 : 18,
              14,
              isDesktop ? 32 : 18,
              8,
            ),
            child: const Text(
              'Quick Picks',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 18,
            4,
            isDesktop ? 32 : 18,
            16,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 3 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: isDesktop ? 3.4 : 2.5,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final track = quickPicks[index];
              return _SpotifyQuickPickTile(
                track: track,
                onPlay: () => playerNotifier.playTrack(track),
              );
            }, childCount: quickPicks.length),
          ),
        ),
      ],

      // 2. Shelf: Trending in India / Global Trending
      _buildShelfHeader(
        isDesktop: isDesktop,
        title: isIndia ? 'Trending in India' : 'Global Most Played',
        subtitle: isIndia
            ? 'Top chartbusters across India'
            : 'Real-time global charts',
      ),
      SliverToBoxAdapter(
        child: trendingSongs.isNotEmpty
            ? SizedBox(
                height: 244,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 18,
                  ),
                  itemCount: trendingSongs.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final track = trendingSongs[index];
                    return _SpotifySquareAlbumCard(
                      track: track,
                      onPlay: () => playerNotifier.playTrack(track),
                    );
                  },
                ),
              )
            : (trendingSongsAsync.isLoading
                  ? SizedBox(
                      height: 244,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 32 : 18,
                        ),
                        child: const ShimmerHorizontalCharts(),
                      ),
                    )
                  : const SizedBox.shrink()),
      ),

      // 3. Shelf: Bollywood Chartbusters
      _buildShelfHeader(
        isDesktop: isDesktop,
        title: 'Bollywood Chartbusters',
        subtitle: 'The biggest Hindi film melodies & blockbuster hits',
      ),
      SliverToBoxAdapter(
        child: bollywoodHits.isNotEmpty
            ? SizedBox(
                height: 244,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 18,
                  ),
                  itemCount: bollywoodHits.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final track = bollywoodHits[index];
                    return _SpotifySquareAlbumCard(
                      track: track,
                      onPlay: () => playerNotifier.playTrack(track),
                    );
                  },
                ),
              )
            : (bollywoodHitsAsync.isLoading
                  ? SizedBox(
                      height: 244,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 32 : 18,
                        ),
                        child: const ShimmerHorizontalCharts(),
                      ),
                    )
                  : const SizedBox.shrink()),
      ),

      // 4. Shelf: Punjabi Hits
      _buildShelfHeader(
        isDesktop: isDesktop,
        title: 'Punjabi Hits & Fire',
        subtitle: 'Bhangra, urban Punjabi bass & high-energy anthems',
      ),
      SliverToBoxAdapter(
        child: punjabiHits.isNotEmpty
            ? SizedBox(
                height: 244,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 18,
                  ),
                  itemCount: punjabiHits.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final track = punjabiHits[index];
                    return _SpotifySquareAlbumCard(
                      track: track,
                      onPlay: () => playerNotifier.playTrack(track),
                    );
                  },
                ),
              )
            : (punjabiHitsAsync.isLoading
                  ? SizedBox(
                      height: 244,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 32 : 18,
                        ),
                        child: const ShimmerHorizontalCharts(),
                      ),
                    )
                  : const SizedBox.shrink()),
      ),

      // 5. Shelf: Desi Hip-Hop
      _buildShelfHeader(
        isDesktop: isDesktop,
        title: 'Desi Hip-Hop & Rap',
        subtitle: 'Gully rap, drill, and underground Indian street flow',
      ),
      SliverToBoxAdapter(
        child: desiHipHop.isNotEmpty
            ? SizedBox(
                height: 244,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 18,
                  ),
                  itemCount: desiHipHop.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final track = desiHipHop[index];
                    return _SpotifySquareAlbumCard(
                      track: track,
                      onPlay: () => playerNotifier.playTrack(track),
                    );
                  },
                ),
              )
            : (desiHipHopAsync.isLoading
                  ? SizedBox(
                      height: 244,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 32 : 18,
                        ),
                        child: const ShimmerHorizontalCharts(),
                      ),
                    )
                  : const SizedBox.shrink()),
      ),

      // 6. Shelf: Trending Albums
      if (trendingAlbums.isNotEmpty) ...[
        _buildShelfHeader(
          isDesktop: isDesktop,
          title: 'Trending Albums',
          subtitle: 'Featured full-length releases',
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 18),
              itemCount: trendingAlbums.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final album = trendingAlbums[index];
                return _AlbumCardItem(album: album);
              },
            ),
          ),
        ),
      ],
    ];
  }

  Widget _buildShelfHeader({
    required bool isDesktop,
    required String title,
    required String subtitle,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 32 : 18,
          26,
          isDesktop ? 32 : 18,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // RADIO SECTION (Keyless Free Radio Browser API)
  // =========================================================================
  List<Widget> _buildRadioSection(bool isDesktop) {
    final topRadioAsync = ref.watch(topRadioStationsProvider);
    final indiaRadioAsync = ref.watch(indiaRadioStationsProvider);

    return [
      _buildShelfHeader(
        isDesktop: isDesktop,
        title: 'India Live Radio Broadcasts',
        subtitle: 'AIR, Vividh Bharati, Mirchi & top regional FM stations',
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 180,
          child: indiaRadioAsync.when(
            data: (stations) => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 18),
              itemCount: stations.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 14),
              itemBuilder: (context, index) =>
                  _RadioStationCardItem(station: stations[index]),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),
      ),
      _buildShelfHeader(
        isDesktop: isDesktop,
        title: 'Top Global Radio Stations',
        subtitle: 'Free and keyless live streams from around the globe',
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 180,
          child: topRadioAsync.when(
            data: (stations) => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 18),
              itemCount: stations.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 14),
              itemBuilder: (context, index) =>
                  _RadioStationCardItem(station: stations[index]),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    ];
  }

  // =========================================================================
  // PODCASTS SECTION
  // =========================================================================
  List<Widget> _buildPodcastSection(bool isDesktop) {
    final popularPodcastsAsync = ref.watch(popularPodcastsProvider);

    return [
      _buildShelfHeader(
        isDesktop: isDesktop,
        title: 'Featured Podcasts & Shows',
        subtitle: '1-tap offline download & streaming',
      ),
      popularPodcastsAsync.when(
        data: (podcasts) => SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 18),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final podcast = podcasts[index];
              return GestureDetector(
                onTap: () => showPodcastEpisodesSheet(context, ref, podcast),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.subtleHairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: AlbumArtView(
                          imageUrl: podcast.artworkUrl,
                          size: isDesktop ? 120 : 100,
                          borderRadius: 8,
                          placeholderText: podcast.title,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        podcast.title,
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
                        podcast.artist,
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
            }, childCount: podcasts.length),
          ),
        ),
        loading: () => const SliverToBoxAdapter(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
        error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      ),
    ];
  }
}

/// Spotify's signature 56px Quick Pick Tile with circular #38BDF8 Play Button on hover
class _SpotifyQuickPickTile extends StatefulWidget {
  final Track track;
  final VoidCallback onPlay;

  const _SpotifyQuickPickTile({required this.track, required this.onPlay});

  @override
  State<_SpotifyQuickPickTile> createState() => _SpotifyQuickPickTileState();
}

class _SpotifyQuickPickTileState extends State<_SpotifyQuickPickTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.cardHover : AppColors.card,
            borderRadius: BorderRadius.circular(6),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Left square 56px cover art
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(6),
                ),
                child: AlbumArtView(
                  imageUrl: widget.track.localCoverPath,
                  localFilePath: widget.track.localCoverPath,
                  size: 56,
                  borderRadius: 0,
                  placeholderText: widget.track.title,
                ),
              ),
              const SizedBox(width: 12),
              // Bold title
              Expanded(
                child: Text(
                  widget.track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              // Circular #38BDF8 play button appearing on hover with subtle shadow
              AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _hovered ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent, // Electric Cyan #38BDF8
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withAlpha(80),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.play,
                      color: Colors.black,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spotify 165x165 Square Album Card with bottom-right hover-reveal circular #38BDF8 play button
class _SpotifySquareAlbumCard extends StatefulWidget {
  final Track track;
  final VoidCallback onPlay;

  const _SpotifySquareAlbumCard({required this.track, required this.onPlay});

  @override
  State<_SpotifySquareAlbumCard> createState() =>
      _SpotifySquareAlbumCardState();
}

class _SpotifySquareAlbumCardState extends State<_SpotifySquareAlbumCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 165,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPlay,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 165x165 Square Artwork
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AlbumArtView(
                      imageUrl: widget.track.localCoverPath,
                      localFilePath: widget.track.localCoverPath,
                      size: 165,
                      borderRadius: 8,
                      showShadow: true,
                      placeholderText: widget.track.title,
                    ),
                  ),
                  // Bottom-right hover-reveal circular #38BDF8 play button
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 140),
                      opacity: _hovered ? 1.0 : 0.0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent, // Electric Cyan #38BDF8
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(120),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.play,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Title
              Text(
                widget.track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              // 2-line artist metadata
              Text(
                widget.track.artist,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Album Card Item for ChartAlbum
class _AlbumCardItem extends StatelessWidget {
  final ChartAlbum album;

  const _AlbumCardItem({required this.album});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 165,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AlbumArtView(
            imageUrl: album.artworkUrl,
            size: 165,
            borderRadius: 8,
            showShadow: true,
            placeholderText: album.name,
          ),
          const SizedBox(height: 8),
          Text(
            album.name,
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
            album.artist,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Radio Station Card Item
class _RadioStationCardItem extends ConsumerWidget {
  final RadioStation station;
  const _RadioStationCardItem({required this.station});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerNotifier = ref.read(playerProvider.notifier);

    return SizedBox(
      width: 140,
      child: GestureDetector(
        onTap: () {
          playerNotifier.playTrack(station.toTrack());
          AppToast.show(
            context,
            'Streaming: "${station.name}"',
            icon: LucideIcons.radio,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.subtleHairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AlbumArtView(
                imageUrl: station.favicon,
                size: 120,
                borderRadius: 8,
                placeholderText: station.name,
              ),
              const SizedBox(height: 8),
              Text(
                station.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                station.country,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
