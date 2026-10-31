import 'dart:typed_data';

import 'dart:io';

import 'package:flutter/material.dart';

import '../image_viewer_page.dart';

import '../../../models/chat_message.dart';
import '../../../shared/motion.dart';
import '../../../theme/app_theme.dart';

/// 时间分隔：做成胶囊，比裸文字更有层次，也不会和消息混在一起。
class TimeDivider extends StatelessWidget {
  final DateTime time;
  const TimeDivider({super.key, required this.time});

  @override
  Widget build(BuildContext context) {
    final t = time;
    final text = '${t.year}/${_two(t.month)}/${_two(t.day)} '
        '${_two(t.hour)}:${_two(t.minute)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: C.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: AppText.meta.copyWith(
              fontSize: 11,
              color: C.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final double screenWidth;
  final VoidCallback? onRetry;

  /// 长按气泡（用于撤回/删除菜单）
  final VoidCallback? onLongPress;

  /// 头像图片；为空时退化成文字头像。
  final Uint8List? selfAvatar;
  final Uint8List? otherAvatar;
  final String selfLabel;
  final String otherLabel;

  /// 气泡颜色，用户可在设置里改。
  final Color? selfColor;
  final Color? otherColor;

  const MessageBubble({
    super.key,
    required this.message,
    required this.screenWidth,
    this.onRetry,
    this.onLongPress,
    this.selfAvatar,
    this.otherAvatar,
    this.selfLabel = '我',
    this.otherLabel = '云',
    this.selfColor,
    this.otherColor,
  });

  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRole.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            message.text ?? '',
            style: AppText.meta.copyWith(fontSize: 11),
          ),
        ),
      );
    }

    final isUser = message.role == ChatRole.user;
    final failed = message.status == ChatStatus.failed;
    final streaming = message.status == ChatStatus.streaming;
    final empty = (message.text ?? '').isEmpty;

    final fill = failed
        ? C.dangerSoft
        : (isUser
            ? (selfColor ?? C.accentSoft)
            : (otherColor ?? C.surface1));

    // 靠头像那一侧收一个小圆角，气泡就有方向感了
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppMetrics.bubbleRadius),
      topRight: const Radius.circular(AppMetrics.bubbleRadius),
      bottomLeft: Radius.circular(
        isUser ? AppMetrics.bubbleRadius : AppMetrics.bubbleTightRadius,
      ),
      bottomRight: Radius.circular(
        isUser ? AppMetrics.bubbleTightRadius : AppMetrics.bubbleRadius,
      ),
    );

    Widget content;
    if (message.hasAttachment) {
      content = _attachment(context, message);
    } else if (message.isSticker) {
      final raw = message.sticker!;
      content = SizedBox(
        width: 100,
        height: 100,
        child: raw.startsWith('assets/')
            ? popIn(
                context,
                Image.asset(
                  raw,
                  fit: BoxFit.contain,
                  // 表情最大显示 160dp，按 3 倍屏解码 480 足够
                  cacheWidth: 480,
                ),
              )
            : raw.startsWith('/')
                ? popIn(
                    context,
                    Image.file(
                      File(raw),
                      fit: BoxFit.contain,
                      cacheWidth: 480,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.broken_image_outlined,
                        size: 28,
                        color: C.textTertiary,
                      ),
                    ),
                  )
                : Center(
                    child: Text(raw, style: const TextStyle(fontSize: 64)),
                  ),
      );
    } else if (streaming && empty) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: fill, borderRadius: radius),
        child: const _TypingDots(),
      );
    } else {
      content = Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth * AppMetrics.bubbleMaxRatio,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: isUser || failed
              ? null
              : Border.all(color: C.border, width: 1),
        ),
        child: Text(
          message.text ?? '',
          style: failed
              ? AppText.body.copyWith(color: C.danger)
              : AppText.body.copyWith(color: onColor(fill)),
        ),
      );
    }

    // 长按气泡弹菜单（复制 / 撤回 / 删除）
    if (onLongPress != null) {
      content = GestureDetector(
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    final errorBadge = failed
        ? GestureDetector(
            onTap: onRetry,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(right: 6, top: 8),
              child: Icon(Icons.error, size: 18, color: C.danger),
            ),
          )
        : null;

    final avatar = _Avatar(
      bytes: isUser ? selfAvatar : otherAvatar,
      label: isUser ? selfLabel : otherLabel,
    );

    final bubble = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppMetrics.messageGap / 2),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isUser
            ? [
                ?errorBadge,
                Flexible(child: content),
                const SizedBox(width: AppMetrics.gap),
                avatar,
              ]
            : [
                avatar,
                const SizedBox(width: AppMetrics.gap),
                Flexible(child: content),
                ?errorBadge,
              ],
      ),
    );

    // key 只跟消息本身有关，流式更新文字时不会反复重播动画
    return slideFadeIn(
      context,
      bubble,
      key: ValueKey('${message.role}-${message.time.microsecondsSinceEpoch}'),
    );
  }
}

/// 等待首字时的三点动画。
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final step = (_c.value * 3).floor() % 3;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final on = i <= step;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on
                    ? C.textPrimary
                    : C.textTertiary.withValues(alpha: 0.5),
              ),
            );
          }),
        );
      },
    );
  }
}

/// 圆角方形头像（squircle），比正圆更有设计感，也和气泡圆角呼应。
/// 附件气泡：图片直接显示，视频/文件显示成卡片
  Widget _attachment(BuildContext context, ChatMessage m) {
    final path = m.attachment!;
    final kind = m.attachmentKind ?? AttachmentKind.file;

    if (kind == AttachmentKind.image) {
      return GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ImageViewerPage(paths: [path]),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path),
            width: 180,
            fit: BoxFit.cover,
            cacheWidth: 540,
            errorBuilder: (_, _, _) => Container(
              width: 180,
              height: 120,
              color: C.surface2,
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined,
                  size: 24, color: C.textTertiary),
            ),
          ),
        ),
      );
    }

    final isVideo = kind == AttachmentKind.video;
    final name = m.attachmentName ?? (isVideo ? '瑙嗛' : '鏂囦欢');
    final size = m.attachmentSize;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: C.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.play_circle_outline_rounded : Icons.insert_drive_file_outlined,
            size: 30,
            color: C.accent,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta.copyWith(color: C.textPrimary),
                ),
                if (size != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _readableSize(size),
                    style: AppText.meta.copyWith(
                      fontSize: 10,
                      color: C.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _readableSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
class _Avatar extends StatelessWidget {
  final Uint8List? bytes;
  final String label;

  const _Avatar({required this.bytes, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppMetrics.avatarSize,
      height: AppMetrics.avatarSize,
      decoration: BoxDecoration(
        color: C.surface2,
        borderRadius: BorderRadius.circular(AppMetrics.avatarRadius),
        border: Border.all(color: C.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: bytes == null
          ? Text(
              label.length > 1 ? label.characters.first : label,
              style: TextStyle(
                fontSize: 15,
                color: C.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          : Image.memory(
              bytes!,
              fit: BoxFit.cover,
              // 头像只有 38 逻辑像素，按 3 倍屏解码 120 就够了。
              // 之前用原图 + high 滤镜，长列表滚动时会卡。
              cacheWidth: 120,
              filterQuality: FilterQuality.medium,
            ),
    );
  }
}

/// Pick a readable text color for a bubble background.
Color onColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF101014);
