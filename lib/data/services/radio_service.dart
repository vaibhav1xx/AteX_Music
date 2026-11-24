import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/radio_station.dart';

class RadioService {
  final Dio _dio;

  // Radio Browser API mirror servers
  static const List<String> _baseUrls = [
    'https://de1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
    'https://at1.api.radio-browser.info',
  ];

  RadioService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'User-Agent': 'AteXMusic/1.0',
                  'Accept': 'application/json',
                },
              ),
            );

  Future<List<RadioStation>> _fetchWithFallback(String path, {Map<String, dynamic>? queryParams}) async {
    for (final base in _baseUrls) {
      try {
        final response = await _dio.get(
          '$base$path',
          queryParameters: queryParams,
        );

        if (response.statusCode == 200 && response.data is List) {
          final list = response.data as List;
          return list
              .whereType<Map<String, dynamic>>()
              .map(RadioStation.fromJson)
              .where((s) => s.url.isNotEmpty && s.name.isNotEmpty)
              .toList();
        }
      } catch (e) {
        debugPrint('Radio Browser fetch error on $base: $e');
      }
    }
    return [];
  }

  /// Top voted global live stations
  Future<List<RadioStation>> getTopVotedStations({int limit = 30}) async {
    return _fetchWithFallback('/json/stations/topvote/$limit');
  }

  /// Top stations in India
  Future<List<RadioStation>> getIndiaStations({int limit = 30}) async {
    return _fetchWithFallback('/json/stations/search', queryParams: {
      'countrycode': 'IN',
      'limit': limit,
      'order': 'votes',
      'reverse': true,
      'hidebroken': true,
    });
  }

  /// Stations by Tag (Lo-Fi, Chill, Electronic, Jazz, News, etc.)
  Future<List<RadioStation>> getStationsByTag(String tag, {int limit = 30}) async {
    return _fetchWithFallback('/json/stations/bytag/${Uri.encodeComponent(tag)}', queryParams: {
      'limit': limit,
      'order': 'votes',
      'reverse': true,
      'hidebroken': true,
    });
  }

  /// Search stations by keyword
  Future<List<RadioStation>> searchStations(String query, {int limit = 30}) async {
    if (query.trim().isEmpty) return [];
    return _fetchWithFallback('/json/stations/search', queryParams: {
      'name': query.trim(),
      'limit': limit,
      'order': 'votes',
      'reverse': true,
      'hidebroken': true,
    });
  }
}

final radioServiceProvider = Provider<RadioService>((ref) {
  return RadioService();
});

final topRadioStationsProvider = FutureProvider<List<RadioStation>>((ref) async {
  final service = ref.watch(radioServiceProvider);
  return service.getTopVotedStations(limit: 30);
});

final indiaRadioStationsProvider = FutureProvider<List<RadioStation>>((ref) async {
  final service = ref.watch(radioServiceProvider);
  return service.getIndiaStations(limit: 30);
});

final lofiRadioStationsProvider = FutureProvider<List<RadioStation>>((ref) async {
  final service = ref.watch(radioServiceProvider);
  return service.getStationsByTag('lofi', limit: 30);
});

final chillRadioStationsProvider = FutureProvider<List<RadioStation>>((ref) async {
  final service = ref.watch(radioServiceProvider);
  return service.getStationsByTag('chill', limit: 30);
});

final electronicRadioStationsProvider = FutureProvider<List<RadioStation>>((ref) async {
  final service = ref.watch(radioServiceProvider);
  return service.getStationsByTag('electronic', limit: 30);
});
