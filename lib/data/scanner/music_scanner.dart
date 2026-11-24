import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'desktop_music_scanner.dart';
import 'mobile_music_scanner.dart';
import 'music_scanner_interface.dart';

export 'music_scanner_interface.dart';

/// Factory providing the platform-appropriate music scanner implementation.
class MusicScannerFactory {
  MusicScannerFactory._();

  static MusicScanner create() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return MobileMusicScanner();
    } else {
      return DesktopMusicScanner();
    }
  }
}

final musicScannerProvider = Provider<MusicScanner>((ref) {
  return MusicScannerFactory.create();
});
