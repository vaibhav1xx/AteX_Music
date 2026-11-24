import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import '../../core/widgets/track_action_menu.dart';
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

enum HomeSegment { music, radio, podcasts }

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
  HomeSegment _selectedSegment = HomeSegment.music;
  bool _isScanning = false;

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
                              'Explore',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Offline Music • Keyless Live Radio • Keyless Podcasts',
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
                                size: 16,
                                color: AppColors.accent,
                              ),
                        label: Text(
                          _isScanning
                              ? '...'
                              : (isDesktop ? 'Import Music' : 'Import'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.onOpenStats != null) ...[
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: widget.onOpenStats,
                          icon: const Icon(
                            LucideIcons.flame,
                            size: 16,
                            color: Color(0xFFFF5722),
                          ),
                          label: Text(
                            isDesktop ? 'AteX Rewind' : 'Rewind',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Segment Pill Selector (Music / Radio / Podcasts)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 36 : 20,
                    vertical: 8,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPillTab(
                          HomeSegment.music,
                          LucideIcons.music,
                          'Music',
                        ),
                        const SizedBox(width: 8),
                        _buildPillTab(
                          HomeSegment.radio,
                          LucideIcons.radio,
                          'Live Radio',
                        ),
                        const SizedBox(width: 8),
                        _buildPillTab(
                          HomeSegment.podcasts,
                          LucideIcons.podcast,
                          'Podcasts',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Dynamic Segment Content
              if (_selectedSegment == HomeSegment.music)
                ..._buildMusicSlivers(isDesktop)
              else if (_selectedSegment == HomeSegment.radio)
                ..._buildRadioSlivers(isDesktop)
              else
                ..._buildPodcastSlivers(isDesktop),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillTab(HomeSegment segment, IconData icon, String title) {
    final isSelected = _selectedSegment == segment;
    return GestureDetector(
      onTap: () => setState(() => _selectedSegment = segment),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.subtleHairline,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.black : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.black : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // MUSIC SECTION (Offline Tracks + Charts)
  // =========================================================================
  List<Widget> _buildMusicSlivers(bool isDesktop) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final dbTracksAsync = ref.watch(allTracksStreamProvider);
    final trendingSongsAsync = ref.watch(trendingSongsProvider);
    final trendingAlbumsAsync = ref.watch(trendingAlbumsProvider);

    final localTracks =
        dbTracksAsync.valueOrNull?.map((d) => d.toDomain()).toList() ?? [];
    final trendingSongs = trendingSongsAsync.valueOrNull ?? [];
    final trendingAlbums = trendingAlbumsAsync.valueOrNull ?? [];

    final quickPicks = localTracks.isNotEmpty
        ? localTracks.take(6).toList()
        : trendingSongs.take(6).toList();

    return [
      if (quickPicks.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 36 : 20,
              16,
              isDesktop ? 36 : 20,
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
            isDesktop ? 36 : 20,
            8,
            isDesktop ? 36 : 20,
            20,
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
              return _QuickPickTile(
                track: track,
                onPlay: () => playerNotifier.playTrack(track),
              );
            }, childCount: quickPicks.length),
          ),
        ),
      ],

      // Local Music Storage Banner
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
                  child: const Icon(
                    LucideIcons.hardDrive,
                    color: AppColors.accent,
                    size: 22,
                  ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  onPressed: widget.onOpenLibrary,
                  child: const Text(
                    'View Library',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // Global Trending Charts
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
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onOpenSearch != null)
                TextButton(
                  onPressed: widget.onOpenSearch,
                  child: const Text(
                    'Search More',
                    style: TextStyle(color: AppColors.accent, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),

      SliverToBoxAdapter(
        child: trendingSongs.isNotEmpty
            ? SizedBox(
                height: 228,
                child: ListView.separated(
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
              )
            : (trendingSongsAsync.isLoading
                ? SizedBox(
                    height: 228,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 36 : 20,
                      ),
                      child: const ShimmerHorizontalCharts(),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 36 : 20,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;
                        if (isNarrow) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.subtleHairline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.cardHover,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        LucideIcons.wifiOff,
                                        size: 20,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Offline Mode Active',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Connect to Wi-Fi to load trending charts, or enjoy your local library with zero internet.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.playButtonBg,
                                      foregroundColor: AppColors.playButtonIcon,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: _isScanning ? null : _triggerScan,
                                    icon: const Icon(
                                      LucideIcons.folderDown,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Scan Music',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.subtleHairline),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.cardHover,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  LucideIcons.wifiOff,
                                  size: 24,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Offline Mode Active',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Connect to Wi-Fi to load trending charts, or enjoy your local library with zero internet.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.playButtonBg,
                                  foregroundColor: AppColors.playButtonIcon,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _isScanning ? null : _triggerScan,
                                icon: const Icon(
                                  LucideIcons.folderDown,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Scan Music',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )),
      ),

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
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 20),
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
    ];
  }

  // =========================================================================
  // LIVE RADIO SECTION (Keyless Free Radio Browser API)
  // =========================================================================
  List<Widget> _buildRadioSlivers(bool isDesktop) {
    final topRadioAsync = ref.watch(topRadioStationsProvider);
    final indiaRadioAsync = ref.watch(indiaRadioStationsProvider);
    final lofiRadioAsync = ref.watch(lofiRadioStationsProvider);
    final electronicRadioAsync = ref.watch(electronicRadioStationsProvider);

    return [
      // Top Global Live Stations
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 36 : 20,
            16,
            isDesktop ? 36 : 20,
            10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Top Global Live Radio',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Radio Browser API • Free & Keyless',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 180,
          child: topRadioAsync.when(
            data: (stations) => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 20),
              itemCount: stations.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 14),
              itemBuilder: (context, index) =>
                  _RadioStationCard(station: stations[index]),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      LucideIcons.wifiOff,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Live Radio stations require an active internet connection.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      // India Live Stations
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 36 : 20,
            24,
            isDesktop ? 36 : 20,
            10,
          ),
          child: const Text(
            'India Popular Broadcasts',
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
          height: 180,
          child: indiaRadioAsync.when(
            data: (stations) => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 20),
              itemCount: stations.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 14),
              itemBuilder: (context, index) =>
                  _RadioStationCard(station: stations[index]),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (err, _) => const SizedBox.shrink(),
          ),
        ),
      ),

      // Lo-Fi & Chill Stations
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 36 : 20,
            24,
            isDesktop ? 36 : 20,
            10,
          ),
          child: const Text(
            'Lo-Fi & Study Streams',
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
          height: 180,
          child: lofiRadioAsync.when(
            data: (stations) => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 20),
              itemCount: stations.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 14),
              itemBuilder: (context, index) =>
                  _RadioStationCard(station: stations[index]),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (err, _) => const SizedBox.shrink(),
          ),
        ),
      ),

      // Electronic & Dance Stations
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 36 : 20,
            24,
            isDesktop ? 36 : 20,
            10,
          ),
          child: const Text(
            'Electronic & EDM Radio',
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
          height: 180,
          child: electronicRadioAsync.when(
            data: (stations) => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 20),
              itemCount: stations.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 14),
              itemBuilder: (context, index) =>
                  _RadioStationCard(station: stations[index]),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (err, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    ];
  }

  // =========================================================================
  // PODCASTS SECTION (Keyless iTunes Search & RSS XML)
  // =========================================================================
  List<Widget> _buildPodcastSlivers(bool isDesktop) {
    final popularPodcastsAsync = ref.watch(popularPodcastsProvider);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 36 : 20,
            16,
            isDesktop ? 36 : 20,
            12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Featured Podcasts',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Keyless iTunes RSS • 1-Tap Offline Download',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),

      popularPodcastsAsync.when(
        data: (podcasts) => SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 20),
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
        error: (_, _) => SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    LucideIcons.wifiOff,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Podcasts require an active internet connection to refresh episodes.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

