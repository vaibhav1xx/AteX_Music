import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import '../models/track.dart';

class PlaylistFileResult {
  final bool success;
  final String message;
  final int count;
  final String? filePath;

  const PlaylistFileResult({
    required this.success,
    required this.message,
    this.count = 0,
    this.filePath,
  });
}

class PlaylistFileService {
  /// Exports tracks to standard UTF-8 M3U8 format
  static Future<PlaylistFileResult> exportToM3u(String playlistName, List<Track> tracks) async {
    if (tracks.isEmpty) {
      return const PlaylistFileResult(success: false, message: 'Playlist contains no tracks to export');
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('#EXTM3U');
      buffer.writeln('#PLAYLIST:$playlistName');
      buffer.writeln();

      for (final t in tracks) {
        final durationSec = t.duration.inSeconds;
        buffer.writeln('#EXTINF:$durationSec,${t.artist} - ${t.title}');
        buffer.writeln(t.filePath);
      }

      final fileName = '${_sanitizeFileName(playlistName)}.m3u8';
      final dir = await _getExportDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(buffer.toString(), encoding: utf8);

      return PlaylistFileResult(
        success: true,
        message: 'Exported ${tracks.length} tracks to $fileName',
        count: tracks.length,
        filePath: file.path,
      );
    } catch (e) {
      debugPrint('M3U export error: $e');
      return PlaylistFileResult(success: false, message: 'Export failed: $e');
    }
  }

