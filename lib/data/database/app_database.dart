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

@DriftDatabase(tables: [Tracks, Playlists, PlaylistTracks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

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

  Future<int> deleteTrack(String id) {
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

final playlistsStreamProvider = StreamProvider<List<DbPlaylist>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchPlaylists();
});
