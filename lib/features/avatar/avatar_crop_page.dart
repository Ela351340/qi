import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/app_theme.dart';

/// 头像裁剪（单一模式：完整显示 + 可放大移动）。
///
/// 规则：
/// 1. 一进来整张图**等比缩放到方框内**，一条边都不切，四周留白（透明）；
/// 2. 用户可以双指放大、拖动，自己决定要框哪一块；
/// 3. 选图阶段不做任何压缩，只有点了「完成」才按目标尺寸输出一次。
class AvatarCropPage extends StatefulWidget {
  final Uint8List bytes;

  /// 输出边长（压缩发生在这一步，之前不动原图）
  final int outputSize;

  /// 页内换一张图（返回 null 表示取消）
  final Future<Uint8List?> Function()? onPickAnother;

  const AvatarCropPage({
    super.key,
    required this.bytes,
    this.outputSize = 768,
    this.onPickAnother,
  });

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final GlobalKey _boxKey = GlobalKey();
  late Uint8List _bytes = widget.bytes;

  /// 原图宽高比，用来算"等比铺进方框"的大小
  double _aspect = 1;
  bool _decoded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    try {
      final codec = await ui.instantiateImageCodec(_bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _aspect = h == 0 ? 1 : w / h;
        _decoded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aspect = 1;
        _decoded = true;
      });
    }
  }

  Future<void> _confirm(double boxSize) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final boundary =
          _boxKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // 压缩只发生在这里：把方框里的画面渲染成 outputSize 见方
      final image = await boundary.toImage(
        pixelRatio: widget.outputSize / boxSize,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(data?.buffer.asUint8List());
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('处理失败，换张图试试')),
      );
    }
  }

  Future<void> _swap() async {
    final next = await widget.onPickAnother?.call();
    if (next == null || !mounted) return;
    setState(() {
      _bytes = next;
      _decoded = false;
    });
    await _measure();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final box = MediaQuery.of(context).size.width - 48;

    // 等比放进方框：宽图按宽铺满，高图按高铺满
    final double imgW = _aspect >= 1 ? box : box * _aspect;
    final double imgH = _aspect >= 1 ? box / _aspect : box;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface3,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('调整头像', style: AppText.title),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _busy ? null : () => _confirm(box),
            child: Text(
              _busy ? '处理中…' : '完成',
              style: TextStyle(
                color: c.accent,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 26),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 方框里看到的 = 最终头像；不画底色，留白就是透明
                RepaintBoundary(
                  key: _boxKey,
                  child: SizedBox(
                    width: box,
                    height: box,
                    child: ClipRect(
                      child: _decoded
                          ? InteractiveViewer(
                              minScale: 1,
                              maxScale: 5,
                              panEnabled: true,
                              scaleEnabled: true,
                              boundaryMargin: EdgeInsets.zero,
                              clipBehavior: Clip.none,
                              child: SizedBox(
                                width: box,
                                height: box,
                                child: Center(
                                  child: SizedBox(
                                    width: imgW,
                                    height: imgH,
                                    child: Image.memory(
                                      _bytes,
                                      fit: BoxFit.fill,
                                      gaplessPlayback: true,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.accent,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                // 圆角外框只是视觉提示，不进截图
                IgnorePointer(
                  child: Container(
                    width: box,
                    height: box,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '整张图已完整放入，可双指放大再拖动',
                style: AppText.meta.copyWith(color: c.textSecondary),
              ),
              if (widget.onPickAnother != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _swap,
                  child: Text(
                    '换一张',
                    style: AppText.meta.copyWith(
                      color: c.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '不放大时保留整张图；留白为透明；完成时才压缩到 768',
            style: AppText.meta.copyWith(fontSize: 11, color: c.textTertiary),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.textSecondary,
                        side: BorderSide(color: c.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : () => _confirm(box),
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _busy ? '处理中…' : '使用这张',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
