import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/track_action_menu.dart';
import '../../data/database/app_database.dart';
import '../../data/models/track.dart';
import '../../data/scanner/music_scanner.dart';
import '../player/providers/player_provider.dart';
import '../player/widgets/album_art_view.dart';

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
    _tabController = TabController(length: 4, vsync: this);
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
          content: Text('Scanner error: $e'),
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
                  Row(
                    children: [
                      // Offline Only filter toggle
                      GestureDetector(
                        onTap: () => setState(() => _offlineOnly = !_offlineOnly),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      const SizedBox(width: 10),
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
                          _isScanning ? 'Importing...' : 'Scan / Import Music',
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

                    // Tab 2: Albums Grid
                    tracks.isEmpty
                        ? _buildEmptyLibraryPrompt()
                        : _buildAlbumsGrid(tracks, isDesktop, playerNotifier),

                    // Tab 3: Playlists List
                    _buildPlaylistsTab(),

                    // Tab 4: Local Storage Folders
                    _buildFoldersTab(tracks.length),
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

  Widget _buildPlaylistsTab() {
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final playlists = playlistsAsync.valueOrNull ?? [];

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
        _buildPlaylistTile('High Resolution Lossless', 'FLAC and 24-bit audio tracks', LucideIcons.disc),
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
                      icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.textMuted),
                      onPressed: () async {
                        final db = ref.read(appDatabaseProvider);
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

  Widget _buildFoldersTab(int count) {
    return ListView(
      children: [
        _buildFolderRow('Primary Device Music Storage', '/storage/emulated/0/Music', count),
        const SizedBox(height: 8),
        _buildFolderRow('AteX Offline Downloads Directory', 'AteX_Music/Media', count),
        const SizedBox(height: 8),
        _buildFolderRow('Desktop User Audio Library', 'C:\\Users\\Music', count),
      ],
    );
  }

  Widget _buildFolderRow(String title, String path, int trackCount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
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
            '$trackCount tracks',
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
