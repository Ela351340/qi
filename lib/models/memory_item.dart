/// 一条记忆。
///
/// 设计原则照大肥鱼那套研究：记忆要「人工可管理」——
/// 用户能看见、能改、能删，而不是黑盒向量库。
class MemoryItem {
  /// 三类：事实 / 事件 / 画像
  final String category;
  final String text;
  final DateTime createdAt;

  /// 来源会话标题，便于追溯
  final String source;

  const MemoryItem({
    required this.category,
    required this.text,
    required this.createdAt,
    this.source = '',
  });

  static const String fact = 'fact';
  static const String episode = 'episode';
  static const String profile = 'profile';

  static const List<String> categories = [fact, episode, profile];

  static String labelOf(String category) {
    switch (category) {
      case fact:
        return '事实';
      case episode:
        return '事件';
      case profile:
        return '画像';
      default:
        return category;
    }
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'source': source,
      };

  factory MemoryItem.fromJson(Map<String, dynamic> j) => MemoryItem(
        category: (j['category'] ?? fact).toString(),
        text: (j['text'] ?? '').toString(),
        createdAt:
            DateTime.tryParse((j['createdAt'] ?? '').toString()) ??
                DateTime.now(),
        source: (j['source'] ?? '').toString(),
      );

  /// 写进 markdown 的一行，人能直接读和改
  String toMarkdownLine() {
    final d = '${createdAt.year}-${_two(createdAt.month)}-${_two(createdAt.day)}';
    final src = source.isEmpty ? '' : ' | $source';
    return '- [$d] $text$src';
  }

  /// 从 markdown 一行解析回来；解析不出返回 null（用户手改留下的脏行要能跳过）
  static MemoryItem? parseLine(String line, String category) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('- [')) return null;
    final close = trimmed.indexOf(']');
    if (close < 0) return null;
    final dateStr = trimmed.substring(3, close);
    var rest = trimmed.substring(close + 1).trim();
    var source = '';
    final pipe = rest.lastIndexOf(' | ');
    if (pipe >= 0) {
      source = rest.substring(pipe + 3).trim();
      rest = rest.substring(0, pipe).trim();
    }
    if (rest.isEmpty) return null;
    return MemoryItem(
      category: category,
      text: rest,
      createdAt: DateTime.tryParse(dateStr) ?? DateTime.now(),
      source: source,
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
