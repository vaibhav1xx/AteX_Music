import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../database/app_database.dart';
import 'music_scanner_interface.dart';

class DesktopMusicScanner implements MusicScanner {
  static const supportedExtensions = {
    '.mp3',
    '.flac',
    '.m4a',
    '.wav',
    '.ogg',
    '.aac',
    '.alac',
    '.wma',
  };

  @override
  Future<bool> requestPermissions() async {
    // Desktop platforms (Windows, macOS, Linux) do not require runtime permissions for user-picked folders
    return true;
  }

  @override
  Future<ScanResult> scanAndImport(AppDatabase database, {String? targetDirectory}) async {
    String? selectedDir = targetDirectory;

    if (selectedDir == null) {
      try {
        selectedDir = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Select Music Folder to Scan (AteX Music)',
        );
      } catch (e) {
        debugPrint('FilePicker error: $e');
      }
    }

    if (selectedDir == null || selectedDir.isEmpty) {
      return const ScanResult(
        scannedCount: 0,
        addedCount: 0,
        statusMessage: 'No folder selected',
        success: false,
      );
    }

    final directory = Directory(selectedDir);
    if (!directory.existsSync()) {
      return ScanResult(
        scannedCount: 0,
        addedCount: 0,
        statusMessage: 'Directory does not exist: $selectedDir',
        success: false,
      );
    }

    final audioFiles = <File>[];
    try {
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            audioFiles.add(entity);
          }
        }
      }
    } catch (e) {
      debugPrint('Error listing files in $selectedDir: $e');
    }

    int added = 0;
    final companions = <TracksCompanion>[];

    for (final file in audioFiles) {
      try {
        String title = p.basenameWithoutExtension(file.path);
        String artist = 'Unknown Artist';
        String album = 'Local Collection';
        int durationMs = 0;

        try {
          final metadata = readMetadata(file, getImage: false);
          if (metadata.title != null && metadata.title!.trim().isNotEmpty) {
            title = metadata.title!.trim();
          }
          if (metadata.artist != null && metadata.artist!.trim().isNotEmpty) {
            artist = metadata.artist!.trim();
          }
          if (metadata.album != null && metadata.album!.trim().isNotEmpty) {
            album = metadata.album!.trim();
          }
          if (metadata.duration != null) {
            durationMs = metadata.duration!.inMilliseconds;
          }
        } catch (_) {
          // Fallback to filename parsing: "Artist - Title" if present
          if (title.contains(' - ')) {
            final parts = title.split(' - ');
            if (parts.length >= 2) {
              artist = parts[0].trim();
              title = parts.sublist(1).join(' - ').trim();
            }
          }
        }

        // Check for matching .lrc lyrics file in the same directory
        final lrcPath = p.setExtension(file.path, '.lrc');
        final localLyricsPath = File(lrcPath).existsSync() ? lrcPath : null;

        // Generate stable unique ID based on file path
        final trackId = 'local_${file.path.hashCode.abs().toString()}';

        companions.add(
          TracksCompanion(
            id: Value(trackId),
            title: Value(title),
            artist: Value(artist),
            album: Value(album),
            durationMs: Value(durationMs > 0 ? durationMs : 180000), // Default 3min if tag absent
            localAudioPath: Value(file.path),
            localCoverPath: const Value(null),
            localLyricsPath: Value(localLyricsPath),
            isFavorite: const Value(false),
            dateAdded: Value(DateTime.now()),
          ),
        );
        added++;
      } catch (e) {
        debugPrint('Error processing file ${file.path}: $e');
      }
    }

    if (companions.isNotEmpty) {
      await database.insertOrUpdateTracks(companions);
    }

    return ScanResult(
      scannedCount: audioFiles.length,
      addedCount: added,
      statusMessage: 'Successfully scanned ${audioFiles.length} files from $selectedDir',
      success: true,
    );
  }
}
