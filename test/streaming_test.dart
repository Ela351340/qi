import 'dart:async';

import 'package:chat_app/core/llm/llm_client.dart';
import 'package:chat_app/features/chat/chat_page.dart';
import 'package:chat_app/models/chat_message.dart';
import 'package:chat_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(() async {
    useReducedMotion();
    await loadTestFonts();
  });

  Future<void> pumpChat(
    WidgetTester tester,
    Stream<LlmDelta> Function(List<ChatMessage>) override,
  ) async {
    tester.view.physicalSize = const Size(1440, 3168);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(
          fontFamily: 'AppFont',
          fontFamilyFallback: const ['AppEmoji'],
        ),
        home: ChatPage(streamOverride: override),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('发送后流式追加，逐字上屏', (tester) async {
    final controller = StreamController<LlmDelta>();
    await pumpChat(tester, (_) => controller.stream);
    addTearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    await tester.enterText(find.byType(TextField), '在吗');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pump();

    expect(find.text('在吗'), findsOneWidget);

    controller.add(const LlmDelta(content: '在的'));
    await tester.pump();
    expect(find.text('在的'), findsOneWidget);

    controller.add(const LlmDelta(content: '，怎么了？'));
    await tester.pump();
    expect(find.text('在的，怎么了？'), findsOneWidget);

    await controller.close();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ChatPage),
      matchesGoldenFile('goldens/after_send.png'),
    );
  });

  testWidgets('思考内容不显示，只等正文', (tester) async {
    final controller = StreamController<LlmDelta>();
    await pumpChat(tester, (_) => controller.stream);
    addTearDown(() async {
      if (!controller.isClosed) await controller.close();
    });

    await tester.enterText(find.byType(TextField), '测试思考');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pump();

    controller.add(const LlmDelta(reasoning: '用户问了一个问题，我需要'));
    await tester.pump();
    // 思考内容绝不出现在气泡里
    expect(find.textContaining('用户问了一个问题'), findsNothing);

    controller.add(const LlmDelta(content: '正文来了'));
    await tester.pump();
    expect(find.text('正文来了'), findsOneWidget);

    await controller.close();
    await tester.pumpAndSettle();
  });

  testWidgets('只有思考没有正文时，退化成显示思考内容', (tester) async {
    await pumpChat(
      tester,
      (_) => Stream<LlmDelta>.fromIterable(const [
        LlmDelta(reasoning: '这句话本来是想直接回答的'),
      ]),
    );

    await tester.enterText(find.byType(TextField), '测试退化');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    expect(find.text('这句话本来是想直接回答的'), findsOneWidget);
  });

  testWidgets('流报错时显示红色错误并可重试', (tester) async {
    var calls = 0;
    await pumpChat(tester, (_) {
      calls++;
      if (calls == 1) {
        return Stream<LlmDelta>.error('连不上「本地 Ollama」：测试错误');
      }
      return Stream<LlmDelta>.fromIterable(const [
        LlmDelta(content: '恢复了'),
      ]);
    });

    await tester.enterText(find.byType(TextField), '测试失败');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error), findsOneWidget);

    await tester.tap(find.byIcon(Icons.error));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.text('恢复了'), findsOneWidget);
  });
}
