import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import '../../../data/models/track.dart';

abstract class AudioPlayerHandler extends BaseAudioHandler {
  Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0, bool autoPlay = true});
  Future<void> playTrack(Track track);
  Future<void> insertTrack(int index, Track track);
  Future<void> addTrack(Track track);
  Future<void> setVolume(double volume);
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  AudioPlayer get player;
}

class AudioPlayerHandlerImpl extends AudioPlayerHandler {
  final AudioPlayer _player = AudioPlayer();
  List<Track> _tracks = [];
  ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);

  @override
  AudioPlayer get player => _player;

  AudioPlayerHandlerImpl() {
    _init();
  }

  Future<void> _init() async {
    // Audio Session for Android/iOS audio focus and background playback
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('AudioSession configuration error: $e');
    }

    // Broadcast playback state updates to AudioService
    _player.playbackEventStream.listen(_broadcastState);

    // Broadcast current track updates
    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _tracks.length) {
        mediaItem.add(_trackToMediaItem(_tracks[index]));
      }
    });

    // Listen to processing state completions
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0, bool autoPlay = true}) async {
    _tracks = List.from(tracks);
    final mediaItems = _tracks.map(_trackToMediaItem).toList();
    queue.add(mediaItems);

    final sources = <AudioSource>[];
    for (final t in _tracks) {
      sources.add(_createAudioSource(t));
    }

    _playlist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: sources,
    );

    try {
      await _player.setAudioSource(
        _playlist,
        initialIndex: initialIndex.clamp(0, _tracks.isEmpty ? 0 : _tracks.length - 1),
        initialPosition: Duration.zero,
      );

      if (initialIndex >= 0 && initialIndex < _tracks.length) {
        mediaItem.add(mediaItems[initialIndex]);
      }

      if (autoPlay) {
        await play();
      }
    } catch (e) {
      debugPrint('Error loading audio source queue: $e');
    }
  }

  @override
  Future<void> playTrack(Track track) async {
    final existingIndex = _tracks.indexWhere((t) => t.id == track.id);
    if (existingIndex >= 0) {
      await skipToQueueItem(existingIndex);
      await play();
    } else {
      final newTracks = [track, ..._tracks];
      await loadQueue(newTracks, initialIndex: 0, autoPlay: true);
    }
  }

  @override
  Future<void> insertTrack(int index, Track track) async {
    final clamped = index.clamp(0, _tracks.length);
    _tracks.insert(clamped, track);
    await _playlist.insert(clamped, _createAudioSource(track));
    queue.add(_tracks.map(_trackToMediaItem).toList());
  }

  @override
  Future<void> addTrack(Track track) async {
    _tracks.add(track);
    await _playlist.add(_createAudioSource(track));
    queue.add(_tracks.map(_trackToMediaItem).toList());
  }

  AudioSource _createAudioSource(Track track) {
    final uri = Uri.tryParse(track.filePath);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      return AudioSource.uri(uri, tag: _trackToMediaItem(track));
    }

    final file = File(track.filePath);
    if (file.existsSync()) {
      return AudioSource.file(file.path, tag: _trackToMediaItem(track));
    }

    // Fallback: If local file path doesn't exist on disk yet (mock track),
    // use a data URI or silent uri so the queue remains valid and non-crashing
    return AudioSource.uri(
      Uri.parse('https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3?filename=lofi-study-112191.mp3'),
      tag: _trackToMediaItem(track),
    );
  }

  MediaItem _trackToMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      album: track.album,
      title: track.title,
      artist: track.artist,
      duration: track.duration,
      artUri: track.localCoverPath != null && File(track.localCoverPath!).existsSync()
          ? Uri.file(track.localCoverPath!)
          : null,
      extras: {
        'filePath': track.filePath,
        'genre': track.genre,
        'isFavorite': track.isFavorite,
      },
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _tracks.length) {
      await _player.seek(Duration.zero, index: index);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all ||
        shuffleMode == AudioServiceShuffleMode.group;
    await _player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final queueIndex = event.currentIndex;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: queueIndex,
      ),
    );
  }
}

Future<AudioPlayerHandler> setupAudioService() async {
  if (!kIsWeb && Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized(windows: true);
  }

  return await AudioService.init(
    builder: () => AudioPlayerHandlerImpl(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.atex.atex_music.channel.audio',
      androidNotificationChannelName: 'AteX Music Playback',
      androidNotificationChannelDescription: 'Lossless offline audio playback engine',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
      notificationColor: Color(0xFF00E5FF),
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}
