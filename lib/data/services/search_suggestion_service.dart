import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service querying Google/YouTube's public autocomplete endpoint for fast 1-word smart suggestions.
class SearchSuggestionService {
  final Dio _dio;

  SearchSuggestionService([Dio? dio]) : _dio = dio ?? Dio();

  Future<List<String>> fetchSuggestions(
    String query, {
    List<String> localItems = const [],
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final Set<String> results = {};
    final lowerQ = trimmed.toLowerCase();

    // 1. Merge local library track & artist matches first
    for (final item in localItems) {
      if (item.toLowerCase().contains(lowerQ)) {
        results.add(item);
        if (results.length >= 4) break;
      }
    }

    // 2. Fetch live Google / YouTube Indian music suggestions (gl=IN)
    try {
      final encoded = Uri.encodeComponent(trimmed);
      final url =
          'https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&hl=en&gl=IN&q=$encoded';
      final response = await _dio.get<dynamic>(
        url,
        options: Options(
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }

      if (data is List && data.length > 1 && data[1] is List) {
        final suggestionsList = data[1] as List;
        for (final item in suggestionsList) {
          if (item != null) {
            final str = item.toString().trim();
            if (str.isNotEmpty) {
              results.add(str);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SearchSuggestionService] Autocomplete error: $e');
    }

    return results.take(8).toList();
  }
}

final searchSuggestionServiceProvider = Provider<SearchSuggestionService>((ref) {
  return SearchSuggestionService();
});
