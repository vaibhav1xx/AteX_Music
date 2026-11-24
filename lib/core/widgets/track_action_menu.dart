import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/database/app_database.dart';
import '../../data/models/track.dart';
import '../../data/services/offline_download_service.dart';
import '../../features/player/providers/player_provider.dart';
import '../theme/app_colors.dart';
import 'app_toast.dart';

/// Shows the track action menu (bottom sheet on mobile, modal popup on desktop)
void showTrackActionMenu(BuildContext context, WidgetRef ref, Track track) {
  final isDesktop = MediaQuery.sizeOf(context).width >= 700;

  if (isDesktop) {
    showDialog(
      context: context,
      builder: (ctx) => _TrackActionDialog(track: track, ref: ref),
    );
  } else {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sidebar,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TrackActionSheet(track: track, ref: ref),
    );
  }
}

class _TrackActionSheet extends StatelessWidget {
  final Track track;
  final WidgetRef ref;

  const _TrackActionSheet({required this.track, required this.ref});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            const SizedBox(height: 14),
            _TrackHeader(track: track),
            const SizedBox(height: 12),
            const Divider(color: AppColors.dockHairline, height: 1),
            const SizedBox(height: 8),
            _ActionList(track: track, ref: ref),
          ],
        ),
      ),
    );
  }
}

class _TrackActionDialog extends StatelessWidget {
  final Track track;
  final WidgetRef ref;

  const _TrackActionDialog({required this.track, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.subtleHairline, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrackHeader(track: track),
              const SizedBox(height: 16),
              const Divider(color: AppColors.dockHairline, height: 1),
              const SizedBox(height: 8),
              _ActionList(track: track, ref: ref),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackHeader extends StatelessWidget {
  final Track track;

  const _TrackHeader({required this.track});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(LucideIcons.music, color: AppColors.accent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionList extends StatelessWidget {
  final Track track;
  final WidgetRef ref;

  const _ActionList({required this.track, required this.ref});

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(playerProvider.notifier);
    final downloadService = ref.read(offlineDownloadServiceProvider.notifier);

    return Column(
      children: [
        _ActionTile(
          icon: LucideIcons.listPlus,
          title: 'Play Next',
          onTap: () {
            Navigator.pop(context);
            notifier.playNext(track);
            AppToast.show(context, 'Playing next: "${track.title}"', icon: LucideIcons.listPlus);
          },
        ),
        _ActionTile(
          icon: LucideIcons.listMusic,
          title: 'Add to Queue',
          onTap: () {
            Navigator.pop(context);
            notifier.addToQueue(track);
            AppToast.show(context, 'Added to queue: "${track.title}"', icon: LucideIcons.listMusic);
          },
        ),
        _ActionTile(
          icon: LucideIcons.folderPlus,
          title: 'Add to Playlist',
          onTap: () {
            Navigator.pop(context);
            showAddToPlaylistDialog(context, ref, track);
          },
        ),
        _ActionTile(
          icon: track.isFavorite ? LucideIcons.heartCrack : LucideIcons.heart,
          iconColor: track.isFavorite ? Colors.redAccent : AppColors.accent,
          title: track.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
          onTap: () {
            Navigator.pop(context);
            notifier.toggleTrackFavorite(track);
            AppToast.show(
              context,
              track.isFavorite ? 'Removed from Favorites' : 'Added to Favorites',
              icon: LucideIcons.heart,
            );
          },
        ),
        _ActionTile(
          icon: LucideIcons.download,
          title: 'Download Offline',
          onTap: () {
            Navigator.pop(context);
            downloadService.downloadTrack(
              trackId: track.id,
              audioUrl: track.filePath,
              title: track.title,
              artist: track.artist,
              album: track.album,
              coverUrl: track.localCoverPath,
              duration: track.duration,
            );
            AppToast.show(context, 'Started download for "${track.title}"', icon: LucideIcons.download);
          },
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      dense: true,
      leading: Icon(icon, color: iconColor ?? AppColors.textPrimary, size: 18),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

/// Dialog to Add a Track to an Existing or New Playlist
void showAddToPlaylistDialog(BuildContext context, WidgetRef ref, Track track) {
  showDialog(
    context: context,
    builder: (ctx) {
      return Consumer(
        builder: (context, ref, _) {
          final playlistsAsync = ref.watch(playlistsStreamProvider);
          final playlists = playlistsAsync.valueOrNull ?? [];

          return Dialog(
            backgroundColor: AppColors.sidebar,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.subtleHairline),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add to Playlist',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 16, color: AppColors.textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.plus, color: AppColors.accent, size: 18),
                      ),
                      title: const Text(
                        'New Playlist',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        showCreatePlaylistDialog(context, ref, onCreated: (plId) async {
                          final db = ref.read(appDatabaseProvider);
                          await db.addTrackToPlaylist(plId, track.id);
                          if (context.mounted) {
                            AppToast.show(context, 'Added "${track.title}" to new playlist', icon: LucideIcons.check);
                          }
                        });
                      },
                    ),
                    const Divider(color: AppColors.dockHairline),
                    Expanded(
                      child: playlists.isEmpty
                          ? const Center(
                              child: Text(
                                'No playlists yet. Create one above!',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: playlists.length,
                              itemBuilder: (c, idx) {
                                final pl = playlists[idx];
                                return ListTile(
                                  leading: const Icon(LucideIcons.listMusic, color: AppColors.accent, size: 18),
                                  title: Text(
                                    pl.name,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                  ),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    final db = ref.read(appDatabaseProvider);
                                    await db.addTrackToPlaylist(pl.id, track.id);
                                    if (context.mounted) {
                                      AppToast.show(
                                        context,
                                        'Added "${track.title}" to ${pl.name}',
                                        icon: LucideIcons.check,
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Dialog to Create a New Playlist in Drift Database
void showCreatePlaylistDialog(
  BuildContext context,
  WidgetRef ref, {
  void Function(String playlistId)? onCreated,
}) {
  final nameController = TextEditingController();
  final descController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: AppColors.sidebar,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.subtleHairline),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Playlist',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Playlist Name',
                    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.playButtonBg,
                        foregroundColor: AppColors.playButtonIcon,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        final id = 'pl_${DateTime.now().millisecondsSinceEpoch}';
                        final db = ref.read(appDatabaseProvider);
                        await db.createPlaylist(
                          PlaylistsCompanion(
                            id: drift.Value(id),
                            name: drift.Value(name),
                            description: drift.Value(descController.text.trim().isEmpty ? null : descController.text.trim()),
                          ),
                        );

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (context.mounted) {
                          AppToast.show(context, 'Created playlist "$name"', icon: LucideIcons.folderPlus);
                        }
                        onCreated?.call(id);
                      },
                      child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
