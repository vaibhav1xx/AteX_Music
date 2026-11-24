import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import '../../core/widgets/track_action_menu.dart';
import '../../data/database/app_database.dart';
import '../../data/models/podcast.dart';
import '../../data/models/radio_station.dart';
import '../../data/models/track.dart';
import '../../data/services/itunes_search_service.dart';
import '../../data/services/offline_download_service.dart';
import '../../data/services/podcast_service.dart';
import '../../data/services/radio_service.dart';
import '../../data/services/search_suggestion_service.dart';
import '../../data/services/universal_playlist_importer.dart';
import '../player/providers/player_provider.dart';
import '../player/widgets/album_art_view.dart';
import '../podcast/widgets/podcast_episodes_sheet.dart';

enum SearchCategory { music, radio, podcasts }

class _BrowseCategoryItem {
  final String title;
  final String query;
  final Color color;
  final IconData icon;

  const _BrowseCategoryItem({
    required this.title,
    required this.query,
    required this.color,
    required this.icon,
  });
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  SearchCategory _selectedCategory = SearchCategory.music;

  List<Track> _musicResults = [];
  List<RadioStation> _radioResults = [];
  List<Podcast> _podcastResults = [];
  List<String> _suggestions = [];

  bool _isLoading = false;
  bool _showSuggestions = false;
  String _query = '';
  Timer? _debounceTimer;

  static const List<_BrowseCategoryItem> _browseCategories = [
    _BrowseCategoryItem(
      title: 'Bollywood Hits',
      query: 'Bollywood Top Hits',
      color: Color(0xFFE11D48), // Rose
      icon: LucideIcons.flame,
    ),
    _BrowseCategoryItem(
      title: 'Punjabi Fire',
      query: 'Punjabi Hits',
      color: Color(0xFFEA580C), // Orange
      icon: LucideIcons.sparkles,
    ),
    _BrowseCategoryItem(
      title: 'Desi Hip-Hop',
      query: 'Desi Hip Hop',
      color: Color(0xFF8B5CF6), // Purple
      icon: LucideIcons.mic,
    ),
    _BrowseCategoryItem(
      title: 'South Indian',
      query: 'South Indian Hits',
      color: Color(0xFF059669), // Emerald
      icon: LucideIcons.music4,
    ),
    _BrowseCategoryItem(
      title: 'Romantic Hindi',
      query: 'Hindi Romantic Songs',
      color: Color(0xFFDB2777), // Pink
      icon: LucideIcons.heart,
    ),
    _BrowseCategoryItem(
      title: 'Indie India',
      query: 'Indian Indie',
      color: Color(0xFF0284C7), // Sky Cyan
      icon: LucideIcons.compass,
    ),
    _BrowseCategoryItem(
      title: 'Lo-Fi Chill',
      query: 'Indian Lo-Fi Chill',
      color: Color(0xFF4F46E5), // Indigo
      icon: LucideIcons.headphones,
    ),
    _BrowseCategoryItem(
      title: 'Workout & Phonk',
      query: 'Gym Workout Phonk',
      color: Color(0xFFD97706), // Amber
      icon: LucideIcons.zap,
    ),
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _yt.close();
    super.dispose();
  }

