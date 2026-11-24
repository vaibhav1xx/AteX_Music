import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LrcLibService {
  final Dio _dio;

  LrcLibService([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: {
                  'User-Agent': 'AteXMusic/1.0',
                  'Accept': 'application/json',
                },
              ),
            );

  /// Fetches synchronized LRC lyrics from LRCLIB.
  /// First tries the exact match endpoint, then falls back to full-text search.
  Future<String?> fetchLyrics({
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    final cleanTitle = _cleanTitle(title);
    final cleanArtist = _cleanArtist(artist);

    // 1. Exact Match via /api/get
    try {
      final queryParams = <String, dynamic>{
        'track_name': cleanTitle,
        'artist_name': cleanArtist,
      };
      if (album != null && album.isNotEmpty && !album.toLowerCase().contains('single')) {
        queryParams['album_name'] = album;
      }
      if (duration != null && duration.inSeconds > 0) {
        queryParams['duration'] = duration.inSeconds;
      }

      final response = await _dio.get(
        'https://lrclib.net/api/get',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final syncedLyrics = data['syncedLyrics'] as String?;
        if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
          debugPrint('[LrcLibService] Found exact synced lyrics for "$title"');
          return syncedLyrics;
        }
        final plainLyrics = data['plainLyrics'] as String?;
        if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
          return plainLyrics;
        }
      }
    } catch (_) {
      // Fall through to search endpoint
    }

    // 2. Search Fallback via /api/search
    try {
      final q = '$cleanArtist $cleanTitle'.trim();
      final response = await _dio.get(
        'https://lrclib.net/api/search',
        queryParameters: {'q': q},
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        for (final item in list) {
          if (item is Map) {
            final synced = item['syncedLyrics'] as String?;
            if (synced != null && synced.trim().isNotEmpty) {
              debugPrint('[LrcLibService] Found search synced lyrics for "$title"');
              return synced;
            }
          }
        }

        // Plain lyrics fallback if no synced version is available
        for (final item in list) {
          if (item is Map) {
            final plain = item['plainLyrics'] as String?;
            if (plain != null && plain.trim().isNotEmpty) {
              return plain;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LrcLibService] Lyrics fetch error: $e');
    }

    return null;
  }

  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\(.*?(feat|ft|official|audio|remaster).*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .trim();
  }

  String _cleanArtist(String artist) {
    return artist
        .replaceAll(RegExp(r'(feat\.|ft\.).*', caseSensitive: false), '')
        .trim();
  }
}

final lrcLibServiceProvider = Provider<LrcLibService>((ref) {
  return LrcLibService();
});
