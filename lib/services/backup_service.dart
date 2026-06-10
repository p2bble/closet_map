import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import 'image_store.dart';

/// DB + 사진을 ZIP 하나로 백업/복원
class BackupService {
  static const _appId = 'closet_map';
  static const _dbName = 'closet_map.db';

  /// 복원 시 사진 절대경로를 재작성할 테이블 (테이블명: 이미지 컬럼명)
  static const _imageColumns = {
    'clothes': 'image_path',
    'storage_places': 'image_path',
  };

  static Future<String> _dbPath() async =>
      p.join(await getDatabasesPath(), _dbName);

  /// ZIP 생성 후 공유 시트 표시. 성공 시 null, 실패 시 사용자용 메시지 반환
  static Future<String?> exportBackup() async {
    try {
      await DatabaseService().close(); // 닫아서 WAL 내용까지 파일에 반영
      final dbFile = File(await _dbPath());
      if (!await dbFile.exists()) return '백업할 데이터가 없어요.';

      final tmp = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .substring(0, 16)
          .replaceAll(':', '-');
      final zipPath = p.join(tmp.path, '${_appId}_backup_$stamp.zip');

      final manifest = File(p.join(tmp.path, 'manifest.json'));
      await manifest.writeAsString(jsonEncode({
        'app': _appId,
        'created_at': DateTime.now().toIso8601String(),
      }));

      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await encoder.addFile(manifest);
      await encoder.addFile(dbFile, _dbName);
      final imagesDir = Directory(await ImageStore.imagesDirPath());
      if (await imagesDir.exists()) {
        for (final f in imagesDir.listSync().whereType<File>()) {
          await encoder.addFile(f, 'images/${p.basename(f.path)}');
        }
      }
      await encoder.close();

      await Share.shareXFiles([XFile(zipPath)], text: '옷장지도 백업');
      return null;
    } catch (e) {
      return '백업 생성에 실패했어요. ($e)';
    }
  }

  /// ZIP 선택 → 검증 → DB·사진 교체.
  /// 성공 시 null, 사용자가 선택을 취소하면 'cancelled', 실패 시 메시지 반환
  static Future<String?> importBackup() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      final path = picked?.files.single.path;
      if (path == null) return 'cancelled';

      final archive =
          ZipDecoder().decodeBytes(await File(path).readAsBytes());

      ArchiveFile? manifestEntry;
      ArchiveFile? dbEntry;
      for (final f in archive.files) {
        if (!f.isFile) continue;
        if (f.name == 'manifest.json') manifestEntry = f;
        if (f.name == _dbName) dbEntry = f;
      }
      if (manifestEntry == null || dbEntry == null) {
        return '올바른 백업 파일이 아니에요.';
      }
      final manifest =
          jsonDecode(utf8.decode(manifestEntry.content)) as Map<String, dynamic>;
      if (manifest['app'] != _appId) return '다른 앱의 백업 파일이에요.';

      // DB 파일 교체 (이후 첫 접근에서 재오픈되며 구버전이면 onUpgrade 수행)
      final db = DatabaseService();
      await db.close();
      await File(await _dbPath()).writeAsBytes(dbEntry.content, flush: true);

      // 사진 폴더 교체
      final imagesDirPath = await ImageStore.imagesDirPath();
      final imagesDir = Directory(imagesDirPath);
      if (await imagesDir.exists()) await imagesDir.delete(recursive: true);
      await imagesDir.create(recursive: true);
      for (final f in archive.files) {
        if (f.isFile && f.name.startsWith('images/')) {
          await File(p.join(imagesDirPath, p.basename(f.name)))
              .writeAsBytes(f.content);
        }
      }

      // 다른 기기 백업 대비: DB의 사진 절대경로를 현재 기기 경로로 재작성
      await _rewriteImagePaths(imagesDirPath);

      db.notifyDataChanged();
      return null;
    } catch (e) {
      return '복원에 실패했어요. 파일을 확인해주세요. ($e)';
    }
  }

  static Future<void> _rewriteImagePaths(String imagesDirPath) async {
    final d = await DatabaseService().db;
    for (final entry in _imageColumns.entries) {
      final table = entry.key;
      final col = entry.value;
      final rows = await d.query(table,
          columns: ['id', col], where: '$col IS NOT NULL');
      for (final row in rows) {
        final newPath = p.join(imagesDirPath, p.basename(row[col] as String));
        await d.update(
          table,
          {col: await File(newPath).exists() ? newPath : null},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }
}
