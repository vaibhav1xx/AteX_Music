import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/track.dart';

class _StreamCacheEntry {
  final String streamUrl;
  final DateTime expiresAt;
  final Duration? duration;

  _StreamCacheEntry({
    required this.streamUrl,
    required this.expiresAt,
    this.duration,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Real full-length audio stream resolver using YouTube Explode.
/// Resolves high-bitrate Opus / M4A streams for any track lacking a local audio file,
/// with an in-memory 2-hour TTL cache and graceful iTunes preview fallback.
class AudioStreamResolver {
  final YoutubeExplode _yt;
  final Map<String, _StreamCacheEntry> _cache = {};
  static const Duration _cacheTtl = Duration(hours: 2);

  AudioStreamResolver([YoutubeExplode? yt]) : _yt = yt ?? YoutubeExplode();

  String _buildCacheKey(Track track) {
    if (track.id.isNotEmpty && !track.id.startsWith('mock_')) {
      return track.id;
    }
    return '${track.artist.trim().toLowerCase()} - ${track.title.trim().toLowerCase()}';
  }

  /// Resolves the highest bitrate full-length audio stream URL for [track].
  /// Returns a direct HTTP stream URL, or falls back to [track.filePath] if resolution fails.
  Future<String?> resolveStreamUrl(Track track) async {
    // 1. If track already points to a verified local audio file, use it directly
    if (track.filePath.isNotEmpty && File(track.filePath).existsSync()) {
      return track.filePath;
    }

    final cacheKey = _buildCacheKey(track);

    // 2. Check 2-hour in-memory cache for instant replay
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('[AudioStreamResolver] Cache hit for "$cacheKey"');
      return cached.streamUrl;
    }

    // 3. Search and resolve full-length audio stream
    try {
      VideoId? targetVideoId;
      Duration? targetDuration;

      if (track.id.startsWith('yt:')) {
        final rawId = track.id.substring(3);
        try {
          targetVideoId = VideoId(rawId);
        } catch (_) {}
      }

      if (targetVideoId == null) {
        final query = '${track.title} ${track.artist} official audio'.trim();
        debugPrint('[AudioStreamResolver] Searching: "$query"');

        final searchResults = await _yt.search
            .search(query)
            .timeout(const Duration(seconds: 8));

        final videos = searchResults.whereType<Video>().toList();
        if (videos.isEmpty) {
          debugPrint('[AudioStreamResolver] No video matches for "$query", falling back');
          return _fallbackUrl(track);
        }

        targetVideoId = videos.first.id;
        targetDuration = videos.first.duration;
      }

      debugPrint('[AudioStreamResolver] Fetching manifest for video ID: $targetVideoId');
      // Use default client set for reliable playback without 403 errors
      final manifest = await _yt.videos.streams
          .getManifest(targetVideoId)
          .timeout(const Duration(seconds: 8));

      // Extract highest bitrate audioOnly stream (M4A or Opus)
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isNotEmpty) {
        final bestAudio = audioStreams.withHighestBitrate();
        final streamUrl = bestAudio.url.toString();

        // Cache resolved stream URL for 2 hours
        _cache[cacheKey] = _StreamCacheEntry(
          streamUrl: streamUrl,
          expiresAt: DateTime.now().add(_cacheTtl),
          duration: targetDuration,
        );

        debugPrint('[AudioStreamResolver] Resolved "${track.title}" -> ${(bestAudio.bitrate.bitsPerSecond / 1000).round()} kbps (${bestAudio.container.name})');
        return streamUrl;
      }

      // Muxed stream fallback if audio-only is missing
      if (manifest.muxed.isNotEmpty) {
        final bestMuxed = manifest.muxed.withHighestBitrate();
        final streamUrl = bestMuxed.url.toString();
        _cache[cacheKey] = _StreamCacheEntry(
          streamUrl: streamUrl,
          expiresAt: DateTime.now().add(_cacheTtl),
          duration: targetDuration,
        );
        return streamUrl;
      }
    } catch (e) {
      debugPrint('[AudioStreamResolver] Stream resolution error for "${track.title}": $e');
    }

    // 4. Graceful fallback to existing preview URL
    return _fallbackUrl(track);
  }

  /// Resolves the stream and returns an updated [Track] domain object with the resolved stream URL.
  Future<Track> resolveTrack(Track track) async {
    final streamUrl = await resolveStreamUrl(track);
    if (streamUrl != null && streamUrl.isNotEmpty) {
      final cacheKey = _buildCacheKey(track);
      final cached = _cache[cacheKey];
      final newDuration = (cached?.duration != null && cached!.duration! > Duration.zero)
          ? cached.duration!
          : track.duration;

      return track.copyWith(
        filePath: streamUrl,
        duration: newDuration,
      );
    }
    return track;
  }

  String? _fallbackUrl(Track track) {
    if (track.filePath.isNotEmpty && track.filePath.startsWith('http')) {
      debugPrint('[AudioStreamResolver] Falling back to preview URL for "${track.title}"');
      return track.filePath;
    }
    return null;
  }

  void clearCache() {
    _cache.clear();
  }

  void dispose() {
    _cache.clear();
    _yt.close();
  }
}

final audioStreamResolverProvider = Provider<AudioStreamResolver>((ref) {
  final resolver = AudioStreamResolver();
  ref.onDispose(() => resolver.dispose());
  return resolver;
});
