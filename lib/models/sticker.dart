import 'dart:convert';

/// 单张表情。tags 是给模型看的可选项，label 是图片上原本的字。
class Sticker {
  final String id;
  final String file;
  final String label;
  final List<String> tags;

  const Sticker({
    required this.id,
    required this.file,
    required this.label,
    required this.tags,
  });

  factory Sticker.fromJson(Map<String, dynamic> j) => Sticker(
        id: (j['id'] ?? '').toString(),
        file: (j['file'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        tags: (j['tags'] is List)
            ? (j['tags'] as List).map((e) => e.toString()).toList()
            : const [],
      );
}

/// 一套表情包。AI 用的和用户用的分开成两个 pack。
class StickerPack {
  final String name;
  /// 资源根目录，例如 assets/stickers/ai
  final String assetDir;
  final List<Sticker> stickers;

  const StickerPack({
    required this.name,
    required this.assetDir,
    required this.stickers,
  });

  String assetPathOf(Sticker s) => '$assetDir/${s.file}';

  /// 标签 → 表情。一个标签可能对应多张（取第一张，稳定可预测）。
  Map<String, Sticker> get tagIndex {
    final map = <String, Sticker>{};
    for (final s in stickers) {
      map.putIfAbsent(s.label, () => s);
      for (final t in s.tags) {
        map.putIfAbsent(t, () => s);
      }
    }
    return map;
  }

  /// 给模型看的一行清单，尽量短，别占太多上下文。
  String get promptList => stickers.map((s) => s.label).join('、');

  static StickerPack fromJsonString(
    String raw, {
    required String assetDir,
  }) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final list = (j['stickers'] as List?) ?? const [];
    return StickerPack(
      name: (j['packName'] ?? '表情包').toString(),
      assetDir: assetDir,
      stickers: list
          .whereType<Map>()
          .map((e) => Sticker.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
