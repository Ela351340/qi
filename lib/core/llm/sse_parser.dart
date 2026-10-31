/// SSE（Server-Sent Events）增量解析。
///
/// 网络分片是任意切开的，一个 `data:` 行可能被切成两半，
/// 所以必须留着不完整的尾巴等下一块，不能直接按块解析。
class SseParser {
  static const String done = '__SSE_DONE__';

  final StringBuffer _pending = StringBuffer();

  /// 喂一块文本，返回本次能解析出的完整 data 载荷（不含 "data:" 前缀）。
  /// 遇到 `[DONE]` 时返回 [done]。
  List<String> add(String chunk) {
    _pending.write(chunk);
    final buffer = _pending.toString();
    final parts = buffer.split('\n');
    final rest = parts.removeLast(); // 可能是不完整的一行

    _pending
      ..clear()
      ..write(rest);

    final out = <String>[];
    for (final raw in parts) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty) continue;
      out.add(payload == '[DONE]' ? done : payload);
    }
    return out;
  }

  /// 流结束时调用，处理最后一小块没有换行符的残留。
  List<String> flush() {
    final leftover = _pending.toString().trim();
    _pending.clear();
    if (leftover.isEmpty) return const [];
    if (!leftover.startsWith('data:')) return const [];
    final payload = leftover.substring(5).trim();
    if (payload.isEmpty) return const [];
    return [payload == '[DONE]' ? done : payload];
  }
}
