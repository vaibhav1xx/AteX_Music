import 'package:flutter_test/flutter_test.dart';
import 'package:atex_music/data/models/track.dart';
import 'package:atex_music/data/models/radio_station.dart';
import 'package:atex_music/data/models/podcast.dart';

void main() {
  group('Radio Station & Audio Conversion Tests', () {
    test('RadioStation parses JSON and converts to playable Track', () {
      final json = {
        'stationuuid': 'radio_test_uuid_123',
        'name': 'Chillhop Lofi Live',
        'url': 'https://stream.lofi.example/live.mp3',
        'url_resolved': 'https://stream.lofi.example/live.mp3',
        'favicon': 'https://stream.lofi.example/art.png',
        'tags': 'lofi,chill,beats',
        'country': 'Japan',
        'bitrate': 128,
        'codec': 'MP3',
        'votes': 950,
      };

      final station = RadioStation.fromJson(json);
      expect(station.name, 'Chillhop Lofi Live');
      expect(station.country, 'Japan');
      expect(station.bitrate, 128);

      final track = station.toTrack();
      expect(track.id, 'radio_radio_test_uuid_123');
      expect(track.title, 'Chillhop Lofi Live');
      expect(track.genre, 'Radio');
      expect(track.filePath, 'https://stream.lofi.example/live.mp3');
      expect(track.localCoverPath, 'https://stream.lofi.example/art.png');
    });
  });

  group('Podcast Model & Duration Parsing Tests', () {
    test('Podcast parses iTunes payload and Episode converts to Track', () {
      final itunesJson = {
        'collectionId': 98765,
        'collectionName': 'Syntax Audio & Tech',
        'artistName': 'Tech Hosts',
        'artworkUrl600': 'https://cdn.example/syntax.jpg',
        'feedUrl': 'https://feed.syntax.example/rss',
        'primaryGenreName': 'Technology',
        'trackCount': 420,
      };

      final podcast = Podcast.fromItunes(itunesJson);
      expect(podcast.id, '98765');
      expect(podcast.title, 'Syntax Audio & Tech');
      expect(podcast.primaryGenre, 'Technology');

      const episode = PodcastEpisode(
        id: 'guid_ep_101',
        podcastTitle: 'Syntax Audio & Tech',
        title: 'Episode 101: Flutter & Audio Engines',
        description: 'Deep dive into offline audio architectures and hardware DACs.',
        audioUrl: 'https://media.syntax.example/ep101.mp3',
        artworkUrl: 'https://cdn.example/syntax.jpg',
        duration: Duration(hours: 1, minutes: 12, seconds: 34),
      );

      expect(episode.durationFormatted, '1h 12m');

      final epTrack = episode.toTrack();
      expect(epTrack.title, 'Episode 101: Flutter & Audio Engines');
      expect(epTrack.artist, 'Syntax Audio & Tech');
      expect(epTrack.genre, 'Podcast');
      expect(epTrack.duration, const Duration(hours: 1, minutes: 12, seconds: 34));
    });
  });

  group('Track Domain Model with Schema v2 Extensions', () {
    test('Track includes playCount and lastPlayed fields', () {
      final now = DateTime.now();
      final track = Track(
        id: 'track_test_1',
        title: 'Lossless Echoes',
        artist: 'Obsidian Artist',
        album: 'Cyber Studio',
        duration: const Duration(minutes: 3, seconds: 45),
        genre: 'Electronic',
        filePath: 'C:/Audio/track.flac',
        playCount: 15,
        lastPlayedAt: now,
      );

      expect(track.playCount, 15);
      expect(track.lastPlayed, now);
      expect(track.lastPlayedAt, now);
      expect(track.durationFormatted, '03:45');

      final companion = track.toCompanion();
      expect(companion.id.value, 'track_test_1');
      expect(companion.playCount.value, 15);
      expect(companion.lastPlayedAt.value, now);
    });
  });
}
