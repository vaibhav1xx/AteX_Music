import '../database/app_database.dart';

class ScanResult {
  final int scannedCount;
  final int addedCount;
  final String statusMessage;
  final bool success;

  const ScanResult({
    required this.scannedCount,
    required this.addedCount,
    required this.statusMessage,
    this.success = true,
  });
}

abstract class MusicScanner {
  /// Request platform-specific permissions
  Future<bool> requestPermissions();

  /// Scan storage / directories and persist found tracks into [AppDatabase]
  Future<ScanResult> scanAndImport(AppDatabase database, {String? targetDirectory});
}
