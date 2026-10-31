import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 用户给「她」加的表情：图片 + 标签。
///
/// 和内置那套分开存：内置在 assets 里（只读），这里在应用目录，
/// 索引写成一个 JSON，方便增删和查询标签。
class AiStickerStore {
  static const String _folder = 'stickers/ai_user';
  static const String _indexFile = 'index.json';

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _index() async {
    final dir = await _dir();
    return File('${dir.path}/$_indexFile');
  }

  /// 读索引：[{file: 'xxx.png', tag: '开心'}]
  Future<List<AiSticker>> load() async {
    try {
      final f = await _index();
      if (!await f.exists()) return const [];
      final raw = await f.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      final dir = await _dir();
      final out = <AiSticker>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final path = '${dir.path}/${m['file']}';
        if (await File(path).exists()) {
          out.add(AiSticker(
            file: File(path),
            tag: (m['tag'] ?? '').toString(),
          ));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// 加一张：写文件 + 落索引
  Future<bool> add(Uint8List bytes, String tag) async {
    try {
      final dir = await _dir();
      final name = 'ai_${DateTime.now().microsecondsSinceEpoch}.png';
      await File('${dir.path}/$name').writeAsBytes(bytes, flush: true);

      final f = await _index();
      final list = <Map<String, dynamic>>[];
      if (await f.exists()) {
        final raw = await f.readAsString();
        for (final e in jsonDecode(raw) as List<dynamic>) {
          list.add(Map<String, dynamic>.from(e as Map));
        }
      }
      list.add({'file': name, 'tag': tag});
      await f.writeAsString(jsonEncode(list), flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 删一张：文件 + 索引一起删
  Future<void> remove(AiSticker sticker) async {
    try {
      if (await sticker.file.exists()) await sticker.file.delete();
      final f = await _index();
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) => '${m['file']}' != sticker.file.uri.pathSegments.last)
          .toList();
      await f.writeAsString(jsonEncode(list), flush: true);
    } catch (_) {
      // 失败就算了，不影响使用
    }
  }
}

class AiSticker {
  final File file;
  final String tag;

  const AiSticker({required this.file, required this.tag});
}
