import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 关掉入场动效。
///
/// flutter_animate 挂载时会排一个 0 延迟 Timer，用例结束时若仍挂着，
/// flutter_test 会判定为 pending timer 失败。走「减弱动态效果」这条路
/// 而不是改测试断言，因为这也是无障碍上正确的行为。
void useReducedMotion() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
}

/// golden 测试默认字体没有任何字形（全是方块），必须手动加载系统字体，
/// 否则截出来的图看不出排版好坏。图标字体同理，不加载就是方块。
Future<void> loadTestFonts() async {
  await _load('AppFont', [
    r'C:\Windows\Fonts\simhei.ttf',
    r'C:\Windows\Fonts\msyh.ttc',
    r'C:\Windows\Fonts\Deng.ttf',
  ]);
  await _load('AppEmoji', [
    r'C:\Windows\Fonts\seguiemj.ttf',
  ]);
  await _load('MaterialIcons', [
    r'D:\AI\An\aichat\toolchain\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
  ]);
}

Future<void> _load(String family, List<String> candidates) async {
  for (final path in candidates) {
    final file = File(path);
    if (!await file.exists()) continue;
    final bytes = await file.readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
    return;
  }
}
