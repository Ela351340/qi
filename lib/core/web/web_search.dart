import 'dart:convert';

import 'package:http/http.dart' as http;

/// 一条搜索结果
class WebResult {
  final String title;
  final String url;
  final String snippet;

  const WebResult({
    required this.title,
    required this.url,
    required this.snippet,
  });
}

/// 极简联网检索：抓 DuckDuckGo 的 HTML 结果页。
///
/// 为什么不用官方搜索 API：免费、不用注册 Key、也不把查询发给额外的第三方账号。
/// 代价是页面结构一变就可能失效 —— 失效时返回空列表，上层降级处理。
class WebSearch {
  static const Map<String, String> _ua = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/122.0 Mobile Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9',
  };

  static Future<List<WebResult>> search(String query, {int limit = 5}) async {
    try {
      final uri = Uri.parse('https://html.duckduckgo.com/html/')
          .replace(queryParameters: {'q': query});
      final resp = await http
          .get(uri, headers: _ua)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return const [];
      final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
      return _parse(html, limit);
    } catch (_) {
      return const [];
    }
  }

  /// DuckDuckGo 的结果块结构：result__a 标题、result__snippet 摘要
  static List<WebResult> _parse(String html, int limit) {
    final out = <WebResult>[];
    final blockRe = RegExp(
      r'<a[^>]+class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>'
      r'(?:[\s\S]*?class="result__snippet"[^>]*>([\s\S]*?)</a>)?',
      caseSensitive: false,
    );
    for (final m in blockRe.allMatches(html)) {
      final url = _unwrap(m.group(1) ?? '');
      final title = _strip(m.group(2) ?? '');
      final snippet = _strip(m.group(3) ?? '');
      if (url.isEmpty || title.isEmpty) continue;
      out.add(WebResult(title: title, url: url, snippet: snippet));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// DDG 的跳转链接里带着真实地址
  static String _unwrap(String href) {
    try {
      final uri = Uri.parse(href);
      final real = uri.queryParameters['uddg'];
      if (real != null && real.isNotEmpty) return Uri.decodeComponent(real);
      return href;
    } catch (_) {
      return href;
    }
  }

  /// 抓一页正文，剥标签、压空白、限长度
  static Future<String> fetchText(String url, {int maxChars = 3500}) async {
    try {
      final resp = await http
          .get(Uri.parse(url), headers: _ua)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return '';
      final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
      var text = _strip(html);
      if (text.length > maxChars) text = text.substring(0, maxChars);
      return text;
    } catch (_) {
      return '';
    }
  }

  static String _strip(String html) {
    var s = html
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }
}
