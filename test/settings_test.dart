import 'package:chat_app/core/storage/settings_store.dart';
import 'package:chat_app/features/settings/settings_page.dart';
import 'package:chat_app/models/app_settings.dart';
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('设置存取', () {
    test('默认值可用', () async {
      final s = await SettingsStore().load();
      expect(s.aiName, '阿栖');
      expect(s.providers.length, greaterThanOrEqualTo(3));
      expect(s.stickerProbability, 35);
      // 0 表示跟随主题，不写死颜色
      expect(s.bgColor, 0);
      expect(s.bgImageBase64, isNull);
    });

    test('往返不丢字段', () async {
      final store = SettingsStore();
      final s = defaultSettings().copyWith(
        aiName: '小满',
        userNick: '阿岚',
        stickerProbability: 70,
        bubbleSelfColor: 0xFF0A84FF,
        bubbleOtherColor: 0xFF31C48D,
        bgColor: 0xFF12161F,
        activeProviderId: 'dashscope',
        notifyEnabled: false,
        quietEnabled: true,
        quietStart: '22:30',
        quietEnd: '07:15',
      );
      await store.save(s);
      final loaded = await store.load();
      expect(loaded.aiName, '小满');
      expect(loaded.userNick, '阿岚');
      expect(loaded.stickerProbability, 70);
      expect(loaded.bubbleSelfColor, 0xFF0A84FF);
      expect(loaded.bubbleOtherColor, 0xFF31C48D);
      expect(loaded.bgColor, 0xFF12161F);
      expect(loaded.activeProviderId, 'dashscope');
      expect(loaded.notifyEnabled, isFalse);
      expect(loaded.quietEnabled, isTrue);
      expect(loaded.quietStart, '22:30');
      expect(loaded.quietEnd, '07:15');
    });

    test('存储损坏时回落到默认值', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{SettingsStore.storageKey: '{{{bad'},
      );
      final s = await SettingsStore().load();
      expect(s.aiName, '阿栖');
    });

    test('头像解码：坏数据返回 null 而不是抛异常', () {
      expect(AppSettings.decodeAvatar(null), isNull);
      expect(AppSettings.decodeAvatar(''), isNull);
      expect(AppSettings.decodeAvatar('!!!not-base64!!!'), isNull);
    });
  });

  group('设置页', () {
    late List<AppSettings> changed;

    Future<void> pumpPage(WidgetTester tester) async {
      changed = <AppSettings>[];
      final initial = defaultSettings();
      // 用一块很高的屏幕，让所有分组一次性建出来，测试不必折腾滚动
      tester.view.physicalSize = const Size(1440, 4500);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(
            fontFamily: 'AppFont',
            fontFamilyFallback: const ['AppEmoji'],
          ),
          home: SettingsPage(
            initial: initial,
            onChanged: (s) => changed.add(s),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('三个服务都列出来，并显示当前选中的那个', (tester) async {
      await pumpPage(tester);
      expect(find.text('本地 Ollama（本机）'), findsOneWidget);
      expect(find.text('本地 Ollama（局域网）'), findsOneWidget);
      expect(find.text('阿里云 DashScope'), findsOneWidget);
      // 选中那一行前面是勾
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('点另一个服务会切换选中', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('阿里云 DashScope'));
      await tester.pumpAndSettle();

      expect(changed, isNotEmpty);
      expect(changed.last.activeProviderId, 'dashscope');
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('色块在弹层里，点一下改对应的气泡颜色', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('气泡颜色'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('swatch-self-5')));
      await tester.pumpAndSettle();
      // 选色后会有一个 900ms 的小冒泡提示，等它走完，避免留下 pending timer
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(changed, isNotEmpty);
      expect(changed.last.bubbleSelfColor, isNot(0));
      // 只改自己那一侧，对方的不能被被动到
      expect(changed.last.bubbleOtherColor, 0);
    });

    testWidgets('按钮打开背景弹层，能看到纯色选项', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('聊天背景'));
      await tester.pumpAndSettle();

      expect(find.text('纯色'), findsOneWidget);
      expect(find.text('从相册选'), findsOneWidget);
    });
  });

  testWidgets('设置页快照', (tester) async {
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
        home: SettingsPage(initial: defaultSettings(), onChanged: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SettingsPage),
      matchesGoldenFile('goldens/settings.png'),
    );
  });
}
