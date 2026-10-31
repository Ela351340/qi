import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 全屏看大图。左右可切、双指放大，点击空白关闭。
class ImageViewerPage extends StatelessWidget {
  final List<String> paths;
  final int initialIndex;

  const ImageViewerPage({
    super.key,
    required this.paths,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: paths.length,
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.file(
                  File(paths[i]),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Text(
                    '图片已不存在',
                    style: AppText.bodySmall.copyWith(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          if (paths.length > 1)
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '共 ${paths.length} 张',
                  style: AppText.meta.copyWith(color: c.textTertiary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
