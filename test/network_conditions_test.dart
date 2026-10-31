import 'dart:io';

import 'package:chat_app/core/llm/llm_client.dart';
import 'package:chat_app/core/llm/llm_provider.dart';
import 'package:chat_app/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用本地 HTTP 服务模拟各种网络情况，验证客户端不会卡死、不会静默失败。
void main() {
  LlmProvider providerFor(int port) => LlmProvider(
        id: 'test',
        name: '测试服务',
        baseUrl: 'http://127.0.0.1:$port/v1',
        model: 'test-model',
      );

  List<ChatMessage> oneMessage() => [
        ChatMessage(
          role: ChatRole.user,
          text: '在吗',
          time: DateTime(2026, 1, 1),
        ),
      ];

  Future<HttpServer> serve(
    Future<void> Function(HttpRequest req) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) {
      handler(req).catchError((_) {});
    });
    return server;
  }

  test('服务没开 → 明确提示连不上', () async {
    final server = await serve((req) async {});
    final port = server.port;
    await server.close(force: true);

    final client = LlmClient();
    await expectLater(
      client
          .streamChat(
            provider: providerFor(port),
            systemPrompt: '',
            messages: oneMessage(),
          )
          .toList(),
      throwsA(
        isA<LlmException>().having((e) => e.message, 'message', contains('连不上')),
      ),
    );
    client.dispose();
  });

  test('401 → 鉴权失败', () async {
    final server = await serve((req) async {
      req.response.statusCode = 401;
      req.response.write('{"error":"invalid api key"}');
      await req.response.close();
    });
    final client = LlmClient();
    await expectLater(
      client
          .streamChat(
            provider: providerFor(server.port),
            systemPrompt: '',
            messages: oneMessage(),
          )
          .toList(),
      throwsA(
        isA<LlmException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', contains('鉴权失败')),
      ),
    );
    client.dispose();
    await server.close(force: true);
  });

  test('429 → 额度/限流提示', () async {
    final server = await serve((req) async {
      req.response.statusCode = 429;
      req.response.write('{"error":"rate limited"}');
      await req.response.close();
    });
    final client = LlmClient();
    await expectLater(
      client
          .streamChat(
            provider: providerFor(server.port),
            systemPrompt: '',
            messages: oneMessage(),
          )
          .toList(),
      throwsA(
        isA<LlmException>().having((e) => e.message, 'message', contains('429')),
      ),
    );
    client.dispose();
    await server.close(force: true);
  });

  test('500 → 服务端错误提示', () async {
    final server = await serve((req) async {
      req.response.statusCode = 500;
      req.response.write('boom');
      await req.response.close();
    });
    final client = LlmClient();
    await expectLater(
      client
          .streamChat(
            provider: providerFor(server.port),
            systemPrompt: '',
            messages: oneMessage(),
          )
          .toList(),
      throwsA(
        isA<LlmException>().having((e) => e.message, 'message', contains('服务端出错')),
      ),
    );
    client.dispose();
    await server.close(force: true);
  });

  test('服务器不响应 → 超时，而不是无限期卡住', () async {
    final server = await serve((req) async {
      // 故意什么都不回
      await Future<void>.delayed(const Duration(seconds: 5));
    });
    final client = LlmClient();
    final sw = Stopwatch()..start();
    await expectLater(
      client
          .streamChat(
            provider: providerFor(server.port),
            systemPrompt: '',
            messages: oneMessage(),
            requestTimeout: const Duration(milliseconds: 300),
          )
          .toList(),
      throwsA(
        isA<LlmException>().having((e) => e.message, 'message', contains('超时')),
      ),
    );
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(3000),
        reason: '超时应该在设定时间附近就抛，不能等到默认的 30 秒');
    client.dispose();
    await server.close(force: true);
  });

  test('流式中途断开（没有 [DONE]）→ 保留已收到内容，不抛异常', () async {
    final server = await serve((req) async {
      req.response.bufferOutput = false;
      req.response.headers.contentType =
          ContentType('text', 'event-stream', charset: 'utf-8');
      req.response.write(
        'data: {"choices":[{"delta":{"content":"前半句"}}]}\n\n',
      );
      await req.response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await req.response.close();
    });

    final client = LlmClient();
    final deltas = await client
        .streamChat(
          provider: providerFor(server.port),
          systemPrompt: '',
          messages: oneMessage(),
          idleTimeout: const Duration(seconds: 2),
        )
        .toList();

    expect(deltas.map((d) => d.content).join(), '前半句');
    client.dispose();
    await server.close(force: true);
  });

  test('坏分片被跳过，好分片照常送达', () async {
    final server = await serve((req) async {
      req.response.headers.contentType =
          ContentType('text', 'event-stream', charset: 'utf-8');
      req.response.write('data: 这不是JSON\n\n');
      req.response.write('data: {"choices":[{"delta":{"content":"好的"}}]}\n\n');
      req.response.write('data: [DONE]\n\n');
      await req.response.close();
    });

    final client = LlmClient();
    final deltas = await client
        .streamChat(
          provider: providerFor(server.port),
          systemPrompt: '',
          messages: oneMessage(),
        )
        .toList();

    expect(deltas.map((d) => d.content).join(), '好的');
    client.dispose();
    await server.close(force: true);
  });

  test('返回整体 JSON 而不是流 → 不崩，只是没有内容', () async {
    final server = await serve((req) async {
      req.response.headers.contentType = ContentType('application', 'json');
      req.response.write('{"error":{"message":"model not found"}}');
      await req.response.close();
    });

    final client = LlmClient();
    final deltas = await client
        .streamChat(
          provider: providerFor(server.port),
          systemPrompt: '',
          messages: oneMessage(),
        )
        .toList();

    expect(deltas, isEmpty);
    client.dispose();
    await server.close(force: true);
  });

  test('思考字段单独收，正文为空时不混进正文', () async {
    final server = await serve((req) async {
      req.response.headers.contentType =
          ContentType('text', 'event-stream', charset: 'utf-8');
      req.response.write(
        'data: {"choices":[{"delta":{"content":"","reasoning":"想一想"}}]}\n\n',
      );
      req.response.write(
        'data: {"choices":[{"delta":{"content":"答案"}}]}\n\n',
      );
      req.response.write('data: [DONE]\n\n');
      await req.response.close();
    });

    final client = LlmClient();
    final deltas = await client
        .streamChat(
          provider: providerFor(server.port),
          systemPrompt: '',
          messages: oneMessage(),
        )
        .toList();

    final content = deltas.map((d) => d.content).join();
    final reasoning = deltas.map((d) => d.reasoning).join();
    expect(content, '答案');
    expect(reasoning, '想一想');
    client.dispose();
    await server.close(force: true);
  });
}
