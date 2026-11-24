import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atex_monogram.dart';
import '../../core/widgets/desktop_title_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () {
          ref.read(playerProvider.notifier).togglePlayPause();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight, control: true): () {
          ref.read(playerProvider.notifier).next();
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true): () {
          ref.read(playerProvider.notifier).previous();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          setState(() => _currentIndex = 1);
        },
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.canvas,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 700;
              return Column(
                children: [
                  // Integrated Frameless Desktop Drag Titlebar (Windows & macOS on desktop widths)
                  if (DesktopTitleBar.isSupported && isDesktop)
                    DesktopTitleBar(
                      onSearchTap: () => setState(() => _currentIndex = 1),
                    ),

                  // Main Responsive Layout
                  Expanded(
                    child: isDesktop
                        ? _buildDesktopLayout(context)
                        : _buildMobileLayout(context),
                  ),
                ],
              );
            },
          ),
        ),
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

                    const SizedBox(height: 28),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
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
                    const SizedBox(height: 8),

                    Expanded(
                      child: ListView(
                        children: [
                          _buildPlaylistLink('Favorite Songs'),
                          _buildPlaylistLink('Offline Downloads'),
                          _buildPlaylistLink('FLAC Studio Mix'),
                          _buildPlaylistLink('Recently Added'),
                        ],
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
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistLink(String name) {
    return Padding(
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
    );
  }
}
