import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Branded geometric monogram for AteX Music.
/// Intertwined 'A' and 'X' with cybernetic lines, electric cyan to deep cobalt gradient.
class AteXMonogram extends StatelessWidget {
  final double size;
  final bool showGlow;

  const AteXMonogram({
    super.key,
    this.size = 36,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showGlow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.electricCyan.withAlpha(70),
                  blurRadius: size * 0.4,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: CustomPaint(
        size: Size(size, size),
        painter: _AteXMonogramPainter(),
      ),
    );
  }
}

class _AteXMonogramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Gradient Shader
    final Rect rect = Rect.fromLTWH(0, 0, w, h);
    final Gradient gradient = const LinearGradient(
      colors: [AppColors.electricCyan, AppColors.deepCobalt],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final Paint linePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw stylized 'A'
    final Path pathA = Path()
      ..moveTo(w * 0.22, h * 0.88)
      ..lineTo(w * 0.50, h * 0.14)
      ..lineTo(w * 0.78, h * 0.88);

    // Crossbar for A connecting to form the X
    final Path crossBar = Path()
      ..moveTo(w * 0.32, h * 0.60)
      ..lineTo(w * 0.68, h * 0.60);

    // Draw stylized dynamic diagonal slash for 'X'
    final Path pathX = Path()
      ..moveTo(w * 0.78, h * 0.25)
      ..lineTo(w * 0.22, h * 0.88);

    canvas.drawPath(pathA, linePaint);
    canvas.drawPath(crossBar, linePaint);
    canvas.drawPath(pathX, linePaint);

    // Small glowing apex point
    final Paint dotPaint = Paint()
      ..color = AppColors.electricCyan
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.50, h * 0.14), w * 0.06, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
