import 'package:flutter_tts/flutter_tts.dart';

/// 语音输出：让她的回复"读出来"。
///
/// 用系统自带的 TTS 引擎（离线、免费、不需要 Key）。
/// 中文音色质量取决于手机装了什么引擎，OPPO 自带的一般够用。
class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;
  static bool enabled = false;

  /// 朗读语速，0.5 正常偏慢一点，听起来更像说话而不是播报
  static double rate = 0.48;

  /// 音调略低，避免机械感
  static double pitch = 0.95;

  static Future<void> ensureInit() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(pitch);
      await _tts.setVolume(1.0);
      // 一句话说完再结束，避免被系统切成碎句
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    } catch (_) {
      // 没有 TTS 引擎时静默失败，不影响文字聊天
    }
  }

  /// 朗读一段文字。表情标记、链接这类会读得很怪的片段先清掉。
  static Future<void> speak(String text) async {
    if (!enabled) return;
    final clean = _clean(text);
    if (clean.isEmpty) return;
    try {
      await ensureInit();
      await _tts.stop();
      await _tts.speak(clean);
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  static Future<void> setRate(double v) async {
    rate = v;
    try {
      await _tts.setSpeechRate(v);
    } catch (_) {}
  }

  static Future<void> setPitch(double v) async {
    pitch = v;
    try {
      await _tts.setPitch(v);
      await ensureInit();
    } catch (_) {}
  }

  /// 列出手机 TTS 引擎里可用的中文音色
  static Future<List<Map<String, String>>> chineseVoices() async {
    final out = <Map<String, String>>[];
    try {
      await ensureInit();
      final raw = await _tts.getVoices;
      if (raw is List) {
        for (final v in raw) {
          if (v is! Map) continue;
          final locale = (v['locale'] ?? '').toString();
          final name = (v['name'] ?? '').toString();
          if (name.isEmpty) continue;
          if (locale.toLowerCase().startsWith('zh')) {
            out.add({'name': name, 'locale': locale});
          }
        }
      }
    } catch (_) {}
    return out;
  }

  /// 选一个音色；传空字符串表示回到系统默认
  static Future<void> selectVoice(String name, String locale) async {
    try {
      await ensureInit();
      if (name.isEmpty) {
        await _tts.setLanguage('zh-CN');
        return;
      }
      await _tts.setVoice({'name': name, 'locale': locale});
    } catch (_) {}
  }

  /// 去掉不该读出来的东西：表情标记、markdown 符号、URL
  static String _clean(String input) {
    var s = input;
    s = s.replaceAll(RegExp(r'\[\s*s\s*[:：][^\]]*\]'), ''); // [s:标签]
    s = s.replaceAll(RegExp(r'https?://\S+'), ''); // 链接
    s = s.replaceAll(RegExp(r'[*_`#>~]'), ''); // markdown 符号
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }
}
