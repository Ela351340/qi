import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/conversation.dart';

/// 会话持久化。目前用 shared_preferences 存一个 JSON 串，
/// 够用到几百个会话；再大再换 sqlite。
class ConversationStore {
  static const String storageKey = 'conversations_v1';

  Future<List<Conversation>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      // 插件不可用（比如没 mock 的测试环境）时降级为空，不能让首页崩。
      return const [];
    }
  }

  Future<void> save(List<Conversation> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        storageKey,
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // 存不进去不该影响聊天本身
    }
  }
}