  /// Exports tracks to structured JSON format
  static Future<PlaylistFileResult> exportToJson(String playlistName, List<Track> tracks) async {
    if (tracks.isEmpty) {
      return const PlaylistFileResult(success: false, message: 'Playlist contains no tracks to export');
    }

    try {
      final exportData = {
        'name': playlistName,
        'exportedAt': DateTime.now().toIso8601String(),
        'trackCount': tracks.length,
        'tracks': tracks.map((t) => {
          'id': t.id,
          'title': t.title,
          'artist': t.artist,
          'album': t.album,
          'durationMs': t.duration.inMilliseconds,
          'filePath': t.filePath,
          'genre': t.genre,
        }).toList(),
      };

      final fileName = '${_sanitizeFileName(playlistName)}.json';
      final dir = await _getExportDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(exportData), encoding: utf8);

      return PlaylistFileResult(
        success: true,
        message: 'Exported ${tracks.length} tracks to $fileName',
        count: tracks.length,
        filePath: file.path,
      );
    } catch (e) {
      debugPrint('JSON export error: $e');
      return PlaylistFileResult(success: false, message: 'Export failed: $e');
    }
  }

  /// Imports a playlist from an .m3u / .m3u8 or .json file
  static Future<PlaylistFileResult> importPlaylist(AppDatabase db) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8', 'json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return const PlaylistFileResult(success: false, message: 'No file selected');
      }

      final file = File(result.files.first.path!);
      final extension = file.path.split('.').last.toLowerCase();
      final rawContent = await file.readAsString();

      if (extension == 'json') {
        return await _importFromJson(db, file, rawContent);
      } else {
        return await _importFromM3u(db, file, rawContent);
      }
    } catch (e) {
      debugPrint('Playlist import error: $e');
      return PlaylistFileResult(success: false, message: 'Import failed: $e');
    }
  }

  static Future<PlaylistFileResult> _importFromM3u(AppDatabase db, File file, String content) async {
    final lines = content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) {
      return const PlaylistFileResult(success: false, message: 'Empty playlist file');
    }

    String playlistName = file.uri.pathSegments.last.replaceAll(RegExp(r'\.m3u8?$'), '');
    final existingTracks = await db.getAllTracks();
    final trackPathMap = {for (var t in existingTracks) t.localAudioPath: t};

    int importedCount = 0;
    final playlistId = 'pl_${DateTime.now().millisecondsSinceEpoch}';

    // Check if #PLAYLIST tag exists
    for (final l in lines) {
      if (l.startsWith('#PLAYLIST:')) {
        playlistName = l.substring('#PLAYLIST:'.length).trim();
        break;
      }
    }

    // Create playlist in DB
    await db.createPlaylist(
      PlaylistsCompanion(
        id: drift.Value(playlistId),
        name: drift.Value(playlistName),
        description: drift.Value('Imported from ${file.path}'),
      ),
    );

    int sortOrder = 0;
    String currentTitle = 'Imported Track';
    String currentArtist = 'Unknown Artist';
    int currentDurationSec = 0;

    for (final line in lines) {
      if (line.startsWith('#EXTINF:')) {
        final info = line.substring(8).trim();
        final commaIdx = info.indexOf(',');
        if (commaIdx >= 0) {
          final durPart = info.substring(0, commaIdx).trim();
          currentDurationSec = int.tryParse(durPart) ?? 0;
          final titlePart = info.substring(commaIdx + 1).trim();
          final dashIdx = titlePart.indexOf(' - ');
          if (dashIdx >= 0) {
            currentArtist = titlePart.substring(0, dashIdx).trim();
            currentTitle = titlePart.substring(dashIdx + 3).trim();
          } else {
            currentTitle = titlePart;
          }
        }
      } else if (!line.startsWith('#')) {
        // Line is audio file path or URL
        final filePath = line;
        String trackId;

        if (trackPathMap.containsKey(filePath)) {
          trackId = trackPathMap[filePath]!.id;
        } else {
          // Track not yet in database: register track
          trackId = 'track_${filePath.hashCode.abs()}';
          await db.insertOrUpdateTrack(
            TracksCompanion(
              id: drift.Value(trackId),
              title: drift.Value(currentTitle),
              artist: drift.Value(currentArtist),
              album: drift.Value('Imported Audio'),
              durationMs: drift.Value(currentDurationSec * 1000),
              localAudioPath: drift.Value(filePath),
              isFavorite: const drift.Value(false),
            ),
          );
        }

        await db.addTrackToPlaylist(playlistId, trackId, sortOrder: sortOrder++);
        importedCount++;

        // Reset metadata
        currentTitle = 'Imported Track';
        currentArtist = 'Unknown Artist';
        currentDurationSec = 0;
      }
    }

    return PlaylistFileResult(
      success: true,
      message: 'Imported "$playlistName" with $importedCount tracks',
      count: importedCount,
      filePath: file.path,
    );
  }

  static Future<PlaylistFileResult> _importFromJson(AppDatabase db, File file, String content) async {
    final Map<String, dynamic> data = jsonDecode(content);
    final playlistName = (data['name'] as String? ?? 'Imported Playlist').trim();
    final rawTracks = data['tracks'] as List? ?? [];

    final playlistId = 'pl_${DateTime.now().millisecondsSinceEpoch}';
    await db.createPlaylist(
      PlaylistsCompanion(
        id: drift.Value(playlistId),
        name: drift.Value(playlistName),
        description: drift.Value('Imported from JSON on ${DateTime.now().toString().split('.').first}'),
      ),
    );

    int count = 0;
    for (int i = 0; i < rawTracks.length; i++) {
      final t = rawTracks[i] as Map<String, dynamic>;
      final filePath = t['filePath'] as String? ?? '';
      if (filePath.isEmpty) continue;

      final trackId = t['id'] as String? ?? 'track_${filePath.hashCode.abs()}';
      await db.insertOrUpdateTrack(
        TracksCompanion(
          id: drift.Value(trackId),
          title: drift.Value(t['title'] as String? ?? 'Imported Track'),
          artist: drift.Value(t['artist'] as String? ?? 'Unknown Artist'),
          album: drift.Value(t['album'] as String? ?? 'Imported Audio'),
          durationMs: drift.Value(t['durationMs'] as int? ?? 0),
          localAudioPath: drift.Value(filePath),
          isFavorite: const drift.Value(false),
        ),
      );

      await db.addTrackToPlaylist(playlistId, trackId, sortOrder: i);
      count++;
    }

    return PlaylistFileResult(
      success: true,
      message: 'Imported "$playlistName" with $count tracks',
      count: count,
      filePath: file.path,
    );
  }

  static Future<Directory> _getExportDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null && downloads.existsSync()) return downloads;
    } catch (_) {}
    return getApplicationDocumentsDirectory();
  }

  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }
}
