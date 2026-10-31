import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/emoji/emoji_catalog.dart';
import '../../core/stickers/ai_sticker_store.dart';
import '../../models/sticker.dart';
import '../../shared/motion.dart';
import '../../theme/app_theme.dart';

/// 表情面板。
///
/// tab 0 = emoji（Twemoji 图片，跨平台一致）
/// tab 1 = 用户自己导入的表情（本地图片文件）
/// 内置的那套 AI 表情不在这里出现 —— 那是她发图用的，各有各的入口。
class StickerPanel extends StatefulWidget {
  final ValueChanged<EmojiItem> onPickEmoji;
  final VoidCallback onAddSticker;

  /// 点已导入的表情
  final ValueChanged<File>? onPickFileSticker;

  /// 点内置表情（传 asset 路径）
  final ValueChanged<String>? onPickAssetSticker;

  /// 长按删除
  final ValueChanged<File>? onDeleteSticker;

  /// 内置表情包（测试 / 老数据兼容用）
  final StickerPack? userPack;

  /// 用户自己导入的表情文件
  final List<File> userFiles;

  /// 她的表情库（内置，只读展示）
  final StickerPack? aiPack;

  /// 用户给她加的表情（按标签匹配）
  final List<AiSticker> aiUserStickers;

  /// 给她加一张 / 删一张
  final VoidCallback? onAddAiSticker;
  final ValueChanged<AiSticker>? onDeleteAiSticker;

  /// 附件：图片 / 视频 / 文件
  final VoidCallback? onPickImage;
  final VoidCallback? onPickVideo;
  final VoidCallback? onPickFile;

  /// 打开时默认停在哪个 tab（0 emoji / 1 我的 / 2 她的 / 3 附件）
  final int initialTab;

  /// 屏幕高度，用来算面板占多少
  final double screenHeight;

  const StickerPanel({
    super.key,
    required this.onPickEmoji,
    required this.onAddSticker,
    required this.screenHeight,
    this.onPickFileSticker,
    this.onPickAssetSticker,
    this.onDeleteSticker,
    this.userPack,
    this.userFiles = const [],
    this.aiPack,
    this.aiUserStickers = const [],
    this.onAddAiSticker,
    this.onDeleteAiSticker,
    this.onPickImage,
    this.onPickVideo,
    this.onPickFile,
    this.initialTab = 0,
  });

