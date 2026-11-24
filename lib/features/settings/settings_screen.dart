import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/atex_monogram.dart';
import '../../data/services/update_checker_service.dart';

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
  bool _isCheckingUpdate = false;
  String _currentVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentVersion = '${info.version}+${info.buildNumber}';
        });
      }
    } catch (_) {}
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isCheckingUpdate = true);
    final service = UpdateCheckerService();

    try {
      final info = await service.checkForUpdate();
      if (!mounted) return;

      if (info.hasUpdate) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.sidebar,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.subtleHairline),
            ),
            title: Row(
              children: const [
                Icon(LucideIcons.sparkles, color: AppColors.accent, size: 20),
                SizedBox(width: 10),
                Text(
                  'Update Available',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A newer version of AteX Music is available: v${info.latestVersion}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current version: v$_currentVersion',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                if (info.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Release Notes:',
                    style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(
                      child: Text(
                        info.releaseNotes,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  UpdateCheckerService.launchUrlExternal(info.releaseUrl);
                },
                child: const Text('Download Update', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      } else {
        AppToast.show(
          context,
          'AteX Music is up to date (v$_currentVersion)',
          icon: LucideIcons.checkCheck,
          iconColor: Colors.greenAccent,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Unable to reach GitHub updates service',
          icon: LucideIcons.alertCircle,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

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

              // In-App Updates Section
              _buildSectionHeader('UPDATES & MAINTENANCE'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(LucideIcons.refreshCw, color: AppColors.accent, size: 20),
                      title: const Text(
                        'Check for Updates',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Current version: v$_currentVersion • GitHub Releases',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      trailing: _isCheckingUpdate
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.cardHover,
                                foregroundColor: AppColors.textPrimary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: _isCheckingUpdate ? null : _checkForUpdates,
                              child: const Text('Check Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                      onTap: _isCheckingUpdate ? null : _checkForUpdates,
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
