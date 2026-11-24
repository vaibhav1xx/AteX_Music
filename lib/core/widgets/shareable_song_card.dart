import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/track.dart';
import '../theme/app_colors.dart';
import 'atex_monogram.dart';

/// Dark glassmorphic 9:16 shareable song card
class ShareableSongCard extends StatelessWidget {
  final Track track;
  final String? lyricsSnippet;
  final Color? accentColor;

  const ShareableSongCard({
    super.key,
    required this.track,
    this.lyricsSnippet,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? AppColors.accent;

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF090A0E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(25), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(160),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. Ambient blurred background glow
              Positioned.fill(
                child: track.localCoverPath != null && File(track.localCoverPath!).existsSync()
                    ? Image.file(
                        File(track.localCoverPath!),
                        fit: BoxFit.cover,
                        color: Colors.black.withAlpha(200),
                        colorBlendMode: BlendMode.darken,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              effectiveAccent.withAlpha(40),
                              const Color(0xFF07090E),
                              const Color(0xFF020305),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
              ),

              // Gradient vignette
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withAlpha(140),
                        Colors.black.withAlpha(220),
                        Colors.black.withAlpha(245),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // 2. Foreground Card Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/icon/logo_mark.png',
                          width: 22,
                          height: 22,
                          errorBuilder: (_, _, _) => const AteXMonogram(size: 22),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'AteX Music',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: effectiveAccent.withAlpha(35),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: effectiveAccent.withAlpha(90), width: 0.8),
                          ),
                          child: const Text(
                            'OFFLINE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(flex: 2),

                    // Centered Album Artwork Glass Frame
                    Center(
                      child: Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withAlpha(40), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: effectiveAccent.withAlpha(70),
                              blurRadius: 36,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: track.localCoverPath != null && File(track.localCoverPath!).existsSync()
                              ? Image.file(
                                  File(track.localCoverPath!),
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        effectiveAccent.withAlpha(160),
                                        const Color(0xFF1E1B4B),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      track.title.isNotEmpty ? track.title[0].toUpperCase() : 'A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 64,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Song Title & Artist
                    Text(
                      track.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      track.artist,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withAlpha(190),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.album,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Lyrics Snippet or Audio Stats Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withAlpha(22), width: 1.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            lyricsSnippet != null && lyricsSnippet!.isNotEmpty
                                ? Icons.format_quote_rounded
                                : Icons.graphic_eq_rounded,
                            color: effectiveAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              lyricsSnippet != null && lyricsSnippet!.isNotEmpty
                                  ? lyricsSnippet!
                                  : 'Studio Obsidian • Zero-Server Lossless Audio',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Footer Watermark & Quality Tag
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '100% OFFLINE AUDIO',
                          style: TextStyle(
                            color: Colors.white.withAlpha(100),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: effectiveAccent,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              track.durationFormatted,
                              style: TextStyle(
                                color: Colors.white.withAlpha(160),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
}
