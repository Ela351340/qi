import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/chat_message.dart';
import 'llm_provider.dart';
import 'sse_parser.dart';

/// 流式分片。Qwen3 这类带思考的模型会把过程放在 reasoning 里，
/// 正文在 content 里，所以两者都要接住。
class LlmDelta {
  final String content;
  final String reasoning;

  const LlmDelta({this.content = '', this.reasoning = ''});

  bool get isEmpty => content.isEmpty && reasoning.isEmpty;
}

class LlmException implements Exception {
  final String message;
  final int? statusCode;

  LlmException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// OpenAI 兼容接口客户端，支持流式。
class LlmClient {
  final http.Client _http;

  LlmClient({http.Client? client}) : _http = client ?? http.Client();

  void dispose() => _http.close();

  Stream<LlmDelta> streamChat({
    required LlmProvider provider,
    required String systemPrompt,
    required List<ChatMessage> messages,
    double temperature = 0.8,
    int maxTokens = 1024,
    /// 多久没拿到响应头就放弃
    Duration requestTimeout = const Duration(seconds: 30),
    /// 流式中途多久没有新数据就放弃
    Duration idleTimeout = const Duration(seconds: 60),
  }) async* {
    final uri = Uri.parse('${provider.normalizedBaseUrl}/chat/completions');

    final payload = jsonEncode({
      'model': provider.model,
      'stream': true,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        ...messages
            .where((m) => m.role != ChatRole.system && m.text != null)
            .map((m) => {
                  'role': m.role == ChatRole.user ? 'user' : 'assistant',
                  'content': m.text,
                }),
      ],
      // 各家私有开关，比如 Ollama 的 think:false
      ...provider.extraBody,
    });

    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = payload;

    if (provider.apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${provider.apiKey}';
    }

    http.StreamedResponse response;
    try {
      response = await _http.send(request).timeout(requestTimeout);
    } on TimeoutException {
      throw LlmException(
        '连接「${provider.name}」超时：${requestTimeout.inSeconds} 秒内没有响应。'
        '检查服务是否在运行、地址端口对不对、手机和电脑是否在同一个网络。',
      );
    } catch (e) {
      throw LlmException(
        '连不上「${provider.name}」（$uri）：${_networkHint(provider)}\n$e',
      );
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw LlmException(
        _httpErrorMessage(response.statusCode, body),
        statusCode: response.statusCode,
      );
    }

    final parser = SseParser();
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final payloadLine in parser.add(chunk)) {
        if (payloadLine == SseParser.done) return;
        final delta = _extractDelta(payloadLine);
        if (delta != null && !delta.isEmpty) yield delta;
      }
    }
    for (final payloadLine in parser.flush()) {
      if (payloadLine == SseParser.done) return;
      final delta = _extractDelta(payloadLine);
      if (delta != null && !delta.isEmpty) yield delta;
    }
  }

  static LlmDelta? _extractDelta(String json) {
    try {
      final j = jsonDecode(json);
      if (j is! Map) return null;
      final choices = j['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final first = choices.first;
      if (first is! Map) return null;
      // 流式用 delta，非流式兼容用 message
      final d = first['delta'] ?? first['message'];
      if (d is! Map) return null;
      final content = d['content'];
      final reasoning = d['reasoning'] ?? d['reasoning_content'];
      return LlmDelta(
        content: content is String ? content : '',
        reasoning: reasoning is String ? reasoning : '',
      );
    } catch (_) {
      return null; // 单个坏分片不该中断整条回复
    }
  }

  static String _networkHint(LlmProvider p) {
    final host = p.normalizedBaseUrl;
    if (host.contains('127.0.0.1') || host.contains('localhost')) {
      return '在手机上时 127.0.0.1 指向手机自己，请把地址改成电脑的局域网 IP；'
          '并确认 Ollama 已设置 OLLAMA_HOST=0.0.0.0 后重启。';
    }
    return '检查地址是否可访问、服务是否在运行、手机是否和电脑在同一个 Wi-Fi。';
  }

  static String _httpErrorMessage(int code, String body) {
    final short = body.length > 300 ? body.substring(0, 300) : body;

    // 模型名写错时，很多服务会在报错里列出可用模型。
    // 把这段挖出来直接告诉用户该填什么，比让他自己读 JSON 强。
    final modelHint = RegExp(
      r'supported (?:API )?model names? (?:are|is)\s*([^.(]+)',
      caseSensitive: false,
    ).firstMatch(body);
    if (modelHint != null) {
      final names = modelHint.group(1)!.trim().replaceAll('\n', ' ');
      return '模型名不对（$code）。这个服务支持：$names';
    }

    switch (code) {
      case 400:
        // 不一定是模型名，也可能是参数问题，原文带上
        return '请求被拒绝（400）：$short';
      case 401:
        return '鉴权失败（401）：API Key 不对或没填。';
      case 403:
        return '没有权限（403）：Key 可能没有该模型的权限。';
      case 404:
        return '地址或模型名不对（404）：$short';
      case 429:
        return '请求太频繁或额度用尽（429）。';
    }
    if (code >= 500) return '服务端出错（$code）：$short';
    return '请求失败（$code）：$short';
  }
}
