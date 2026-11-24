import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/track.dart';

/// Shows the "Track Info & Metadata" sheet (Inspector)
void showTrackInfoSheet(BuildContext context, Track track) {
  final isDesktop = MediaQuery.sizeOf(context).width >= 700;

  if (isDesktop) {
    showDialog(
      context: context,
      builder: (ctx) => _TrackInfoDialog(track: track),
    );
  } else {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sidebar,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TrackInfoSheet(track: track),
    );
  }
}

class _TrackInfoSheet extends StatelessWidget {
  final Track track;
  const _TrackInfoSheet({required this.track});

  @override
  Widget build(BuildContext context) {
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
              _InspectorContent(track: track),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackInfoDialog extends StatelessWidget {
  final Track track;
  const _TrackInfoDialog({required this.track});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.subtleHairline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Audio Inspector & Metadata',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _InspectorContent(track: track),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InspectorContent extends StatefulWidget {
  final Track track;
  const _InspectorContent({required this.track});

  @override
  State<_InspectorContent> createState() => _InspectorContentState();
}

class _InspectorContentState extends State<_InspectorContent> {
  int? _fileSizeBytes;
  String _codec = 'Unknown';
  int? _bitrateKbps;
  int? _sampleRateHz;

  @override
  void initState() {
    super.initState();
    _inspectFile();
  }

  Future<void> _inspectFile() async {
    final path = widget.track.filePath;

    // Detect format/codec from extension or URL
    final ext = path.split('?').first.split('.').last.toUpperCase();
    if (ext.length <= 5 && RegExp(r'^[A-Z0-9]+$').hasMatch(ext)) {
      _codec = ext;
    } else if (path.startsWith('http')) {
      _codec = 'Live Web Stream';
    }

    // Inspect local file stats & tags
    final file = File(path);
    if (file.existsSync()) {
      try {
        final size = file.lengthSync();
        setState(() {
          _fileSizeBytes = size;
        });

        // Calculate estimated bitrate: (size in bits) / (duration in seconds)
        if (widget.track.duration.inSeconds > 0) {
          final estBitrate = ((size * 8) / (widget.track.duration.inSeconds * 1000)).round();
          if (estBitrate > 0 && estBitrate < 10000) {
            _bitrateKbps = estBitrate;
          }
        }

        // Try reading with audio_metadata_reader
        final meta = readMetadata(file);
        if (meta.duration != null && meta.duration! > Duration.zero) {
          // Additional metadata tags
          if (meta.genres.isNotEmpty) {
            // Genre available
          }
        }
      } catch (e) {
        debugPrint('Inspector metadata reader fallback: $e');
      }
    }
    if (mounted) setState(() {});
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Stream / Unknown';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Artist Badge
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.fileAudio, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.title,
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
                      '${widget.track.artist} • ${widget.track.album}',
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
          ),
        ),
        const SizedBox(height: 16),

        _buildInfoRow('Format / Audio Codec', _codec, LucideIcons.disc),
        const SizedBox(height: 10),
        _buildInfoRow('File Size', _formatFileSize(_fileSizeBytes), LucideIcons.hardDrive),
        const SizedBox(height: 10),
        _buildInfoRow('Duration', widget.track.durationFormatted, LucideIcons.clock),
        const SizedBox(height: 10),
        _buildInfoRow(
          'Bitrate',
          _bitrateKbps != null ? '$_bitrateKbps kbps' : (_codec == 'FLAC' ? 'Lossless (VBR)' : 'High Quality Audio'),
          LucideIcons.activity,
        ),
        if (_sampleRateHz != null) ...[
          const SizedBox(height: 10),
          _buildInfoRow('Sample Rate', '$_sampleRateHz Hz', LucideIcons.radio),
        ],
        const SizedBox(height: 10),
        _buildInfoRow('Play Count', '${widget.track.playCount} plays', LucideIcons.playCircle),
        const SizedBox(height: 14),

        const Divider(color: AppColors.dockHairline, height: 1),
        const SizedBox(height: 14),

        // Local File Path
        const Text(
          'LOCAL SOURCE PATH / STREAM URI',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.subtleHairline),
          ),
          child: SelectableText(
            widget.track.filePath,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
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
      ),
    );
  }
}
