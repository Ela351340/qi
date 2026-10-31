import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/memory_item.dart';

/// 外置记忆存储。
///
/// 以 markdown 文件为准（人可读、可改、可备份）：
///   <应用文档目录>/memory/facts.md
///   <应用文档目录>/memory/episodes.md
///   <应用文档目录>/memory/profile.md
///
/// 文件不可写时（web / 测试环境）自动退回 shared_preferences，
/// 这样同一套界面在哪儿都能跑。
class MemoryStore {
  static const String prefsKey = 'memory_items_v1';
  static const String dirName = 'memory';

  Future<Directory?> _dir() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}$dirName');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }

  static String fileNameOf(String category) {
    switch (category) {
      case MemoryItem.episode:
        return 'episodes.md';
      case MemoryItem.profile:
        return 'profile.md';
      case MemoryItem.fact:
      default:
        return 'facts.md';
    }
  }

  /// 记忆文件所在目录（给界面显示，让用户知道东西在哪）
  Future<String?> directoryPath() async {
    final dir = await _dir();
    return dir?.path;
  }

  Future<List<MemoryItem>> loadAll() async {
    final dir = await _dir();
    if (dir != null) {
      final items = <MemoryItem>[];
      for (final category in MemoryItem.categories) {
        final file =
            File('${dir.path}${Platform.pathSeparator}'
                '${fileNameOf(category)}');
        if (!await file.exists()) continue;
        final content = await file.readAsString();
        for (final line in content.split('\n')) {
          final item = MemoryItem.parseLine(line, category);
          if (item != null) items.add(item);
        }
      }
      if (items.isNotEmpty) return _sorted(items);
    }
    return _loadFromPrefs();
  }

  Future<void> saveAll(List<MemoryItem> items) async {
    await _saveToPrefs(items);
    final dir = await _dir();
    if (dir == null) return;
    for (final category in MemoryItem.categories) {
      final list = items.where((i) => i.category == category).toList();
      final buffer = StringBuffer()
        ..writeln('# ${MemoryItem.labelOf(category)}')
        ..writeln()
        ..writeln('<!-- 一行一条，格式：- [YYYY-MM-DD] 内容 | 来源。可以直接编辑 -->')
        ..writeln();
      for (final item in _sorted(list)) {
        buffer.writeln(item.toMarkdownLine());
      }
      final file = File(
        '${dir.path}${Platform.pathSeparator}${fileNameOf(category)}',
      );
      await file.writeAsString(buffer.toString());
    }
  }

  /// 导出成一段可读文本，方便用户复制走或存盘
  Future<String> exportText(List<MemoryItem> items) async {
    final buffer = StringBuffer();
    for (final category in MemoryItem.categories) {
      final list = _sorted(items.where((i) => i.category == category).toList());
      if (list.isEmpty) continue;
      buffer
        ..writeln('# ${MemoryItem.labelOf(category)}')
        ..writeln();
      for (final item in list) {
        buffer.writeln(item.toMarkdownLine());
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// 从文本解析（导入用）。容忍脏行，解析不出的直接跳过。
  List<MemoryItem> parseText(String text) {
    final items = <MemoryItem>[];
    var category = MemoryItem.fact;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('# ')) {
        final label = line.substring(2).trim();
        if (label == '事实') {
          category = MemoryItem.fact;
        } else if (label == '事件') {
          category = MemoryItem.episode;
        } else if (label == '画像') {
          category = MemoryItem.profile;
        }
        continue;
      }
      final item = MemoryItem.parseLine(line, category);
      if (item != null) items.add(item);
    }
    return _sorted(items);
  }

  List<MemoryItem> _sorted(List<MemoryItem> items) {
    final copy = List<MemoryItem>.from(items);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  Future<List<MemoryItem>> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return _sorted(decoded
          .whereType<Map>()
          .map((e) => MemoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList());
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveToPrefs(List<MemoryItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        prefsKey,
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }
}
