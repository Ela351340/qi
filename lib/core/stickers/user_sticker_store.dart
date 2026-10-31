import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 用户自己导入的表情（图片文件）。
///
/// 存成文件而不是 base64：表情图多、图也大，塞进 SharedPreferences 会拖慢启动。
/// 位置：<应用文档目录>/stickers/user/
class UserStickerStore {
  static const String _folder = 'stickers/user';

  Future<Directory> directory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_folder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 按文件名排序，保证顺序稳定
  Future<List<File>> load() async {
    try {
      final dir = await directory();
      final files = await dir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      // 新的排在前面：按文件修改时间倒序（同等时间再按名字）
      files.sort((a, b) {
        final ta = a.statSync().modified;
        final tb = b.statSync().modified;
        final cmp = tb.compareTo(ta);
        return cmp != 0 ? cmp : b.path.compareTo(a.path);
      });
      return files;
    } catch (_) {
      return const [];
    }
  }

  /// 保存一张新表情，返回落盘后的文件
  Future<File?> add(Uint8List bytes, {String ext = 'png'}) async {
    try {
      final dir = await directory();
      final name = 'u_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 删不掉就算了，不影响使用
    }
  }
}
