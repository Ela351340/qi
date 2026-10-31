import 'dart:math' as math;

import 'package:chat_app/core/theme/chat_schemes.dart';
import 'package:chat_app/features/chat/widgets/message_bubble.dart' show onColor;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 相对亮度与对比度
double _luminance(Color c) {
  double channel(double v) {
    final s = v / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.r * 255) +
      0.7152 * channel(c.g * 255) +
      0.0722 * channel(c.b * 255);
}

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('配色方案可读性', () {
    for (final scheme in ChatScheme.all) {
      test('${scheme.name}：两侧气泡文字都达到 4.5:1', () {
        for (final bubble in [scheme.selfBubble, scheme.otherBubble]) {
          final text = onColor(bubble);
          final ratio = contrastRatio(bubble, text);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${scheme.name} 气泡 $bubble 上文字对比度只有 '
                '${ratio.toStringAsFixed(2)}，会看不清',
          );
        }
      });

      test('${scheme.name}：气泡和背景能区分开', () {
        // 用 RGB 距离而不是纯亮度：WhatsApp 那样的米色背景+浅绿气泡，
        // 亮度接近但色相差别明显，纯亮度会误判。
        final dr = (scheme.selfBubble.r - scheme.bg.r) * 255;
        final dg = (scheme.selfBubble.g - scheme.bg.g) * 255;
        final db = (scheme.selfBubble.b - scheme.bg.b) * 255;
        final distance = math.sqrt(dr * dr + dg * dg + db * db);
        expect(distance, greaterThan(25),
            reason: '${scheme.name} 气泡和背景色差只有 '
                '${distance.toStringAsFixed(0)}，会糊在一起');
      });
    }

    test('方案 id 唯一', () {
      final ids = ChatScheme.all.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('按 id 能查回来', () {
      expect(ChatScheme.byId('linen')?.name, '亚麻');
      expect(ChatScheme.byId('nope'), isNull);
      expect(ChatScheme.byId(null), isNull);
    });
  });

  group('自动文字颜色', () {
    test('深底配白字，浅底配深字', () {
      expect(onColor(const Color(0xFF000000)), Colors.white);
      expect(onColor(const Color(0xFFFFFFFF)), const Color(0xFF101014));
      expect(onColor(const Color(0xFF0B93F6)), Colors.white);
      expect(onColor(const Color(0xFF95EC69)), const Color(0xFF101014));
    });
  });
}
