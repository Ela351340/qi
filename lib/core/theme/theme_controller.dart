import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式：浅色（默认）/ 深色 / 跟随系统。
/// 单独存一个 key，不动 AppSettings 那一大坨结构。
class ThemeController {
  static const String prefsKey = 'theme_mode_v1';

  /// 当前模式字符串，供设置页显示勾选状态
  static final ValueNotifier<String> mode = ValueNotifier('light');

  static Brightness resolve(String mode) {
    switch (mode) {
      case 'dark':
        return Brightness.dark;
      case 'system':
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
      case 'light':
      default:
        return Brightness.light;
    }
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefsKey);
      if (saved == 'light' || saved == 'dark' || saved == 'system') {
        mode.value = saved!;
      }
    } catch (_) {
      // 读不到就用默认浅色
    }
  }

  static Future<void> set(String value) async {
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, value);
    } catch (_) {}
  }

  static String labelOf(String value) {
    switch (value) {
      case 'dark':
        return '深色';
      case 'system':
        return '跟随系统';
      default:
        return '浅色';
    }
  }
}
