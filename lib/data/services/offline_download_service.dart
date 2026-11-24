import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../models/track.dart';
import 'audio_stream_resolver.dart';
import 'lrclib_service.dart';

enum DownloadStatus { pending, downloading, completed, failed }

class TrackDownloadState {
  final String trackId;
  final String title;
  final String artist;
  final double progress;
  final DownloadStatus status;
  final String? error;
  final String? localAudioPath;

  const TrackDownloadState({
    required this.trackId,
    required this.title,
    required this.artist,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
    this.error,
    this.localAudioPath,
  });

  TrackDownloadState copyWith({
    double? progress,
    DownloadStatus? status,
    String? error,
    String? localAudioPath,
  }) {
    return TrackDownloadState(
      trackId: trackId,
      title: title,
      artist: artist,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: error ?? this.error,
      localAudioPath: localAudioPath ?? this.localAudioPath,
    );
  }
}

class OfflineDownloadService extends StateNotifier<Map<String, TrackDownloadState>> {
  final Dio _dio;
  final AppDatabase _database;
  final AudioStreamResolver _streamResolver;
  final LrcLibService _lrcLibService;

  OfflineDownloadService(
    this._database, {
    AudioStreamResolver? streamResolver,
    LrcLibService? lrcLibService,
    Dio? dio,
  })  : _streamResolver = streamResolver ?? AudioStreamResolver(),
        _lrcLibService = lrcLibService ?? LrcLibService(),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 60),
              ),
            ),
        super({});

  Future<String> _getStorageDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(docsDir.path, 'AteX_Music', 'Media'));
    if (!mediaDir.existsSync()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir.path;
  }

  Future<void> downloadTrackDomain(Track track) async {
    await downloadTrack(
      trackId: track.id,
      audioUrl: track.filePath,
      title: track.title,
      artist: track.artist,
      album: track.album,
      coverUrl: track.localCoverPath,
      duration: track.duration,
    );
  }

  Future<void> downloadTrack({
    required String trackId,
    required String audioUrl,
    required String title,
    required String artist,
    required String album,
    String? coverUrl,
    String? lyricsUrl,
    Duration duration = const Duration(minutes: 3),
  }) async {
    // 1. Register task in state
    state = {
      ...state,
      trackId: TrackDownloadState(
        trackId: trackId,
        title: title,
        artist: artist,
        status: DownloadStatus.downloading,
        progress: 0.05,
      ),
    };

    try {
      final mediaPath = await _getStorageDirectory();
      final sanitizedFilename = '${artist}_$title'
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();

      // 2. Resolve real full-length audio stream if audioUrl is preview or empty
      String effectiveAudioUrl = audioUrl;
      final isPreview = audioUrl.contains('apple.com') ||
          audioUrl.contains('preview') ||
          audioUrl.isEmpty;

      if (isPreview) {
        debugPrint('[OfflineDownloadService] Resolving full stream for "$title - $artist"');
        final resolved = await _streamResolver.resolveStreamUrl(
          Track(
            id: trackId,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            genre: '',
            filePath: audioUrl,
          ),
        );
        if (resolved != null && resolved.isNotEmpty) {
          effectiveAudioUrl = resolved;
        }
      }

      if (effectiveAudioUrl.isEmpty) {
        throw Exception('Could not resolve valid audio stream URL for "$title"');
      }

      // Determine extension (.m4a, .webm, .opus, or .mp3)
      String audioExt = p.extension(Uri.parse(effectiveAudioUrl).path);
      if (audioExt.isEmpty || audioExt.length > 5) {
        audioExt = effectiveAudioUrl.contains('mime=audio%2Fwebm') ? '.opus' : '.m4a';
      }
      final localAudioPath = p.join(mediaPath, '$sanitizedFilename$audioExt');

      // 3. Download audio file with live progress (0.1 to 0.8)
      await _dio.download(
        effectiveAudioUrl,
        localAudioPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final fraction = (0.1 + (received / total) * 0.7).clamp(0.1, 0.8);
            final current = state[trackId];
            if (current != null) {
              state = {
                ...state,
                trackId: current.copyWith(
                  progress: fraction,
                  status: DownloadStatus.downloading,
                ),
              };
            }
          }
        },
      );

      // 4. Download high-res cover art (0.8 to 0.9)
      String? localCoverPath;
      if (coverUrl != null && coverUrl.isNotEmpty && coverUrl.startsWith('http')) {
        try {
          final coverExt = p.extension(Uri.parse(coverUrl).path);
          final finalCoverExt = coverExt.isNotEmpty && coverExt.length <= 5 ? coverExt : '.jpg';
          localCoverPath = p.join(mediaPath, '${sanitizedFilename}_cover$finalCoverExt');
          await _dio.download(coverUrl, localCoverPath);
        } catch (e) {
          debugPrint('[OfflineDownloadService] Optional cover download error: $e');
        }
      }

      // 5. Fetch and save LRCLIB .lrc synchronized lyrics (0.9 to 0.95)
      String? localLyricsPath;
      try {
        String? lrcContent;
        if (lyricsUrl != null && lyricsUrl.isNotEmpty && lyricsUrl.startsWith('http')) {
          final resp = await _dio.get<String>(lyricsUrl);
          lrcContent = resp.data;
        } else {
          lrcContent = await _lrcLibService.fetchLyrics(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
          );
        }

        if (lrcContent != null && lrcContent.trim().isNotEmpty) {
          localLyricsPath = p.join(mediaPath, '$sanitizedFilename.lrc');
          final lrcFile = File(localLyricsPath);
          await lrcFile.writeAsString(lrcContent);
          debugPrint('[OfflineDownloadService] Saved .lrc lyrics to $localLyricsPath');
        }
      } catch (e) {
        debugPrint('[OfflineDownloadService] Optional lyrics fetch error: $e');
      }

      // 6. Save into local SQLite AppDatabase
      final companion = TracksCompanion(
        id: Value(trackId),
        title: Value(title),
        artist: Value(artist),
        album: Value(album),
        durationMs: Value(duration.inMilliseconds),
        localAudioPath: Value(localAudioPath),
        localCoverPath: Value(localCoverPath),
        localLyricsPath: Value(localLyricsPath),
        isFavorite: const Value(false),
        dateAdded: Value(DateTime.now()),
      );

      await _database.insertOrUpdateTrack(companion);

      // 7. Update state to completed
      final current = state[trackId];
      if (current != null) {
        state = {
          ...state,
          trackId: current.copyWith(
            progress: 1.0,
            status: DownloadStatus.completed,
            localAudioPath: localAudioPath,
          ),
        };
      }
      debugPrint('[OfflineDownloadService] Successfully downloaded and stored "$title" offline');
    } catch (e) {
      debugPrint('[OfflineDownloadService] Error downloading track $trackId: $e');
      final current = state[trackId];
      if (current != null) {
        state = {
          ...state,
          trackId: current.copyWith(
            status: DownloadStatus.failed,
            error: e.toString(),
          ),
        };
      }
    }
  }

  TrackDownloadState? getDownloadState(String trackId) => state[trackId];
}

final offlineDownloadServiceProvider =
    StateNotifierProvider<OfflineDownloadService, Map<String, TrackDownloadState>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final resolver = ref.watch(audioStreamResolverProvider);
  final lrcService = ref.watch(lrcLibServiceProvider);
  return OfflineDownloadService(
    db,
    streamResolver: resolver,
    lrcLibService: lrcService,
  );
});
