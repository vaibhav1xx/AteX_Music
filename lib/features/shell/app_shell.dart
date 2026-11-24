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
import '../player/widgets/now_playing_side_panel.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  bool _updateBannerDismissed = false;
  String _libraryFilter =
      'All'; // 'All', 'Playlists', 'Favorites', 'Downloaded'

  @override
  void initState() {
    super.initState();
    // Global HardwareKeyboard handler that preserves text typing in all TextFields
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Global Ctrl + K / Cmd + K: Focus & navigate to Search immediately
    if (event.logicalKey == LogicalKeyboardKey.keyK &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      setState(() => _currentIndex = 1);
      return true;
    }

    // FIRST check whether FocusManager.instance.primaryFocus belongs to an EditableText
    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    final isTextInputActive =
        context != null &&
        (context.widget is EditableText ||
            context.findAncestorWidgetOfExactType<EditableText>() != null);

    // Whenever ANY text field is focused, immediately return false so m, M, Space,
    // and arrow keys type normally into Search, dialogs, and inputs.
    if (isTextInputActive) {
      return false;
    }

    // Handle playback / navigation hotkeys when NOT typing
    if (event.logicalKey == LogicalKeyboardKey.space) {
      ref.read(playerProvider.notifier).togglePlayPause();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      ref
          .read(playerProvider.notifier)
          .seekRelative(const Duration(seconds: -10));
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      ref
          .read(playerProvider.notifier)
          .seekRelative(const Duration(seconds: 10));
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      ref.read(playerProvider.notifier).adjustVolume(0.05);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      ref.read(playerProvider.notifier).adjustVolume(-0.05);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
      ref.read(playerProvider.notifier).toggleMute();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final updateAsync = ref.watch(appUpdateFutureProvider);
    final updateInfo = updateAsync.valueOrNull;

    return FocusScope(
      autofocus: true,
      child: Scaffold(
        backgroundColor:
            AppColors.sidebar, // Studio Obsidian #09090B outer background
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 700;
            final themeState = ref.watch(themeProvider);
            final wallpaperPath = themeState.customWallpaperPath;
            final hasWallpaper =
                wallpaperPath != null && File(wallpaperPath).existsSync();

            return Stack(
              children: [
                // Custom Background Wallpaper (optional user preference)
                if (hasWallpaper) ...[
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: themeState.wallpaperBlur,
                        sigmaY: themeState.wallpaperBlur,
                      ),
                      child: Image.file(File(wallpaperPath), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withAlpha(
                        (themeState.wallpaperDim * 255).toInt(),
                      ),
                    ),
                  ),
                ] else ...[
                  Positioned.fill(child: Container(color: AppColors.sidebar)),
                ],

                // Main App Layout
                Positioned.fill(
                  child: Column(
                    children: [
                      // Frameless Desktop Drag Titlebar (Windows & macOS on desktop widths)
                      if (DesktopTitleBar.isSupported && isDesktop)
                        DesktopTitleBar(
                          onSearchTap: () => setState(() => _currentIndex = 1),
                        ),

                      // In-App Update Banner (dismissible)
                      if (updateInfo != null &&
                          updateInfo.hasUpdate &&
                          !_updateBannerDismissed)
                        _buildUpdateBanner(updateInfo),

                      // Responsive Layout (Spotify 3-Panel Desktop vs Mobile)
                      Expanded(
                        child: isDesktop
                            ? _buildDesktopLayout(context, constraints)
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () =>
                UpdateCheckerService.launchUrlExternal(updateInfo.releaseUrl),
            child: const Text(
              'Download',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              LucideIcons.x,
              color: AppColors.textMuted,
              size: 16,
            ),
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
          onOpenStats: () => setState(() => _currentIndex = 4),
        );
      case 1:
        return const SearchScreen();
      case 2:
        return const LibraryScreen();
      case 3:
        return const SettingsScreen();
      case 4:
        return const StatsScreen();
      default:
        return HomeScreen(
          onOpenLibrary: () => setState(() => _currentIndex = 2),
          onOpenSearch: () => setState(() => _currentIndex = 1),
          onOpenStats: () => setState(() => _currentIndex = 4),
        );
    }
  }

  // =========================================================================
  // MOBILE SPOTIFY LAYOUT (< 700px): Clean Canvas + Floating Mini-Player
  // =========================================================================
  Widget _buildMobileLayout(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _buildCurrentPage()),

        // Floating Mini-Player (58px) & Bottom Nav
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
                    _buildBottomNavItem(4, LucideIcons.flame, 'Rewind'),
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
            color: isSelected ? AppColors.accent : AppColors.textMuted,
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

  // =========================================================================
  // DESKTOP 3-PANEL SPOTIFY ARCHITECTURE (>= 700px):
  // 260px Left Sidebar + Rounded Center Canvas + Optional Right Panel + 80px Dock
  // =========================================================================
  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    final isWideDesktop = constraints.maxWidth >= 1200;
    final isRightPanelVisible = ref.watch(isNowPlayingSidePanelVisibleProvider);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                // 1. LEFT SIDEBAR (260px width with 12px panel gaps)
                SizedBox(
                  width: 260,
                  child: Column(
                    children: [
                      // Top Rounded Card (#111114) with Brand, Home & Search
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.subtleHairline),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Row(
                                children: const [
                                  AteXMonogram(size: 24, showGlow: false),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'AteX Music',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildSidebarItem(0, LucideIcons.home, 'Home'),
                            const SizedBox(height: 4),
                            _buildSidebarItem(1, LucideIcons.search, 'Search'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Bottom Rounded "Your Library" Card (#111114)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.subtleHairline),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Your Library Header & Add Playlist Button
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            setState(() => _currentIndex = 2),
                                        behavior: HitTestBehavior.opaque,
                                        child: Row(
                                          children: const [
                                            Icon(
                                              LucideIcons.library,
                                              size: 18,
                                              color: AppColors.textSecondary,
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Your Library',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: 'Create Playlist',
                                      child: GestureDetector(
                                        onTap: () => showCreatePlaylistDialog(
                                          context,
                                          ref,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: AppColors.cardHover,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            LucideIcons.plus,
                                            size: 16,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Filter Pills: Playlists, Favorites, Downloaded
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildLibraryPill('All'),
                                    const SizedBox(width: 6),
                                    _buildLibraryPill('Playlists'),
                                    const SizedBox(width: 6),
                                    _buildLibraryPill('Favorites'),
                                    const SizedBox(width: 6),
                                    _buildLibraryPill('Downloaded'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Divider(
                                height: 1,
                                color: AppColors.subtleHairline,
                              ),
                              const SizedBox(height: 8),

                              // Scrollable saved collections with square 44x44 cover thumbnails
                              Expanded(
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final playlistsAsync = ref.watch(
                                      playlistsStreamProvider,
                                    );
                                    final playlists =
                                        playlistsAsync.valueOrNull ?? [];

                                    return ListView(
                                      children: [
                                        if (_libraryFilter == 'All' ||
                                            _libraryFilter == 'Favorites')
                                          _buildPlaylistCollectionTile(
                                            title: 'Favorite Songs',
                                            subtitle:
                                                'Playlist • Auto-collected',
                                            icon: LucideIcons.heart,
                                            iconColor: AppColors.accent,
                                            bgColor: const Color(0xFF1E293B),
                                            onTap: () => setState(
                                              () => _currentIndex = 2,
                                            ),
                                          ),
                                        if (_libraryFilter == 'All' ||
                                            _libraryFilter == 'Downloaded')
                                          _buildPlaylistCollectionTile(
                                            title: 'Downloaded Tracks',
                                            subtitle:
                                                'Playlist • Offline audio',
                                            icon: LucideIcons.arrowDownToLine,
                                            iconColor: const Color(0xFF34D399),
                                            bgColor: const Color(0xFF064E3B),
                                            onTap: () => setState(
                                              () => _currentIndex = 2,
                                            ),
                                          ),
                                        if (_libraryFilter == 'All' ||
                                            _libraryFilter == 'Playlists')
                                          ...playlists.map(
                                            (
                                              pl,
                                            ) => _buildPlaylistCollectionTile(
                                              title: pl.name,
                                              subtitle:
                                                  'Playlist • Local collection',
                                              icon: LucideIcons.music,
                                              iconColor: AppColors.textPrimary,
                                              bgColor: AppColors.cardHover,
                                              onTap: () => setState(
                                                () => _currentIndex = 2,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        // Quick Navigation to Settings and Rewind
                                        _buildSidebarItem(
                                          4,
                                          LucideIcons.flame,
                                          'Rewind & Stats',
                                        ),
                                        const SizedBox(height: 4),
                                        _buildSidebarItem(
                                          3,
                                          LucideIcons.settings,
                                          'Settings',
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 2. CENTER MAIN VIEW (#111114 rounded panel with ambient glow)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.subtleHairline),
                      ),
                      child: _buildCurrentPage(),
                    ),
                  ),
                ),

                // 3. OPTIONAL RIGHT "NOW PLAYING" PANEL (>= 1200px width)
                if (isWideDesktop && isRightPanelVisible) ...[
                  const SizedBox(width: 10),
                  const NowPlayingSidePanel(),
                ],
              ],
            ),
          ),
        ),

        // 80px Bottom Player Dock on Studio Obsidian (#09090B)
        const MiniPlayer(isDesktopDock: true),
      ],
    );
  }

  Widget _buildLibraryPill(String filter) {
    final isSelected = _libraryFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _libraryFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withAlpha(40) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.subtleHairline,
            width: 1.0,
          ),
        ),
        child: Text(
          filter,
          style: TextStyle(
            color: isSelected ? AppColors.accent : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistCollectionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        child: Row(
          children: [
            // Square 44x44 cover thumbnail
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.pillFill : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
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
}
