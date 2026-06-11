import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/clothing.dart';
import 'image_store.dart';
import '../models/outfit.dart';
import '../models/storage_place.dart';
import '../models/storage_log.dart';
import '../models/storage_zone.dart';

/// 데이터 변경 시 notifyListeners()로 모든 탭에 갱신을 알린다 (IndexedStack stale 방지)
class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  Database? _db;
  bool _notifyScheduled = false;

  /// 백업/복원 등 외부에서 데이터가 통째로 바뀌었을 때 호출
  void notifyDataChanged() => _changed();

  /// DB 연결을 닫는다 (백업 전 WAL 반영, 복원 시 파일 교체용). 다음 접근 시 자동 재오픈.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// 연속 변경(일괄 처리 루프 등)을 마이크로태스크 단위로 묶어 한 번만 알림
  void _changed() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'closet_map.db'),
      version: 5,
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
            color INTEGER,
            image_path TEXT,
            memo TEXT,
            brand TEXT,
            purchase_price REAL,
            purchase_date TEXT,
            status INTEGER NOT NULL DEFAULT 0,
            storage_place_id INTEGER,
            storage_zone_id INTEGER,
            storage_note TEXT,
            created_at TEXT NOT NULL,
            wear_count INTEGER NOT NULL DEFAULT 0,
            last_worn_at TEXT,
            wear_count_since_wash INTEGER NOT NULL DEFAULT 0,
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
        await db.execute('''
          CREATE TABLE outfits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            memo TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE outfit_items (
            outfit_id INTEGER NOT NULL,
            clothing_id INTEGER NOT NULL,
            FOREIGN KEY (outfit_id) REFERENCES outfits(id),
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
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE clothes ADD COLUMN color INTEGER');
          await db.execute('ALTER TABLE clothes ADD COLUMN brand TEXT');
          await db.execute('ALTER TABLE clothes ADD COLUMN purchase_price REAL');
          await db.execute('ALTER TABLE clothes ADD COLUMN purchase_date TEXT');
          await db.execute('ALTER TABLE clothes ADD COLUMN last_worn_at TEXT');
          await db.execute('''
            CREATE TABLE outfits (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              memo TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE outfit_items (
              outfit_id INTEGER NOT NULL,
              clothing_id INTEGER NOT NULL,
              FOREIGN KEY (outfit_id) REFERENCES outfits(id),
              FOREIGN KEY (clothing_id) REFERENCES clothes(id)
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE clothes ADD COLUMN wear_count_since_wash INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  // ── StoragePlace ──────────────────────────────
  Future<int> insertPlace(StoragePlace p) async {
    final id = await (await db).insert('storage_places', p.toMap()..remove('id'));
    _changed();
    return id;
  }

  Future<List<StoragePlace>> getPlaces() async {
    final rows = await (await db).query('storage_places', orderBy: 'created_at DESC');
    return rows.map(StoragePlace.fromMap).toList();
  }

  Future<void> updatePlace(StoragePlace p) async {
    await (await db).update('storage_places', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
    _changed();
  }

  Future<void> deletePlace(int id) async {
    final d = await db;
    final rows = await d.query('storage_places',
        columns: ['image_path'], where: 'id = ?', whereArgs: [id]);
    await d.transaction((txn) async {
      // 이 장소(및 소속 구역)를 참조하는 옷의 위치 정보 해제
      await txn.rawUpdate('''
        UPDATE clothes SET storage_zone_id = NULL
        WHERE storage_zone_id IN
          (SELECT id FROM storage_zones WHERE storage_place_id = ?)
      ''', [id]);
      await txn.update(
        'clothes',
        {'storage_place_id': null},
        where: 'storage_place_id = ?',
        whereArgs: [id],
      );
      await txn.delete('storage_zones',
          where: 'storage_place_id = ?', whereArgs: [id]);
      await txn.delete('storage_places', where: 'id = ?', whereArgs: [id]);
    });
    if (rows.isNotEmpty) {
      await ImageStore.deleteIfExists(rows.first['image_path'] as String?);
    }
    _changed();
  }

  // ── StorageZone ───────────────────────────────
  Future<int> insertZone(StorageZone z) async {
    final id = await (await db).insert('storage_zones', z.toMap()..remove('id'));
    _changed();
    return id;
  }

  Future<List<StorageZone>> getZonesForPlace(int placeId) async {
    final rows = await (await db).query(
      'storage_zones',
      where: 'storage_place_id = ?',
      whereArgs: [placeId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(StorageZone.fromMap).toList();
  }

  Future<void> updateZone(StorageZone z) async {
    await (await db).update('storage_zones', z.toMap(), where: 'id = ?', whereArgs: [z.id]);
    _changed();
  }

  Future<void> deleteZone(int id) async {
    final d = await db;
    await d.update(
      'clothes',
      {'storage_zone_id': null},
      where: 'storage_zone_id = ?',
      whereArgs: [id],
    );
    await d.delete('storage_zones', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<int> countByZone(int zoneId) async {
    final result = await (await db).rawQuery(
        'SELECT COUNT(*) as cnt FROM clothes WHERE storage_zone_id = ?', [zoneId]);
    return result.first['cnt'] as int;
  }

  // ── Clothing ──────────────────────────────────
  Future<int> insertClothing(Clothing c) async {
    final id = await (await db).insert('clothes', c.toMap()..remove('id'));
    _changed();
    return id;
  }

  Future<List<Clothing>> getClothes({
    ClothingStatus? status,
    ClothingSeason? season,
    ClothingColor? color,
    String? nameQuery,
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
      // 쉼표 경계를 포함해 매칭 — 계절 enum이 두 자리 인덱스가 돼도 오매칭 방지
      conditions.add("(',' || seasons || ',') LIKE ?");
      args.add('%,${season.index},%');
    }
    if (color != null) {
      conditions.add('color = ?');
      args.add(color.index);
    }
    if (nameQuery != null && nameQuery.isNotEmpty) {
      conditions.add('name LIKE ?');
      args.add('%$nameQuery%');
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

  Future<void> bulkStore(
    List<int> ids,
    int placeId, {
    bool washedBefore = false,
    bool conditionGood = true,
    bool mothballAdded = false,
    String? memo,
  }) async {
    final d = await db;
    final now = DateTime.now().toIso8601String();
    await d.transaction((txn) async {
      for (final id in ids) {
        // 구역은 장소에 종속되므로 새 장소로 보관 시 기존 구역 배치를 해제
        await txn.update(
          'clothes',
          {
            'status': ClothingStatus.stored.index,
            'storage_place_id': placeId,
            'storage_zone_id': null,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.insert('storage_logs', {
          'clothing_id': id,
          'storage_place_id': placeId,
          'action': StorageAction.stored.index,
          'washed_before': washedBefore ? 1 : 0,
          'condition_good': conditionGood ? 1 : 0,
          'mothball_added': mothballAdded ? 1 : 0,
          'memo': memo,
          'action_at': now,
        });
      }
    });
    _changed();
  }

  Future<void> bulkRetrieve(List<int> ids) async {
    final d = await db;
    final now = DateTime.now().toIso8601String(); // storage_logs action_at 용
    await d.transaction((txn) async {
      for (final id in ids) {
        await txn.rawUpdate('''
          UPDATE clothes
          SET status = ?, storage_place_id = NULL, storage_zone_id = NULL
          WHERE id = ?
        ''', [ClothingStatus.active.index, id]);
        await txn.insert('storage_logs', {
          'clothing_id': id,
          'storage_place_id': null,
          'action': StorageAction.retrieved.index,
          'washed_before': null,
          'condition_good': null,
          'mothball_added': null,
          'memo': null,
          'action_at': now,
        });
      }
    });
    _changed();
  }

  Future<List<Clothing>> getNeglectedClothes({ClothingSeason? forSeason}) async {
    final sixMonthsAgo = DateTime.now()
        .subtract(const Duration(days: 180))
        .toIso8601String();
    final oneYearAgo = DateTime.now()
        .subtract(const Duration(days: 365))
        .toIso8601String();
    final seasonFilter = forSeason != null
        ? "AND ((',' || seasons || ',') LIKE '%,${forSeason.index},%' "
            "OR (',' || seasons || ',') LIKE '%,${ClothingSeason.all.index},%')"
        : '';
    final rows = await (await db).rawQuery('''
      SELECT * FROM clothes
      WHERE status = ${ClothingStatus.active.index}
      $seasonFilter
      AND (
        (wear_count = 0 AND created_at < ?) OR
        (wear_count > 0 AND (last_worn_at IS NULL OR last_worn_at < ?))
      )
      ORDER BY created_at ASC
    ''', [sixMonthsAgo, oneYearAgo]);
    return rows.map(Clothing.fromMap).toList();
  }

  Future<StorageLog?> getLastStoreLog(int clothingId) async {
    final rows = await (await db).query(
      'storage_logs',
      where: 'clothing_id = ? AND action = ?',
      whereArgs: [clothingId, StorageAction.stored.index],
      orderBy: 'action_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StorageLog.fromMap(rows.first);
  }

  Future<List<int>> getUnwashedStoredIds(List<int> clothingIds) async {
    if (clothingIds.isEmpty) return [];
    // 옷별 최신 보관 로그 중 미세탁(washed_before = 0)인 것만 — 단일 쿼리
    final placeholders = List.filled(clothingIds.length, '?').join(',');
    final rows = await (await db).rawQuery('''
      SELECT clothing_id FROM storage_logs
      WHERE clothing_id IN ($placeholders)
      AND washed_before = 0
      AND id IN (
        SELECT MAX(id) FROM storage_logs
        WHERE action = ${StorageAction.stored.index}
        GROUP BY clothing_id
      )
    ''', clothingIds);
    return rows.map((r) => r['clothing_id'] as int).toList();
  }

  Future<void> incrementWearCount(int id) async {
    await (await db).rawUpdate(
      'UPDATE clothes SET wear_count = wear_count + 1, wear_count_since_wash = wear_count_since_wash + 1, last_worn_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
    _changed();
  }

  Future<void> markAsWashed(int id) async {
    await (await db).rawUpdate(
      'UPDATE clothes SET wear_count_since_wash = 0 WHERE id = ?',
      [id],
    );
    _changed();
  }

  Future<List<Clothing>> getLaundryNeededClothes({int threshold = 3}) async {
    final rows = await (await db).rawQuery('''
      SELECT * FROM clothes
      WHERE status = ${ClothingStatus.active.index}
      AND wear_count_since_wash >= ?
      ORDER BY wear_count_since_wash DESC
    ''', [threshold]);
    return rows.map(Clothing.fromMap).toList();
  }

  Future<void> updateClothing(Clothing c) async {
    await (await db).update('clothes', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    _changed();
  }

  Future<void> deleteClothing(int id) async {
    final d = await db;
    final rows = await d.query('clothes',
        columns: ['image_path'], where: 'id = ?', whereArgs: [id]);
    await d.transaction((txn) async {
      await txn.delete('storage_logs',
          where: 'clothing_id = ?', whereArgs: [id]);
      await txn.delete('outfit_items',
          where: 'clothing_id = ?', whereArgs: [id]);
      await txn.delete('clothes', where: 'id = ?', whereArgs: [id]);
    });
    if (rows.isNotEmpty) {
      await ImageStore.deleteIfExists(rows.first['image_path'] as String?);
    }
    _changed();
  }

  // ── StorageLog ────────────────────────────────
  Future<void> insertLog(StorageLog log) async {
    await (await db).insert('storage_logs', log.toMap()..remove('id'));
    _changed();
  }

  Future<List<StorageLog>> getLogsForClothing(int clothingId) async {
    final rows = await (await db).query('storage_logs',
        where: 'clothing_id = ?',
        whereArgs: [clothingId],
        orderBy: 'action_at DESC');
    return rows.map(StorageLog.fromMap).toList();
  }

  /// 최근 보관 기록 (계절 허브 "지난 보관 기록"용)
  Future<List<StorageLog>> getRecentStoreLogs({int limit = 3}) async {
    final rows = await (await db).query('storage_logs',
        where: 'action = ?',
        whereArgs: [StorageAction.stored.index],
        orderBy: 'action_at DESC',
        limit: limit);
    return rows.map(StorageLog.fromMap).toList();
  }

  /// 특정 시점 이후의 보관/꺼내기 횟수 (계절 전환 진행률용)
  Future<int> countLogsSince(DateTime since) async {
    final rows = await (await db).rawQuery(
      'SELECT COUNT(*) AS cnt FROM storage_logs WHERE action_at >= ?',
      [since.toIso8601String()],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  Future<int> countByPlace(int placeId) async {
    final result = await (await db).rawQuery(
        'SELECT COUNT(*) as cnt FROM clothes WHERE storage_place_id = ? AND status = ?',
        [placeId, ClothingStatus.stored.index]);
    return result.first['cnt'] as int;
  }

  // ── Outfit ────────────────────────────────────
  Future<int> insertOutfit(Outfit o) async {
    final id = await (await db).insert('outfits', o.toMap()..remove('id'));
    _changed();
    return id;
  }

  Future<void> insertOutfitItem(int outfitId, int clothingId) async =>
      (await db).insert('outfit_items', {
        'outfit_id': outfitId,
        'clothing_id': clothingId,
      });

  Future<List<(Outfit, List<Clothing>)>> getRecentOutfits({int limit = 5}) async {
    final d = await db;
    final outfitRows = await d.query(
      'outfits',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    if (outfitRows.isEmpty) return [];
    // 코디별 N+1 대신 IN 절 JOIN 한 번으로 아이템을 모아 그룹핑
    final outfitIds = outfitRows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(outfitIds.length, '?').join(',');
    final itemRows = await d.rawQuery('''
      SELECT oi.outfit_id AS oi_outfit_id, c.* FROM clothes c
      INNER JOIN outfit_items oi ON c.id = oi.clothing_id
      WHERE oi.outfit_id IN ($placeholders)
    ''', outfitIds);
    final itemsByOutfit = <int, List<Clothing>>{};
    for (final row in itemRows) {
      itemsByOutfit
          .putIfAbsent(row['oi_outfit_id'] as int, () => [])
          .add(Clothing.fromMap(row));
    }
    return [
      for (final row in outfitRows)
        (Outfit.fromMap(row), itemsByOutfit[row['id'] as int] ?? []),
    ];
  }

  Future<void> deleteOutfit(int outfitId) async {
    final d = await db;
    await d.delete('outfit_items', where: 'outfit_id = ?', whereArgs: [outfitId]);
    await d.delete('outfits', where: 'id = ?', whereArgs: [outfitId]);
    _changed();
  }

  // ── 마이그레이션 ──────────────────────────────
  /// v1.7.1 이전에 캐시 경로로 저장된 사진을 앱 문서 폴더로 구출.
  /// 캐시에서 이미 지워진 사진은 경로를 NULL 처리해 깨진 이미지 표시를 막는다.
  /// 멱등적이므로 앱 시작 시마다 호출해도 안전하다.
  Future<int> migrateLegacyImages() async {
    final d = await db;
    final dirPath = await ImageStore.imagesDirPath();
    var migrated = 0;
    for (final table in ['clothes', 'storage_places']) {
      final rows = await d.query(table,
          columns: ['id', 'image_path'], where: 'image_path IS NOT NULL');
      for (final row in rows) {
        final path = row['image_path'] as String;
        if (isWithin(dirPath, path)) continue;
        final newPath = await ImageStore.persistPath(path);
        await d.update(table, {'image_path': newPath},
            where: 'id = ?', whereArgs: [row['id']]);
        migrated++;
      }
    }
    return migrated;
  }
}
