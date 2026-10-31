import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 是否允许播放入场动效。
///
/// 系统设置里开了「减弱动态效果」就不播 —— 这既是无障碍需求，
/// 也让测试能通过开关彻底跳过动画（否则 .animate() 会留下 pending timer）。
bool motionAllowed(BuildContext context) =>
    !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

/// 上滑淡入。用于消息气泡、表情面板。
Widget slideFadeIn(
  BuildContext context,
  Widget child, {
  Key? key,
  Duration duration = const Duration(milliseconds: 180),
  double fromY = 0.12,
}) {
  if (!motionAllowed(context)) return child;
  return child
      .animate(key: key)
      .fadeIn(duration: duration)
      .slideY(begin: fromY, end: 0, duration: duration, curve: Curves.easeOut);
}

/// 轻微放大淡入。用于表情包图片。
Widget popIn(
  BuildContext context,
  Widget child, {
  Key? key,
}) {
  if (!motionAllowed(context)) return child;
  return child
      .animate(key: key)
      .fadeIn(duration: const Duration(milliseconds: 200))
      .scale(
        begin: const Offset(0.88, 0.88),
        curve: Curves.easeOutBack,
        duration: const Duration(milliseconds: 240),
      );
}
