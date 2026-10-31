import 'dart:math';

import 'package:chat_app/core/llm/sticker_tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('提取标签', () {
    test('单个标签', () {
      expect(StickerTag.extract('今天好累啊[s:休息]'), ['休息']);
    });

    test('全角冒号和空格都能认', () {
      expect(StickerTag.extract('好开心 [ s ： 加油 ]'), ['加油']);
    });

    test('多个标签按顺序返回', () {
      expect(StickerTag.extract('[s:早安]早[s:加油]'), ['早安', '加油']);
    });

    test('正常方括号不该被误抓', () {
      expect(StickerTag.extract('这是[普通文字]不是标记'), isEmpty);
      expect(StickerTag.extract('看这个 [链接](https://x.com)'), isEmpty);
    });

    test('没有标签时返回空', () {
      expect(StickerTag.extract('普通一句话'), isEmpty);
    });
  });

  group('剔除标签', () {
    test('标记被删干净，正文保留', () {
      expect(StickerTag.strip('今天好累啊[s:休息]'), '今天好累啊');
    });

    test('只剩标记时返回空串', () {
      expect(StickerTag.strip('[s:晚安]'), '');
    });

    test('删掉标记后的空行会被收拾', () {
      expect(StickerTag.strip('第一行\n[s:生气]\n第三行'), '第一行\n第三行');
    });

    test('不会把普通方括号删掉', () {
      expect(StickerTag.strip('这是[普通文字]'), '这是[普通文字]');
    });
  });

  group('概率闸门', () {
    test('0 永远不发', () {
      final gate = StickerGate();
      for (var i = 0; i < 50; i++) {
        expect(gate.shouldSend(0), isFalse);
      }
    });

    test('100 永远发', () {
      final gate = StickerGate();
      for (var i = 0; i < 50; i++) {
        expect(gate.shouldSend(100), isTrue);
      }
    });

    test('35 大致落在三成附近', () {
      final gate = StickerGate(random: Random(42));
      var hits = 0;
      for (var i = 0; i < 2000; i++) {
        if (gate.shouldSend(35)) hits++;
      }
      // 2000 次下 35% 应该稳定在 30%-40%
      expect(hits, greaterThan(600));
      expect(hits, lessThan(800));
    });
  });
}
