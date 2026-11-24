import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';

class ChartAlbum {
  final String id;
  final String name;
  final String artist;
  final String artworkUrl;
  final String releaseDate;

  const ChartAlbum({
    required this.id,
    required this.name,
    required this.artist,
    required this.artworkUrl,
    required this.releaseDate,
  });
}

class MusicChartsService {
  final Dio _dio;

  MusicChartsService([Dio? dio]) : _dio = dio ?? Dio();

  String _upscaleArtwork(String url, [int size = 600]) {
    return url.replaceAll(RegExp(r'\d+x\d+bb'), '${size}x${size}bb');
  }

  Future<List<Track>> fetchTrendingSongs({String country = 'us', int limit = 20}) async {
    try {
      final url = 'https://rss.marketingtools.apple.com/api/v2/$country/music/most-played/$limit/songs.json';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['feed']?['results'] as List<dynamic>? ?? [];
        return results.map((item) {
          final rawArt = item['artworkUrl100'] as String? ?? '';
          final highResArt = _upscaleArtwork(rawArt);
          final id = item['id'] as String? ?? UniqueKey().toString();
          final title = item['name'] as String? ?? 'Trending Track';
          final artist = item['artistName'] as String? ?? 'Artist';
          final genre = (item['genres'] as List<dynamic>?)?.isNotEmpty == true
              ? item['genres'][0]['name'] as String? ?? 'Music'
              : 'Pop';
          final url = item['url'] as String? ?? '';

          return Track(
            id: 'chart_$id',
            title: title,
            artist: artist,
            album: 'Trending Charts',
            duration: const Duration(minutes: 3, seconds: 30),
            coverGradientIndex: id.hashCode.abs() % 6,
            genre: genre,
            filePath: url,
            localCoverPath: highResArt,
            isFavorite: false,
            hasLyrics: false,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching trending songs: $e');
    }
    return [];
  }

  Future<List<ChartAlbum>> fetchTrendingAlbums({String country = 'us', int limit = 20}) async {
    try {
      final url = 'https://rss.marketingtools.apple.com/api/v2/$country/music/most-played/$limit/albums.json';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['feed']?['results'] as List<dynamic>? ?? [];
        return results.map((item) {
          final rawArt = item['artworkUrl100'] as String? ?? '';
          final highResArt = _upscaleArtwork(rawArt);
          return ChartAlbum(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? 'Album',
            artist: item['artistName'] as String? ?? 'Artist',
            artworkUrl: highResArt,
            releaseDate: item['releaseDate'] as String? ?? '',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching trending albums: $e');
    }
    return [];
  }
}

final musicChartsServiceProvider = Provider<MusicChartsService>((ref) {
  return MusicChartsService();
});

final trendingSongsProvider = FutureProvider<List<Track>>((ref) async {
  final service = ref.watch(musicChartsServiceProvider);
  return service.fetchTrendingSongs();
});

final trendingAlbumsProvider = FutureProvider<List<ChartAlbum>>((ref) async {
  final service = ref.watch(musicChartsServiceProvider);
  return service.fetchTrendingAlbums();
});
