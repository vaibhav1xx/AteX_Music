import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/app_database.dart';
import 'music_scanner_interface.dart';

class MobileMusicScanner implements MusicScanner {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  @override
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    if (Platform.isAndroid) {
      // Android 13+ (API 33+) requires READ_MEDIA_AUDIO
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) return true;

      // Android 12 and below requires READ_EXTERNAL_STORAGE
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }

    if (Platform.isIOS) {
      final mediaStatus = await Permission.mediaLibrary.request();
      return mediaStatus.isGranted;
    }

    return false;
  }

  @override
  Future<ScanResult> scanAndImport(AppDatabase database, {String? targetDirectory}) async {
    final hasPerm = await requestPermissions();
    if (!hasPerm) {
      return const ScanResult(
        scannedCount: 0,
        addedCount: 0,
        statusMessage: 'Storage / Audio permissions were denied',
        success: false,
      );
    }

    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      final companions = <TracksCompanion>[];
      for (final song in songs) {
        if (song.isMusic != false && song.data.isNotEmpty) {
          companions.add(
            TracksCompanion(
              id: Value('mob_${song.id}'),
              title: Value(song.title.isNotEmpty ? song.title : 'Unknown Title'),
              artist: Value(song.artist != null && song.artist != '<unknown>' ? song.artist! : 'Unknown Artist'),
              album: Value(song.album != null && song.album != '<unknown>' ? song.album! : 'Local Audio'),
              durationMs: Value(song.duration ?? 0),
              localAudioPath: Value(song.data),
              localCoverPath: const Value(null),
              localLyricsPath: const Value(null),
              isFavorite: const Value(false),
              dateAdded: Value(DateTime.now()),
            ),
          );
        }
      }

      if (companions.isNotEmpty) {
        await database.insertOrUpdateTracks(companions);
      }

      return ScanResult(
        scannedCount: songs.length,
        addedCount: companions.length,
        statusMessage: 'Indexed ${companions.length} device tracks into local SQLite database',
        success: true,
      );
    } catch (e) {
      debugPrint('MobileMusicScanner error: $e');
      return ScanResult(
        scannedCount: 0,
        addedCount: 0,
        statusMessage: 'Error scanning device audio: $e',
        success: false,
      );
    }
  }
}
