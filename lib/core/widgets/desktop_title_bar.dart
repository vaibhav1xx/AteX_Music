import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_colors.dart';
import 'atex_monogram.dart';

class DesktopTitleBar extends StatelessWidget {
  final VoidCallback? onSearchTap;

  const DesktopTitleBar({
    super.key,
    this.onSearchTap,
  });

  static bool get isSupported {
    return !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  }

  @override
  Widget build(BuildContext context) {
    if (!isSupported) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 42,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(
          bottom: BorderSide(color: AppColors.dockHairline, width: 1.0),
        ),
      ),
      child: Stack(
        children: [
          // Drag area covering the whole bar
          const Positioned.fill(
            child: DragToMoveArea(child: SizedBox.expand()),
          ),

          Row(
            children: [
              // Left: Logo & Wordmark
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    AteXMonogram(size: 20, showGlow: false),
                    SizedBox(width: 8),
                    Text(
                      'AteX',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Center: Quick Search Trigger
              Flexible(
                child: GestureDetector(
                  onTap: onSearchTap,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.subtleHairline, width: 1),
                    ),
                    child: Row(
                      children: const [
                        Icon(LucideIcons.search, size: 14, color: AppColors.textMuted),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Search artists, songs, albums...',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Ctrl+K',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Right: Windows Caption Controls (Minimize, Maximize, Close)
              if (!kIsWeb && Platform.isWindows) ...[
                _TitleBarButton(
                  icon: LucideIcons.minus,
                  onTap: () => windowManager.minimize(),
                ),
                _TitleBarButton(
                  icon: LucideIcons.square,
                  onTap: () async {
                    if (await windowManager.isMaximized()) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
                _TitleBarButton(
                  icon: LucideIcons.x,
                  isClose: true,
                  onTap: () => windowManager.close(),
                ),
              ] else
                const SizedBox(width: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;

  const _TitleBarButton({
    required this.icon,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 44,
          height: 42,
          color: _hovered
              ? (widget.isClose ? const Color(0xFFE81123) : Colors.white.withAlpha(20))
              : Colors.transparent,
          child: Center(
            child: Icon(
              widget.icon,
              size: 13,
              color: _hovered && widget.isClose ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
