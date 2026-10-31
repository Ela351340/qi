import 'package:chat_app/features/chat/chat_page.dart';
import 'package:chat_app/features/home/home_page.dart';
import 'package:chat_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(() async {
    useReducedMotion();
    await loadTestFonts();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 3168);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(fontFamily: 'AppFont'),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('首次打开：默认会话直接显示在首页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpHome(tester);

    // 首页应该有「最近的对话」和一张卡片，而不是空空的引导语
    expect(find.text('最近的对话'), findsOneWidget);
    expect(find.byKey(const Key('new-chat')), findsOneWidget);
    // 种子会话标题里带着她名字
    expect(find.textContaining('的对话'), findsWidgets);
  });

  testWidgets('开始新对话：新建会话，不复用已有卡片', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('new-chat')));
    await tester.pumpAndSettle();

    expect(find.byType(ChatPage), findsOneWidget);

    // 返回首页：点我们自己画的返回箭头（不是 Cupertino 的）
    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await tester.pumpAndSettle();

    final tiles = find.textContaining('的对话');
    expect(tiles.evaluate().length, greaterThanOrEqualTo(2),
        reason: '新建对话后首页应该多一张卡片');
  });
}
