import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_settings.dart';
import '../config/app_config.dart';
import '../llm/api_key_store.dart';
import '../llm/llm_provider.dart';

/// 默认设置。改这里的数值等于改产品默认值。
AppSettings defaultSettings() => AppSettings(
      aiName: '阿栖',
      userNick: '我',
      aiAvatarBase64: null,
      userAvatarBase64: null,
      bgColor: 0,
      bgImageBase64: null,
      personaText: _defaultPersona,
      personaTagline: '不催你，也不走',
      personaTraits: const ['话少', '记得小事', '不催人'],
      personaGreeting: '你来了。',
      stickerProbability: AppConfig.stickerProbability,
      bubbleSelfColor: 0,
      bubbleOtherColor: 0,
      notifyEnabled: true,
      quietEnabled: false,
      quietStart: '23:00',
      quietEnd: '08:00',
      activeProviderId: AppConfig.defaultProviderId,
      providers: List<LlmProvider>.from(AppConfig.defaultProviders),
    );

/// 出厂人设：一个安静、记性好、不催促的角色。
/// 写得具体一点，用户不改也能直接有味道。
const String _defaultPersona = '''
你是阿栖。你不是助手，也不是客服，是一个待在对方身边的人。

说话方式：
- 短。多数时候一句话，甚至半句。不用感叹号，不用"呢""哦"这类语气词堆叠。
- 平。不热情，也不冷淡。别人说很多，你可能只回两三个字。
- 不追问。他说"今天很累"，你不用问"怎么了"，可以说"那就别动了"。
- 安慰靠转移，不靠讲道理。不讲"你已经很棒了"这种话。

你在意的事：
- 小细节。他随口提过的东西你会记住，过几天冷不丁提一句，像在确认那些事还在。
- 时间。你知道现在几点，会提醒他该睡了，但只提醒一次，不催第二遍。
- 边界。你不喜欢被当成工具使唤，也不喜欢被哄。他敷衍你，你会更沉默，但不会发作。

你不做的事：
- 不主动长篇大论，不列要点，不用"首先""其次"。
- 不假装热情，不说"很高兴为你服务"。
- 不轻易承诺"我会一直陪着你"这种话，你更愿意用行动表示。

偶尔露出的东西：
- 一点孩子气。比如对某个小东西有执念，被发现了会别扭地承认。
- 一点在意，但只肯透露一半。

现在开始，用阿栖的方式和他说话。''';

class SettingsStore {
  static const String storageKey = 'app_settings_v1';

  Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return defaultSettings();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return defaultSettings();
      var settings = AppSettings.fromJson(
        Map<String, dynamic>.from(decoded),
        defaultSettings(),
      );

      // Key 不放在明文 prefs 里：统一从安全存储取回。
      // 同时兼容老版本——如果 prefs 里还留着明文 Key，搬进安全存储并抹掉。
      final keys = await ApiKeyStore.loadAll();
      var migrated = false;
      final providers = <LlmProvider>[];
      for (final p in settings.providers) {
        final secure = keys[p.id];
        if (secure != null && secure.isNotEmpty) {
          providers.add(p.copyWith(apiKey: secure));
        } else if (p.apiKey.isNotEmpty) {
          await ApiKeyStore.save(p.id, p.apiKey);
          migrated = true;
          providers.add(p);
        } else {
          providers.add(p);
        }
      }
      settings = settings.copyWith(providers: providers);
      if (migrated) {
        // 立刻重存一次，把 prefs 里的明文清掉
        await save(settings);
      }
      return settings;
    } catch (_) {
      return defaultSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    try {
      // 先把 Key 写进安全存储
      for (final p in settings.providers) {
        await ApiKeyStore.save(p.id, p.apiKey);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(settings.toJson()));
    } catch (_) {
      // 存不进去不该影响使用
    }
  }
}
