import 'dart:convert';

import '../core/llm/llm_provider.dart';

/// 全部用户设置。存成一个 JSON 串，切页面就靠它。
class AppSettings {
  final String aiName;
  final String userNick;

  /// 头像用 base64 存在本地。256x256 的图约 20–50KB，可接受。
  final String? aiAvatarBase64;
  final String? userAvatarBase64;

  /// 聊天背景：纯色，或一张图（图片优先于颜色）
  final int bgColor;
  final String? bgImageBase64;

  /// 人格卡片：正文人设 + 一句话简介 + 性格标签 + 开场白
  final String personaText;
  final String personaTagline;
  final List<String> personaTraits;
  final String personaGreeting;

  final int stickerProbability;

  /// 自己的气泡 / 对方的气泡。ARGB 整数。
  final int bubbleSelfColor;
  final int bubbleOtherColor;

  /// 通知
  final bool notifyEnabled;
  final bool quietEnabled;

  /// "23:00" 这种 24 小时制字符串
  final String quietStart;
  final String quietEnd;

  final String activeProviderId;
  final List<LlmProvider> providers;

  const AppSettings({
    required this.aiName,
    required this.userNick,
    required this.aiAvatarBase64,
    required this.userAvatarBase64,
    required this.bgColor,
    required this.bgImageBase64,
    required this.personaText,
    required this.personaTagline,
    required this.personaTraits,
    required this.personaGreeting,
    required this.stickerProbability,
    required this.bubbleSelfColor,
    required this.bubbleOtherColor,
    required this.notifyEnabled,
    required this.quietEnabled,
    required this.quietStart,
    required this.quietEnd,
    required this.activeProviderId,
    required this.providers,
  });

  AppSettings copyWith({
    String? aiName,
    String? userNick,
    String? aiAvatarBase64,
    String? userAvatarBase64,
    int? bgColor,
    String? bgImageBase64,
    bool clearBgImage = false,
    String? personaText,
    String? personaTagline,
    List<String>? personaTraits,
    String? personaGreeting,
    int? stickerProbability,
    int? bubbleSelfColor,
    int? bubbleOtherColor,
    bool? notifyEnabled,
    bool? quietEnabled,
    String? quietStart,
    String? quietEnd,
    String? activeProviderId,
    List<LlmProvider>? providers,
  }) {
    return AppSettings(
      aiName: aiName ?? this.aiName,
      userNick: userNick ?? this.userNick,
      aiAvatarBase64: aiAvatarBase64 ?? this.aiAvatarBase64,
      userAvatarBase64: userAvatarBase64 ?? this.userAvatarBase64,
      bgColor: bgColor ?? this.bgColor,
      bgImageBase64: clearBgImage
          ? null
          : (bgImageBase64 ?? this.bgImageBase64),
      personaText: personaText ?? this.personaText,
      personaTagline: personaTagline ?? this.personaTagline,
      personaTraits: personaTraits ?? this.personaTraits,
      personaGreeting: personaGreeting ?? this.personaGreeting,
      stickerProbability: stickerProbability ?? this.stickerProbability,
      bubbleSelfColor: bubbleSelfColor ?? this.bubbleSelfColor,
      bubbleOtherColor: bubbleOtherColor ?? this.bubbleOtherColor,
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
      quietEnabled: quietEnabled ?? this.quietEnabled,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
      activeProviderId: activeProviderId ?? this.activeProviderId,
      providers: providers ?? this.providers,
    );
  }

  Map<String, dynamic> toJson() => {
        'aiName': aiName,
        'userNick': userNick,
        if (aiAvatarBase64 != null) 'aiAvatarBase64': aiAvatarBase64,
        if (userAvatarBase64 != null) 'userAvatarBase64': userAvatarBase64,
        'bgColor': bgColor,
        if (bgImageBase64 != null) 'bgImageBase64': bgImageBase64,
        'personaText': personaText,
        'personaTagline': personaTagline,
        'personaTraits': personaTraits,
        'personaGreeting': personaGreeting,
        'stickerProbability': stickerProbability,
        'bubbleSelfColor': bubbleSelfColor,
        'bubbleOtherColor': bubbleOtherColor,
        'notifyEnabled': notifyEnabled,
        'quietEnabled': quietEnabled,
        'quietStart': quietStart,
        'quietEnd': quietEnd,
        'activeProviderId': activeProviderId,
        'providers': providers.map((p) => p.toJson()).toList(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> j, AppSettings fallback) {
    final rawProviders = j['providers'];
    final providers = (rawProviders is List && rawProviders.isNotEmpty)
        ? rawProviders
            .whereType<Map>()
            .map((e) => LlmProvider.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : fallback.providers;
    return AppSettings(
      aiName: (j['aiName'] ?? fallback.aiName).toString(),
      userNick: (j['userNick'] ?? fallback.userNick).toString(),
      aiAvatarBase64: _nonEmpty(j['aiAvatarBase64']),
      userAvatarBase64: _nonEmpty(j['userAvatarBase64']),
      bgColor: (j['bgColor'] as num?)?.toInt() ?? fallback.bgColor,
      bgImageBase64: _nonEmpty(j['bgImageBase64']),
      personaText: (j['personaText'] as String?)?.isNotEmpty == true
          ? j['personaText'] as String
          : fallback.personaText,
      personaTagline:
          (j['personaTagline'] ?? fallback.personaTagline).toString(),
      personaTraits: (j['personaTraits'] is List)
          ? (j['personaTraits'] as List).map((e) => e.toString()).toList()
          : fallback.personaTraits,
      personaGreeting:
          (j['personaGreeting'] ?? fallback.personaGreeting).toString(),
      stickerProbability: (j['stickerProbability'] as num?)?.toInt() ??
          fallback.stickerProbability,
      bubbleSelfColor:
          (j['bubbleSelfColor'] as num?)?.toInt() ?? fallback.bubbleSelfColor,
      bubbleOtherColor:
          (j['bubbleOtherColor'] as num?)?.toInt() ?? fallback.bubbleOtherColor,
      notifyEnabled: (j['notifyEnabled'] as bool?) ?? fallback.notifyEnabled,
      quietEnabled: (j['quietEnabled'] as bool?) ?? fallback.quietEnabled,
      quietStart: (j['quietStart'] ?? fallback.quietStart).toString(),
      quietEnd: (j['quietEnd'] ?? fallback.quietEnd).toString(),
      activeProviderId:
          (j['activeProviderId'] ?? fallback.activeProviderId).toString(),
      providers: providers,
    );
  }

  static String? _nonEmpty(Object? v) {
    final s = v as String?;
    return (s == null || s.isEmpty) ? null : s;
  }

  /// 头像/背景 base64 → 字节。解码失败返回 null，界面退化成纯色。
  static List<int>? decodeAvatar(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}
