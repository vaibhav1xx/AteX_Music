import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database/app_database.dart';
import '../../data/models/track.dart';
import '../../data/scanner/music_scanner.dart';
import '../../data/services/music_charts_service.dart';
import '../player/providers/player_provider.dart';
import '../player/widgets/album_art_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenLibrary;
  final VoidCallback? onOpenSearch;

  const HomeScreen({
    super.key,
    required this.onOpenLibrary,
    this.onOpenSearch,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isScanning = false;

  Future<void> _triggerScan() async {
    setState(() => _isScanning = true);
    final scanner = ref.read(musicScannerProvider);
    final db = ref.read(appDatabaseProvider);

    try {
      final result = await scanner.scanAndImport(db);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.statusMessage),
          backgroundColor: result.success ? AppColors.surfaceElevated : Colors.red.shade900,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan error: $e'),
          backgroundColor: Colors.red.shade900,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;
    final playerNotifier = ref.read(playerProvider.notifier);
    final dbTracksAsync = ref.watch(allTracksStreamProvider);
    final trendingSongsAsync = ref.watch(trendingSongsProvider);
    final trendingAlbumsAsync = ref.watch(trendingAlbumsProvider);

    final localTracks = dbTracksAsync.valueOrNull?.map((d) => d.toDomain()).toList() ?? [];
    final trendingSongs = trendingSongsAsync.valueOrNull ?? [];
    final trendingAlbums = trendingAlbumsAsync.valueOrNull ?? [];

    // Combine local tracks or trending tracks for Quick Picks
    final quickPicks = localTracks.isNotEmpty
        ? localTracks.take(6).toList()
        : trendingSongs.take(6).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Ambient Radial Glow at top
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
                    radius: 1.2,
                    colors: [
                      const Color(0xFF0369A1).withAlpha(45),
                      const Color(0xFF0C4A6E).withAlpha(15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          CustomScrollView(
            slivers: [
              // Header & Quick Action
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 36 : 20,
                    isDesktop ? 28 : 20,
                    isDesktop ? 36 : 20,
                    16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Good day',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Lossless Audio & Offline Local Engine',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cardHover,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 14 : 10,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _isScanning ? null : _triggerScan,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              )
                            : const Icon(LucideIcons.folderDown, size: 16, color: AppColors.accent),
                        label: Text(
                          _isScanning ? '...' : (isDesktop ? 'Import Music' : 'Import'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 1. Top "Quick Picks" Compact 2-Row Grid
              if (quickPicks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 36 : 20,
                      vertical: 6,
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
                    isDesktop ? 36 : 20,
                    8,
                    isDesktop ? 36 : 20,
                    24,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isDesktop ? 3 : 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: isDesktop ? 3.4 : 2.5,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = quickPicks[index];
                        return _QuickPickTile(
                          track: track,
                          onPlay: () => playerNotifier.playTrack(track),
                        );
                      },
                      childCount: quickPicks.length,
                    ),
                  ),
                ),
              ],

              // 2. Local Music Banner (if local tracks exist or if empty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 36 : 20,
                    vertical: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.hardDrive, color: AppColors.accent, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localTracks.isNotEmpty
                                    ? '${localTracks.length} Offline Tracks Stored on Device'
                                    : 'Zero Cloud Dependency • Offline Local Storage',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                localTracks.isNotEmpty
                                    ? 'Indexed in local SQLite database with zero tracking.'
                                    : 'Scan folders on your computer or phone to build your offline library.',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.subtleHairline),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: widget.onOpenLibrary,
                          child: const Text('View Library', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Live Real Music Charts (Apple Music Most Played)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 36 : 20,
                    24,
                    isDesktop ? 36 : 20,
                    12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Global Trending',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Real-time most played songs',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onOpenSearch != null)
                        TextButton(
                          onPressed: widget.onOpenSearch,
                          child: const Text('Search More', style: TextStyle(color: AppColors.accent, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              ),

              // Trending Songs Horizontal Carousel
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 228,
                  child: trendingSongs.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 36 : 20,
                          ),
                          itemCount: trendingSongs.length,
                          separatorBuilder: (ctx, i) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final track = trendingSongs[index];
                            return _SongCard(
                              track: track,
                              onPlay: () => playerNotifier.playTrack(track),
                            );
                          },
                        ),
                ),
              ),

              // 4. Featured Albums Carousel
              if (trendingAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 36 : 20,
                      28,
                      isDesktop ? 36 : 20,
                      12,
                    ),
                    child: const Text(
                      'Trending Albums',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 224,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 36 : 20,
                      ),
                      itemCount: trendingAlbums.length,
                      separatorBuilder: (ctx, i) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final album = trendingAlbums[index];
                        return _AlbumCard(album: album);
                      },
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact 56px Quick Pick Tile with hover-reveal Play button
class _QuickPickTile extends StatefulWidget {
  final Track track;
  final VoidCallback onPlay;

  const _QuickPickTile({
    required this.track,
    required this.onPlay,
  });

  @override
  State<_QuickPickTile> createState() => _QuickPickTileState();
}

class _QuickPickTileState extends State<_QuickPickTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.cardHover : AppColors.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              AlbumArtView(
                imageUrl: widget.track.localCoverPath,
                size: 56,
                borderRadius: 8,
                placeholderText: widget.track.title,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.title,
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
                      widget.track.artist,
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
              if (_hovered)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.playButtonBg,
                    ),
                    child: const Icon(
                      LucideIcons.play,
                      color: AppColors.playButtonIcon,
                      size: 16,
                    ),
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Song Card with floating hover play button
class _SongCard extends StatefulWidget {
  final Track track;
  final VoidCallback onPlay;

  const _SongCard({
    required this.track,
    required this.onPlay,
  });

  @override
  State<_SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<_SongCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPlay,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AlbumArtView(
                    imageUrl: widget.track.localCoverPath,
                    size: 148,
                    borderRadius: 8,
                    showShadow: true,
                    placeholderText: widget.track.title,
                  ),
                  if (_hovered)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.playButtonBg,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(100),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.play,
                          color: AppColors.playButtonIcon,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.track.title,
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
                widget.track.artist,
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
      ),
    );
  }
}

/// Album Card
class _AlbumCard extends StatelessWidget {
  final ChartAlbum album;

  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AlbumArtView(
            imageUrl: album.artworkUrl,
            size: 148,
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
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