  void _onInputChanged(String val) {
    _debounceTimer?.cancel();
    final trimmed = val.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _query = '';
        _suggestions = [];
        _showSuggestions = false;
        _musicResults = [];
        _radioResults = [];
        _podcastResults = [];
        _isLoading = false;
      });
      return;
    }

    // 1. Fast 180ms debounce for Smart 1-Word Live Autocomplete ("AI Suggestions")
    _debounceTimer = Timer(const Duration(milliseconds: 180), () async {
      if (!mounted) return;
      final dbTracks = ref.read(allTracksStreamProvider).valueOrNull ?? [];
      final localNames = dbTracks
          .map((d) => '${d.title} ${d.artist}')
          .take(20)
          .toList();

      final suggestions = await ref
          .read(searchSuggestionServiceProvider)
          .fetchSuggestions(trimmed, localItems: localNames);

      if (mounted && _searchController.text.trim() == trimmed) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
        });
      }

      // Auto-trigger dual-source search if user stops typing
      _performSearch(trimmed);
    });
  }

  Future<List<Track>> _searchYoutube(String query) async {
    try {
      final searchList = await _yt.search
          .search(query)
          .timeout(const Duration(seconds: 8));

      final List<Track> tracks = [];
      for (final item in searchList) {
        final art = item.thumbnails.highResUrl.isNotEmpty
            ? item.thumbnails.highResUrl
            : item.thumbnails.mediumResUrl;

        tracks.add(
          Track(
            id: 'yt:${item.id.value}',
            title: item.title,
            artist: item.author,
            album: 'YouTube Music',
            duration: item.duration ?? const Duration(minutes: 3, seconds: 30),
            coverGradientIndex: item.id.value.hashCode.abs() % 6,
            genre: 'Music',
            filePath: '', // Resolved cleanly on demand via video ID in AudioStreamResolver
            localCoverPath: art,
            isFavorite: false,
            hasLyrics: true,
          ),
        );
        if (tracks.length >= 15) break;
      }
      return tracks;
    } catch (e) {
      debugPrint('[SearchScreen] YouTube search error: $e');
      return [];
    }
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _query = trimmed;
      _isLoading = true;
    });

    try {
      if (_selectedCategory == SearchCategory.music) {
        // Dual-source parallel search: YouTube Explode + iTunes India Search
        final ytFuture = _searchYoutube(trimmed);
        final itunesFuture = ref
            .read(iTunesSearchServiceProvider)
            .search(trimmed, limit: 20, country: 'IN');

        final results = await Future.wait([ytFuture, itunesFuture]);
        final ytTracks = results[0];
        final itunesTracks = results[1];

        // Interleave & merge cleanly
        final List<Track> combined = [];
        final maxLen = (ytTracks.length > itunesTracks.length)
            ? ytTracks.length
            : itunesTracks.length;

        for (int i = 0; i < maxLen; i++) {
          if (i < itunesTracks.length) combined.add(itunesTracks[i]);
          if (i < ytTracks.length) combined.add(ytTracks[i]);
        }

        if (mounted && _query == trimmed) {
          setState(() {
            _musicResults = combined;
            _isLoading = false;
          });
        }
      } else if (_selectedCategory == SearchCategory.radio) {
        final stations = await ref
            .read(radioServiceProvider)
            .searchStations(trimmed);
        if (mounted && _query == trimmed) {
          setState(() {
            _radioResults = stations;
            _isLoading = false;
          });
        }
      } else {
        final pods = await ref
            .read(podcastServiceProvider)
            .searchPodcasts(trimmed);
        if (mounted && _query == trimmed) {
          setState(() {
            _podcastResults = pods;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCategoryChanged(SearchCategory cat) {
    setState(() {
      _selectedCategory = cat;
    });
    if (_query.isNotEmpty) {
      _performSearch(_query);
    }
  }

  void _onSelectSuggestion(String suggestion) {
    _debounceTimer?.cancel();
    _searchController.text = suggestion;
    setState(() => _showSuggestions = false);
    _performSearch(suggestion);
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
        onImportResult: (result) {
          if (!mounted) return;
          AppToast.show(
            context,
            result.message,
            icon: result.success
                ? LucideIcons.listMusic
                : LucideIcons.alertCircle,
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
    final dbTracks =
        dbTracksAsync.valueOrNull?.map((d) => d.toDomain()).toList() ?? [];

    final localMatches =
        _query.isEmpty || _selectedCategory != SearchCategory.music
        ? <Track>[]
        : dbTracks.where((t) {
            final q = _query.toLowerCase();
            return t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q) ||
                t.album.toLowerCase().contains(q);
          }).toList();

    final hasResults =
        localMatches.isNotEmpty ||
        _musicResults.isNotEmpty ||
        _radioResults.isNotEmpty ||
        _podcastResults.isNotEmpty;

    // Top Result Hero Item
    final topResult = localMatches.isNotEmpty
        ? localMatches.first
        : (_musicResults.isNotEmpty ? _musicResults.first : null);

    final songsList = _musicResults.length > 1
        ? _musicResults.sublist(1)
        : _musicResults;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 18,
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
                        border: Border.all(color: AppColors.subtleHairline),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.search,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    _selectedCategory == SearchCategory.music
                                    ? 'Search songs, Bollywood, artists, slowed+reverb, remixes...'
                                    : (_selectedCategory == SearchCategory.radio
                                          ? 'Search live radio stations by name, tag or city...'
                                          : 'Search podcasts and audio shows...'),
                                hintStyle: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: _onInputChanged,
                              onSubmitted: (val) {
                                _debounceTimer?.cancel();
                                setState(() => _showSuggestions = false);
                                _performSearch(val);
                              },
                            ),
                          ),
                          if (_isLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          else if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _onInputChanged('');
                              },
                              child: const Icon(
                                LucideIcons.x,
                                color: AppColors.textMuted,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Universal Playlist Link Importer Trigger
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardHover,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 14 : 10,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _openPlaylistImporterModal,
                    icon: const Icon(
                      LucideIcons.link,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    label: Text(
                      isDesktop ? 'Import Playlist' : 'Import',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // Smart 1-Word Live Autocomplete Dropdown
              if (_showSuggestions && _suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.subtleHairline),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(140),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _suggestions.map((s) {
                      return InkWell(
                        onTap: () => _onSelectSuggestion(s),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.search,
                                size: 14,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  s,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(
                                LucideIcons.arrowUpLeft,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 12),

              // Search Filter Category Pills (Music / Radio / Podcasts)
              Row(
                children: [
                  _buildCategoryPill(
                    SearchCategory.music,
                    LucideIcons.music,
                    'Music',
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryPill(
                    SearchCategory.radio,
                    LucideIcons.radio,
                    'Live Radio',
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryPill(
                    SearchCategory.podcasts,
                    LucideIcons.podcast,
                    'Podcasts',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Body: Browse All Grid (when query empty) OR Live Dual-Source Results
              Expanded(
                child: _query.isEmpty
                    ? _buildBrowseAllGrid(isDesktop)
                    : (_isLoading && !hasResults)
                    ? ListView(
                        children: List.generate(
                          8,
                          (_) => const ShimmerTrackRow(),
                        ),
                      )
                    : !hasResults && !_isLoading
                    ? _buildNoResults()
                    : _buildResultsView(
                        isDesktop: isDesktop,
                        topResult: topResult,
                        songsList: songsList,
                        localMatches: localMatches,
                        playerNotifier: playerNotifier,
                        downloadService: downloadService,
                        downloadStates: downloadStates,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SPOTIFY-STYLE "BROWSE ALL" GRID (When Search bar is empty)
  // =========================================================================
  Widget _buildBrowseAllGrid(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Browse All',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.8,
            ),
            itemCount: _browseCategories.length,
            itemBuilder: (context, index) {
              final cat = _browseCategories[index];
              return _buildBrowseCard(cat);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBrowseCard(_BrowseCategoryItem cat) {
    return GestureDetector(
      onTap: () {
        _searchController.text = cat.query;
        setState(() => _showSuggestions = false);
        _performSearch(cat.query);
      },
      child: Container(
        decoration: BoxDecoration(
          color: cat.color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: cat.color.withAlpha(60),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Bold Category Title
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                cat.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            // Tilted Corner Artwork Icon
            Positioned(
              right: -8,
              bottom: -8,
              child: Transform.rotate(
                angle: 0.35,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(45),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(70),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(cat.icon, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // DUAL-SOURCE RESULTS VIEW: Top Result Hero + Songs List
  // =========================================================================
  Widget _buildResultsView({
    required bool isDesktop,
    required Track? topResult,
    required List<Track> songsList,
    required List<Track> localMatches,
    required dynamic playerNotifier,
    required dynamic downloadService,
    required Map<String, TrackDownloadState> downloadStates,
  }) {
    if (_selectedCategory == SearchCategory.radio) {
      return _buildRadioResultsList(playerNotifier);
    }
    if (_selectedCategory == SearchCategory.podcasts) {
      return _buildPodcastResultsList();
    }

    // Music category: Spotify Desktop 2-column (Top Result Left + Songs List Right)
    if (isDesktop && MediaQuery.sizeOf(context).width >= 800) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Top Result Hero Card (flex 2)
          if (topResult != null)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Result',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _TopResultHeroCard(
                    track: topResult,
                    onPlay: () => playerNotifier.playTrack(topResult),
                    onDownload: () =>
                        downloadService.downloadTrackDomain(topResult),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 20),

          // Right: Songs List (flex 3)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Songs',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: songsList.length,
                    itemBuilder: (context, index) {
                      final t = songsList[index];
                      final dlState = downloadStates[t.id];
                      return _TrackListTile(
                        track: t,
                        isLocal:
                            t.filePath.isNotEmpty &&
                            !t.filePath.startsWith('http'),
                        downloadState: dlState,
                        onPlay: () => playerNotifier.playTrack(t),
                        onDownload: () =>
                            downloadService.downloadTrackDomain(t),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Mobile / Narrow Stacked Layout
    return ListView(
      children: [
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
          _TopResultHeroCard(
            track: topResult,
            onPlay: () => playerNotifier.playTrack(topResult),
            onDownload: () => downloadService.downloadTrackDomain(topResult),
          ),
          const SizedBox(height: 20),
        ],

        if (localMatches.isNotEmpty) ...[
          Row(
            children: [
              const Icon(
                LucideIcons.hardDrive,
                size: 14,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Offline Library (${localMatches.length})',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...localMatches.map(
            (t) => _TrackListTile(
              track: t,
              isLocal: true,
              onPlay: () => playerNotifier.playTrack(t),
            ),
          ),
          const SizedBox(height: 20),
        ],

        if (songsList.isNotEmpty) ...[
          const Text(
            'Songs',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...songsList.map((t) {
            final dlState = downloadStates[t.id];
            return _TrackListTile(
              track: t,
              isLocal: false,
              downloadState: dlState,
              onPlay: () => playerNotifier.playTrack(t),
              onDownload: () => downloadService.downloadTrackDomain(t),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildRadioResultsList(dynamic playerNotifier) {
    return ListView.builder(
      itemCount: _radioResults.length,
      itemBuilder: (context, index) {
        final st = _radioResults[index];
        final tr = st.toTrack();
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.subtleHairline),
          ),
          child: Row(
            children: [
              AlbumArtView(
                imageUrl: st.favicon,
                size: 44,
                borderRadius: 6,
                placeholderText: st.name,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      st.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${st.country} • ${st.tags.isNotEmpty ? st.tags : st.codec}',
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
              IconButton(
                icon: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.play,
                    color: Colors.black,
                    size: 16,
                  ),
                ),
                onPressed: () {
                  playerNotifier.playTrack(tr);
                  AppToast.show(
                    context,
                    'Streaming "${st.name}"',
                    icon: LucideIcons.radio,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPodcastResultsList() {
    return ListView.builder(
      itemCount: _podcastResults.length,
      itemBuilder: (context, index) {
        final pod = _podcastResults[index];
        return GestureDetector(
          onTap: () => showPodcastEpisodesSheet(context, ref, pod),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.subtleHairline),
            ),
            child: Row(
              children: [
                AlbumArtView(
                  imageUrl: pod.artworkUrl,
                  size: 54,
                  borderRadius: 8,
                  placeholderText: pod.title,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pod.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pod.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryPill(
    SearchCategory category,
    IconData icon,
    String label,
  ) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => _onCategoryChanged(category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.subtleHairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.black : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
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

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(LucideIcons.music, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No matching songs found',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Check your spelling or search another Indian song or artist.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Spotify Top Result Hero Card with #38BDF8 Play Button & Source Tag
class _TopResultHeroCard extends StatefulWidget {
  final Track track;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  const _TopResultHeroCard({
    required this.track,
    required this.onPlay,
    required this.onDownload,
  });

  @override
  State<_TopResultHeroCard> createState() => _TopResultHeroCardState();
}

class _TopResultHeroCardState extends State<_TopResultHeroCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isYouTube = widget.track.id.startsWith('yt:');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.cardHover : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.subtleHairline),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(80),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AlbumArtView(
                imageUrl: widget.track.localCoverPath,
                localFilePath: widget.track.localCoverPath,
                size: 92,
                borderRadius: 8,
                showShadow: true,
                placeholderText: widget.track.title,
              ),
              const SizedBox(height: 16),
              Text(
                widget.track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isYouTube
                          ? Colors.redAccent.withAlpha(30)
                          : AppColors.accent.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isYouTube ? 'YOUTUBE' : 'SONG',
                      style: TextStyle(
                        color: isYouTube ? Colors.redAccent : AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Save to Offline Storage',
                    icon: const Icon(
                      LucideIcons.download,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: widget.onDownload,
                  ),
                  Consumer(
                    builder: (ctx, ref, _) => IconButton(
                      tooltip: 'More actions',
                      icon: const Icon(
                        LucideIcons.ellipsisVertical,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          showTrackActionMenu(context, ref, widget.track),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent, // Electric Cyan #38BDF8
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withAlpha(100),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.play,
                      color: Colors.black,
                      size: 20,
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

/// Track List Tile with source tags and hover play button
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
    final isDownloaded =
        widget.isLocal || dl?.status == DownloadStatus.completed;
    final isYouTube = widget.track.id.startsWith('yt:');

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
                    Row(
                      children: [
                        if (isYouTube) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'YT',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            widget.track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.onDownload != null)
                IconButton(
                  tooltip: isDownloaded ? 'Saved' : 'Download',
                  icon: isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : Icon(
                          isDownloaded
                              ? LucideIcons.check
                              : LucideIcons.download,
                          color: isDownloaded
                              ? AppColors.accent
                              : AppColors.textMuted,
                          size: 16,
                        ),
                  onPressed: isDownloaded ? null : widget.onDownload,
                ),
              Consumer(
                builder: (ctx, ref, _) => IconButton(
                  icon: const Icon(
                    LucideIcons.ellipsisVertical,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                  onPressed: () =>
                      showTrackActionMenu(context, ref, widget.track),
                ),
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
  final void Function(UniversalImportResult result) onImportResult;

  const _PlaylistImporterModal({required this.onImportResult});

  @override
  State<_PlaylistImporterModal> createState() => _PlaylistImporterModalState();
}

class _PlaylistImporterModalState extends State<_PlaylistImporterModal> {
  final TextEditingController _urlController = TextEditingController();
  bool _isImporting = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleImport(WidgetRef ref) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isImporting = true);
    final db = ref.read(appDatabaseProvider);
    final importer = UniversalPlaylistImporterService(db);

    try {
      final result = await importer.importPlaylist(url);
      if (mounted) {
        Navigator.pop(context);
        widget.onImportResult(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        AppToast.show(
          context,
          'Import failed: $e',
          icon: LucideIcons.alertCircle,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.link,
                  color: AppColors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Import Universal Playlist',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Paste any public Spotify, YouTube, Apple Music, or JioSaavn playlist URL to import tracks offline.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  'https://open.spotify.com/playlist/... or youtube.com/...',
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Consumer(
            builder: (ctx, ref, _) => SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isImporting ? null : () => _handleImport(ref),
                child: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Import Playlist',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
