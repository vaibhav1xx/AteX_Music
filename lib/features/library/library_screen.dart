import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/track_action_menu.dart';
import '../../data/database/app_database.dart';
import '../../data/models/track.dart';
import '../../data/scanner/music_scanner.dart';
import '../../data/services/playlist_file_service.dart';
import '../player/providers/player_provider.dart';
import '../player/widgets/album_art_view.dart';
import 'widgets/duplicate_cleaner_dialog.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _offlineOnly = true;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _scanMusic() async {
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
      AppToast.show(context, 'Scanner error: $e', icon: LucideIcons.alertCircle);
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _importPlaylistFile() async {
    final db = ref.read(appDatabaseProvider);
    final result = await PlaylistFileService.importPlaylist(db);
    if (!mounted) return;
    AppToast.show(
      context,
      result.message,
      icon: result.success ? LucideIcons.fileCheck : LucideIcons.alertCircle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;

    // Read real tracks from SQLite Drift database
    final tracksAsync = ref.watch(allTracksStreamProvider);
    final dbTracks = tracksAsync.valueOrNull ?? [];
    final List<Track> tracks = dbTracks.map((d) => d.toDomain()).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 36 : 20,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Library',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${tracks.length} Offline Tracks in SQLite Storage',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Duplicate Finder Tool
                      IconButton(
                        tooltip: 'Find & Clean Duplicates',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.card,
                          padding: const EdgeInsets.all(10),
                        ),
                        icon: const Icon(LucideIcons.copy, size: 16, color: AppColors.accent),
                        onPressed: () => showDuplicateCleanerDialog(context, ref),
                      ),

                      // Import M3U/JSON Playlist Button
                      IconButton(
                        tooltip: 'Import M3U / M3U8 / JSON Playlist',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.card,
                          padding: const EdgeInsets.all(10),
                        ),
                        icon: const Icon(LucideIcons.fileUp, size: 16, color: AppColors.accent),
                        onPressed: _importPlaylistFile,
                      ),

                      // Offline Only filter toggle
                      GestureDetector(
                        onTap: () => setState(() => _offlineOnly = !_offlineOnly),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _offlineOnly ? AppColors.accent.withAlpha(30) : AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _offlineOnly ? AppColors.accent : AppColors.subtleHairline,
                            ),
                          ),
                          child: Text(
                            _offlineOnly ? 'Offline Only' : 'All Media',
                            style: TextStyle(
                              color: _offlineOnly ? AppColors.accent : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cardHover,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: _isScanning ? null : _scanMusic,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              )
                            : const Icon(LucideIcons.folderDown, size: 16, color: AppColors.accent),
                        label: Text(
                          _isScanning ? 'Importing...' : 'Scan Music',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.accent,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                dividerColor: AppColors.dockHairline,
                tabs: const [
                  Tab(text: 'Auto-Mixes'),
                  Tab(text: 'Tracks'),
                  Tab(text: 'Albums'),
                  Tab(text: 'Playlists'),
                  Tab(text: 'Folders'),
                ],
              ),
              const SizedBox(height: 16),

              // Tab View Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Smart Auto-Mixes
                    _buildSmartAutoMixesTab(isDesktop, playerNotifier),

                    // Tab 2: Tracks List
                    tracks.isEmpty
                        ? _buildEmptyLibraryPrompt()
                        : ListView.separated(
                            itemCount: tracks.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 4),
                            itemBuilder: (ctx, index) {
                              final track = tracks[index];
                              return _LibraryTrackTile(
                                index: index,
                                track: track,
                                onPlay: () => playerNotifier.playTrack(track),
                                onToggleFavorite: () => playerNotifier.toggleFavorite(),
                              );
                            },
                          ),

                    // Tab 3: Albums Grid
                    tracks.isEmpty
                        ? _buildEmptyLibraryPrompt()
                        : _buildAlbumsGrid(tracks, isDesktop, playerNotifier),

                    // Tab 4: Playlists List
                    _buildPlaylistsTab(tracks),

                    // Tab 5: Local Storage Real Folder Browser
                    _buildRealFoldersTab(tracks, playerNotifier),
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

  // =========================================================================
  // SMART AUTO-MIXES TAB (Most Played, Recently Added, Favorites, Forgotten Gems)
  // =========================================================================
  Widget _buildSmartAutoMixesTab(bool isDesktop, PlayerNotifier notifier) {
    final mostPlayedAsync = ref.watch(mostPlayedTracksStreamProvider);
    final recentlyAddedAsync = ref.watch(recentlyAddedTracksStreamProvider);
    final favoritesAsync = ref.watch(favoriteTracksStreamProvider);
    final forgottenGemsAsync = ref.watch(forgottenGemsTracksStreamProvider);

    final mostPlayed = mostPlayedAsync.valueOrNull?.map((d) => d.toDomain()).toList() ?? [];
    final recentlyAdded = recentlyAddedAsync.valueOrNull?.map((d) => d.toDomain()).toList() ?? [];
    final favorites = favoritesAsync.valueOrNull?.map((d) => d.toDomain()).toList() ?? [];
    final forgottenGems = forgottenGemsAsync.valueOrNull?.map((d) => d.toDomain()).toList() ?? [];

    return ListView(
      children: [
        const Text(
          'DYNAMIC SMART MIXES',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Generated automatically from local SQLite listening statistics and dates.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),

        _buildAutoMixCard(
          title: 'Most Played Mix',
          subtitle: '${mostPlayed.length} songs you listen to repeatedly',
          icon: LucideIcons.flame,
          accentColor: Colors.deepOrangeAccent,
          tracks: mostPlayed,
          onPlay: () => notifier.loadAndPlayQueue(mostPlayed),
          onExportM3u: () => _exportMix('Most_Played_Mix', mostPlayed),
        ),
        const SizedBox(height: 12),

        _buildAutoMixCard(
          title: 'Recently Added',
          subtitle: '${recentlyAdded.length} fresh audio files scanned to device',
          icon: LucideIcons.sparkles,
          accentColor: AppColors.accent,
          tracks: recentlyAdded,
          onPlay: () => notifier.loadAndPlayQueue(recentlyAdded),
          onExportM3u: () => _exportMix('Recently_Added_Mix', recentlyAdded),
        ),
        const SizedBox(height: 12),

        _buildAutoMixCard(
          title: 'Favorites Mix',
          subtitle: '${favorites.length} curated starred tracks',
          icon: LucideIcons.heart,
          accentColor: Colors.pinkAccent,
          tracks: favorites,
          onPlay: () => notifier.loadAndPlayQueue(favorites),
          onExportM3u: () => _exportMix('Favorites_Mix', favorites),
        ),
        const SizedBox(height: 12),

        _buildAutoMixCard(
          title: 'Forgotten Gems',
          subtitle: '${forgottenGems.length} library tracks you haven\'t played in a while',
          icon: LucideIcons.compass,
          accentColor: const Color(0xFF818CF8),
          tracks: forgottenGems,
          onPlay: () => notifier.loadAndPlayQueue(forgottenGems),
          onExportM3u: () => _exportMix('Forgotten_Gems_Mix', forgottenGems),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _exportMix(String name, List<Track> tracks) async {
    final result = await PlaylistFileService.exportToM3u(name, tracks);
    if (!mounted) return;
    AppToast.show(
      context,
      result.message,
      icon: result.success ? LucideIcons.fileCheck : LucideIcons.alertCircle,
    );
  }

  Widget _buildAutoMixCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<Track> tracks,
    required VoidCallback onPlay,
    required VoidCallback onExportM3u,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              color: accentColor.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Export M3U8',
            icon: const Icon(LucideIcons.share, size: 16, color: AppColors.textMuted),
            onPressed: tracks.isEmpty ? null : onExportM3u,
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.playButtonBg,
              foregroundColor: AppColors.playButtonIcon,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: tracks.isEmpty ? null : onPlay,
            icon: const Icon(LucideIcons.play, size: 14),
            label: const Text('Play Mix', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLibraryPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.cardHover,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.music, size: 28, color: AppColors.accent),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your local library is empty',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Scan audio folders from your device or download songs to listen 100% offline.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.playButtonBg,
              foregroundColor: AppColors.playButtonIcon,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _scanMusic,
            icon: const Icon(LucideIcons.folderDown, size: 16),
            label: const Text('Scan Local Folders Now', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumsGrid(List<Track> tracks, bool isDesktop, PlayerNotifier notifier) {
    final albumMap = <String, List<Track>>{};
    for (final t in tracks) {
      albumMap.putIfAbsent(t.album, () => []).add(t);
    }

    final albums = albumMap.keys.toList();

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: albums.length,
      itemBuilder: (ctx, index) {
        final albumName = albums[index];
        final albumTracks = albumMap[albumName]!;
        final firstTrack = albumTracks.first;

        return GestureDetector(
          onTap: () => notifier.loadAndPlayQueue(albumTracks, startIndex: 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: AlbumArtView(
                    imageUrl: firstTrack.localCoverPath,
                    localFilePath: firstTrack.localCoverPath,
                    size: isDesktop ? 130 : 100,
                    borderRadius: 8,
                    placeholderText: albumName,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  albumName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${albumTracks.length} Tracks',
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
    );
  }

  Widget _buildPlaylistsTab(List<Track> allTracks) {
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final playlists = playlistsAsync.valueOrNull ?? [];
    final db = ref.read(appDatabaseProvider);
    final playerNotifier = ref.read(playerProvider.notifier);

    return ListView(
      children: [
        // Create New Playlist Card
        GestureDetector(
          onTap: () => showCreatePlaylistDialog(context, ref),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardHover,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.subtleHairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.plus, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Playlist',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Create an offline playlist saved in local SQLite storage',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Default System Playlists
        _buildPlaylistTile('Favorite Tracks', 'All your liked tracks', LucideIcons.heart),
        const SizedBox(height: 8),
        _buildPlaylistTile('Recently Added', 'Latest imported local audio', LucideIcons.clock),
        const SizedBox(height: 8),

        // User Playlists from Drift Database
        if (playlists.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              'YOUR PLAYLISTS',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...playlists.map(
            (pl) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.cardHover,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.listMusic, color: AppColors.accent, size: 20),
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
                            pl.description ?? 'Local Playlist',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Play Playlist',
                      icon: const Icon(LucideIcons.play, size: 16, color: AppColors.accent),
                      onPressed: () async {
                        final plTracks = await db.getTracksForPlaylist(pl.id);
                        if (!mounted) return;
                        if (plTracks.isNotEmpty) {
                          playerNotifier.loadAndPlayQueue(plTracks.map((d) => d.toDomain()).toList());
                          if (mounted) {
                            AppToast.show(context, 'Playing "${pl.name}"', icon: LucideIcons.play);
                          }
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Export Playlist (.m3u8)',
                      icon: const Icon(LucideIcons.share, size: 16, color: AppColors.textMuted),
                      onPressed: () async {
                        final plTracks = await db.getTracksForPlaylist(pl.id);
                        final domainTracks = plTracks.map((d) => d.toDomain()).toList();
                        final res = await PlaylistFileService.exportToM3u(pl.name, domainTracks);
                        if (!mounted) return;
                        AppToast.show(context, res.message, icon: LucideIcons.fileCheck);
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete Playlist',
                      icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.textMuted),
                      onPressed: () async {
                        await db.deletePlaylist(pl.id);
                        if (!mounted) return;
                        AppToast.show(context, 'Deleted "${pl.name}"', icon: LucideIcons.trash);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaylistTile(String name, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.cardHover,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textMuted),
        ],
      ),
    );
  }

  // =========================================================================
  // REAL FOLDER BROWSER TAB (Grouping local tracks by parent directory)
  // =========================================================================
  Widget _buildRealFoldersTab(List<Track> tracks, PlayerNotifier notifier) {
    if (tracks.isEmpty) {
      return _buildEmptyLibraryPrompt();
    }

    final Map<String, List<Track>> folderMap = {};
    for (final t in tracks) {
      final f = File(t.filePath);
      final parentDir = f.parent.path;
      folderMap.putIfAbsent(parentDir, () => []).add(t);
    }

    final folderPaths = folderMap.keys.toList()..sort();

    return ListView.separated(
      itemCount: folderPaths.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final path = folderPaths[index];
        final folderTracks = folderMap[path]!;
        final dirName = path.split(RegExp(r'[\\/]')).lastWhere((s) => s.isNotEmpty, orElse: () => path);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.subtleHairline),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cardHover,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.folder, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dirName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${folderTracks.length} tracks in folder',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.playButtonBg,
                  foregroundColor: AppColors.playButtonIcon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: () {
                  notifier.loadAndPlayQueue(folderTracks);
                  AppToast.show(context, 'Playing folder: "$dirName"', icon: LucideIcons.play);
                },
                icon: const Icon(LucideIcons.play, size: 14),
                label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LibraryTrackTile extends StatefulWidget {
  final int index;
  final Track track;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;

  const _LibraryTrackTile({
    required this.index,
    required this.track,
    required this.onPlay,
    required this.onToggleFavorite,
  });

  @override
  State<_LibraryTrackTile> createState() => _LibraryTrackTileState();
}

class _LibraryTrackTileState extends State<_LibraryTrackTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.cardHover : AppColors.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${widget.index + 1}'.padLeft(2, '0'),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AlbumArtView(
                imageUrl: widget.track.localCoverPath,
                localFilePath: widget.track.localCoverPath,
                size: 44,
                borderRadius: 6,
                placeholderText: widget.track.title,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.title,
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
                      '${widget.track.artist} • ${widget.track.album}',
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
                widget.track.durationFormatted,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: widget.onToggleFavorite,
                child: Icon(
                  widget.track.isFavorite ? LucideIcons.heart : LucideIcons.heart,
                  color: widget.track.isFavorite ? AppColors.accent : AppColors.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Consumer(
                builder: (ctx, ref, _) => GestureDetector(
                  onTap: () => showTrackActionMenu(context, ref, widget.track),
                  child: const Icon(
                    LucideIcons.ellipsisVertical,
                    color: AppColors.textMuted,
                    size: 18,
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
