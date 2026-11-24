import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/track.dart';
import '../../../data/repositories/mock_music_repository.dart';

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

class PlayerNotifier extends StateNotifier<PlayerState> {
  Timer? _progressTimer;

  PlayerNotifier()
      : super(
          PlayerState(
            currentTrack: MockMusicRepository.sampleTracks.first,
            duration: MockMusicRepository.sampleTracks.first.duration,
            queue: MockMusicRepository.sampleTracks,
            queueIndex: 0,
            isPlaying: false,
          ),
        );

  void togglePlayPause() {
    if (state.isPlaying) {
      _stopTimer();
      state = state.copyWith(isPlaying: false);
    } else {
      state = state.copyWith(isPlaying: true);
      _startTimer();
    }
  }

  void playTrack(Track track) {
    final idx = state.queue.indexWhere((t) => t.id == track.id);
    _stopTimer();
    state = state.copyWith(
      currentTrack: track,
      duration: track.duration,
      position: Duration.zero,
      isPlaying: true,
      queueIndex: idx >= 0 ? idx : state.queueIndex,
    );
    _startTimer();
  }

  void seekTo(Duration position) {
    state = state.copyWith(position: position);
  }

  void next() {
    final nextIndex = (state.queueIndex + 1) % state.queue.length;
    final nextTrack = state.queue[nextIndex];
    playTrack(nextTrack);
    state = state.copyWith(queueIndex: nextIndex);
  }

  void previous() {
    if (state.position.inSeconds > 3) {
      seekTo(Duration.zero);
      return;
    }
    final prevIndex = (state.queueIndex - 1 + state.queue.length) % state.queue.length;
    final prevTrack = state.queue[prevIndex];
    playTrack(prevTrack);
    state = state.copyWith(queueIndex: prevIndex);
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  void cycleRepeatMode() {
    final next = switch (state.repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
  }

  void toggleFavorite() {
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
  }

  void toggleLyrics() {
    state = state.copyWith(isLyricsVisible: !state.isLyricsVisible);
  }

  void setVolume(double vol) {
    state = state.copyWith(volume: vol.clamp(0.0, 1.0));
  }

  void _startTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isPlaying) {
        timer.cancel();
        return;
      }
      final newSeconds = state.position.inSeconds + 1;
      if (newSeconds >= state.duration.inSeconds) {
        if (state.repeatMode == PlaybackRepeatMode.one) {
          seekTo(Duration.zero);
        } else {
          next();
        }
      } else {
        state = state.copyWith(position: Duration(seconds: newSeconds));
      }
    });
  }

  void _stopTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});
