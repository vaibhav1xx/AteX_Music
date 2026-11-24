import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';

class ITunesSearchService {
  final Dio _dio;

  ITunesSearchService([Dio? dio]) : _dio = dio ?? Dio();

  String _upscaleArtwork(String? url, [int size = 600]) {
    if (url == null || url.isEmpty) return '';
    return url.replaceAll(RegExp(r'\d+x\d+bb'), '${size}x${size}bb');
  }

  Future<List<Track>> search(String query, {int limit = 20, String country = 'IN'}) async {
    if (query.trim().isEmpty) return [];

    try {
      final encoded = Uri.encodeComponent(query.trim());
      final url = 'https://itunes.apple.com/search?term=$encoded&country=$country&media=music&entity=song&limit=$limit';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data is Map ? response.data : null;
        final results = rawData?['results'] as List<dynamic>? ?? [];

        return results.map((item) {
          final trackId = item['trackId']?.toString() ?? UniqueKey().toString();
          final title = item['trackName'] as String? ?? 'Unknown Title';
          final artist = item['artistName'] as String? ?? 'Unknown Artist';
          final album = item['collectionName'] as String? ?? 'Single';
          final previewUrl = item['previewUrl'] as String? ?? '';
          final artwork100 = item['artworkUrl100'] as String? ?? '';
          final durationMs = item['trackTimeMillis'] as int? ?? 180000;
          final genre = item['primaryGenreName'] as String? ?? 'Music';

          return Track(
            id: 'itunes_$trackId',
            title: title,
            artist: artist,
            album: album,
            duration: Duration(milliseconds: durationMs),
            coverGradientIndex: trackId.hashCode.abs() % 6,
            genre: genre,
            filePath: previewUrl,
            localCoverPath: _upscaleArtwork(artwork100, 600),
            isFavorite: false,
            hasLyrics: true,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('iTunes search error: $e');
    }
    return [];
  }
}

final iTunesSearchServiceProvider = Provider<ITunesSearchService>((ref) {
  return ITunesSearchService();
});
