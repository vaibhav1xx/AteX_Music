import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/services/share_card_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atex_monogram.dart';
import '../../core/widgets/shareable_rewind_card.dart';
import '../../data/database/app_database.dart';
import '../../data/models/track.dart';
import '../player/providers/player_provider.dart';
import '../player/widgets/album_art_view.dart';
import 'widgets/weekly_listening_chart.dart';

final listeningStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final events = await db.getAllListeningEvents();

  int totalDurationMs = 0;
  for (final e in events) {
    totalDurationMs += e.durationListenedMs;
  }

  final streak = await db.getCurrentListeningStreak();
  final topArtists = await db.getTopArtists(limit: 5);
  final topTracks = await db.getTopTracks(limit: 10);
  final weeklyStats = await db.getWeeklyListeningStats();

  return {
    'totalDurationMs': totalDurationMs,
    'totalTracks': events.length,
    'streak': streak,
    'topArtists': topArtists,
    'topTracks': topTracks,
    'weeklyStats': weeklyStats,
  };
});

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  final GlobalKey _rewindCardKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareRewindCard() async {
    setState(() => _isSharing = true);
    try {
      await ShareCardService.captureAndShare(
        context,
        _rewindCardKey,
        filePrefix: 'atex_rewind',
        subject: 'My AteX Music Rewind',
        text: 'Check out my AteX Music listening stats! 100% Offline Audio.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(listeningStatsProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/icon/logo_mark.png',
              width: 22,
              height: 22,
              errorBuilder: (_, _, _) => const AteXMonogram(size: 22),
            ),
            const SizedBox(width: 10),
            const Text('AteX Rewind & Stats'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Stats',
            icon: const Icon(LucideIcons.refreshCw, size: 18, color: AppColors.textSecondary),
            onPressed: () => ref.invalidate(listeningStatsProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, stack) => Center(
          child: Text('Error loading stats: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (data) {
          final totalMs = data['totalDurationMs'] as int;
          final totalTracks = data['totalTracks'] as int;
          final streak = data['streak'] as int;
          final topArtists = data['topArtists'] as List<MapEntry<String, int>>;
          final topTracks = data['topTracks'] as List<DbTrack>;
          final weeklyStats = data['weeklyStats'] as List<DailyListeningStat>;

          final totalMinutes = totalMs ~/ (1000 * 60);
          final hours = totalMinutes ~/ 60;
          final mins = totalMinutes % 60;

          final topArtistName = topArtists.isNotEmpty ? topArtists.first.key : 'None yet';
          final topTrackDb = topTracks.isNotEmpty ? topTracks.first : null;
          final topTrackName = topTrackDb?.title ?? 'No tracks played';
          final topTrackCover = topTrackDb?.localCoverPath;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner header
                    _buildHeaderBanner(hours, mins, totalTracks, streak),
                    const SizedBox(height: 24),

                    // Main 2-column or single column layout
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Weekly Chart & Top Artists & Top Tracks
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCardContainer(
                                  child: WeeklyListeningChart(stats: weeklyStats),
                                ),
                                const SizedBox(height: 20),
                                _buildTopArtistsSection(topArtists),
                                const SizedBox(height: 20),
                                _buildTopTracksSection(topTracks),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right Column: Year in Review Card Preview
                          Expanded(
                            flex: 4,
                            child: _buildRewindCardPreview(
                              totalMinutes: totalMinutes,
                              totalTracks: totalTracks,
                              streak: streak,
                              topArtist: topArtistName,
                              topTrackTitle: topTrackName,
                              topTrackCover: topTrackCover,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildCardContainer(
                        child: WeeklyListeningChart(stats: weeklyStats),
                      ),
                      const SizedBox(height: 20),
                      _buildTopArtistsSection(topArtists),
                      const SizedBox(height: 20),
                      _buildTopTracksSection(topTracks),
                      const SizedBox(height: 24),
                      _buildRewindCardPreview(
                        totalMinutes: totalMinutes,
                        totalTracks: totalTracks,
                        streak: streak,
                        topArtist: topArtistName,
                        topTrackTitle: topTrackName,
                        topTrackCover: topTrackCover,
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderBanner(int hours, int mins, int totalTracks, int streak) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.subtleHairline, width: 1.0),
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withAlpha(25),
            AppColors.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '100% Local Listening Analytics',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your Offline Music Journey',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5722).withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF5722).withAlpha(100), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF5722), size: 18),
                    const SizedBox(width: 5),
                    Text(
                      '$streak Days Streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMetricChip(
                label: 'Total Listening Time',
                value: hours > 0 ? '${hours}h ${mins}m' : '${mins}m',
                icon: LucideIcons.clock,
              ),
              const SizedBox(width: 14),
              _buildMetricChip(
                label: 'Tracks Played',
                value: '$totalTracks',
                icon: LucideIcons.music,
              ),
              const SizedBox(width: 14),
              _buildMetricChip(
                label: 'Streak',
                value: '$streak Days',
                icon: LucideIcons.flame,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.subtleHairline, width: 1.0),
      ),
      child: child,
    );
  }

  Widget _buildTopArtistsSection(List<MapEntry<String, int>> topArtists) {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.users, size: 18, color: AppColors.accent),
              SizedBox(width: 8),
              Text(
                'Top 5 Artists',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (topArtists.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Play tracks for > 20s to log artist statistics.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            )
          else
            ...List.generate(topArtists.length, (idx) {
              final artist = topArtists[idx];
              final maxCount = topArtists.first.value;
              final progress = maxCount > 0 ? (artist.value / maxCount) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '#${idx + 1}',
                        style: TextStyle(
                          color: idx == 0 ? AppColors.accent : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Text(
                        artist.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withAlpha(15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            idx == 0 ? AppColors.accent : AppColors.accent.withAlpha(150),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${artist.value} plays',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTopTracksSection(List<DbTrack> topTracks) {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.flame, size: 18, color: AppColors.accent),
              SizedBox(width: 8),
              Text(
                'Top 10 Most-Played Tracks',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (topTracks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Play tracks for > 20s to log track statistics.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            )
          else
            ...List.generate(topTracks.length, (idx) {
              final track = topTracks[idx].toDomain();
              return InkWell(
                onTap: () {
                  ref.read(playerProvider.notifier).playTrack(track);
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            color: idx < 3 ? AppColors.accent : AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AlbumArtView(
                        imageUrl: track.localCoverPath,
                        localFilePath: track.localCoverPath,
                        size: 38,
                        borderRadius: 6,
                        placeholderText: track.title,
                      ),
                      const SizedBox(width: 12),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${track.playCount} plays',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRewindCardPreview({
    required int totalMinutes,
    required int totalTracks,
    required int streak,
    required String topArtist,
    required String topTrackTitle,
    String? topTrackCover,
  }) {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Year in Review Card',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '9:16 Shareable',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Live Card Rendered with RepaintBoundary for Sharing
          Center(
            child: SizedBox(
              width: 290,
              child: RepaintBoundary(
                key: _rewindCardKey,
                child: ShareableRewindCard(
                  totalListeningMinutes: totalMinutes,
                  totalTracksPlayed: totalTracks,
                  listeningStreak: streak,
                  topArtist: topArtist,
                  topTrackTitle: topTrackTitle,
                  topTrackCover: topTrackCover,
                  accentColor: AppColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSharing ? null : _shareRewindCard,
              icon: _isSharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(LucideIcons.share2, size: 18),
              label: Text(
                _isSharing ? 'Generating Card...' : 'Share Rewind Card',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
