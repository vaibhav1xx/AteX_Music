import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/atex_monogram.dart';
import '../../core/widgets/focusable_card.dart';
import '../../core/widgets/frosted_glass.dart';
import '../../core/widgets/responsive_layout.dart';
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
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.oledBlack,
          body: ResponsiveLayout(
            mobile: (context, constraints) => _buildMobileLayout(context),
            desktop: (context, constraints) => _buildDesktopLayout(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(onOpenLibrary: () => setState(() => _currentIndex = 2));
      case 1:
        return const SearchScreen();
      case 2:
        return const LibraryScreen();
      case 3:
        return const SettingsScreen();
      default:
        return HomeScreen(onOpenLibrary: () => setState(() => _currentIndex = 2));
    }
  }

  // Mobile Layout (< 700px): Bottom nav + Floating Mini-Player
  Widget _buildMobileLayout(BuildContext context) {
    return Stack(
      children: [
        // Content Area
        Positioned.fill(
          child: _buildCurrentPage(),
        ),

        // Floating Frosted Mini-Player & Frosted Bottom Navigation Bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Floating Mini-Player
              const MiniPlayer(isDesktopDock: false),

              // Frosted Bottom Nav
              FrostedGlass(
                height: 64,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                backgroundColor: const Color(0x330B0F19),
                borderColor: AppColors.glassBorderSubtle,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomNavItem(0, Icons.home_rounded, 'Home'),
                    _buildBottomNavItem(1, Icons.search_rounded, 'Search'),
                    _buildBottomNavItem(2, Icons.library_music_rounded, 'Library'),
                    _buildBottomNavItem(3, Icons.settings_rounded, 'Settings'),
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
            color: isSelected ? AppColors.electricCyan : AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.electricCyan : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Desktop / TV Layout (>= 700px): Left Sidebar + Persistent Bottom Dock
  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Left Frosted Sidebar
              FrostedGlass(
                width: 250,
                borderRadius: BorderRadius.zero,
                backgroundColor: const Color(0x220B0F19),
                borderColor: AppColors.glassBorderSubtle,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Header
                    Row(
                      children: const [
                        AteXMonogram(size: 32),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'AteX Music',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Nav Links
                    _buildSidebarItem(0, Icons.home_rounded, 'Home'),
                    const SizedBox(height: 6),
                    _buildSidebarItem(1, Icons.search_rounded, 'Search'),
                    const SizedBox(height: 6),
                    _buildSidebarItem(2, Icons.library_music_rounded, 'Library'),
                    const SizedBox(height: 6),
                    _buildSidebarItem(3, Icons.settings_rounded, 'Settings'),

                    const SizedBox(height: 24),
                    const Divider(color: AppColors.glassBorder),
                    const SizedBox(height: 12),

                    // Quick Playlists Header
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(
                        'LOCAL PLAYLISTS',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView(
                        children: [
                          _buildQuickPlaylistTile('OLED Night Drive'),
                          _buildQuickPlaylistTile('Cyberpunk Workout'),
                          _buildQuickPlaylistTile('Lossless Favorites'),
                          _buildQuickPlaylistTile('Focus & Flowstate'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: _buildCurrentPage(),
              ),
            ],
          ),
        ),

        // Persistent Desktop Bottom Playback Dock
        const MiniPlayer(isDesktopDock: true),
      ],
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return FocusableCard(
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => setState(() => _currentIndex = index),
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.electricCyan : AppColors.textSecondary,
            size: 22,
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.electricCyan : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPlaylistTile(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }
}
