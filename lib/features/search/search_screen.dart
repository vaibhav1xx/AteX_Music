import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database/app_database.dart';
import '../../data/models/track.dart';
import '../../data/services/itunes_search_service.dart';
import '../../data/services/offline_download_service.dart';
import '../player/providers/player_provider.dart';
import '../player/widgets/album_art_view.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _itunesResults = [];
  bool _isLoading = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _query = query;
      if (query.trim().isEmpty) {
        _itunesResults = [];
        _isLoading = false;
        return;
      }
      _isLoading = true;
    });

    try {
      final results = await ref.read(iTunesSearchServiceProvider).search(query);
      if (mounted && _query == query) {
        setState(() {
          _itunesResults = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openPlaylistImporterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PlaylistImporterModal(
        onImportTracks: (tracks) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported ${tracks.length} tracks to offline download queue'),
              backgroundColor: AppColors.surfaceElevated,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final downloadService = ref.read(offlineDownloadServiceProvider.notifier);
    final downloadStates = ref.watch(offlineDownloadServiceProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;

    // Local SQLite database tracks
    final dbTracksAsync = ref.watch(allTracksStreamProvider);
    final dbTracks = dbTracksAsync.valueOrNull?.map((d) => d.toDomain()).toList() ?? [];

    final localMatches = _query.isEmpty
        ? <Track>[]
        : dbTracks.where((t) {
            final q = _query.toLowerCase();
            return t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q) ||
                t.album.toLowerCase().contains(q);
          }).toList();

    final hasResults = localMatches.isNotEmpty || _itunesResults.isNotEmpty;
    final topResult = localMatches.isNotEmpty
        ? localMatches.first
        : (_itunesResults.isNotEmpty ? _itunesResults.first : null);

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
              // Search Input Row & Universal Playlist Importer Button
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.search, color: AppColors.textMuted, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Search songs, artists, albums, or offline audio...',
                                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: _performSearch,
                            ),
                          ),
                          if (_isLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                            )
                          else if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                              child: const Icon(LucideIcons.x, color: AppColors.textMuted, size: 16),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Universal Playlist Link Importer Trigger
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardHover,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _openPlaylistImporterModal,
                    icon: const Icon(LucideIcons.link, size: 16, color: AppColors.accent),
                    label: const Text(
                      'Import Playlist URL',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Body
              Expanded(
                child: _query.isEmpty
                    ? _buildEmptyPrompt()
                    : !hasResults && !_isLoading
                        ? _buildNoResults()
                        : ListView(
                            children: [
                              // 1. Top Result Hero Card
                              if (topResult != null) ...[
                                const Text(
                                  'Top Result',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _TopResultCard(
                                  track: topResult,
                                  onPlay: () => playerNotifier.playTrack(topResult),
                                  onDownload: () {
                                    downloadService.downloadTrack(
                                      trackId: topResult.id,
                                      audioUrl: topResult.filePath,
                                      title: topResult.title,
                                      artist: topResult.artist,
                                      album: topResult.album,
                                      coverUrl: topResult.localCoverPath,
                                      duration: topResult.duration,
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                              ],

                              // 2. Local Database Matches
                              if (localMatches.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Icon(LucideIcons.hardDrive, size: 14, color: AppColors.accent),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Offline Library Matches (${localMatches.length})',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...localMatches.map((t) => _TrackListTile(
                                      track: t,
                                      isLocal: true,
                                      onPlay: () => playerNotifier.playTrack(t),
                                    )),
                                const SizedBox(height: 24),
                              ],

                              // 3. iTunes Live Results
                              if (_itunesResults.isNotEmpty) ...[
                                Row(
                                  children: const [
                                    Icon(LucideIcons.globe, size: 14, color: AppColors.accent),
                                    SizedBox(width: 6),
                                    Text(
                                      'Live iTunes Search Results',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ..._itunesResults.map((t) {
                                  final dlState = downloadStates[t.id];
                                  return _TrackListTile(
                                    track: t,
                                    isLocal: false,
                                    downloadState: dlState,
                                    onPlay: () => playerNotifier.playTrack(t),
                                    onDownload: () {
                                      downloadService.downloadTrack(
                                        trackId: t.id,
                                        audioUrl: t.filePath,
                                        title: t.title,
                                        artist: t.artist,
                                        album: t.album,
                                        coverUrl: t.localCoverPath,
                                        duration: t.duration,
                                      );
                                    },
                                  );
                                }),
                              ],

                              const SizedBox(height: 100),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(LucideIcons.search, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Explore Songs, Artists, or Import Offline',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Search over 100 million songs instantly or filter your local SQLite tracks.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(LucideIcons.music, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No matching songs found',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Try checking your spelling or search by artist name.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Top Result Hero Card
class _TopResultCard extends StatefulWidget {
  final Track track;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  const _TopResultCard({
    required this.track,
    required this.onPlay,
    required this.onDownload,
  });

  @override
  State<_TopResultCard> createState() => _TopResultCardState();
}

class _TopResultCardState extends State<_TopResultCard> {
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.cardHover : AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              AlbumArtView(
                imageUrl: widget.track.localCoverPath,
                localFilePath: widget.track.localCoverPath,
                size: 80,
                borderRadius: 10,
                showShadow: true,
                placeholderText: widget.track.title,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'SONG',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.track.artist} • ${widget.track.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Save to Offline Storage',
                icon: const Icon(LucideIcons.download, color: AppColors.textSecondary, size: 20),
                onPressed: widget.onDownload,
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.playButtonBg,
                ),
                child: const Icon(
                  LucideIcons.play,
                  color: AppColors.playButtonIcon,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Track List Tile
class _TrackListTile extends StatefulWidget {
  final Track track;
  final bool isLocal;
  final TrackDownloadState? downloadState;
  final VoidCallback onPlay;
  final VoidCallback? onDownload;

  const _TrackListTile({
    required this.track,
    this.isLocal = false,
    this.downloadState,
    required this.onPlay,
    this.onDownload,
  });

  @override
  State<_TrackListTile> createState() => _TrackListTileState();
}

class _TrackListTileState extends State<_TrackListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final dl = widget.downloadState;
    final isDownloading = dl?.status == DownloadStatus.downloading;
    final isDownloaded = widget.isLocal || dl?.status == DownloadStatus.completed;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.cardHover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
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
                        fontSize: 14,
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
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                widget.track.durationFormatted,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 12),
              if (isDownloading)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: dl?.progress,
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else if (isDownloaded)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(LucideIcons.checkCheck, size: 16, color: AppColors.accent),
                )
              else if (widget.onDownload != null)
                IconButton(
                  tooltip: 'Download Offline',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(LucideIcons.download, size: 16, color: AppColors.textMuted),
                  onPressed: widget.onDownload,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Universal Playlist Link Importer Modal
class _PlaylistImporterModal extends StatefulWidget {
  final void Function(List<Track> tracks) onImportTracks;

  const _PlaylistImporterModal({required this.onImportTracks});

  @override
  State<_PlaylistImporterModal> createState() => _PlaylistImporterModalState();
}

class _PlaylistImporterModalState extends State<_PlaylistImporterModal> {
  final TextEditingController _urlController = TextEditingController();
  bool _isProcessing = false;
  String _status = '';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _processImport() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _status = 'Resolving playlist items...';
    });

    try {
      // Parse plain song queries or playlist URLs
      final lines = input.split(RegExp(r'[\n,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final searchService = ITunesSearchService();
      final importedTracks = <Track>[];

      for (final line in lines.take(15)) {
        // Clean line from URLs or numbers
        final query = line.replaceAll(RegExp(r'https?://[^\s]+'), '').replaceAll(RegExp(r'^\d+[\.\s]+'), '').trim();
        final effectiveQuery = query.isNotEmpty ? query : line;

        final matches = await searchService.search(effectiveQuery, limit: 1);
        if (matches.isNotEmpty) {
          importedTracks.add(matches.first);
        }
      }

      if (mounted) {
        widget.onImportTracks(importedTracks);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = 'Error parsing playlist: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Universal Playlist Link Importer',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Paste Spotify, Apple Music, or comma/newline separated song names to batch-import into your offline library.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            maxLines: 4,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Paste playlist link or track names:\ne.g. Blinding Lights - The Weeknd\nStay - Kid LAROI, Justin Bieber',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _status,
                style: const TextStyle(color: AppColors.accent, fontSize: 12),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.playButtonBg,
                foregroundColor: AppColors.playButtonIcon,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isProcessing ? null : _processImport,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.playButtonIcon),
                    )
                  : const Icon(LucideIcons.downloadCloud, size: 18),
              label: Text(
                _isProcessing ? 'Processing Playlist...' : 'Import to Offline Library',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