  @override
  State<StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends State<StickerPanel> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    // emoji 面板 25%（7 列小格够用），图片表情 40%（4 列大图）
    // emoji 矮一点，其它三种都是图片格子
    final factor = _tab == 0 ? 0.25 : 0.40;
    return slideFadeIn(
      context,
      AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: widget.screenHeight * factor,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(top: BorderSide(color: C.border, width: 1)),
        ),
        child: Column(
          children: [
            _tabBar(),
            Expanded(
              child: _tab == 0
                  ? _emojiGrid()
                  : _tab == 1
                      ? _customGrid()
                      : _tab == 2
                          ? _aiGrid()
                          : _attachGrid(),
            ),
          ],
        ),
      ),
      fromY: 0.18,
    );
  }

  Widget _tabBar() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 6),
          _tabButton(0, Icons.emoji_emotions_outlined),
          const SizedBox(width: 4),
          _tabButton(1, Icons.folder_outlined),
          const SizedBox(width: 4),
          // 她的表情库：只读，看看她会发什么
          _tabButton(2, Icons.auto_awesome_outlined),
          const SizedBox(width: 4),
          _tabButton(3, Icons.add_circle_outline_rounded),
          const Spacer(),
          if (_tab == 1)
            IconButton(
              onPressed: widget.onAddSticker,
              icon: const Icon(Icons.add_rounded, size: 20),
              color: C.textTertiary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              tooltip: '添加表情',
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _tabButton(int index, IconData icon) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 44,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 19,
          color: selected ? C.accent : C.textTertiary,
        ),
      ),
    );
  }

  Widget _emojiGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: kEmoji.length,
      itemBuilder: (context, i) {
        final e = kEmoji[i];
        return InkWell(
          onTap: () => widget.onPickEmoji(e),
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Image.asset(
              e.asset,
              width: 28,
              height: 28,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Icon(
                Icons.emoji_emotions_outlined,
                size: 22,
                color: C.textTertiary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _customGrid() {
    final files = widget.userFiles;
    final pack = widget.userPack;
    final stickers = pack?.stickers ?? const <Sticker>[];
    final hasBuiltin = pack != null && stickers.isNotEmpty;
    final total = stickers.length + files.length + 1; // 末尾留一格给"添加"

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: total,
      itemBuilder: (context, i) {
        // 第一格永远是「添加」，放最前面方便找到
        if (i == 0) {
          return GestureDetector(
            key: const Key('sticker-add'),
            onTap: widget.onAddSticker,
            child: Container(
              decoration: BoxDecoration(
                // 中性底色 + 细描边，不再用整块紫色（和表情图放一起太抢眼）
                color: C.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.borderStrong, width: 1),
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 24,
                color: C.textSecondary,
              ),
            ),
          );
        }

        // 自己添加的紧跟在后面（新的在最前，顺序由存储层保证）
        if (i <= files.length) {
          final f = files[i - 1];
          return _tile(
            child: Image.file(
              f,
              cacheWidth: 180,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.broken_image_outlined,
                size: 20,
                color: C.textTertiary,
              ),
            ),
            onTap: () => widget.onPickFileSticker?.call(f),
            onLongPress: () => widget.onDeleteSticker?.call(f),
          );
        }

        // 内置库排在最后
        if (hasBuiltin) {
          final s = stickers[i - 1 - files.length];
          return _tile(
            child: Image.asset(
              pack.assetPathOf(s),
              cacheWidth: 160,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.broken_image_outlined,
                size: 20,
                color: C.textTertiary,
              ),
            ),
            onTap: widget.onPickAssetSticker == null
                ? null
                : () => widget.onPickAssetSticker!(pack.assetPathOf(s)),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
  /// 她的表情库（只读）：让用户知道她手里有哪些图、什么标签
  Widget _aiGrid() {
    final pack = widget.aiPack;
    final stickers = pack?.stickers ?? const <Sticker>[];
    final custom = widget.aiUserStickers;
    final total = stickers.length + custom.length + 1; // +1 = 添加

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
          child: Text(
            '她只会从这里挑表情发（内置 ${stickers.length} 张'
            '${custom.isEmpty ? '' : ' + 你加的 ${custom.length} 张'}）',
            style: AppText.meta.copyWith(
              fontSize: 11,
              color: C.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: total,
            itemBuilder: (context, i) {
              // 第一格：给她加一张
              if (i == 0) {
                return GestureDetector(
                  key: const Key('ai-sticker-add'),
                  onTap: widget.onAddAiSticker,
                  child: Container(
                    decoration: BoxDecoration(
                      color: C.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.borderStrong),
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 24,
                      color: C.textSecondary,
                    ),
                  ),
                );
              }

              // 用户给她加的（排在前面，新的在前）
              if (i <= custom.length) {
                final a = custom[i - 1];
                return GestureDetector(
                  onLongPress: () => widget.onDeleteAiSticker?.call(a),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _tile(
                          child: Image.file(
                            a.file,
                            cacheWidth: 160,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.broken_image_outlined,
                              size: 20,
                              color: C.textTertiary,
                            ),
                          ),
                        ),
                      ),
                      _tagBadge(a.tag),
                    ],
                  ),
                );
              }

              // 内置表情
              final s = stickers[i - 1 - custom.length];
              return Stack(
                children: [
                  Positioned.fill(
                    child: _tile(
                      child: Image.asset(
                        pack!.assetPathOf(s),
                        cacheWidth: 160,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.broken_image_outlined,
                          size: 20,
                          color: C.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  // 标签角标：说明她靠这个标签匹配
                  Positioned(
                    left: 3,
                    right: 3,
                    bottom: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tagBadge(String tag) {
    return Positioned(
      left: 3,
      right: 3,
      bottom: 3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          tag,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, color: Colors.white),
        ),
      ),
    );
  }

  /// 附件：三个方形入口，和表情同一层
  Widget _attachGrid() {
    Widget box(IconData icon, String label, VoidCallback? tap, String key) {
      return Expanded(
        child: GestureDetector(
          key: ValueKey('attach-$key'),
          onTap: tap,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: C.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 26, color: C.accent),
                  const SizedBox(height: 8),
                  Text(label,
                      style:
                          AppText.meta.copyWith(color: C.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              '发点别的',
              style: AppText.sectionLabel.copyWith(color: C.textTertiary),
            ),
          ),
          Row(
            children: [
              box(Icons.image_outlined, '图片', widget.onPickImage, 'image'),
              const SizedBox(width: 12),
              box(Icons.videocam_outlined, '视频', widget.onPickVideo, 'video'),
              const SizedBox(width: 12),
              box(Icons.insert_drive_file_outlined, '文件', widget.onPickFile,
                  'file'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: C.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border, width: 1),
        ),
        padding: const EdgeInsets.all(3),
        child: child,
      ),
    );
  }
}
