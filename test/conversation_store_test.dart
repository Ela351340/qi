import 'package:chat_app/core/storage/conversation_store.dart';
import 'package:chat_app/models/chat_message.dart';
import 'package:chat_app/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('会话存取往返，表情消息不丢', () async {
    final store = ConversationStore();
    final c = Conversation.empty(id: 'a');
    c.messages.add(ChatMessage(
      role: ChatRole.user,
      text: '你好',
      time: DateTime(2026, 1, 1, 10),
    ));
    c.messages.add(ChatMessage(
      role: ChatRole.bot,
      sticker: '😀',
      time: DateTime(2026, 1, 1, 10, 1),
    ));
    c.retitleIfNeeded();

    await store.save([c]);
    final loaded = await store.load();

    expect(loaded.length, 1);
    expect(loaded.first.title, '你好');
    expect(loaded.first.messages.length, 2);
    expect(loaded.first.messages[1].sticker, '😀');
  });

  test('标题只取第一次，不会每次覆盖', () async {
    final c = Conversation.empty(id: 'b');
    c.messages.add(ChatMessage(
      role: ChatRole.user,
      text: '第一句话',
      time: DateTime(2026, 1, 1),
    ));
    c.retitleIfNeeded();
    c.messages.add(ChatMessage(
      role: ChatRole.user,
      text: '第二句话',
      time: DateTime(2026, 1, 1),
    ));
    c.retitleIfNeeded();
    expect(c.title, '第一句话');
  });

  test('存储内容损坏时降级为空，不抛异常', () async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{ConversationStore.storageKey: 'not-json{{{'},
    );
    final store = ConversationStore();
    expect(await store.load(), isEmpty);
  });
}
