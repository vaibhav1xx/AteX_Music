import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:atex_music/main.dart';
import 'package:atex_music/core/widgets/shareable_song_card.dart';
import 'package:atex_music/core/widgets/shareable_rewind_card.dart';
import 'package:atex_music/features/player/widgets/audio_visualizer.dart';
import 'package:atex_music/data/models/track.dart';

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
    expect(find.text('Rewind'), findsOneWidget);
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
      expect(find.text('Your Library'), findsOneWidget);
      expect(find.text('Rewind & Stats'), findsOneWidget);
    },
  );

  testWidgets(
    'Typing "tum hi ho" in Search TextField updates text and preserves "m" and Space',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: AteXMusicApp()));
      await tester.pump(const Duration(milliseconds: 300));

      // Navigate to Search tab
      final searchNavFinder = find.widgetWithText(GestureDetector, 'Search');
      expect(searchNavFinder, findsWidgets);
      await tester.tap(searchNavFinder.first);
      await tester.pump(const Duration(milliseconds: 300));

      // Find Search TextField
      final searchFieldFinder = find.byType(TextField);
      expect(searchFieldFinder, findsOneWidget);

      // Focus and enter "tum hi ho" containing 'm' and spaces
      await tester.tap(searchFieldFinder);
      await tester.pump();
      await tester.enterText(searchFieldFinder, 'tum hi ho');
      await tester.pump(const Duration(milliseconds: 250));

      // Verify the text was accepted properly
      final textField = tester.widget<TextField>(searchFieldFinder);
      expect(textField.controller?.text, 'tum hi ho');
      expect(find.text('tum hi ho'), findsOneWidget);

      // Verify primaryFocus is an EditableText so global keyboard handler ignores typing keys
      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(
        primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() !=
            null,
        isTrue,
      );

      // Pump the fake clock past the 8-second YouTube search timeout before disposing widget tree
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('ShareableSongCard renders 9:16 layout cleanly', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const sampleTrack = Track(
      id: 'test_1',
      title: 'Obsidian Dreams',
      artist: 'AteX Producer',
      album: 'Studio Vault',
      duration: Duration(minutes: 3, seconds: 45),
      genre: 'Electronic',
      filePath: '/dummy/audio.mp3',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: ShareableSongCard(
                track: sampleTrack,
                lyricsSnippet: 'Digital audio flowing in high fidelity',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Obsidian Dreams'), findsOneWidget);
    expect(find.text('AteX Producer'), findsOneWidget);
    expect(find.text('AteX Music'), findsOneWidget);
  });

  testWidgets('ShareableRewindCard renders stats and badge cleanly', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: ShareableRewindCard(
                totalListeningMinutes: 1420,
                totalTracksPlayed: 185,
                listeningStreak: 12,
                topArtist: 'Synthesizer Lab',
                topTrackTitle: 'Electric Horizon',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('AteX Rewind'), findsOneWidget);
    expect(find.text('12 Days Streak 🔥'), findsOneWidget);
    expect(find.text('185'), findsOneWidget);
    expect(find.text('Synthesizer Lab'), findsOneWidget);
  });

  testWidgets(
    'AudioVisualizerView renders custom painters without exceptions',
    (WidgetTester tester) async {
      const sampleTrack = Track(
        id: 'test_2',
        title: 'Neon Pulse',
        artist: 'Cyber Sound',
        album: 'Obsidian Night',
        duration: Duration(minutes: 4, seconds: 12),
        genre: 'Synthwave',
        filePath: '/dummy/audio2.mp3',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AudioVisualizerView(
                isPlaying: true,
                position: Duration(seconds: 45),
                accentColor: Color(0xFF00E5FF),
                track: sampleTrack,
                size: 280,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AudioVisualizerView), findsOneWidget);
    },
  );
}
