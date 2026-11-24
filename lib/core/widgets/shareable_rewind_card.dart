import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'atex_monogram.dart';

/// Dark glassmorphic 9:16 shareable AteX Rewind / Stats card
class ShareableRewindCard extends StatelessWidget {
  final int totalListeningMinutes;
  final int totalTracksPlayed;
  final int listeningStreak;
  final String topArtist;
  final String topTrackTitle;
  final String? topTrackCover;
  final Color? accentColor;

  const ShareableRewindCard({
    super.key,
    required this.totalListeningMinutes,
    required this.totalTracksPlayed,
    required this.listeningStreak,
    required this.topArtist,
    required this.topTrackTitle,
    this.topTrackCover,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? AppColors.accent;
    final hours = totalListeningMinutes ~/ 60;
    final mins = totalListeningMinutes % 60;

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF07080C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(25), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(180),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Radial gradient mesh background
              Positioned(
                top: -60,
                right: -60,
                width: 260,
                height: 260,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        effectiveAccent.withAlpha(80),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                left: -80,
                width: 300,
                height: 300,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF2979FF).withAlpha(50),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Vignette
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withAlpha(120),
                        Colors.black.withAlpha(210),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // Foreground Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/icon/logo_mark.png',
                              width: 24,
                              height: 24,
                              errorBuilder: (_, _, _) => const AteXMonogram(size: 24),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'AteX Rewind',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: effectiveAccent.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: effectiveAccent.withAlpha(100), width: 1),
                          ),
                          child: Text(
                            '${DateTime.now().year}',
                            style: TextStyle(
                              color: effectiveAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Big Headline
                    const Text(
                      'YOUR YEAR IN\nOFFLINE AUDIO.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -0.8,
                      ),
                    ),

                    const Spacer(),

                    // Stat 1: Total Time
                    _buildStatCard(
                      label: 'TOTAL LISTENING TIME',
                      value: hours > 0 ? '$hours hrs $mins mins' : '$mins mins',
                      icon: Icons.timer_outlined,
                      accent: effectiveAccent,
                    ),

                    const SizedBox(height: 8),

                    // Stat 2: Daily Streak & Tracks Played (Side-by-side)
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            label: 'LISTENING STREAK',
                            value: '$listeningStreak Days Streak 🔥',
                            icon: Icons.local_fire_department_rounded,
                            accent: const Color(0xFFFF5722),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            label: 'TRACKS PLAYED',
                            value: '$totalTracksPlayed',
                            icon: Icons.music_note_rounded,
                            accent: const Color(0xFF60A5FA),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Stat 3: #1 Top Artist
                    if (topArtist.isNotEmpty) ...[
                      _buildHighlightCard(
                        category: '#1 TOP ARTIST',
                        title: topArtist,
                        subtitle: 'Most frequent in your rotation',
                        accent: effectiveAccent,
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Stat 4: #1 Top Song
                    if (topTrackTitle.isNotEmpty)
                      _buildHighlightCard(
                        category: '#1 MOST PLAYED SONG',
                        title: topTrackTitle,
                        subtitle: 'Your personal anthem',
                        accent: const Color(0xFF10B981),
                        icon: Icons.stars_rounded,
                        artworkPath: topTrackCover,
                      ),

                    const Spacer(),

                    // Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: effectiveAccent,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '100% Zero-Server Music',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(120),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AteX Music v1.0',
                          style: TextStyle(
                            color: Colors.white.withAlpha(80),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard({
    required String category,
    required String title,
    required String subtitle,
    required Color accent,
    required IconData icon,
    String? artworkPath,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
      ),
      child: Row(
        children: [
          if (artworkPath != null && File(artworkPath).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(artworkPath),
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withAlpha(110),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
