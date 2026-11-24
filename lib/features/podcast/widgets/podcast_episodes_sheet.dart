import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/podcast.dart';
import '../../../data/services/offline_download_service.dart';
import '../../../data/services/podcast_service.dart';
import '../../player/providers/player_provider.dart';
import '../../player/widgets/album_art_view.dart';

/// Shows the Podcast Episodes viewer (Modal on desktop, Bottom sheet on mobile)
void showPodcastEpisodesSheet(BuildContext context, WidgetRef ref, Podcast podcast) {
  final isDesktop = MediaQuery.sizeOf(context).width >= 700;

  if (isDesktop) {
    showDialog(
      context: context,
      builder: (ctx) => _PodcastEpisodesDialog(podcast: podcast),
    );
  } else {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sidebar,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PodcastEpisodesSheet(podcast: podcast),
    );
  }
}

class _PodcastEpisodesSheet extends StatelessWidget {
  final Podcast podcast;
  const _PodcastEpisodesSheet({required this.podcast});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
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
              _PodcastHeader(podcast: podcast),
              const SizedBox(height: 12),
              const Divider(color: AppColors.dockHairline, height: 1),
              Expanded(
                child: _EpisodesList(
                  podcast: podcast,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PodcastEpisodesDialog extends StatelessWidget {
  final Podcast podcast;
  const _PodcastEpisodesDialog({required this.podcast});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.subtleHairline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _PodcastHeader(podcast: podcast)),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.dockHairline, height: 1),
              const SizedBox(height: 8),
              Expanded(
                child: _EpisodesList(podcast: podcast),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PodcastHeader extends StatelessWidget {
  final Podcast podcast;
  const _PodcastHeader({required this.podcast});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AlbumArtView(
          imageUrl: podcast.artworkUrl,
          size: 60,
          borderRadius: 8,
          placeholderText: podcast.title,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                podcast.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'By ${podcast.artist}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (podcast.primaryGenre != null) ...[
                const SizedBox(height: 2),
                Text(
                  podcast.primaryGenre!,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EpisodesList extends ConsumerStatefulWidget {
  final Podcast podcast;
  final ScrollController? scrollController;

  const _EpisodesList({
    required this.podcast,
    this.scrollController,
  });

  @override
  ConsumerState<_EpisodesList> createState() => _EpisodesListState();
}

class _EpisodesListState extends ConsumerState<_EpisodesList> {
  List<PodcastEpisode>? _episodes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    final service = ref.read(podcastServiceProvider);
    try {
      final list = await service.fetchEpisodes(
        widget.podcast.feedUrl,
        podcastTitle: widget.podcast.title,
        podcastArtwork: widget.podcast.artworkUrl,
      );
      if (mounted) {
        setState(() {
          _episodes = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load podcast episodes: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      );
    }

    if (_episodes == null || _episodes!.isEmpty) {
      return const Center(
        child: Text(
          'No episodes found in feed',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    final playerNotifier = ref.read(playerProvider.notifier);
    final downloadService = ref.read(offlineDownloadServiceProvider.notifier);
    final downloadStates = ref.watch(offlineDownloadServiceProvider);

    return ListView.separated(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _episodes!.length,
      separatorBuilder: (ctx, i) => const Divider(color: AppColors.subtleHairline, height: 1),
      itemBuilder: (context, index) {
        final ep = _episodes![index];
        final track = ep.toTrack();
        final dlState = downloadStates[track.id];
        final isDownloading = dlState?.status == DownloadStatus.downloading;
        final isDownloaded = dlState?.status == DownloadStatus.completed;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.play, color: AppColors.accent, size: 16),
                ),
                onPressed: () {
                  playerNotifier.playTrack(track);
                  AppToast.show(context, 'Streaming episode: "${ep.title}"', icon: LucideIcons.radio);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ep.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (ep.description.isNotEmpty) ...[
                      Text(
                        ep.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        const Icon(LucideIcons.clock, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          ep.durationFormatted,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isDownloading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: dlState?.progress,
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else if (isDownloaded)
                const Icon(LucideIcons.checkCheck, color: AppColors.accent, size: 18)
              else
                IconButton(
                  tooltip: 'Download Episode for Offline Listening',
                  icon: const Icon(LucideIcons.download, color: AppColors.textSecondary, size: 18),
                  onPressed: () {
                    downloadService.downloadTrack(
                      trackId: track.id,
                      audioUrl: track.filePath,
                      title: track.title,
                      artist: track.artist,
                      album: track.album,
                      coverUrl: track.localCoverPath,
                      duration: track.duration,
                    );
                    AppToast.show(context, 'Downloading "${ep.title}"', icon: LucideIcons.download);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
