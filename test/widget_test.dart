import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:atex_music/main.dart';

void main() {
  testWidgets('AteX Music launches shell on mobile viewport without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ProviderScope(child: AteXMusicApp()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('AteX Music'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets(
    'AteX Music launches shell on desktop viewport without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: AteXMusicApp()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('AteX Music'), findsWidgets);
      expect(find.text('LOCAL PLAYLISTS'), findsOneWidget);
    },
  );
}
