import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart';
import '../models/podcast.dart';

class PodcastService {
  final Dio _dio;

  PodcastService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 12),
                headers: {
                  'User-Agent': 'AteXMusic/1.0',
                  'Accept': 'application/json, application/xml, text/xml',
                },
              ),
            );

  /// Search podcasts via keyless iTunes Search API
  Future<List<Podcast>> searchPodcasts(String term, {int limit = 20}) async {
    if (term.trim().isEmpty) return [];

    try {
      final response = await _dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'media': 'podcast',
          'term': term.trim(),
          'limit': limit,
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        final results = response.data['results'] as List? ?? [];
        return results
            .whereType<Map<String, dynamic>>()
            .map(Podcast.fromItunes)
            .where((p) => p.feedUrl.isNotEmpty && p.title.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('iTunes podcast search error: $e');
    }
    return [];
  }

  /// Get popular curated podcasts for Explore
  Future<List<Podcast>> getPopularPodcasts() async {
    // Curated high quality search terms
    final list = await searchPodcasts('technology audio stories', limit: 20);
    if (list.isEmpty) {
      return searchPodcasts('news music', limit: 20);
    }
    return list;
  }

  /// Fetch and parse episodes from a podcast's RSS feed XML
  Future<List<PodcastEpisode>> fetchEpisodes(String feedUrl, {String podcastTitle = 'Podcast', String? podcastArtwork}) async {
    if (feedUrl.trim().isEmpty) return [];

    try {
      final response = await _dio.get(
        feedUrl.trim(),
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        final xmlString = response.data.toString();
        final document = XmlDocument.parse(xmlString);

        final items = document.findAllElements('item');
        final episodes = <PodcastEpisode>[];

        for (final item in items) {
          final title = item.findElements('title').firstOrNull?.innerText.trim() ?? 'Untitled Episode';
          
          // Audio URL from enclosure
          final enclosure = item.findElements('enclosure').firstOrNull;
          final audioUrl = enclosure?.getAttribute('url') ?? '';
          if (audioUrl.isEmpty) continue;

          // Description or itunes:summary
          String desc = item.findElements('itunes:summary').firstOrNull?.innerText.trim() ?? '';
          if (desc.isEmpty) {
            desc = item.findElements('description').firstOrNull?.innerText.trim() ?? '';
          }
          // Strip HTML tags for clean display
          desc = _stripHtml(desc);

          // Artwork from itunes:image or podcast
          String? artUrl = item.findElements('itunes:image').firstOrNull?.getAttribute('href');
          artUrl ??= podcastArtwork;

          // Duration
          final durStr = item.findElements('itunes:duration').firstOrNull?.innerText.trim() ?? '';
          final duration = _parseDuration(durStr);

          // PubDate
          final pubDateStr = item.findElements('pubDate').firstOrNull?.innerText.trim();
          DateTime? pubDate;
          if (pubDateStr != null) {
            try {
              pubDate = DateTime.tryParse(pubDateStr);
            } catch (_) {}
          }

          final guid = item.findElements('guid').firstOrNull?.innerText.trim() ?? audioUrl;

          episodes.add(
            PodcastEpisode(
              id: guid,
              podcastTitle: podcastTitle,
              title: title,
              description: desc,
              audioUrl: audioUrl,
              artworkUrl: artUrl,
              duration: duration,
              pubDate: pubDate,
            ),
          );
        }

        return episodes;
      }
    } catch (e) {
      debugPrint('Podcast RSS parse error for $feedUrl: $e');
    }
    return [];
  }

  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#39;', "'").trim();
  }

  static Duration _parseDuration(String raw) {
    if (raw.isEmpty) return Duration.zero;

    // Check if raw is plain seconds (e.g. "3600")
    final plainSeconds = int.tryParse(raw);
    if (plainSeconds != null) {
      return Duration(seconds: plainSeconds);
    }

    // Check HH:MM:SS or MM:SS
    final parts = raw.split(':').map((s) => int.tryParse(s.trim()) ?? 0).toList();
    if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } else if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    }
    return Duration.zero;
  }
}

final podcastServiceProvider = Provider<PodcastService>((ref) {
  return PodcastService();
});

final popularPodcastsProvider = FutureProvider<List<Podcast>>((ref) async {
  final service = ref.watch(podcastServiceProvider);
  return service.getPopularPodcasts();
});
