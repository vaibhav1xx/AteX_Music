import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/track.dart';

/// Shows the Duplicate Finder & Cleaner Dialog
void showDuplicateCleanerDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => const _DuplicateCleanerDialog(),
  );
}

class _DuplicateCleanerDialog extends ConsumerStatefulWidget {
  const _DuplicateCleanerDialog();

  @override
  ConsumerState<_DuplicateCleanerDialog> createState() => _DuplicateCleanerDialogState();
}

class _DuplicateCleanerDialogState extends ConsumerState<_DuplicateCleanerDialog> {
  bool _scanning = true;
  List<List<Track>> _duplicateGroups = [];

  @override
  void initState() {
    super.initState();
    _findDuplicates();
  }

  Future<void> _findDuplicates() async {
    final db = ref.read(appDatabaseProvider);
    final allDbTracks = await db.getAllTracks();
    final allTracks = allDbTracks.map((d) => d.toDomain()).toList();

    // Group tracks by normalized title + artist
    final Map<String, List<Track>> map = {};
    for (final t in allTracks) {
      final key = '${_normalize(t.title)}:::${_normalize(t.artist)}';
      map.putIfAbsent(key, () => []).add(t);
    }

    final groups = <List<Track>>[];
    for (final entry in map.entries) {
      if (entry.value.length > 1) {
        // Also check if duration is similar (within 3 seconds)
        final firstDur = entry.value.first.duration.inSeconds;
        final matchingDuration = entry.value.where(
          (t) => (t.duration.inSeconds - firstDur).abs() <= 3,
        ).toList();

        if (matchingDuration.length > 1) {
          groups.add(matchingDuration);
        }
      }
    }

    if (mounted) {
      setState(() {
        _duplicateGroups = groups;
        _scanning = false;
      });
    }
  }

  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
  }

  Future<void> _deleteDuplicateTrack(Track track) async {
    final db = ref.read(appDatabaseProvider);
    await db.deleteTrack(track.id);

    setState(() {
      for (final g in _duplicateGroups) {
        g.removeWhere((t) => t.id == track.id);
      }
      _duplicateGroups.removeWhere((g) => g.length <= 1);
    });

    if (mounted) {
      AppToast.show(context, 'Removed duplicate: "${track.title}"', icon: LucideIcons.trash);
    }
  }

  Future<void> _cleanAllDuplicatesAuto() async {
    final db = ref.read(appDatabaseProvider);
    int removed = 0;

    for (final group in _duplicateGroups) {
      // Keep track with highest file size or highest play count
      Track best = group.first;
      for (final t in group) {
        final tFile = File(t.filePath);
        final bestFile = File(best.filePath);
        final tSize = tFile.existsSync() ? tFile.lengthSync() : 0;
        final bestSize = bestFile.existsSync() ? bestFile.lengthSync() : 0;
        if (tSize > bestSize || t.playCount > best.playCount) {
          best = t;
        }
      }

      for (final t in group) {
        if (t.id != best.id) {
          await db.deleteTrack(t.id);
          removed++;
        }
      }
    }

    if (mounted) {
      Navigator.pop(context);
      AppToast.show(
        context,
        'Cleaned $removed duplicate tracks from library',
        icon: LucideIcons.checkCheck,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.subtleHairline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.copy, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Duplicate Audio Finder',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            _scanning
                                ? 'Scanning library...'
                                : '${_duplicateGroups.length} duplicate groups found',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.dockHairline, height: 1),
              const SizedBox(height: 12),

              Expanded(
                child: _scanning
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : _duplicateGroups.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(LucideIcons.checkCircle, color: Colors.greenAccent, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'Clean Library!',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Zero duplicate tracks detected in your local SQLite library.',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _duplicateGroups.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final group = _duplicateGroups[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.subtleHairline),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${group.first.title} • ${group.first.artist}',
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent.withAlpha(20),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${group.length} copies',
                                            style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...group.map((t) {
                                      final f = File(t.filePath);
                                      final sizeStr = f.existsSync()
                                          ? '${(f.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB'
                                          : 'Local Track';
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    t.filePath,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: AppColors.textSecondary,
                                                      fontSize: 11,
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                  Text(
                                                    '$sizeStr • ${t.durationFormatted}',
                                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Delete this duplicate',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                              icon: const Icon(LucideIcons.trash2, size: 15, color: Colors.redAccent),
                                              onPressed: () => _deleteDuplicateTrack(t),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            },
                          ),
              ),

              if (_duplicateGroups.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.playButtonBg,
                        foregroundColor: AppColors.playButtonIcon,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _cleanAllDuplicatesAuto,
                      icon: const Icon(LucideIcons.sparkles, size: 16),
                      label: const Text('Auto-Clean All Duplicates', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
