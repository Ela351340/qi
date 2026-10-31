import 'package:shared_preferences/shared_preferences.dart';

/// 一些小开关，和 AppSettings 分开存。
///
/// 理由：AppSettings 那条链路（JSON 序列化 + copyWith + 表单）已经很长，
/// 每次加字段都容易漏一处；这些"运行时行为"开关独立存更省事，也更好回滚。
class FeaturePrefs {
  static const String kVoice = 'feature_voice_v1';
  static const String kProactive = 'feature_proactive_v1';
  static const String kProactiveHours = 'feature_proactive_hours_v1';
  static const String kAutoMemory = 'feature_auto_memory_v1';
  static const String kNextAt = 'feature_proactive_next_at_v1';
  static const String kTtsVoice = 'feature_tts_voice_v1';
  static const String kTtsPitch = 'feature_tts_pitch_v1';

  /// 她的回复用语音读出来
  static bool voiceEnabled = false;

  /// 主动找你说话
  static bool proactiveEnabled = false;

  /// 多久没聊就主动开口（小时，作为随机区间的基准）
  static int proactiveHours = 6;

  /// 聊到一定轮数自动整理记忆
  static bool autoMemoryEnabled = true;

  /// 下一次该开口的时间戳（毫秒）。
  /// 存下来是为了让"随机"只掷一次骰子，而不是每次回前台都重算。
  static int proactiveNextAt = 0;

  /// TTS 音色名（空 = 系统默认）
  static String ttsVoice = '';

  /// TTS 音调 0.5–1.5
  static double ttsPitch = 0.95;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      voiceEnabled = p.getBool(kVoice) ?? false;
      proactiveEnabled = p.getBool(kProactive) ?? false;
      proactiveHours = p.getInt(kProactiveHours) ?? 6;
      autoMemoryEnabled = p.getBool(kAutoMemory) ?? true;
      proactiveNextAt = p.getInt(kNextAt) ?? 0;
      ttsVoice = p.getString(kTtsVoice) ?? '';
      ttsPitch = p.getDouble(kTtsPitch) ?? 0.95;
    } catch (_) {
      // 读不到就用默认值
    }
  }

  static Future<void> setNextAt(int millis) async {
    proactiveNextAt = millis;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(kNextAt, millis);
    } catch (_) {}
  }

  static Future<void> setTtsVoice(String v) async {
    ttsVoice = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(kTtsVoice, v);
    } catch (_) {}
  }

  static Future<void> setTtsPitch(double v) async {
    ttsPitch = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(kTtsPitch, v);
    } catch (_) {}
  }

  static Future<void> setVoice(bool v) async {
    voiceEnabled = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(kVoice, v);
    } catch (_) {}
  }

  static Future<void> setProactive(bool v) async {
    proactiveEnabled = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(kProactive, v);
    } catch (_) {}
  }

  static Future<void> setProactiveHours(int v) async {
    proactiveHours = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(kProactiveHours, v);
    } catch (_) {}
  }

  static Future<void> setAutoMemory(bool v) async {
    autoMemoryEnabled = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(kAutoMemory, v);
    } catch (_) {}
  }
}
