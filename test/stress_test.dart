import 'package:chat_app/core/storage/conversation_store.dart';
import 'package:chat_app/features/chat/chat_page.dart';
import 'package:chat_app/models/chat_message.dart';
import 'package:chat_app/models/conversation.dart';
import 'package:chat_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_fonts.dart';

/// 压力与安全测试：确认极端数据量不会把界面拖死。
/// 手机上最怕的就是这种场景 —— 内存吃爆、主线程卡住。
void main() {
  setUpAll(() async {
    useReducedMotion();
    await loadTestFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3168);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(fontFamily: 'AppFont'),
        home: const ChatPage(seedDemo: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('2000 条历史消息能渲染且不抛异常', (tester) async {
    final big = Conversation.empty(id: 'big');
    final t0 = DateTime(2026, 1, 1, 8);
    for (var i = 0; i < 2000; i++) {
      big.messages.add(ChatMessage(
        role: i.isEven ? ChatRole.user : ChatRole.bot,
        text: '第 $i 条消息，用来压一压渲染。',
        time: t0.add(Duration(minutes: i)),
      ));
    }
    await ConversationStore().save([big]);

    final sw = Stopwatch()..start();
    await pumpChat(tester);
    sw.stop();

    expect(tester.takeException(), isNull);
    // ignore: avoid_print
    print('2000 条消息首屏渲染耗时 ${sw.elapsedMilliseconds}ms');
    expect(sw.elapsedMilliseconds, lessThan(15000),
        reason: '首屏渲染超过 15 秒说明有性能问题');
  });

  testWidgets('超长单条消息不会撑破布局', (tester) async {
    final c = Conversation.empty(id: 'long');
    c.messages.add(ChatMessage(
      role: ChatRole.user,
      text: '超长' * 5000,
      time: DateTime(2026, 1, 1),
    ));
    await ConversationStore().save([c]);

    await pumpChat(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空会话显示正常，不崩', (tester) async {
    await ConversationStore().save([Conversation.empty(id: 'empty')]);
    await pumpChat(tester);
    expect(tester.takeException(), isNull);
  });
}
