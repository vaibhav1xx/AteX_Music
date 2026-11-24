import 'package:flutter/material.dart';

/// Responsive layout helper with 700px threshold.
/// Mobile (< 700px): Bottom navigation + floating mini-player.
/// Desktop / TV (>= 700px): Left sidebar navigation + persistent bottom playback dock.
class ResponsiveLayout extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints) mobile;
  final Widget Function(BuildContext context, BoxConstraints constraints) desktop;

  static const double breakpoint = 700.0;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.desktop,
  });

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= breakpoint;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < breakpoint;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return desktop(context, constraints);
        } else {
          return mobile(context, constraints);
        }
      },
    );
  }
}
