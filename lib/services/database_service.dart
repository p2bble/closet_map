import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/clothing.dart';
import '../models/storage_place.dart';
import '../models/storage_log.dart';
import '../models/storage_zone.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'closet_map.db'),
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE storage_places (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            image_path TEXT,
            memo TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE storage_zones (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            storage_place_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            x REAL NOT NULL,
            y REAL NOT NULL,
            w REAL NOT NULL,
            h REAL NOT NULL,
            color_value INTEGER NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (storage_place_id) REFERENCES storage_places(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE clothes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category INTEGER NOT NULL,
            seasons TEXT NOT NULL,
            image_path TEXT,
            memo TEXT,
            status INTEGER NOT NULL DEFAULT 0,
            storage_place_id INTEGER,
            storage_zone_id INTEGER,
            storage_note TEXT,
            created_at TEXT NOT NULL,
            wear_count INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (storage_place_id) REFERENCES storage_places(id),
            FOREIGN KEY (storage_zone_id) REFERENCES storage_zones(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE storage_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            clothing_id INTEGER NOT NULL,
            storage_place_id INTEGER,
            action INTEGER NOT NULL,
            washed_before INTEGER,
            condition_good INTEGER,
            mothball_added INTEGER,
            memo TEXT,
            action_at TEXT NOT NULL,
            FOREIGN KEY (clothing_id) REFERENCES clothes(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE storage_zones (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              storage_place_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              x REAL NOT NULL,
              y REAL NOT NULL,
              w REAL NOT NULL,
              h REAL NOT NULL,
              color_value INTEGER NOT NULL,
              sort_order INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (storage_place_id) REFERENCES storage_places(id)
            )
          ''');
          await db.execute(
            'ALTER TABLE clothes ADD COLUMN storage_zone_id INTEGER',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE clothes ADD COLUMN wear_count INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  // ── StoragePlace ──────────────────────────────
  Future<int> insertPlace(StoragePlace p) async =>
      (await db).insert('storage_places', p.toMap()..remove('id'));

  Future<List<StoragePlace>> getPlaces() async {
    final rows = await (await db).query('storage_places', orderBy: 'created_at DESC');
    return rows.map(StoragePlace.fromMap).toList();
  }

  Future<void> updatePlace(StoragePlace p) async =>
      (await db).update('storage_places', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  Future<void> deletePlace(int id) async {
    final d = await db;
    await d.delete('storage_zones', where: 'storage_place_id = ?', whereArgs: [id]);
    await d.delete('storage_places', where: 'id = ?', whereArgs: [id]);
  }

  // ── StorageZone ───────────────────────────────
  Future<int> insertZone(StorageZone z) async =>
      (await db).insert('storage_zones', z.toMap()..remove('id'));

  Future<List<StorageZone>> getZonesForPlace(int placeId) async {
    final rows = await (await db).query(
      'storage_zones',
      where: 'storage_place_id = ?',
      whereArgs: [placeId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(StorageZone.fromMap).toList();
  }

  Future<void> updateZone(StorageZone z) async =>
      (await db).update('storage_zones', z.toMap(), where: 'id = ?', whereArgs: [z.id]);

  Future<void> deleteZone(int id) async =>
      (await db).delete('storage_zones', where: 'id = ?', whereArgs: [id]);

  Future<int> countByZone(int zoneId) async {
    final result = await (await db).rawQuery(
        'SELECT COUNT(*) as cnt FROM clothes WHERE storage_zone_id = ?', [zoneId]);
    return result.first['cnt'] as int;
  }

  // ── Clothing ──────────────────────────────────
  Future<int> insertClothing(Clothing c) async =>
      (await db).insert('clothes', c.toMap()..remove('id'));

  Future<List<Clothing>> getClothes({
    ClothingStatus? status,
    ClothingSeason? season,
    int? placeId,
    int? zoneId,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    if (status != null) {
      conditions.add('status = ?');
      args.add(status.index);
    }
    if (season != null) {
      conditions.add('seasons LIKE ?');
      args.add('%${season.index}%');
    }
    if (placeId != null) {
      conditions.add('storage_place_id = ?');
      args.add(placeId);
    }
    if (zoneId != null) {
      conditions.add('storage_zone_id = ?');
      args.add(zoneId);
    }
    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final rows = await (await db).query(
      'clothes',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(Clothing.fromMap).toList();
  }

  Future<void> incrementWearCount(int id) async =>
      (await db).rawUpdate(
        'UPDATE clothes SET wear_count = wear_count + 1 WHERE id = ?',
        [id],
      );

  Future<void> updateClothing(Clothing c) async =>
      (await db).update('clothes', c.toMap(), where: 'id = ?', whereArgs: [c.id]);

  Future<void> deleteClothing(int id) async =>
      (await db).delete('clothes', where: 'id = ?', whereArgs: [id]);

  // ── StorageLog ────────────────────────────────
  Future<void> insertLog(StorageLog log) async =>
      (await db).insert('storage_logs', log.toMap()..remove('id'));

  Future<List<StorageLog>> getLogsForClothing(int clothingId) async {
    final rows = await (await db).query('storage_logs',
        where: 'clothing_id = ?',
        whereArgs: [clothingId],
        orderBy: 'action_at DESC');
    return rows.map(StorageLog.fromMap).toList();
  }

  Future<int> countByPlace(int placeId) async {
    final result = await (await db).rawQuery(
        'SELECT COUNT(*) as cnt FROM clothes WHERE storage_place_id = ? AND status = ?',
        [placeId, ClothingStatus.stored.index]);
    return result.first['cnt'] as int;
  }
}
