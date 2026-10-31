import 'package:chat_app/core/llm/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('多个完整 data 行', () {
    final p = SseParser();
    expect(p.add('data: {"a":1}\ndata: {"b":2}\n'), ['{"a":1}', '{"b":2}']);
  });

  test('一个 data 行被网络切成两半，不能提前解析', () {
    final p = SseParser();
    expect(p.add('data: {"he'), isEmpty);
    expect(p.add('llo":1}\n'), ['{"hello":1}']);
  });

  test('心跳行和 CRLF 要被忽略', () {
    final p = SseParser();
    expect(p.add(': keep-alive\r\n\r\ndata: x\r\n'), ['x']);
  });

  test('[DONE] 返回结束标记', () {
    final p = SseParser();
    expect(p.add('data: [DONE]\n'), [SseParser.done]);
  });

  test('flush 处理结尾没有换行的残留', () {
    final p = SseParser();
    expect(p.add('data: tail'), isEmpty);
    expect(p.flush(), ['tail']);
  });

  test('一行里既有半截又有完整行，只交完整的那个', () {
    final p = SseParser();
    expect(p.add('data: first\ndata: sec'), ['first']);
    expect(p.add('ond\n'), ['second']);
  });
}
