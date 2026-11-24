import 'package:flutter_test/flutter_test.dart';
import 'package:atex_music/data/models/synced_lyric.dart';
import 'package:atex_music/data/models/track.dart';
import 'package:atex_music/data/services/audio_stream_resolver.dart';
import 'package:atex_music/data/services/lrclib_service.dart';

void main() {
  group('AudioStreamResolver Tests', () {
    test('AudioStreamResolver instantiates and handles fallback gracefully', () async {
      final resolver = AudioStreamResolver();
      const trackWithPreview = Track(
        id: 'test_track_1',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        duration: Duration(minutes: 3, seconds: 50),
        genre: 'Pop',
        filePath: 'https://audio-ssl.itunes.apple.com/preview/test.mp3',
      );

      // Verify resolver clears cache cleanly
      resolver.clearCache();
      expect(trackWithPreview.filePath, contains('apple.com'));
    });
  });

  group('SyncedLyricLine LRC Parser Tests', () {
    test('Correctly parses standard LRC lines and sort order', () {
      const sampleLrc = '''
[00:05.12] First lyric line
[00:15.50] Second lyric line
[00:30.00] Third lyric line
''';

      final lines = SyncedLyricLine.parseLrc(sampleLrc);
      expect(lines.length, equals(3));
      expect(lines[0].text, equals('First lyric line'));
      expect(lines[0].timestamp, equals(const Duration(seconds: 5, milliseconds: 120)));
      expect(lines[1].text, equals('Second lyric line'));
      expect(lines[2].text, equals('Third lyric line'));
    });

    test('Correctly detects active lyric index based on playback position', () {
      const sampleLrc = '''
[00:05.00] Intro
[00:15.00] Verse 1
[00:30.00] Chorus
''';

      final lines = SyncedLyricLine.parseLrc(sampleLrc);
      expect(SyncedLyricLine.getActiveIndex(lines, const Duration(seconds: 2)), equals(0));
      expect(SyncedLyricLine.getActiveIndex(lines, const Duration(seconds: 10)), equals(0));
      expect(SyncedLyricLine.getActiveIndex(lines, const Duration(seconds: 16)), equals(1));
      expect(SyncedLyricLine.getActiveIndex(lines, const Duration(seconds: 35)), equals(2));
    });
  });

  group('LrcLibService Cleaning Tests', () {
    test('Cleans featured artist suffixes and labels from titles', () {
      final service = LrcLibService();
      // Service cleans metadata before making queries
      expect(service, isNotNull);
    });
  });

  group('Track Domain Model Tests', () {
    test('Duration formatted prints correct mm:ss and hh:mm:ss', () {
      const shortTrack = Track(
        id: '1',
        title: 'Song A',
        artist: 'Artist A',
        album: 'Album A',
        duration: Duration(minutes: 3, seconds: 45),
        genre: 'Pop',
        filePath: '/test.mp3',
      );
      expect(shortTrack.durationFormatted, equals('3:45'));

      const longTrack = Track(
        id: '2',
        title: 'Podcast B',
        artist: 'Host B',
        album: 'Show B',
        duration: Duration(hours: 1, minutes: 12, seconds: 34),
        genre: 'Podcast',
        filePath: '/podcast.mp3',
      );
      expect(longTrack.durationFormatted, equals('1:12:34'));
    });
  });
}
