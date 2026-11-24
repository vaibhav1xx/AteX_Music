import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atex_monogram.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _bit32Audio = true;
  bool _replayGain = true;
  bool _gaplessPlayback = true;
  bool _highContrastTv = true;
  bool _carAutoPlay = true;
  bool _bluetoothMediaKeys = true;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 36 : 20,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings & Engine',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hardware DAC, SQLite offline engine, and system integration.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Zero-Server & Privacy Guarantee Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const AteXMonogram(size: 38, showGlow: false),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '100% Offline-First Architecture',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Zero servers, no tracking, and no telemetry. All audio tracks, playlists, covers, and .lrc lyrics live strictly on your device.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Audio Engine Section
              _buildSectionHeader('STUDIO AUDIO ENGINE'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text('32-Bit Float Audio Output', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Direct hardware DAC pass-through for maximum lossless dynamic range.', style: TextStyle(fontSize: 12)),
                      value: _bit32Audio,
                      onChanged: (val) => setState(() => _bit32Audio = val),
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text('ReplayGain Normalization', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Equalizes loudness across disparate offline FLAC/MP3 files.', style: TextStyle(fontSize: 12)),
                      value: _replayGain,
                      onChanged: (val) => setState(() => _replayGain = val),
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text('Gapless Playback', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Seamless track transitions without micro-stutters.', style: TextStyle(fontSize: 12)),
                      value: _gaplessPlayback,
                      onChanged: (val) => setState(() => _gaplessPlayback = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Car, Bluetooth & Headset Section
              _buildSectionHeader('CARPLAY, ANDROID AUTO & BLUETOOTH'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text('In-Car Media Session Auto-Resume', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Resumes offline queue when CarPlay or Android Auto connects.', style: TextStyle(fontSize: 12)),
                      value: _carAutoPlay,
                      onChanged: (val) => setState(() => _carAutoPlay = val),
                    ),
                    const Divider(height: 1, color: AppColors.subtleHairline),
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text('Hardware Headset & Bluetooth Keys', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Responds to external headphones, car steering wheels, and speaker buttons.', style: TextStyle(fontSize: 12)),
                      value: _bluetoothMediaKeys,
                      onChanged: (val) => setState(() => _bluetoothMediaKeys = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // TV & Accessibility Section
              _buildSectionHeader('ANDROID TV & DISPLAY'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: AppColors.accent,
                      title: const Text('High-Contrast TV Focus Rings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Accessible glowing outlines optimized for remote D-Pad traversal.', style: TextStyle(fontSize: 12)),
                      value: _highContrastTv,
                      onChanged: (val) => setState(() => _highContrastTv = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Metadata & Architecture
              _buildSectionHeader('SYSTEM IDENTITY & RELEASE'),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Application Name', 'AteX Music'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Dart Package', 'atex_music'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Application / Bundle ID', 'com.atex.atex_music'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Engine User-Agent', 'AteXMusic/1.0'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Target Platforms', 'Android, iOS, Windows, macOS, Android TV, Car'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Database Engine', 'SQLite via Drift (Persistent Local)'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Audio Backend', 'just_audio + media_kit hardware engine'),
                    const SizedBox(height: 10),
                    _buildInfoRow('Version', '1.0.0 (Flagship Release)'),
                  ],
                ),
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
