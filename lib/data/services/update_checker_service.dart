import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String releaseNotes;
  final String? publishedAt;

  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.releaseNotes,
    this.publishedAt,
  });

  factory UpdateInfo.noUpdate(String currentVersion) {
    return UpdateInfo(
      hasUpdate: false,
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      releaseUrl: 'https://github.com/vaibhav1xx/AteX_Music/releases',
      releaseNotes: '',
    );
  }
}

class UpdateCheckerService {
  final Dio _dio;

  UpdateCheckerService([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 6),
                headers: {
                  'User-Agent': 'AteXMusic/1.0',
                  'Accept': 'application/vnd.github.v3+json',
                },
              ),
            );

  static const String _releasesApi =
      'https://api.github.com/repos/vaibhav1xx/AteX_Music/releases/latest';

  /// Compare two semver strings like "1.0.1" and "1.0.0"
  static bool isNewerVersion(String latest, String current) {
    final cleanLatest = latest.replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final cleanCurrent = current.replaceFirst(RegExp(r'^[vV]'), '').split('+').first;

    final latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (latestParts.length < 3) {
      latestParts.add(0);
    }
    while (currentParts.length < 3) {
      currentParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  Future<UpdateInfo> checkForUpdate() async {
    String currentVersion = '1.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
    } catch (_) {
      // Fallback if package_info_plus fails on headless test
    }

    try {
      final response = await _dio.get(_releasesApi);
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String?) ?? '';
        final htmlUrl = (data['html_url'] as String?) ??
            'https://github.com/vaibhav1xx/AteX_Music/releases';
        final body = (data['body'] as String?) ?? '';
        final publishedAt = data['published_at'] as String?;

        final hasNewer = isNewerVersion(tagName, currentVersion);

        return UpdateInfo(
          hasUpdate: hasNewer,
          currentVersion: currentVersion,
          latestVersion: tagName.replaceFirst(RegExp(r'^[vV]'), ''),
          releaseUrl: htmlUrl,
          releaseNotes: body,
          publishedAt: publishedAt,
        );
      }
    } catch (_) {
      // Offline, rate limited, or 404: silently ignore
    }

    return UpdateInfo.noUpdate(currentVersion);
  }

  static Future<bool> launchUrlExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}

final updateCheckerServiceProvider = Provider<UpdateCheckerService>((ref) {
  return UpdateCheckerService();
});

final appUpdateFutureProvider = FutureProvider<UpdateInfo>((ref) async {
  final service = ref.watch(updateCheckerServiceProvider);
  return await service.checkForUpdate();
});
