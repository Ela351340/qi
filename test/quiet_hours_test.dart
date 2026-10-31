import 'package:chat_app/core/notify/quiet_hours.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime at(int h, int m) => DateTime(2026, 1, 1, h, m);

void main() {
  group('时间解析', () {
    test('正常格式', () {
      expect(parseHhMm('23:00'), 1380);
      expect(parseHhMm('08:05'), 485);
      expect(parseHhMm('0:00'), 0);
    });

    test('非法输入返回 null', () {
      expect(parseHhMm(''), isNull);
      expect(parseHhMm('23'), isNull);
      expect(parseHhMm('24:00'), isNull);
      expect(parseHhMm('12:60'), isNull);
      expect(parseHhMm('ab:cd'), isNull);
    });

    test('格式化补零', () {
      expect(formatHhMm(0), '00:00');
      expect(formatHhMm(485), '08:05');
      expect(formatHhMm(1380), '23:00');
    });
  });

  group('免打扰判断', () {
    test('跨午夜：23:00 到 08:00', () {
      const s = '23:00';
      const e = '08:00';
      expect(isInQuietHours(now: at(23, 30), start: s, end: e), isTrue);
      expect(isInQuietHours(now: at(3, 0), start: s, end: e), isTrue);
      expect(isInQuietHours(now: at(7, 59), start: s, end: e), isTrue);
      expect(isInQuietHours(now: at(8, 0), start: s, end: e), isFalse);
      expect(isInQuietHours(now: at(12, 0), start: s, end: e), isFalse);
      expect(isInQuietHours(now: at(22, 59), start: s, end: e), isFalse);
    });

    test('同日区间：13:00 到 14:00', () {
      expect(isInQuietHours(now: at(12, 59), start: '13:00', end: '14:00'),
          isFalse);
      expect(isInQuietHours(now: at(13, 0), start: '13:00', end: '14:00'),
          isTrue);
      expect(isInQuietHours(now: at(13, 59), start: '13:00', end: '14:00'),
          isTrue);
      expect(isInQuietHours(now: at(14, 0), start: '13:00', end: '14:00'),
          isFalse);
    });

    test('起止相同视为关闭', () {
      expect(isInQuietHours(now: at(12, 0), start: '12:00', end: '12:00'),
          isFalse);
    });

    test('配置写错时当成没开，不要静默吞掉所有通知', () {
      expect(isInQuietHours(now: at(2, 0), start: 'bad', end: '08:00'),
          isFalse);
      expect(isInQuietHours(now: at(2, 0), start: '23:00', end: ''), isFalse);
    });
  });
}
