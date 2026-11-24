import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/app_toast.dart';

class ShareCardService {
  ShareCardService._();

  /// Captures a [GlobalKey] boundary, renders to PNG, saves locally, and shares via OS share sheet.
  static Future<String?> captureAndShare(
    BuildContext context,
    GlobalKey boundaryKey, {
    required String filePrefix,
    String? subject,
    String? text,
  }) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (context.mounted) {
          AppToast.show(context, 'Unable to capture card image');
        }
        return null;
      }

      // Render at 3x pixel ratio for crisp high-resolution cards
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (context.mounted) {
          AppToast.show(context, 'Failed to encode PNG image');
        }
        return null;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final fileName = '${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(p.join(tempDir.path, fileName));
      await file.writeAsBytes(pngBytes, flush: true);

      // On desktop, also save a copy to the user's Documents/AteX Music folder if available
      String savedLocation = file.path;
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        try {
          final docsDir = await getApplicationDocumentsDirectory();
          final atexFolder = Directory(p.join(docsDir.path, 'AteX Music', 'Cards'));
          if (!atexFolder.existsSync()) {
            atexFolder.createSync(recursive: true);
          }
          final permanentFile = File(p.join(atexFolder.path, fileName));
          await permanentFile.writeAsBytes(pngBytes, flush: true);
          savedLocation = permanentFile.path;
        } catch (_) {}
      }

      // Trigger OS Share sheet
      final xFile = XFile(file.path, mimeType: 'image/png', name: fileName);
      final shareResult = await Share.shareXFiles(
        [xFile],
        text: text ?? 'Shared from AteX Music — 100% Offline Audio',
        subject: subject ?? 'AteX Music Card',
      );

      if (context.mounted) {
        if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
          AppToast.show(context, 'Card saved: $fileName');
        } else if (shareResult.status == ShareResultStatus.success) {
          AppToast.show(context, 'Shared successfully!');
        }
      }

      return savedLocation;
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Share failed: $e');
      }
      return null;
    }
  }
}
