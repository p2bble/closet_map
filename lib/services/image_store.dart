import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// image_picker가 반환하는 경로는 앱 캐시 폴더라 OS가 언제든 삭제할 수 있다.
/// 사진은 반드시 앱 문서 폴더로 복사한 뒤 그 경로를 DB에 저장한다.
class ImageStore {
  static const _dirName = 'images';

  static Future<String> imagesDirPath() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _dirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// 캐시 등 외부 경로의 파일을 문서 폴더로 복사하고 새 경로를 반환.
  /// 이미 문서 폴더 안이면 그대로, 원본이 사라졌으면 null 반환.
  static Future<String?> persistPath(String srcPath) async {
    final dirPath = await imagesDirPath();
    if (p.isWithin(dirPath, srcPath)) return srcPath;
    final src = File(srcPath);
    if (!await src.exists()) return null;
    final name =
        '${DateTime.now().microsecondsSinceEpoch}_${p.basename(srcPath)}';
    final saved = await src.copy(p.join(dirPath, name));
    return saved.path;
  }

  static Future<String?> persist(XFile xfile) => persistPath(xfile.path);

  static Future<void> deleteIfExists(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // 파일 삭제 실패는 치명적이지 않으므로 무시
    }
  }
}
