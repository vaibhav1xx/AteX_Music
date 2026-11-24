import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atex_monogram.dart';
import '../../core/widgets/focusable_card.dart';
import '../../core/widgets/frosted_glass.dart';

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
  bool _deepOledBlack = true;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 20,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings & Engine',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),

              // Zero Server Guarantee Banner
              FrostedGlass(
                padding: const EdgeInsets.all(18),
                borderRadius: BorderRadius.circular(16),
                backgroundColor: const Color(0x1A00E5FF),
                borderColor: AppColors.electricCyan.withAlpha(60),
                child: Row(
                  children: [
                    const AteXMonogram(size: 42),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '100% Offline-First Guarantee',
                            style: TextStyle(
                              color: AppColors.electricCyan,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'No servers, no tracking, no cloud dependencies. All audio and metadata are stored locally on your device.',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Audio Engine Section
              _buildSectionHeader('LOCAL AUDIO ENGINE'),
              FocusableCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: AppColors.electricCyan,
                      title: const Text('32-Bit Float Audio Output'),
                      subtitle: const Text('Direct hardware DAC pass-through for maximum dynamic range.'),
                      value: _bit32Audio,
                      onChanged: (val) => setState(() => _bit32Audio = val),
                    ),
                    const Divider(height: 1, color: AppColors.glassBorder),
                    SwitchListTile(
                      activeColor: AppColors.electricCyan,
                      title: const Text('ReplayGain Normalization'),
                      subtitle: const Text('Prevent jarring volume jumps across disparate local files.'),
                      value: _replayGain,
                      onChanged: (val) => setState(() => _replayGain = val),
                    ),
                    const Divider(height: 1, color: AppColors.glassBorder),
                    SwitchListTile(
                      activeColor: AppColors.electricCyan,
                      title: const Text('Gapless Playback'),
                      subtitle: const Text('Seamless track transitions without micro-stutters.'),
                      value: _gaplessPlayback,
                      onChanged: (val) => setState(() => _gaplessPlayback = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // TV & Interface Section
              _buildSectionHeader('ANDROID TV & DISPLAY'),
              FocusableCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: AppColors.electricCyan,
                      title: const Text('High-Contrast Focus Rings'),
                      subtitle: const Text('Glowing cyan outlines optimized for TV remote D-Pad traversal.'),
                      value: _highContrastTv,
                      onChanged: (val) => setState(() => _highContrastTv = val),
                    ),
                    const Divider(height: 1, color: AppColors.glassBorder),
                    SwitchListTile(
                      activeColor: AppColors.electricCyan,
                      title: const Text('Deep OLED True Black (#07090E)'),
                      subtitle: const Text('Preserves battery life on mobile AMOLED displays.'),
                      value: _deepOledBlack,
                      onChanged: (val) => setState(() => _deepOledBlack = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Platform Architecture & About
              _buildSectionHeader('SYSTEM ARCHITECTURE & INFO'),
              FocusableCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Application Name', 'AteX Music'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Dart Package', 'atex_music'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Application / Bundle ID', 'com.atex.atex_music'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Engine User-Agent', 'AteXMusic/1.0'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Target Platforms', 'Android, iOS, Windows, macOS, Android TV, CarPlay'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Version', '1.0.0+1 (Pass 1 Architecture)'),
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
          color: AppColors.electricCyan,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
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
