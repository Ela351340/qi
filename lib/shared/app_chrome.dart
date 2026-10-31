import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 让顶栏颜色一直铺到屏幕最顶端（状态栏区域），避免出现一条断层。
///
/// 用法：`statusBarFilled(context, color: C.surface3, child: _topBar())`
/// —— 传进来的顶栏本身**不要**再自己加状态栏内边距。
Widget statusBarFilled(
  BuildContext context, {
  required Color color,
  required Widget child,
}) {
  final top = MediaQuery.of(context).padding.top;
  return Container(
    color: color,
    padding: EdgeInsets.only(top: top),
    child: child,
  );
}

/// 底部同理：把颜色铺到手势条/导航栏区域，避免底部出现一条色差。
Widget bottomBarFilled(
  BuildContext context, {
  required Color color,
  required Widget child,
}) {
  final bottom = MediaQuery.of(context).padding.bottom;
  return Container(
    color: color,
    padding: EdgeInsets.only(bottom: bottom),
    child: child,
  );
}

/// 按明暗设置状态栏图标颜色（深色背景配白图标，浅色背景配黑图标）。
Widget appOverlay(BuildContext context, Widget child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    child: child,
  );
}
