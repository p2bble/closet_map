import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/clothing.dart';
import '../models/storage_place.dart';
import '../models/storage_log.dart';

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
      version: 1,
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
          CREATE TABLE clothes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category INTEGER NOT NULL,
            seasons TEXT NOT NULL,
            image_path TEXT,
            memo TEXT,
            status INTEGER NOT NULL DEFAULT 0,
            storage_place_id INTEGER,
            storage_note TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (storage_place_id) REFERENCES storage_places(id)
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

  Future<void> deletePlace(int id) async =>
      (await db).delete('storage_places', where: 'id = ?', whereArgs: [id]);

  // ── Clothing ──────────────────────────────────
  Future<int> insertClothing(Clothing c) async =>
      (await db).insert('clothes', c.toMap()..remove('id'));

  Future<List<Clothing>> getClothes({ClothingStatus? status, int? placeId}) async {
    String? where;
    List<dynamic>? args;
    if (status != null && placeId != null) {
      where = 'status = ? AND storage_place_id = ?';
      args = [status.index, placeId];
    } else if (status != null) {
      where = 'status = ?';
      args = [status.index];
    } else if (placeId != null) {
      where = 'storage_place_id = ?';
      args = [placeId];
    }
    final rows = await (await db).query('clothes',
        where: where, whereArgs: args, orderBy: 'created_at DESC');
    return rows.map(Clothing.fromMap).toList();
  }

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
