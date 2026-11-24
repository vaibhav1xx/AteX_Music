import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../database/app_database.dart';
import '../models/track.dart';
import 'itunes_search_service.dart';

class UniversalImportResult {
  final bool success;
  final String playlistId;
  final String playlistName;
  final List<Track> tracks;
  final String message;

  const UniversalImportResult({
    required this.success,
    required this.playlistId,
    required this.playlistName,
    required this.tracks,
    required this.message,
  });
}

class UniversalPlaylistImporterService {
  final AppDatabase _db;
  final ITunesSearchService _searchService;
  final Dio _dio;

  UniversalPlaylistImporterService(
    this._db, {
    ITunesSearchService? searchService,
    Dio? dio,
  })  : _searchService = searchService ?? ITunesSearchService(),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                headers: {'User-Agent': 'AteXMusic/1.0'},
              ),
            );

  Future<UniversalImportResult> importPlaylist(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty) {
      return const UniversalImportResult(
        success: false,
        playlistId: '',
        playlistName: '',
        tracks: [],
        message: 'No playlist link or tracks provided',
      );
    }

    // 1. YouTube / YouTube Music playlist
    if (input.contains('youtube.com/playlist') || input.contains('music.youtube.com/playlist')) {
      return await _importYouTubePlaylist(input);
    }

    // 2. Spotify playlist
    if (input.contains('spotify.com/playlist/')) {
      return await _importSpotifyPlaylist(input);
    }

    // 3. Amazon Music playlist
    if (input.contains('music.amazon.')) {
      return await _importAmazonPlaylist(input);
    }

    // 4. Plain text / Comma or newline separated song names
    return await _importFromTextLines(input, defaultPlaylistName: 'Imported Mix');
  }

  Future<UniversalImportResult> _importYouTubePlaylist(String url) async {
    final yt = YoutubeExplode();
    try {
      final uri = Uri.tryParse(url);
      final listId = uri?.queryParameters['list'];
      if (listId == null || listId.isEmpty) {
        return const UniversalImportResult(
          success: false,
          playlistId: '',
          playlistName: '',
          tracks: [],
          message: 'Invalid YouTube playlist URL: missing list ID',
        );
      }

      final ytPlaylist = await yt.playlists.get(listId);
      final playlistName = ytPlaylist.title.trim().isNotEmpty
          ? ytPlaylist.title
          : 'YouTube Playlist';
      final playlistId = 'pl_yt_${DateTime.now().millisecondsSinceEpoch}';

      // Create Drift Playlist in SQLite
      await _db.createPlaylist(
        PlaylistsCompanion(
          id: drift.Value(playlistId),
          name: drift.Value(playlistName),
          description: drift.Value('Imported from YouTube: ${ytPlaylist.author}'),
        ),
      );

      final importedTracks = <Track>[];
      int sortOrder = 0;

      await for (final video in yt.playlists.getVideos(listId).take(50)) {
        final trackId = 'yt_${video.id}';
        final track = Track(
          id: trackId,
          title: video.title,
          artist: video.author.isNotEmpty ? video.author : 'Unknown Artist',
          album: playlistName,
          duration: video.duration ?? const Duration(minutes: 3, seconds: 30),
          genre: 'YouTube Import',
          filePath: '', // Resolved dynamically upon play or download
          localCoverPath: video.thumbnails.highResUrl,
          isFavorite: false,
          hasLyrics: true,
        );

        // Save track to Drift AppDatabase
        await _db.insertOrUpdateTrack(track.toCompanion());
        await _db.addTrackToPlaylist(playlistId, trackId, sortOrder: sortOrder++);
        importedTracks.add(track);
      }

      return UniversalImportResult(
        success: true,
        playlistId: playlistId,
        playlistName: playlistName,
        tracks: importedTracks,
        message: 'Successfully imported "$playlistName" (${importedTracks.length} tracks)',
      );
    } catch (e) {
      debugPrint('[UniversalPlaylistImporter] YouTube error: $e');
      return UniversalImportResult(
        success: false,
        playlistId: '',
        playlistName: '',
        tracks: [],
        message: 'YouTube import error: $e',
      );
    } finally {
      yt.close();
    }
  }

  Future<UniversalImportResult> _importSpotifyPlaylist(String url) async {
    String playlistTitle = 'Spotify Playlist';
    try {
      final oembedUrl = 'https://open.spotify.com/oembed?url=${Uri.encodeComponent(url)}';
      final response = await _dio.get(oembedUrl);
      if (response.statusCode == 200 && response.data is Map) {
        final title = response.data['title'] as String?;
        if (title != null && title.isNotEmpty) {
          playlistTitle = title;
        }
      }
    } catch (e) {
      debugPrint('[UniversalPlaylistImporter] Spotify oEmbed error: $e');
    }

    // Attempt to scrape track names from the page or fall back to text lines
    try {
      final pageResp = await _dio.get(url);
      final html = pageResp.data.toString();
      final titleMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(html);
      if (titleMatch != null) {
        final rawTitle = titleMatch.group(1)?.split('|').first.trim();
        if (rawTitle != null && rawTitle.isNotEmpty) {
          playlistTitle = rawTitle;
        }
      }

      // Extract entity tracks from meta tags or structured metadata
      final trackMatches = RegExp(r'"name":"([^"]+)"[^{}]*"artists":\[\{"name":"([^"]+)"').allMatches(html);
      final queries = <String>[];
      for (final m in trackMatches.take(30)) {
        final title = m.group(1) ?? '';
        final artist = m.group(2) ?? '';
        if (title.isNotEmpty) {
          queries.add('$artist - $title');
        }
      }

      if (queries.isNotEmpty) {
        return await _createPlaylistFromQueries(playlistTitle, queries);
      }
    } catch (e) {
      debugPrint('[UniversalPlaylistImporter] Spotify scrape error: $e');
    }

    // Fallback: parse whatever text lines user provided along with link
    return await _importFromTextLines(url, defaultPlaylistName: playlistTitle);
  }

  Future<UniversalImportResult> _importAmazonPlaylist(String url) async {
    String playlistTitle = 'Amazon Music Playlist';
    try {
      final resp = await _dio.get(url);
      final html = resp.data.toString();
      final titleMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(html);
      if (titleMatch != null) {
        final rawTitle = titleMatch.group(1)?.split('|').first.split('-').first.trim();
        if (rawTitle != null && rawTitle.isNotEmpty) {
          playlistTitle = rawTitle;
        }
      }
    } catch (_) {}

    return await _importFromTextLines(url, defaultPlaylistName: playlistTitle);
  }

  Future<UniversalImportResult> _importFromTextLines(
    String rawText, {
    required String defaultPlaylistName,
  }) async {
    final lines = rawText
        .split(RegExp(r'[\n,]'))
        .map((s) => s.replaceAll(RegExp(r'https?://[^\s]+'), '').replaceAll(RegExp(r'^\d+[\.\s\-]+'), '').trim())
        .where((s) => s.isNotEmpty && s.length > 2)
        .take(40)
        .toList();

    if (lines.isEmpty) {
      return const UniversalImportResult(
        success: false,
        playlistId: '',
        playlistName: '',
        tracks: [],
        message: 'Could not extract any valid track titles from input',
      );
    }

    return await _createPlaylistFromQueries(defaultPlaylistName, lines);
  }

  Future<UniversalImportResult> _createPlaylistFromQueries(
    String playlistName,
    List<String> queries,
  ) async {
    final playlistId = 'pl_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Create real Drift playlist in SQLite
    await _db.createPlaylist(
      PlaylistsCompanion(
        id: drift.Value(playlistId),
        name: drift.Value(playlistName),
        description: drift.Value('Universal import (${queries.length} tracks) on ${DateTime.now().toString().split('.').first}'),
      ),
    );

    final importedTracks = <Track>[];
    int sortOrder = 0;

    for (final q in queries) {
      try {
        final results = await _searchService.search(q, limit: 1);
        Track track;
        if (results.isNotEmpty) {
          final res = results.first;
          track = res.copyWith(album: playlistName);
        } else {
          // Fallback track domain object if search yields nothing
          final parts = q.split(' - ');
          final artist = parts.length > 1 ? parts[0].trim() : 'Unknown Artist';
          final title = parts.length > 1 ? parts[1].trim() : q.trim();
          track = Track(
            id: 'imp_${q.hashCode.abs()}',
            title: title,
            artist: artist,
            album: playlistName,
            duration: const Duration(minutes: 3, seconds: 30),
            genre: 'Universal Import',
            filePath: '',
            isFavorite: false,
            hasLyrics: true,
          );
        }

        // Insert into Drift SQLite database
        await _db.insertOrUpdateTrack(track.toCompanion());
        await _db.addTrackToPlaylist(playlistId, track.id, sortOrder: sortOrder++);
        importedTracks.add(track);
      } catch (e) {
        debugPrint('[UniversalPlaylistImporter] Error resolving query "$q": $e');
      }
    }

    return UniversalImportResult(
      success: true,
      playlistId: playlistId,
      playlistName: playlistName,
      tracks: importedTracks,
      message: 'Created playlist "$playlistName" with ${importedTracks.length} playable tracks',
    );
  }
}

final universalPlaylistImporterProvider = Provider<UniversalPlaylistImporterService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final searchService = ref.watch(iTunesSearchServiceProvider);
  return UniversalPlaylistImporterService(db, searchService: searchService);
});
