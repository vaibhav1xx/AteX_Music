import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/models/track.dart';

/// Smooth, lightweight CustomPainter reactive frequency-bar & glowing circular wave visualizer
class AudioVisualizerView extends StatefulWidget {
  final bool isPlaying;
  final Duration position;
  final Color accentColor;
  final Track track;
  final double size;

  const AudioVisualizerView({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.accentColor,
    required this.track,
    this.size = 320,
  });

  @override
  State<AudioVisualizerView> createState() => _AudioVisualizerViewState();
}

class _AudioVisualizerViewState extends State<AudioVisualizerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    if (widget.isPlaying) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AudioVisualizerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_animController.isAnimating) {
      _animController.repeat();
    } else if (!widget.isPlaying && _animController.isAnimating) {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final animValue = _animController.value;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Reactive Glowing Circular Pulse Waves & Ambient Aura
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _CircularWaveVisualizerPainter(
                  animValue: animValue,
                  isPlaying: widget.isPlaying,
                  accentColor: widget.accentColor,
                  trackSeed: widget.track.title.hashCode.abs(),
                ),
              ),

              // 2. Center Circular Album Artwork with Subtle Border Glow
              Container(
                width: widget.size * 0.44,
                height: widget.size * 0.44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.accentColor.withAlpha(widget.isPlaying ? 160 : 70),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withAlpha(widget.isPlaying ? 90 : 30),
                      blurRadius: widget.isPlaying ? 28 : 12,
                      spreadRadius: widget.isPlaying ? 3 : 0,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: widget.track.localCoverPath != null &&
                          File(widget.track.localCoverPath!).existsSync()
                      ? Image.file(
                          File(widget.track.localCoverPath!),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: const Color(0xFF16161B),
                          child: Center(
                            child: Icon(
                              Icons.music_note_rounded,
                              size: widget.size * 0.18,
                              color: widget.accentColor,
                            ),
                          ),
                        ),
                ),
              ),

              // 3. Lower Frequency Spectrum Bars Overlay
              Positioned(
                bottom: 8,
                left: 16,
                right: 16,
                height: widget.size * 0.28,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _FrequencyBarsVisualizerPainter(
                    animValue: animValue,
                    isPlaying: widget.isPlaying,
                    accentColor: widget.accentColor,
                    trackSeed: widget.track.title.hashCode.abs(),
                    positionSeconds: widget.position.inSeconds,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Circular pulsating wave painter surrounding the cover art
class _CircularWaveVisualizerPainter extends CustomPainter {
  final double animValue;
  final bool isPlaying;
  final Color accentColor;
  final int trackSeed;

  _CircularWaveVisualizerPainter({
    required this.animValue,
    required this.isPlaying,
    required this.accentColor,
    required this.trackSeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final innerRadius = size.width * 0.24;

    final ringsCount = 3;
    for (int i = 0; i < ringsCount; i++) {
      final ringProgress = (animValue + (i / ringsCount)) % 1.0;
      final radius = innerRadius + (ringProgress * (maxRadius - innerRadius));
      final opacity = isPlaying
          ? (1.0 - ringProgress).clamp(0.0, 1.0) * 0.45
          : 0.08;

      final wavePaint = Paint()
        ..color = accentColor.withAlpha((opacity * 255).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = isPlaying ? (2.5 * (1.0 - (ringProgress * 0.5))) : 1.0;

      canvas.drawCircle(center, radius, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularWaveVisualizerPainter oldDelegate) {
    return oldDelegate.animValue != animValue ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.accentColor != accentColor;
  }
}

/// Pure Flutter 32-band reactive frequency spectrum bars painter
class _FrequencyBarsVisualizerPainter extends CustomPainter {
  final double animValue;
  final bool isPlaying;
  final Color accentColor;
  final int trackSeed;
  final int positionSeconds;

  _FrequencyBarsVisualizerPainter({
    required this.animValue,
    required this.isPlaying,
    required this.accentColor,
    required this.trackSeed,
    required this.positionSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 30;
    final barSpacing = size.width / barCount;
    final barWidth = math.max(2.5, barSpacing * 0.55);
    final maxHeight = size.height;

    for (int i = 0; i < barCount; i++) {
      final x = (i * barSpacing) + (barSpacing / 2);

      // Multi-frequency synthesis: bass (low indices) + mids + treble
      double harmonic1 = math.sin((animValue * 2 * math.pi * 2.0) + (i * 0.35) + (trackSeed % 7));
      double harmonic2 = math.cos((animValue * 2 * math.pi * 3.5) - (i * 0.25) + positionSeconds);
      double harmonic3 = math.sin((animValue * 2 * math.pi * 1.2) + (i * 0.55));

      // Shape spectrum envelope (higher in mid/bass, tapering at ends)
      final envelope = math.sin((i / (barCount - 1)) * math.pi);
      double amplitude = (harmonic1 * 0.5 + harmonic2 * 0.3 + harmonic3 * 0.2).abs();

      if (!isPlaying) {
        amplitude = 0.08 + (math.sin(i * 0.5) * 0.04).abs();
      }

      final barHeight = math.max(3.0, (amplitude * envelope * maxHeight).clamp(3.0, maxHeight));
      final topY = size.height - barHeight;

      final rect = Rect.fromLTWH(x - (barWidth / 2), topY, barWidth, barHeight);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2));

      // Gradient from glowing accent at top to subtle base
      final barPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            accentColor,
            accentColor.withAlpha(isPlaying ? 80 : 30),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect)
        ..style = PaintingStyle.fill;

      // Subtle glow for active bars
      if (isPlaying && barHeight > maxHeight * 0.4) {
        final glowPaint = Paint()
          ..color = accentColor.withAlpha(45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawRRect(rrect, glowPaint);
      }

      canvas.drawRRect(rrect, barPaint);

      // Floating cap on top of taller bars
      if (isPlaying && barHeight > 14) {
        final capPaint = Paint()
          ..color = Colors.white.withAlpha(220)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, topY + 1.5), barWidth * 0.4, capPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FrequencyBarsVisualizerPainter oldDelegate) {
    return oldDelegate.animValue != animValue ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.positionSeconds != positionSeconds;
  }
}

