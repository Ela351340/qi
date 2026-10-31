/// 免打扰时段判断。
///
/// [start] / [end] 是 "HH:mm" 字符串。跨午夜（23:00 → 08:00）要能正确处理。
/// 时间串解析不出来时返回 false —— 配错了就当没开，不要突然把通知全吞掉。
bool isInQuietHours({
  required DateTime now,
  required String start,
  required String end,
}) {
  final s = parseHhMm(start);
  final e = parseHhMm(end);
  if (s == null || e == null) return false;
  if (s == e) return false; // 起止相同视为关闭

  final m = now.hour * 60 + now.minute;
  if (s < e) return m >= s && m < e; // 同日区间
  return m >= s || m < e; // 跨午夜
}

/// "23:05" → 1385（分钟）。非法输入返回 null。
int? parseHhMm(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

/// 把分钟数格式化成 "HH:mm"。
String formatHhMm(int minutes) {
  final h = (minutes ~/ 60).clamp(0, 23);
  final m = (minutes % 60).clamp(0, 59);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}';
}
