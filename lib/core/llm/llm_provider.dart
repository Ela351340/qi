/// 一个可切换的模型服务。切换 provider 就是换这里的一个对象，
/// 不涉及任何业务代码改动。
///
/// 以后电脑升级、能跑更大模型时，只要再加一个 entry 指向本地地址即可。
class LlmProvider {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;

  /// 合并进请求体的额外字段，用来适配各家的私有开关。
  /// 例：Ollama 的 qwen3 关思考要传 {"think": false}。
  final Map<String, dynamic> extraBody;

  const LlmProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.apiKey = '',
    required this.model,
    this.extraBody = const {},
  });

  LlmProvider copyWith({
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    Map<String, dynamic>? extraBody,
  }) {
    return LlmProvider(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      extraBody: extraBody ?? this.extraBody,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        if (extraBody.isNotEmpty) 'extraBody': extraBody,
      };

  factory LlmProvider.fromJson(Map<String, dynamic> j) => LlmProvider(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        baseUrl: (j['baseUrl'] ?? '').toString(),
        apiKey: (j['apiKey'] ?? '').toString(),
        model: (j['model'] ?? '').toString(),
        extraBody: (j['extraBody'] is Map)
            ? Map<String, dynamic>.from(j['extraBody'] as Map)
            : const {},
      );

  /// 实际请求用的地址。
  ///
  /// 手填地址时最容易犯三个错，这里统一纠正：
  /// 1. 没写 http(s)://        → 按主机名猜协议补上
  /// 2. 末尾带斜杠             → 去掉，避免双斜杠
  /// 3. 只填到域名、没写 /v1   → 自动补上（OpenAI 兼容接口的约定）
  String get normalizedBaseUrl {
    var url = baseUrl.trim();
    if (url.isEmpty) return url;

    if (!url.contains('://')) {
      final host = url.split('/').first;
      final isLocal = host.startsWith('127.') ||
          host.startsWith('localhost') ||
          host.startsWith('192.168.') ||
          host.startsWith('10.') ||
          host.startsWith('172.16.') ||
          host.startsWith('172.17.') ||
          host.startsWith('172.18.') ||
          host.startsWith('172.19.') ||
          host.startsWith('172.2') ||
          host.startsWith('172.30.') ||
          host.startsWith('172.31.');
      url = '${isLocal ? 'http' : 'https'}://$url';
    }

    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    // 有人会把完整端点直接粘进来，先剥掉，
    // 否则会拼成 /chat/completions/chat/completions → 404
    const suffix = '/chat/completions';
    if (url.endsWith(suffix)) {
      url = url.substring(0, url.length - suffix.length);
      while (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
    }

    final uri = Uri.tryParse(url);
    if (uri != null && (uri.path.isEmpty || uri.path == '/')) {
      url = '$url/v1';
    }
    return url;
  }

  /// 清洗后的 Key：去掉所有空白和不可见字符。
  ///
  /// 从网页/记事本复制 Key 常带换行，直接塞进 HTTP 头会让 http 包
  /// 抛 ArgumentError，表现就是"一填 Key 就报错"。
  String get sanitizedApiKey => apiKey
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll(RegExp(r'[^\x21-\x7E]'), '');
}
