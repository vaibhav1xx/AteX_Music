import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('DbTrack')
class Tracks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text()();
  IntColumn get durationMs => integer()();
  TextColumn get localAudioPath => text()();
  TextColumn get localCoverPath => text().nullable()();
  TextColumn get localLyricsPath => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DbPlaylist')
class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get coverGradientIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get dateCreated => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PlaylistTracks extends Table {
  TextColumn get playlistId => text()();
  TextColumn get trackId => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {playlistId, trackId};
}

@DataClassName('DbRadioStation')
class RadioStations extends Table {
  TextColumn get stationUuid => text()();
  TextColumn get name => text()();
  TextColumn get streamUrl => text()();
  TextColumn get favicon => text().nullable()();
  TextColumn get tags => text().nullable()();
  TextColumn get country => text().nullable()();
  IntColumn get bitrate => integer().withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {stationUuid};
}

@DataClassName('DbListeningEvent')
class ListeningEvents extends Table {
  TextColumn get id => text()();
  TextColumn get trackId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get artworkUrl => text().nullable()();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get durationListenedMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DbUserSetting')
class UserSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class DailyListeningStat {
  final String dayLabel;
  final DateTime date;
  final int totalDurationMs;
  final int trackCount;

  const DailyListeningStat({
    required this.dayLabel,
    required this.date,
    required this.totalDurationMs,
    required this.trackCount,
  });

