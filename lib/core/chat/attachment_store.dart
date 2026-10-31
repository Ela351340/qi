import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 聊天附件（图片 / 视频 / 文件）的本地存储。
///
/// 复制一份到应用目录，避免原文件被系统清理或在相册里被删后聊天记录裂图。
class AttachmentStore {
  static const String _folder = 'attachments';

  Future<Directory> directory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_folder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 保存一份副本，返回落盘后的文件
  Future<File> save(Uint8List bytes, String originalName) async {
    final dir = await directory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    // 保留扩展名，方便系统按类型识别
    final dot = originalName.lastIndexOf('.');
    final ext = dot >= 0 ? originalName.substring(dot) : '';
    final file = File('${dir.path}/${stamp}_${_safe(originalName)}$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// 直接复制一个已有文件（视频往往很大，不读进内存）
  Future<File> saveFromPath(String path, String originalName) async {
    final dir = await directory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final dot = originalName.lastIndexOf('.');
    final ext = dot >= 0 ? originalName.substring(dot) : '';
    final target = File('${dir.path}/${stamp}_${_safe(originalName)}$ext');
    await File(path).copy(target.path);
    return target;
  }

  String _safe(String name) {
    final base = name.contains('/') ? name.split('/').last : name;
    return base.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5.-]'), '_');
  }
}
