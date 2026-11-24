import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/track.dart';
import '../services/audio_player_handler.dart';

enum PlaybackRepeatMode { off, all, one }

class PlayerState {
  final Track currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isShuffle;
  final PlaybackRepeatMode repeatMode;
  final double volume;
  final List<Track> queue;
  final int queueIndex;
  final bool isLyricsVisible;

  const PlayerState({
    required this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    required this.duration,
    this.isShuffle = false,
    this.repeatMode = PlaybackRepeatMode.all,
    this.volume = 1.0,
    required this.queue,
    this.queueIndex = 0,
    this.isLyricsVisible = false,
  });

  PlayerState copyWith({
    Track? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isShuffle,
    PlaybackRepeatMode? repeatMode,
    double? volume,
    List<Track>? queue,
    int? queueIndex,
    bool? isLyricsVisible,
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      volume: volume ?? this.volume,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      isLyricsVisible: isLyricsVisible ?? this.isLyricsVisible,
    );
  }

  double get progressFraction {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

final audioHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  // Safe default fallback handler for standalone or testing environments
  return AudioPlayerHandlerImpl();
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayerHandler _audioHandler;
  final AppDatabase _database;

  StreamSubscription? _playbackStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _mediaItemSub;

  static const idleTrack = Track(
    id: 'idle',
    title: 'No Track Playing',
    artist: 'AteX Music',
    album: 'Offline Audio Engine',
    duration: Duration.zero,
    genre: 'Offline',
    filePath: '',
    isFavorite: false,
  );

  PlayerNotifier(this._audioHandler, this._database)
      : super(
          const PlayerState(
            currentTrack: idleTrack,
            duration: Duration.zero,
            queue: [],
            queueIndex: 0,
            isPlaying: false,
          ),
        ) {
    _initSubscriptions();
  }

  void _initSubscriptions() {
    // 1. Playback state (playing, buffering, completed)
    _playbackStateSub = _audioHandler.playbackState.listen((playbackState) {
      final isPlaying = playbackState.playing;
      final qIndex = playbackState.queueIndex ?? state.queueIndex;

      state = state.copyWith(
        isPlaying: isPlaying,
        queueIndex: qIndex,
      );
    });

    // 2. Real-time audio playback position stream
    _positionSub = _audioHandler.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    // 3. Track duration stream
    _durationSub = _audioHandler.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        state = state.copyWith(duration: dur);
      }
    });

    // 4. Current media item updates
    _mediaItemSub = _audioHandler.mediaItem.listen((item) {
      if (item != null) {
        final matchingIndex = state.queue.indexWhere((t) => t.id == item.id);
        if (matchingIndex >= 0) {
          state = state.copyWith(
            currentTrack: state.queue[matchingIndex],
            queueIndex: matchingIndex,
            duration: item.duration ?? state.duration,
          );
        } else {
          // Construct Track from MediaItem
          final track = Track(
            id: item.id,
            title: item.title,
            artist: item.artist ?? 'Unknown Artist',
            album: item.album ?? 'Local Audio',
            duration: item.duration ?? Duration.zero,
            genre: (item.extras?['genre'] as String?) ?? 'Local Audio',
            filePath: (item.extras?['filePath'] as String?) ?? '',
            isFavorite: (item.extras?['isFavorite'] as bool?) ?? false,
          );
          state = state.copyWith(
            currentTrack: track,
            duration: track.duration,
          );
        }
      }
    });
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> playTrack(Track track) async {
    final idx = state.queue.indexWhere((t) => t.id == track.id);
    state = state.copyWith(
      currentTrack: track,
      duration: track.duration,
      position: Duration.zero,
      queueIndex: idx >= 0 ? idx : 0,
    );
    await _audioHandler.playTrack(track);
  }

  Future<void> loadAndPlayQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    state = state.copyWith(
      queue: tracks,
      queueIndex: startIndex,
      currentTrack: tracks[startIndex],
      duration: tracks[startIndex].duration,
      position: Duration.zero,
    );
    await _audioHandler.loadQueue(tracks, initialIndex: startIndex, autoPlay: true);
  }

  Future<void> seekTo(Duration position) async {
    state = state.copyWith(position: position);
    await _audioHandler.seek(position);
  }

  Future<void> next() async {
    await _audioHandler.skipToNext();
  }

  Future<void> previous() async {
    await _audioHandler.skipToPrevious();
  }

  Future<void> toggleShuffle() async {
    final newShuffle = !state.isShuffle;
    state = state.copyWith(isShuffle: newShuffle);
    await _audioHandler.setShuffleMode(
      newShuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
  }

  Future<void> cycleRepeatMode() async {
    final nextMode = switch (state.repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
    };
    state = state.copyWith(repeatMode: nextMode);

    final serviceMode = switch (nextMode) {
      PlaybackRepeatMode.off => AudioServiceRepeatMode.none,
      PlaybackRepeatMode.all => AudioServiceRepeatMode.all,
      PlaybackRepeatMode.one => AudioServiceRepeatMode.one,
    };
    await _audioHandler.setRepeatMode(serviceMode);
  }

  Future<void> toggleFavorite() async {
    final updated = state.currentTrack.copyWith(
      isFavorite: !state.currentTrack.isFavorite,
    );
    final updatedQueue = state.queue.map((t) {
      return t.id == updated.id ? updated : t;
    }).toList();

    state = state.copyWith(
      currentTrack: updated,
      queue: updatedQueue,
    );

    // Persist to local SQLite database
    await _database.toggleTrackFavorite(updated.id);
  }

  void toggleLyrics() {
    state = state.copyWith(isLyricsVisible: !state.isLyricsVisible);
  }

  Future<void> setVolume(double vol) async {
    final clamped = vol.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    await _audioHandler.setVolume(clamped);
  }

  @override
  void dispose() {
    _playbackStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _mediaItemSub?.cancel();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  final db = ref.watch(appDatabaseProvider);
  return PlayerNotifier(audioHandler, db);
});
