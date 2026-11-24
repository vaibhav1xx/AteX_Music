class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final int coverGradientIndex;
  final String genre;
  final String filePath;
  final bool isFavorite;
  final bool hasLyrics;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.coverGradientIndex = 0,
    required this.genre,
    required this.filePath,
    this.isFavorite = false,
    this.hasLyrics = true,
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
    bool? isFavorite,
    bool? hasLyrics,
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
      isFavorite: isFavorite ?? this.isFavorite,
      hasLyrics: hasLyrics ?? this.hasLyrics,
    );
  }

  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
