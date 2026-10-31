import 'dart:math';

/// 表情标记的解析。
///
/// 协议参考 AstrBot 社区做法（memeify / meme_manager）：
/// 模型在回复里写 `[s:标签]`，前端把它连同内容一起从正文里删掉，
/// 再按标签找图。标签对不上就静默丢弃，绝不把标记显示给用户。
class StickerTag {
  /// 匹配 [s:xx]，标签里不允许出现 ] 和换行。
  static final RegExp pattern = RegExp(r'\[\s*s\s*[:：]\s*([^\]\r\n]{1,16})\s*\]');

  /// 从一段文本里抽出所有标签（按出现顺序，已去重前的原始顺序）。
  static List<String> extract(String text) {
    return pattern
        .allMatches(text)
        .map((m) => (m.group(1) ?? '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// 把标记从正文里删干净，顺带收拾多余的空白。
  static String strip(String text) {
    final cleaned = text.replaceAll(pattern, '');
    // 标记单独占一行时，删掉后会留下空行；聊天场景不需要空段，直接收掉。
    return cleaned
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
  }
}

/// 概率闸门：模型发了标记也要按概率决定是否真的发图。
/// 参考 meme_manager 的 generation.emotion.probability（35 ≈ 三条一张）。
class StickerGate {
  final Random _random;

  StickerGate({Random? random}) : _random = random ?? Random();

  /// [probability] 取 0–100。0 表示不发，100 表示有标记就发。
  bool shouldSend(int probability) {
    if (probability <= 0) return false;
    if (probability >= 100) return true;
    return _random.nextInt(100) < probability;
  }
}
