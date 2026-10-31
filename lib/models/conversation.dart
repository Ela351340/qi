import 'chat_message.dart';

/// 一个会话。多会话是最小单位，标题自动取第一条用户消息。
class Conversation {
  final String id;
  String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;

  Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.empty({String? id}) {
    final now = DateTime.now();
    return Conversation(
      id: id ?? now.microsecondsSinceEpoch.toString(),
      title: '新对话',
      messages: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 从消息里推断标题，取第一条用户消息的前 16 个字。
  void retitleIfNeeded() {
    if (title != '新对话') return;
    for (final m in messages) {
      if (m.role == ChatRole.user && (m.text ?? '').trim().isNotEmpty) {
        final t = m.text!.trim().replaceAll('\n', ' ');
        title = t.length > 16 ? '${t.substring(0, 16)}…' : t;
        return;
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final raw = j['messages'];
    return Conversation(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '新对话').toString(),
      messages: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [],
      createdAt:
          DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse((j['updatedAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
