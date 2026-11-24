import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';

class AlbumArtView extends StatelessWidget {
  final String? imageUrl;
  final String? localFilePath;
  final double size;
  final double borderRadius;
  final bool showShadow;
  final String? placeholderText;

  const AlbumArtView({
    super.key,
    this.imageUrl,
    this.localFilePath,
    this.size = 54,
    this.borderRadius = 8,
    this.showShadow = false,
    this.placeholderText,
    int? gradientIndex, // kept for legacy optional param
  });

  @override
  Widget build(BuildContext context) {
    Widget imageContent;

    if (imageUrl != null && imageUrl!.startsWith('http')) {
      imageContent = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    } else if (localFilePath != null && File(localFilePath!).existsSync()) {
      imageContent = Image.file(
        File(localFilePath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
      );
    } else {
      imageContent = _buildPlaceholder();
    }

    Widget container = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: imageContent,
      ),
    );

    if (showShadow) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: size * 0.35,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: container,
      );
    }

    return container;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.cardHover,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle concentric vinyl grooves
          CustomPaint(
            size: Size(size, size),
            painter: _VinylGroovePainter(),
          ),
          if (placeholderText != null && placeholderText!.isNotEmpty)
            Text(
              placeholderText!.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Icon(
              LucideIcons.disc,
              size: size * 0.42,
              color: AppColors.textMuted,
            ),
        ],
      ),
    );
  }
}

class _VinylGroovePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withAlpha(8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, size.width * 0.38, paint);
    canvas.drawCircle(center, size.width * 0.26, paint);
    canvas.drawCircle(center, size.width * 0.14, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
