import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/atex_monogram.dart';
import '../../core/widgets/desktop_title_bar.dart';
import '../../core/widgets/track_action_menu.dart';
import '../../data/database/app_database.dart';
import '../../data/services/update_checker_service.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../player/providers/player_provider.dart';
import '../player/widgets/mini_player.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  bool _updateBannerDismissed = false;

  bool _isTextInputActive() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final ctx = focus.context;
    if (ctx == null) return false;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    final updateAsync = ref.watch(appUpdateFutureProvider);
    final updateInfo = updateAsync.valueOrNull;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (_isTextInputActive()) return;
          ref.read(playerProvider.notifier).togglePlayPause();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          if (_isTextInputActive()) return;
          setState(() => _currentIndex = 1);
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (_isTextInputActive()) return;
          ref.read(playerProvider.notifier).seekRelative(const Duration(seconds: -10));
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (_isTextInputActive()) return;
          ref.read(playerProvider.notifier).seekRelative(const Duration(seconds: 10));
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          if (_isTextInputActive()) return;
          ref.read(playerProvider.notifier).adjustVolume(0.05);
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          if (_isTextInputActive()) return;
          ref.read(playerProvider.notifier).adjustVolume(-0.05);
        },
        const SingleActivator(LogicalKeyboardKey.keyM): () {
          if (_isTextInputActive()) return;
          ref.read(playerProvider.notifier).toggleMute();
        },
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 700;
              final themeState = ref.watch(themeProvider);
              final wallpaperPath = themeState.customWallpaperPath;
              final hasWallpaper = wallpaperPath != null && File(wallpaperPath).existsSync();

              return Stack(
                children: [
                  // Custom Background Wallpaper (with adjustable Gaussian blur & dim overlay)
                  if (hasWallpaper) ...[
                    Positioned.fill(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: themeState.wallpaperBlur,
                          sigmaY: themeState.wallpaperBlur,
                        ),
                        child: Image.file(
                          File(wallpaperPath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withAlpha((themeState.wallpaperDim * 255).toInt()),
                      ),
                    ),
                  ] else ...[
                    Positioned.fill(
                      child: Container(color: themeState.canvas),
                    ),
                  ],

                  // Main App Layout
                  Positioned.fill(
                    child: Column(
                      children: [
                        // Integrated Frameless Desktop Drag Titlebar (Windows & macOS on desktop widths)
                        if (DesktopTitleBar.isSupported && isDesktop)
                          DesktopTitleBar(
                            onSearchTap: () => setState(() => _currentIndex = 1),
                          ),

                        // In-App Update Banner (dismissible)
                        if (updateInfo != null && updateInfo.hasUpdate && !_updateBannerDismissed)
                          _buildUpdateBanner(updateInfo),

                        // Main Responsive Layout
                        Expanded(
                          child: isDesktop
                              ? _buildDesktopLayout(context)
                              : _buildMobileLayout(context),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateBanner(UpdateInfo updateInfo) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withAlpha(120), width: 1.0),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, color: AppColors.accent, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'AteX Music v${updateInfo.latestVersion} is available!',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => UpdateCheckerService.launchUrlExternal(updateInfo.releaseUrl),
            child: const Text('Download', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(LucideIcons.x, color: AppColors.textMuted, size: 16),
            onPressed: () => setState(() => _updateBannerDismissed = true),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          onOpenLibrary: () => setState(() => _currentIndex = 2),
          onOpenSearch: () => setState(() => _currentIndex = 1),
        );
      case 1:
        return const SearchScreen();
      case 2:
        return const LibraryScreen();
      case 3:
        return const SettingsScreen();
      default:
        return HomeScreen(
          onOpenLibrary: () => setState(() => _currentIndex = 2),
          onOpenSearch: () => setState(() => _currentIndex = 1),
        );
    }
  }

  // Mobile Layout (< 700px): Bottom Nav + Floating Mini-Player
  Widget _buildMobileLayout(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildCurrentPage(),
        ),

        // Floating Mini-Player & Bottom Nav
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPlayer(isDesktopDock: false),
              Container(
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.sidebar,
                  border: Border(
                    top: BorderSide(color: AppColors.dockHairline, width: 1.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomNavItem(0, LucideIcons.home, 'Home'),
                    _buildBottomNavItem(1, LucideIcons.search, 'Search'),
                    _buildBottomNavItem(2, LucideIcons.library, 'Library'),
                    _buildBottomNavItem(3, LucideIcons.settings, 'Settings'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
            size: 20,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Desktop / Tablet / TV Layout (>= 700px): Clean Sidebar + 84px Bottom Dock
  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Clean Studio Sidebar (#09090B)
              Container(
                width: 230,
                color: AppColors.sidebar,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Row(
                        children: const [
                          AteXMonogram(size: 24, showGlow: false),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AteX Music',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Borderless Navigation Items with Translucent Pill Fill ONLY on Active Tab
                    _buildSidebarItem(0, LucideIcons.home, 'Home'),
                    const SizedBox(height: 4),
                    _buildSidebarItem(1, LucideIcons.search, 'Search'),
                    const SizedBox(height: 4),
                    _buildSidebarItem(2, LucideIcons.library, 'Library'),
                    const SizedBox(height: 4),
                    _buildSidebarItem(3, LucideIcons.settings, 'Settings'),
                    const SizedBox(height: 4),
                    _buildSidebarItem(4, LucideIcons.flame, 'Rewind & Stats'),

                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'LOCAL PLAYLISTS',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => showCreatePlaylistDialog(context, ref),
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                LucideIcons.plus,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final playlistsAsync = ref.watch(playlistsStreamProvider);
                          final playlists = playlistsAsync.valueOrNull ?? [];

                          return ListView(
                            children: [
                              _buildPlaylistLink('Favorite Songs', onTap: () => setState(() => _currentIndex = 2)),
                              _buildPlaylistLink('Offline Downloads', onTap: () => setState(() => _currentIndex = 2)),
                              ...playlists.map(
                                (pl) => _buildPlaylistLink(
                                  pl.name,
                                  onTap: () => setState(() => _currentIndex = 2),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Main Canvas (#111114)
              Expanded(
                child: Container(
                  color: AppColors.canvas,
                  child: _buildCurrentPage(),
                ),
              ),
            ],
          ),
        ),

        // Pro 84px Bottom Dock (#0C0C0F)
        const MiniPlayer(isDesktopDock: true),
      ],
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.pillFill : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistLink(String name, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