  double get durationMinutes => totalDurationMs / (1000 * 60);
  double get durationHours => totalDurationMs / (1000 * 60 * 60);
}

@DriftDatabase(tables: [Tracks, Playlists, PlaylistTracks, RadioStations, ListeningEvents, UserSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(tracks, tracks.playCount);
        await m.addColumn(tracks, tracks.lastPlayedAt);
        await m.createTable(radioStations);
      }
      if (from < 3) {
        await m.createTable(listeningEvents);
        await m.createTable(userSettings);
      }
    },
  );

  // -------------------------------------------------------------
  // Tracks Queries
  // -------------------------------------------------------------
  Stream<List<DbTrack>> watchAllTracks() {
    return (select(tracks)..orderBy([(t) => OrderingTerm.desc(t.dateAdded)])).watch();
  }

  Future<List<DbTrack>> getAllTracks() {
    return (select(tracks)..orderBy([(t) => OrderingTerm.desc(t.dateAdded)])).get();
  }

  Stream<List<DbTrack>> watchFavoriteTracks() {
    return (select(tracks)
          ..where((t) => t.isFavorite.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.dateAdded)]))
        .watch();
  }

  Future<DbTrack?> getTrackById(String id) {
    return (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertOrUpdateTrack(TracksCompanion track) {
    return into(tracks).insertOnConflictUpdate(track);
  }

  Future<void> insertOrUpdateTracks(List<TracksCompanion> trackList) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(tracks, trackList);
    });
  }

  Future<int> toggleTrackFavorite(String id) async {
    final track = await getTrackById(id);
    if (track == null) return 0;
    return (update(tracks)..where((t) => t.id.equals(id))).write(
      TracksCompanion(isFavorite: Value(!track.isFavorite)),
    );
  }

  Future<int> recordTrackPlay(String id) async {
    final track = await getTrackById(id);
    if (track == null) return 0;
    return (update(tracks)..where((t) => t.id.equals(id))).write(
      TracksCompanion(
        playCount: Value(track.playCount + 1),
        lastPlayedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> updateTrackMetadata({
    required String id,
    required String title,
    required String artist,
    required String album,
  }) {
    return (update(tracks)..where((t) => t.id.equals(id))).write(
      TracksCompanion(
        title: Value(title),
        artist: Value(artist),
        album: Value(album),
      ),
    );
  }

  Future<int> deleteTrack(String id) async {
    await (delete(playlistTracks)..where((pt) => pt.trackId.equals(id))).go();
    return (delete(tracks)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<DbTrack>> searchTracks(String query) {
    final search = '%${query.toLowerCase()}%';
    return (select(tracks)
          ..where((t) =>
              t.title.lower().like(search) |
              t.artist.lower().like(search) |
              t.album.lower().like(search))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch();
  }

  // -------------------------------------------------------------
  // Smart Auto-Mixes Queries
  // -------------------------------------------------------------
  Stream<List<DbTrack>> watchMostPlayedTracks({int limit = 50}) {
    return (select(tracks)
          ..orderBy([(t) => OrderingTerm.desc(t.playCount), (t) => OrderingTerm.desc(t.dateAdded)])
          ..limit(limit))
        .watch();
  }

  Stream<List<DbTrack>> watchRecentlyAddedTracks({int limit = 50}) {
    return (select(tracks)
          ..orderBy([(t) => OrderingTerm.desc(t.dateAdded)])
          ..limit(limit))
        .watch();
  }

  Stream<List<DbTrack>> watchForgottenGemsTracks({int limit = 50}) {
    return (select(tracks)
          ..orderBy([
            (t) => OrderingTerm(expression: t.lastPlayedAt, mode: OrderingMode.asc, nulls: NullsOrder.first),
            (t) => OrderingTerm.asc(t.dateAdded),
          ])
          ..limit(limit))
        .watch();
  }

  // -------------------------------------------------------------
  // Playlists Queries
  // -------------------------------------------------------------
  Stream<List<DbPlaylist>> watchPlaylists() {
    return (select(playlists)..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();
  }

  Future<List<DbPlaylist>> getAllPlaylists() {
    return (select(playlists)..orderBy([(p) => OrderingTerm.asc(p.name)])).get();
  }

  Future<int> createPlaylist(PlaylistsCompanion pl) {
    return into(playlists).insertOnConflictUpdate(pl);
  }

  Future<int> deletePlaylist(String playlistId) async {
    await (delete(playlistTracks)..where((pt) => pt.playlistId.equals(playlistId))).go();
    return (delete(playlists)..where((p) => p.id.equals(playlistId))).go();
  }

  Future<int> addTrackToPlaylist(String playlistId, String trackId, {int sortOrder = 0}) {
    return into(playlistTracks).insertOnConflictUpdate(
      PlaylistTracksCompanion(
        playlistId: Value(playlistId),
        trackId: Value(trackId),
        sortOrder: Value(sortOrder),
      ),
    );
  }

  Stream<List<DbTrack>> watchTracksForPlaylist(String playlistId) {
    final query = select(tracks).join([
      innerJoin(playlistTracks, playlistTracks.trackId.equalsExp(tracks.id)),
    ])
      ..where(playlistTracks.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistTracks.sortOrder)]);

    return query.watch().map((rows) => rows.map((r) => r.readTable(tracks)).toList());
  }

  Future<List<DbTrack>> getTracksForPlaylist(String playlistId) {
    final query = select(tracks).join([
      innerJoin(playlistTracks, playlistTracks.trackId.equalsExp(tracks.id)),
    ])
      ..where(playlistTracks.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistTracks.sortOrder)]);

    return query.get().then((rows) => rows.map((r) => r.readTable(tracks)).toList());
  }

  // -------------------------------------------------------------
  // Radio Stations Queries
  // -------------------------------------------------------------
  Stream<List<DbRadioStation>> watchFavoriteRadioStations() {
    return (select(radioStations)
          ..where((r) => r.isFavorite.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.name)]))
        .watch();
  }

  Future<List<DbRadioStation>> getFavoriteRadioStations() {
    return (select(radioStations)
          ..where((r) => r.isFavorite.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.name)]))
        .get();
  }

  Future<int> saveRadioStation(RadioStationsCompanion station) {
    return into(radioStations).insertOnConflictUpdate(station);
  }

  Future<int> toggleRadioStationFavorite({
    required String uuid,
    required String name,
    required String url,
    String? favicon,
    String? tags,
    String? country,
    int bitrate = 0,
  }) async {
    final existing = await (select(radioStations)..where((r) => r.stationUuid.equals(uuid))).getSingleOrNull();
    final newFav = existing != null ? !existing.isFavorite : true;
    return into(radioStations).insertOnConflictUpdate(
      RadioStationsCompanion(
        stationUuid: Value(uuid),
        name: Value(name),
        streamUrl: Value(url),
        favicon: Value(favicon),
        tags: Value(tags),
        country: Value(country),
        bitrate: Value(bitrate),
        isFavorite: Value(newFav),
      ),
    );
  }

  Future<bool> isRadioStationFavorite(String uuid) async {
    final station = await (select(radioStations)..where((r) => r.stationUuid.equals(uuid))).getSingleOrNull();
    return station?.isFavorite ?? false;
  }

  // -------------------------------------------------------------
  // Listening Events & Analytics Queries
  // -------------------------------------------------------------
  Future<void> recordListeningEvent({
    required String trackId,
    required String title,
    required String artist,
    String? artworkUrl,
    required int durationListenedMs,
  }) async {
    final eventId = 'evt_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();

    await transaction(() async {
      await into(listeningEvents).insert(
        ListeningEventsCompanion(
          id: Value(eventId),
          trackId: Value(trackId),
          title: Value(title),
          artist: Value(artist),
          artworkUrl: Value(artworkUrl),
          playedAt: Value(now),
          durationListenedMs: Value(durationListenedMs),
        ),
      );

      final track = await (select(tracks)..where((t) => t.id.equals(trackId))).getSingleOrNull();
      if (track != null) {
        await (update(tracks)..where((t) => t.id.equals(trackId))).write(
          TracksCompanion(
            playCount: Value(track.playCount + 1),
            lastPlayedAt: Value(now),
          ),
        );
      }
    });
  }

  Stream<List<DbListeningEvent>> watchAllListeningEvents() {
    return (select(listeningEvents)..orderBy([(e) => OrderingTerm.desc(e.playedAt)])).watch();
  }

  Future<List<DbListeningEvent>> getAllListeningEvents() {
    return (select(listeningEvents)..orderBy([(e) => OrderingTerm.desc(e.playedAt)])).get();
  }

  Future<int> getCurrentListeningStreak() async {
    final events = await (select(listeningEvents)..orderBy([(e) => OrderingTerm.desc(e.playedAt)])).get();
    if (events.isEmpty) return 0;

    final playedDates = <String>{};
    for (final e in events) {
      final d = e.playedAt;
      playedDates.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    DateTime checkDate;
    if (playedDates.contains(todayStr)) {
      checkDate = now;
    } else if (playedDates.contains(yesterdayStr)) {
      checkDate = yesterday;
    } else {
      return 0;
    }

    int streak = 0;
    while (true) {
      final dateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (playedDates.contains(dateStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  Future<List<MapEntry<String, int>>> getTopArtists({int limit = 5}) async {
    final events = await getAllListeningEvents();
    if (events.isEmpty) return [];

    final map = <String, int>{};
    for (final e in events) {
      final artistName = e.artist.trim();
      if (artistName.isNotEmpty && artistName != 'Unknown Artist') {
        map[artistName] = (map[artistName] ?? 0) + 1;
      }
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  Future<List<DbTrack>> getTopTracks({int limit = 10}) async {
    return (select(tracks)
          ..where((t) => t.playCount.isBiggerThanValue(0))
          ..orderBy([(t) => OrderingTerm.desc(t.playCount), (t) => OrderingTerm.desc(t.lastPlayedAt)])
          ..limit(limit))
        .get();
  }

  Future<List<DailyListeningStat>> getWeeklyListeningStats() async {
    final now = DateTime.now();
    final events = await getAllListeningEvents();

    final days = <DailyListeningStat>[];
    for (int i = 6; i >= 0; i--) {
      final dayDate = now.subtract(Duration(days: i));
      final dayStart = DateTime(dayDate.year, dayDate.month, dayDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      int durationMs = 0;
      int trackCount = 0;
      for (final e in events) {
        if (e.playedAt.isAfter(dayStart) && e.playedAt.isBefore(dayEnd)) {
          durationMs += e.durationListenedMs;
          trackCount++;
        }
      }

      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weekdayName = weekdays[dayDate.weekday - 1];
      days.add(DailyListeningStat(
        dayLabel: weekdayName,
        date: dayDate,
        totalDurationMs: durationMs,
        trackCount: trackCount,
      ));
    }
    return days;
  }

  // -------------------------------------------------------------
  // User Settings Queries
  // -------------------------------------------------------------
  Future<String?> getSetting(String key, {String? defaultValue}) async {
    final row = await (select(userSettings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value ?? defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    await into(userSettings).insertOnConflictUpdate(
      UserSettingsCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }

  Stream<String?> watchSetting(String key, {String? defaultValue}) {
    return (select(userSettings)..where((s) => s.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value ?? defaultValue);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'atex_music.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

AppDatabase? _dbInstance;

AppDatabase getAppDatabase() {
  return _dbInstance ??= AppDatabase();
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = getAppDatabase();
  return db;
});

final allTracksStreamProvider = StreamProvider<List<DbTrack>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllTracks();
});

final favoriteTracksStreamProvider = StreamProvider<List<DbTrack>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchFavoriteTracks();
});

final mostPlayedTracksStreamProvider = StreamProvider<List<DbTrack>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchMostPlayedTracks();
});

final recentlyAddedTracksStreamProvider = StreamProvider<List<DbTrack>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchRecentlyAddedTracks();
});

final forgottenGemsTracksStreamProvider = StreamProvider<List<DbTrack>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchForgottenGemsTracks();
});

final playlistsStreamProvider = StreamProvider<List<DbPlaylist>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchPlaylists();
});

final favoriteRadioStationsStreamProvider = StreamProvider<List<DbRadioStation>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchFavoriteRadioStations();
});

final listeningEventsStreamProvider = StreamProvider<List<DbListeningEvent>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllListeningEvents();
});
