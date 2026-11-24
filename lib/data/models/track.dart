import 'package:drift/drift.dart';
import '../database/app_database.dart';

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final int coverGradientIndex;
  final String genre;
  final String filePath;
  final String? localCoverPath;
  final String? localLyricsPath;
  final bool isFavorite;
  final bool hasLyrics;
  final DateTime? dateAdded;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.coverGradientIndex = 0,
    required this.genre,
    required this.filePath,
    this.localCoverPath,
    this.localLyricsPath,
    this.isFavorite = false,
    this.hasLyrics = true,
    this.dateAdded,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    int? coverGradientIndex,
    String? genre,
    String? filePath,
    String? localCoverPath,
    String? localLyricsPath,
    bool? isFavorite,
    bool? hasLyrics,
    DateTime? dateAdded,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverGradientIndex: coverGradientIndex ?? this.coverGradientIndex,
      genre: genre ?? this.genre,
      filePath: filePath ?? this.filePath,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      localLyricsPath: localLyricsPath ?? this.localLyricsPath,
      isFavorite: isFavorite ?? this.isFavorite,
      hasLyrics: hasLyrics ?? this.hasLyrics,
      dateAdded: dateAdded ?? this.dateAdded,
    );
  }

  factory Track.fromDb(DbTrack db) {
    return Track(
      id: db.id,
      title: db.title,
      artist: db.artist,
      album: db.album,
      duration: Duration(milliseconds: db.durationMs),
      coverGradientIndex: db.id.hashCode.abs() % 6,
      genre: 'Local Audio',
      filePath: db.localAudioPath,
      localCoverPath: db.localCoverPath,
      localLyricsPath: db.localLyricsPath,
      isFavorite: db.isFavorite,
      hasLyrics: db.localLyricsPath != null && db.localLyricsPath!.isNotEmpty,
      dateAdded: db.dateAdded,
    );
  }

  TracksCompanion toCompanion() {
    return TracksCompanion(
      id: Value(id),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      durationMs: Value(duration.inMilliseconds),
      localAudioPath: Value(filePath),
      localCoverPath: Value(localCoverPath),
      localLyricsPath: Value(localLyricsPath),
      isFavorite: Value(isFavorite),
      dateAdded: dateAdded != null ? Value(dateAdded!) : const Value.absent(),
    );
  }

  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

extension DbTrackX on DbTrack {
  Track toDomain() => Track.fromDb(this);
}