/// Radio Station Card with 1-tap live streaming & local favorite toggle
class _RadioStationCard extends ConsumerWidget {
  final RadioStation station;
  const _RadioStationCard({required this.station});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final db = ref.read(appDatabaseProvider);

    return SizedBox(
      width: 140,
      child: GestureDetector(
        onTap: () {
          playerNotifier.playTrack(station.toTrack());
          AppToast.show(
            context,
            'Streaming live: "${station.name}"',
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
              Stack(
                children: [
                  AlbumArtView(
                    imageUrl: station.favicon,
                    size: 120,
                    borderRadius: 8,
                    placeholderText: station.name,
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.playButtonBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.play,
                        color: AppColors.playButtonIcon,
                        size: 16,
                      ),
                    ),
                  ),
                ],
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      station.country,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await db.toggleRadioStationFavorite(
                        uuid: station.stationUuid,
                        name: station.name,
                        url: station.urlResolved.isNotEmpty
                            ? station.urlResolved
                            : station.url,
                        favicon: station.favicon,
                        tags: station.tags,
                        country: station.country,
                        bitrate: station.bitrate,
                      );
                      if (!context.mounted) return;
                      AppToast.show(
                        context,
                        'Updated favorite station: "${station.name}"',
                        icon: LucideIcons.heart,
                      );
                    },
                    child: const Icon(
                      LucideIcons.heart,
                      size: 14,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact 56px Quick Pick Tile with hover-reveal Play button
class _QuickPickTile extends StatefulWidget {
  final Track track;
  final VoidCallback onPlay;

  const _QuickPickTile({required this.track, required this.onPlay});

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
                localFilePath: widget.track.localCoverPath,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Consumer(
                      builder: (ctx, ref, _) => IconButton(
                        icon: const Icon(
                          LucideIcons.ellipsisVertical,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            showTrackActionMenu(context, ref, widget.track),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    ),
                  ],
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

  const _SongCard({required this.track, required this.onPlay});

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
                    localFilePath: widget.track.localCoverPath,
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Consumer(
                    builder: (ctx, ref, _) => GestureDetector(
                      onTap: () =>
                          showTrackActionMenu(context, ref, widget.track),
                      child: const Icon(
                        LucideIcons.ellipsisVertical,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
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
