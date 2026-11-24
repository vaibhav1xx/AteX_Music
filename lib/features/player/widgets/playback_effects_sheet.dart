import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/player_provider.dart';

/// Shows the sleek "Speed, Pitch & Sleep Timer" bottom sheet on mobile, or centered dialog on desktop.
void showPlaybackEffectsSheet(BuildContext context, WidgetRef ref) {
  final isDesktop = MediaQuery.sizeOf(context).width >= 700;

  if (isDesktop) {
    showDialog(
      context: context,
      builder: (ctx) => const _PlaybackEffectsDialog(),
    );
  } else {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sidebar,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _PlaybackEffectsSheet(),
    );
  }
}

class _PlaybackEffectsSheet extends ConsumerWidget {
  const _PlaybackEffectsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.subtleHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const _Header(),
              const SizedBox(height: 16),
              const _Content(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackEffectsDialog extends ConsumerWidget {
  const _PlaybackEffectsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: AppColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.subtleHairline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _Header(),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _Content(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.accent.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(LucideIcons.slidersHorizontal, color: AppColors.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Speed, Pitch & Sleep Timer',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Pro hardware audio engine parameters',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    final speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final pitchPresets = [0.8, 1.0, 1.2];
    final timerPresets = [15, 30, 45, 60];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Playback Speed
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PLAYBACK SPEED',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '${playerState.speed.toStringAsFixed(2)}x',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.0,
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.subtleHairline,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          ),
          child: Slider(
            value: playerState.speed.clamp(0.5, 2.0),
            min: 0.5,
            max: 2.0,
            divisions: 15,
            onChanged: (val) => notifier.setSpeed(val),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: speedPresets.map((sp) {
            final isSelected = (playerState.speed - sp).abs() < 0.04;
            return GestureDetector(
              onTap: () => notifier.setSpeed(sp),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.subtleHairline,
                  ),
                ),
                child: Text(
                  '${sp}x',
                  style: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Divider(color: AppColors.dockHairline, height: 1),
        const SizedBox(height: 16),

        // 2. Audio Pitch Control
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'AUDIO PITCH',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            Row(
              children: [
                Text(
                  '${playerState.pitch.toStringAsFixed(2)}x',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => notifier.setPitch(1.0),
                  child: const Text('Reset', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.0,
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.subtleHairline,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          ),
          child: Slider(
            value: playerState.pitch.clamp(0.5, 1.5),
            min: 0.5,
            max: 1.5,
            divisions: 10,
            onChanged: (val) => notifier.setPitch(val),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: pitchPresets.map((pp) {
            final isSelected = (playerState.pitch - pp).abs() < 0.04;
            return GestureDetector(
              onTap: () => notifier.setPitch(pp),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.subtleHairline,
                  ),
                ),
                child: Text(
                  pp == 1.0 ? 'Normal (1.0x)' : '${pp}x',
                  style: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Divider(color: AppColors.dockHairline, height: 1),
        const SizedBox(height: 8),

        // 3. Skip Silence Toggle
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.accent,
          title: const Text(
            'Skip Silence',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            'Automatically leap over silent audio sections in podcasts and tracks',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          value: playerState.skipSilence,
          onChanged: (_) => notifier.toggleSkipSilence(),
        ),
        const SizedBox(height: 8),
        const Divider(color: AppColors.dockHairline, height: 1),
        const SizedBox(height: 16),

        // 4. Sleep Timer
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SLEEP TIMER',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            if (playerState.sleepTimerMinutesRemaining != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Pausing in ~${playerState.sleepTimerMinutesRemaining}m',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => notifier.cancelSleepTimer(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: playerState.sleepTimerMinutesRemaining == null
                      ? AppColors.cardHover
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.subtleHairline),
                ),
                child: const Text('Off', style: TextStyle(color: AppColors.textPrimary, fontSize: 11)),
              ),
            ),
            ...timerPresets.map((mins) {
              final isActive = playerState.sleepTimerMinutesRemaining != null &&
                  playerState.sleepTimerMinutesRemaining! <= mins &&
                  playerState.sleepTimerMinutesRemaining! > mins - 15;
              return GestureDetector(
                onTap: () => notifier.setSleepTimer(mins),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.accent : AppColors.card,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isActive ? AppColors.accent : AppColors.subtleHairline,
                    ),
                  ),
                  child: Text(
                    '${mins}m',
                    style: TextStyle(
                      color: isActive ? Colors.black : AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}
