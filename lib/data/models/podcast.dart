import '../models/track.dart';

class Podcast {
  final String id;
  final String title;
  final String artist;
  final String? artworkUrl;
  final String feedUrl;
  final String? primaryGenre;
  final int trackCount;

  const Podcast({
    required this.id,
    required this.title,
    required this.artist,
    this.artworkUrl,
    required this.feedUrl,
    this.primaryGenre,
    this.trackCount = 0,
  });

  factory Podcast.fromItunes(Map<String, dynamic> json) {
    return Podcast(
      id: (json['collectionId'] ?? json['trackId'] ?? '').toString(),
      title: (json['collectionName'] ?? json['trackName'] ?? 'Untitled Podcast') as String,
      artist: (json['artistName'] ?? 'Unknown Creator') as String,
      artworkUrl: (json['artworkUrl600'] ?? json['artworkUrl100']) as String?,
      feedUrl: (json['feedUrl'] ?? '') as String,
      primaryGenre: json['primaryGenreName'] as String?,
      trackCount: json['trackCount'] as int? ?? 0,
    );
  }
}

class PodcastEpisode {
  final String id;
  final String podcastTitle;
  final String title;
  final String description;
  final String audioUrl;
  final String? artworkUrl;
  final Duration duration;
  final DateTime? pubDate;

  const PodcastEpisode({
    required this.id,
    required this.podcastTitle,
    required this.title,
    required this.description,
    required this.audioUrl,
    this.artworkUrl,
    required this.duration,
    this.pubDate,
  });

  Track toTrack() {
    return Track(
      id: 'ep_${id.hashCode.abs()}',
      title: title,
      artist: podcastTitle,
      album: 'Podcast',
      duration: duration,
      coverGradientIndex: id.hashCode.abs() % 6,
      genre: 'Podcast',
      filePath: audioUrl,
      localCoverPath: artworkUrl,
    );
  }

  String get durationFormatted {
    if (duration == Duration.zero) return '--:--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
