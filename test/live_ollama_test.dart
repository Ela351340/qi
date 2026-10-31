import 'dart:io';

import 'package:chat_app/core/llm/llm_client.dart';
import 'package:chat_app/core/llm/llm_provider.dart';
import 'package:chat_app/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// 真实联调测试：连本机 Ollama。
/// 没开 Ollama 时自动跳过，不会让 CI 挂。
void main() {
  const provider = LlmProvider(
    id: 'ollama-local',
    name: '本地 Ollama（本机）',
    baseUrl: 'http://127.0.0.1:11434/v1',
    model: 'qwen3:8b',
  );

  Future<bool> ollamaAlive() async {
    try {
      final socket = await Socket.connect('127.0.0.1', 11434,
          timeout: const Duration(milliseconds: 800));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  test('真实流式：能收到分片并拼出非空回复', () async {
    if (!await ollamaAlive()) {
      markTestSkipped('本机 Ollama 没在监听 11434，跳过');
      return;
    }

    final client = LlmClient();
    final content = StringBuffer();
    final reasoning = StringBuffer();
    var deltaCount = 0;
    var contentCount = 0;
    final started = DateTime.now();

    await for (final d in client.streamChat(
      provider: provider,
      systemPrompt: '只回答一句话，不要解释。',
      messages: [
        ChatMessage(
          role: ChatRole.user,
          text: '用一句话说明现在几点了这个概念。',
          time: DateTime.now(),
        ),
      ],
      maxTokens: 800,
    )) {
      deltaCount++;
      if (d.content.isNotEmpty) {
        contentCount++;
        content.write(d.content);
      }
      if (d.reasoning.isNotEmpty) reasoning.write(d.reasoning);
    }
    client.dispose();

    final ms = DateTime.now().difference(started).inMilliseconds;

    // ignore: avoid_print
    print('分片=$deltaCount 含正文分片=$contentCount 耗时=${ms}ms');
    // ignore: avoid_print
    print('正文: ${content.toString()}');
    // ignore: avoid_print
    print('思考长度: ${reasoning.length}');

    expect(deltaCount, greaterThan(1), reason: '流式应该收到多个分片');
    expect(
      content.toString().trim().isNotEmpty || reasoning.toString().trim().isNotEmpty,
      isTrue,
      reason: '正文或思考至少得有一个，否则说明解析字段不对',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
