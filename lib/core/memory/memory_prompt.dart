import '../../models/chat_message.dart';
import '../../models/memory_item.dart';

/// 把记忆拼成注入 system prompt 的一段。
///
/// 有字数上限：记忆无限长会把上下文吃光，也会稀释人设。
/// 这里自己按时间倒序排（不依赖调用方排序），超限就丢掉最老的。
String buildMemoryBlock(List<MemoryItem> items, {int maxChars = 1200}) {
  if (items.isEmpty) return '';
  final sorted = List<MemoryItem>.from(items)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final buffer = StringBuffer();
  var used = 0;
  for (final item in sorted) {
    final line = '- ${MemoryItem.labelOf(item.category)}：${item.text}\n';
    if (used + line.length > maxChars) break;
    buffer.write(line);
    used += line.length;
  }
  if (buffer.isEmpty) return '';
  return '## 你记得的事\n'
      '（这些是你和用户之间真实发生过的事，自然使用，不要复述清单）\n'
      '$buffer';
}

/// 让模型把对话总结成记忆条目的提示词。
String buildSummarizePrompt(List<ChatMessage> messages) {
  final transcript = StringBuffer();
  for (final m in messages) {
    if (m.role == ChatRole.system) continue;
    final who = m.role == ChatRole.user ? '用户' : '你';
    final text = m.isSticker ? '[表情包]' : (m.text ?? '');
    if (text.trim().isEmpty) continue;
    transcript.writeln('$who：$text');
  }
  return '下面是一段对话。请从中提炼出值得长期记住的信息，只输出条目，每行一条，'
      '格式严格为：\n'
      '[事实] 具体内容\n'
      '[事件] 具体内容\n'
      '[画像] 具体内容\n\n'
      '规则：\n'
      '- 事实：稳定的客观信息（名字、职业、住处、喜好、习惯、关系）\n'
      '- 事件：某天发生的事、约定、计划\n'
      '- 画像：性格倾向、情绪模式、忌讳、说话习惯\n'
      '- 只写有信息量的，没有就别写，最多 6 条\n'
      '- 不要写「用户说了什么」这种流水账，要写结论\n'
      '- 不要输出任何解释或标题\n\n'
      '对话：\n$transcript';
}

final RegExp _itemPattern =
    RegExp(r'^\s*[-*·]?\s*[\[【]\s*(事实|事件|画像)\s*[\]】]\s*(.+?)\s*$');

/// 解析模型返回的条目。容错：不认识的行直接跳过，前面带 `-` 也能认。
List<MemoryItem> parseExtracted(
  String raw, {
  String source = '',
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final items = <MemoryItem>[];
  for (final line in raw.split('\n')) {
    final m = _itemPattern.firstMatch(line.trim());
    if (m == null) continue;
    final label = m.group(1)!;
    final text = m.group(2)!.trim();
    if (text.isEmpty) continue;
    final category = switch (label) {
      '事实' => MemoryItem.fact,
      '事件' => MemoryItem.episode,
      _ => MemoryItem.profile,
    };
    items.add(MemoryItem(
      category: category,
      text: text,
      createdAt: at,
      source: source,
    ));
  }
  return items;
}
