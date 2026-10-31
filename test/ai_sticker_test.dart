import 'package:chat_app/core/llm/llm_client.dart';
import 'package:chat_app/core/stickers/sticker_catalog.dart';
import 'package:chat_app/features/chat/chat_page.dart';
import 'package:chat_app/models/chat_message.dart';
import 'package:chat_app/models/sticker.dart';
import 'package:chat_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_fonts.dart';

/// 测试用表情包：指向仓库里自带的 emoji 图，避免依赖第三方素材
StickerCatalog fakeCatalog() {
  const json = '''
{
  "packName": "test",
  "stickers": [
    {"id": "12", "file": "1f602.png", "label": "休息", "tags": ["休息", "困"]},
    {"id": "09", "file": "1f319.png", "label": "晚安", "tags": ["晚安", "睡觉"]}
  ]
}
''';
  return StickerCatalog(
    aiPack: StickerPack.fromJsonString(json, assetDir: 'assets/emoji'),
    userPack: StickerPack.fromJsonString(
        '{"packName":"","stickers":[]}', assetDir: 'assets/stickers/user'),
  );
}
/// AI 表情包（图片）是否真的出现在界面里。
void main() {
  setUpAll(() async {
    useReducedMotion();
    await loadTestFonts();
    // 预热表情包，避免用例在异步加载完成前就发送消息
    await StickerCatalog.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpChat(
    WidgetTester tester,
    Stream<LlmDelta> Function(List<ChatMessage>) override, {
    int probability = 100,
  }) async {
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
        home: ChatPage(
          streamOverride: override,
          stickerProbabilityOverride: probability,
          catalogOverride: fakeCatalog(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('模型输出 [s:休息] 时，标记被删掉并渲染出图片', (tester) async {
    await pumpChat(
      tester,
      (_) => Stream<LlmDelta>.fromIterable(const [
        LlmDelta(content: '今天好累啊'),
        LlmDelta(content: '[s:休息]'),
      ]),
    );

    await tester.enterText(find.byType(TextField), '累死了');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    // 正文里不能残留标记
    expect(find.textContaining('[s:休息]'), findsNothing);
    expect(find.text('今天好累啊'), findsOneWidget);
    // 应该出现一张表情图
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('标签对不上时静默丢弃，不显示标记也不报错', (tester) async {
    await pumpChat(
      tester,
      (_) => Stream<LlmDelta>.fromIterable(const [
        LlmDelta(content: '随便说说[s:不存在的标签]'),
      ]),
    );

    await tester.enterText(find.byType(TextField), '测试');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('不存在的标签'), findsNothing);
    expect(find.text('随便说说'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('概率为 0 时不发图，但正文照常显示', (tester) async {
    await pumpChat(
      tester,
      (_) => Stream<LlmDelta>.fromIterable(const [
        LlmDelta(content: '今天好累啊[s:休息]'),
      ]),
      probability: 0,
    );

    await tester.enterText(find.byType(TextField), '累死了');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    expect(find.text('今天好累啊'), findsOneWidget);
    // 面板没打开，正文里也不该有图片
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('整条回复只有一个表情时不留空气泡', (tester) async {
    await pumpChat(
      tester,
      (_) => Stream<LlmDelta>.fromIterable(const [
        LlmDelta(content: '[s:晚安]'),
      ]),
    );

    await tester.enterText(find.byType(TextField), '睡了');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    expect(find.text('（模型没有返回内容）'), findsNothing);
    expect(find.byType(Image), findsWidgets);
  });
}
