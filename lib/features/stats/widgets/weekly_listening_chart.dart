import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/database/app_database.dart';

class WeeklyListeningChart extends StatelessWidget {
  final List<DailyListeningStat> stats;
  final Color? accentColor;
  final double height;

  const WeeklyListeningChart({
    super.key,
    required this.stats,
    this.accentColor,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? AppColors.accent;

    if (stats.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        child: const Text(
          'No activity recorded yet',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    final maxDurationMs = stats.map((s) => s.totalDurationMs).fold<int>(0, math.max);
    final maxMins = (maxDurationMs / (1000 * 60)).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Weekly Listening Activity',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            if (maxMins > 0)
              Text(
                'Peak: ${maxMins}m',
                style: TextStyle(
                  color: effectiveAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _WeeklyListeningBarChartPainter(
              stats: stats,
              accentColor: effectiveAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyListeningBarChartPainter extends CustomPainter {
  final List<DailyListeningStat> stats;
  final Color accentColor;

  _WeeklyListeningBarChartPainter({
    required this.stats,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stats.isEmpty) return;

    final bottomLabelHeight = 24.0;
    final chartHeight = size.height - bottomLabelHeight;
    final maxDuration = stats.map((s) => s.totalDurationMs).fold<int>(0, math.max);
    final effectiveMax = maxDuration > 0 ? maxDuration.toDouble() : 1.0;

    final barCount = stats.length;
    final totalSpacing = size.width * 0.45;
    final slotWidth = size.width / barCount;
    final barWidth = math.min(28.0, (size.width - totalSpacing) / barCount);

    // Background horizontal baseline
    final linePaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      linePaint,
    );

    // Mid guide line
    final dashPaint = Paint()
      ..color = Colors.white.withAlpha(8)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, chartHeight / 2),
      Offset(size.width, chartHeight / 2),
      dashPaint,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < barCount; i++) {
      final stat = stats[i];
      final centerX = (i * slotWidth) + (slotWidth / 2);
      final ratio = (stat.totalDurationMs / effectiveMax).clamp(0.0, 1.0);
      final barHeight = math.max(4.0, ratio * (chartHeight - 16.0));
      final topY = chartHeight - barHeight;

      final isPeak = stat.totalDurationMs == maxDuration && maxDuration > 0;
      final rect = Rect.fromCenter(
        center: Offset(centerX, topY + (barHeight / 2)),
        width: barWidth,
        height: barHeight,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

      // Bar fill gradient
      final fillGradient = LinearGradient(
        colors: [
          isPeak ? accentColor : accentColor.withAlpha(180),
          isPeak ? accentColor.withAlpha(90) : accentColor.withAlpha(30),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

      final barPaint = Paint()
        ..shader = fillGradient.createShader(rect)
        ..style = PaintingStyle.fill;

      // Glow effect for active bars
      if (ratio > 0.1) {
        final glowPaint = Paint()
          ..color = accentColor.withAlpha(isPeak ? 50 : 25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawRRect(rrect, glowPaint);
      }

      canvas.drawRRect(rrect, barPaint);

      // Top highlight dot / cap on peak bar
      if (isPeak) {
        final capPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(centerX, topY + 3), 2.5, capPaint);
      }

      // Value label on top if height permits
      if (barHeight > 30 && stat.totalDurationMs > 0) {
        final mins = (stat.totalDurationMs / (1000 * 60)).round();
        textPainter.text = TextSpan(
          text: '${mins}m',
          style: TextStyle(
            color: Colors.white.withAlpha(190),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(centerX - (textPainter.width / 2), topY - 14),
        );
      }

      // Day label below
      textPainter.text = TextSpan(
        text: stat.dayLabel,
        style: TextStyle(
          color: isPeak ? accentColor : AppColors.textMuted,
          fontSize: 11,
          fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(centerX - (textPainter.width / 2), chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyListeningBarChartPainter oldDelegate) {
    return oldDelegate.stats != stats || oldDelegate.accentColor != accentColor;
  }
}
