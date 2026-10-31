import 'package:chat_app/core/storage/settings_store.dart';
import 'package:chat_app/features/chat/chat_page.dart';
import 'package:chat_app/features/home/home_page.dart';
import 'package:chat_app/features/memory/memory_page.dart';
import 'package:chat_app/features/persona/persona_page.dart';
import 'package:chat_app/models/memory_item.dart';
import 'package:chat_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(() async {
    useReducedMotion();
    await loadTestFonts();
  });

  /// 直接挂具体页面，不受 App 首页路由变化影响。
  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    Brightness brightness = Brightness.light,
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
          brightness: brightness,
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester) => pumpPage(tester, const ChatPage());

  testWidgets('首页', (tester) async {
    await pumpPage(tester, const HomePage());
    await expectLater(
      find.byType(HomePage),
      matchesGoldenFile('goldens/home.png'),
    );
  });

  testWidgets('聊天界面（深色）', (tester) async {
    await pumpPage(tester, const ChatPage(), brightness: Brightness.dark);
    await expectLater(
      find.byType(ChatPage),
      matchesGoldenFile('goldens/chat_dark.png'),
    );
  });

  /// Image.asset 的解码走真实事件循环，pumpAndSettle 不会等它。
  /// 截图前先给它几次机会，否则图全是空白框。
  Future<void> settleImages(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('聊天界面', (tester) async {
    await pumpApp(tester);
    await expectLater(
      find.byType(ChatPage),
      matchesGoldenFile('goldens/chat.png'),
    );
  });

  testWidgets('表情面板', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined).last);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ChatPage),
      matchesGoldenFile('goldens/panel_emoji.png'),
    );
    await tester.tap(find.byIcon(Icons.folder_outlined));
    await tester.pumpAndSettle();
    await settleImages(tester);
    await expectLater(
      find.byType(ChatPage),
      matchesGoldenFile('goldens/panel_custom.png'),
    );
  });

  testWidgets('会话列表抽屉', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ChatPage),
      matchesGoldenFile('goldens/drawer.png'),
    );
  });

  testWidgets('人格卡片', (tester) async {
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
        home: PersonaPage(initial: defaultSettings(), onChanged: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PersonaPage),
      matchesGoldenFile('goldens/persona.png'),
    );
  });

  testWidgets('记忆页', (tester) async {
    tester.view.physicalSize = const Size(1440, 3168);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final items = [
      MemoryItem(
        category: MemoryItem.fact,
        text: '用户叫阿岚，做游戏策划',
        createdAt: DateTime(2026, 10, 28),
        source: '与云若的对话',
      ),
      MemoryItem(
        category: MemoryItem.fact,
        text: '养了一只名叫豆豆的猫',
        createdAt: DateTime(2026, 10, 30),
        source: '与云若的对话',
      ),
      MemoryItem(
        category: MemoryItem.episode,
        text: '约好周末去看海，如果不下雨',
        createdAt: DateTime(2026, 10, 29),
      ),
      MemoryItem(
        category: MemoryItem.profile,
        text: '怕冷，不喜欢被连续追问',
        createdAt: DateTime(2026, 10, 27),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(
          fontFamily: 'AppFont',
          fontFamilyFallback: const ['AppEmoji'],
        ),
        home: MemoryPage(
          initial: items,
          dirPath: '/data/user/0/app/files/memory',
          onChanged: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MemoryPage),
      matchesGoldenFile('goldens/memory.png'),
    );
  });
}
