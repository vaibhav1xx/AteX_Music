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
  final double speed;
  final double pitch;
  final bool skipSilence;
  final int? sleepTimerMinutesRemaining;
  final DateTime? sleepTimerEndTime;
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
    this.speed = 1.0,
    this.pitch = 1.0,
    this.skipSilence = false,
    this.sleepTimerMinutesRemaining,
    this.sleepTimerEndTime,
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
    double? speed,
    double? pitch,
    bool? skipSilence,
    int? sleepTimerMinutesRemaining,
    DateTime? sleepTimerEndTime,
    bool clearSleepTimer = false,
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
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      skipSilence: skipSilence ?? this.skipSilence,
      sleepTimerMinutesRemaining:
          clearSleepTimer ? null : (sleepTimerMinutesRemaining ?? this.sleepTimerMinutesRemaining),
      sleepTimerEndTime:
          clearSleepTimer ? null : (sleepTimerEndTime ?? this.sleepTimerEndTime),
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
  StreamSubscription? _speedSub;

  Timer? _sleepTimer;
  Timer? _sleepTicker;

  bool _hasRecordedCurrentPlay = false;
  String? _lastTrackIdRecorded;

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
        speed: playbackState.speed,
      );
    });

    // 2. Real-time audio playback position stream
    _positionSub = _audioHandler.positionStream.listen((pos) {
      state = state.copyWith(position: pos);

      // Automatically record a play event whenever a track plays for more than 20 seconds
      if (!_hasRecordedCurrentPlay &&
          state.isPlaying &&
          pos.inSeconds >= 20 &&
          state.currentTrack.id != 'idle') {
        _hasRecordedCurrentPlay = true;
        _lastTrackIdRecorded = state.currentTrack.id;
        _database.recordListeningEvent(
          trackId: state.currentTrack.id,
          title: state.currentTrack.title,
          artist: state.currentTrack.artist,
          artworkUrl: state.currentTrack.localCoverPath,
          durationListenedMs: pos.inMilliseconds,
        );
      }
    });

    // 3. Track duration stream
    _durationSub = _audioHandler.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        state = state.copyWith(duration: dur);
      }
    });

    // 4. Speed stream updates
    _speedSub = _audioHandler.speedStream.listen((s) {
      state = state.copyWith(speed: s);
    });

    // 5. Current media item updates
    _mediaItemSub = _audioHandler.mediaItem.listen((item) {
      if (item != null) {
        if (_lastTrackIdRecorded != item.id) {
          _hasRecordedCurrentPlay = false;
        }
        final matchingIndex = state.queue.indexWhere((t) => t.id == item.id);
        if (matchingIndex >= 0) {
          final matchedTrack = state.queue[matchingIndex];
          state = state.copyWith(
            currentTrack: matchedTrack,
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
    _hasRecordedCurrentPlay = false;
    _lastTrackIdRecorded = track.id;
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
    _hasRecordedCurrentPlay = false;
    _lastTrackIdRecorded = tracks[startIndex].id;
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

    await _database.toggleTrackFavorite(updated.id);
  }

  void updateTrackMetadata(Track updated) {
    final updatedQueue = state.queue.map((t) => t.id == updated.id ? updated : t).toList();
    final updatedCurrent = state.currentTrack.id == updated.id ? updated : state.currentTrack;
    state = state.copyWith(
      currentTrack: updatedCurrent,
      queue: updatedQueue,
    );
  }

  Future<void> toggleTrackFavorite(Track track) async {
    final updated = track.copyWith(
      isFavorite: !track.isFavorite,
    );
    final updatedQueue = state.queue.map((t) {
      return t.id == updated.id ? updated : t;
    }).toList();
    final updatedCurrent =
        state.currentTrack.id == updated.id ? updated : state.currentTrack;

    state = state.copyWith(
      currentTrack: updatedCurrent,
      queue: updatedQueue,
    );

    await _database.toggleTrackFavorite(updated.id);
  }

  Future<void> playNext(Track track) async {
    if (state.queue.isEmpty) {
      await loadAndPlayQueue([track]);
      return;
    }
    final nextIndex = (state.queueIndex + 1).clamp(0, state.queue.length);
    final updatedQueue = List<Track>.from(state.queue)..insert(nextIndex, track);
    state = state.copyWith(queue: updatedQueue);
    await _audioHandler.insertTrack(nextIndex, track);
  }

  Future<void> addToQueue(Track track) async {
    if (state.queue.isEmpty) {
      await loadAndPlayQueue([track]);
      return;
    }
    final updatedQueue = List<Track>.from(state.queue)..add(track);
    state = state.copyWith(queue: updatedQueue);
    await _audioHandler.addTrack(track);
  }

  Future<void> seekRelative(Duration delta) async {
    final target = state.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > state.duration ? state.duration : target);
    await seekTo(clamped);
  }

  double _lastNonZeroVolume = 1.0;

  Future<void> adjustVolume(double delta) async {
    final target = (state.volume + delta).clamp(0.0, 1.0);
    if (target > 0) {
      _lastNonZeroVolume = target;
    }
    await setVolume(target);
  }

  Future<void> toggleMute() async {
    if (state.volume > 0.0) {
      _lastNonZeroVolume = state.volume;
      await setVolume(0.0);
    } else {
      await setVolume(_lastNonZeroVolume > 0.0 ? _lastNonZeroVolume : 0.5);
    }
  }

  void toggleLyrics() {
    state = state.copyWith(isLyricsVisible: !state.isLyricsVisible);
  }

  Future<void> setVolume(double vol) async {
    final clamped = vol.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    await _audioHandler.setVolume(clamped);
  }

  // -------------------------------------------------------------
  // Pro Playback Controls: Speed, Pitch, Skip Silence, Sleep Timer
  // -------------------------------------------------------------
  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    state = state.copyWith(speed: clamped);
    await _audioHandler.setSpeed(clamped);
  }

  Future<void> setPitch(double pitch) async {
    final clamped = pitch.clamp(0.5, 1.5);
    state = state.copyWith(pitch: clamped);
    await _audioHandler.setPitch(clamped);
  }

  Future<void> toggleSkipSilence() async {
    final newValue = !state.skipSilence;
    state = state.copyWith(skipSilence: newValue);
    await _audioHandler.setSkipSilence(newValue);
  }

  Future<void> setSkipSilence(bool enabled) async {
    state = state.copyWith(skipSilence: enabled);
    await _audioHandler.setSkipSilence(enabled);
  }

  void setSleepTimer(int minutes) {
    cancelSleepTimer();

    if (minutes <= 0) return;

    final endTime = DateTime.now().add(Duration(minutes: minutes));
    state = state.copyWith(
      sleepTimerMinutesRemaining: minutes,
      sleepTimerEndTime: endTime,
    );

    // Periodic ticker to decrement minutes remaining
    _sleepTicker = Timer.periodic(const Duration(seconds: 15), (timer) {
      final now = DateTime.now();
      final diff = endTime.difference(now);
      if (diff.isNegative || diff.inSeconds <= 0) {
        cancelSleepTimer();
        togglePlayPause();
      } else {
        final minsLeft = (diff.inSeconds / 60).ceil();
        state = state.copyWith(sleepTimerMinutesRemaining: minsLeft);
      }
    });

    // Exact timer when sleep time is up
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      cancelSleepTimer();
      _audioHandler.pause();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTicker?.cancel();
    _sleepTicker = null;
    state = state.copyWith(clearSleepTimer: true);
  }

  @override
  void dispose() {
    _playbackStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _mediaItemSub?.cancel();
    _speedSub?.cancel();
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  final db = ref.watch(appDatabaseProvider);
  return PlayerNotifier(audioHandler, db);
});
