import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';

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

  OfflineDownloadService(this._database, [Dio? dio])
      : _dio = dio ?? Dio(),
        super({});

  Future<String> _getStorageDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(docsDir.path, 'AteX_Music', 'Media'));
    if (!mediaDir.existsSync()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir.path;
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
    // Register task in state
    state = {
      ...state,
      trackId: TrackDownloadState(
        trackId: trackId,
        title: title,
        artist: artist,
        status: DownloadStatus.downloading,
      ),
    };

    try {
      final mediaPath = await _getStorageDirectory();
      final sanitizedFilename = '${artist}_$title'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final audioExt = p.extension(Uri.parse(audioUrl).path);
      final finalAudioExt = audioExt.isNotEmpty ? audioExt : '.mp3';
      final localAudioPath = p.join(mediaPath, '$sanitizedFilename$finalAudioExt');

      // 1. Download audio file with live progress
      await _dio.download(
        audioUrl,
        localAudioPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final fraction = (received / total).clamp(0.0, 1.0);
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

      // 2. Download high-res cover art if provided
      String? localCoverPath;
      if (coverUrl != null && coverUrl.isNotEmpty) {
        try {
          final coverExt = p.extension(Uri.parse(coverUrl).path);
          final finalCoverExt = coverExt.isNotEmpty ? coverExt : '.jpg';
          localCoverPath = p.join(mediaPath, '${sanitizedFilename}_cover$finalCoverExt');
          await _dio.download(coverUrl, localCoverPath);
        } catch (e) {
          debugPrint('Optional cover download error: $e');
        }
      }

      // 3. Download .lrc synchronized lyrics if provided
      String? localLyricsPath;
      if (lyricsUrl != null && lyricsUrl.isNotEmpty) {
        try {
          localLyricsPath = p.join(mediaPath, '$sanitizedFilename.lrc');
          await _dio.download(lyricsUrl, localLyricsPath);
        } catch (e) {
          debugPrint('Optional lyrics download error: $e');
        }
      }

      // 4. Save into local SQLite AppDatabase
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

      // 5. Update state to completed
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
    } catch (e) {
      debugPrint('Error downloading track $trackId: $e');
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
  return OfflineDownloadService(db);
});
