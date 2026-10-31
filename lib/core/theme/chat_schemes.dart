import 'package:flutter/material.dart';

/// 一套完整聊天配色。
///
/// 参考几家成熟产品的真实色值（微信 / iMessage / Telegram / WhatsApp），
/// 每套都自带明暗属性 —— 应用时**同时切换主题**，避免出现
/// 「浅色外壳 + 纯黑背景」这种撞色。
class ChatScheme {
  final String id;
  final String name;
  final Brightness brightness;
  final Color bg;
  final Color selfBubble;
  final Color otherBubble;

  const ChatScheme({
    required this.id,
    required this.name,
    required this.brightness,
    required this.bg,
    required this.selfBubble,
    required this.otherBubble,
  });

  bool get isDark => brightness == Brightness.dark;

  /// 三个色的迷你预览条
  List<Color> get preview => [bg, selfBubble, otherBubble];

  static const List<ChatScheme> all = [
    ChatScheme(
      id: 'linen',
      name: '亚麻',
      brightness: Brightness.light,
      bg: Color(0xFFFAF7F2),
      selfBubble: Color(0xFFE5D3B8),
      otherBubble: Color(0xFFFFFFFF),
    ),
    ChatScheme(
      id: 'wechat',
      name: '微信绿',
      brightness: Brightness.light,
      bg: Color(0xFFEDEDED),
      selfBubble: Color(0xFF95EC69),
      otherBubble: Color(0xFFFFFFFF),
    ),
    ChatScheme(
      id: 'imessage',
      name: 'iMessage',
      brightness: Brightness.light,
      bg: Color(0xFFFFFFFF),
      selfBubble: Color(0xFF0B6BC4),
      otherBubble: Color(0xFFE5E5EA),
    ),
    ChatScheme(
      id: 'telegram',
      name: 'Telegram',
      brightness: Brightness.light,
      bg: Color(0xFFDDE4EC),
      selfBubble: Color(0xFFEEFFDE),
      otherBubble: Color(0xFFFFFFFF),
    ),
    ChatScheme(
      id: 'whatsapp',
      name: 'WhatsApp',
      brightness: Brightness.light,
      bg: Color(0xFFECE5DD),
      selfBubble: Color(0xFFDCF8C6),
      otherBubble: Color(0xFFFFFFFF),
    ),
    ChatScheme(
      id: 'midnight',
      name: '深海',
      brightness: Brightness.dark,
      bg: Color(0xFF000000),
      selfBubble: Color(0xFF2B5278),
      otherBubble: Color(0xFF182533),
    ),
    ChatScheme(
      id: 'forest',
      name: '夜绿',
      brightness: Brightness.dark,
      bg: Color(0xFF000000),
      selfBubble: Color(0xFF3EB575),
      otherBubble: Color(0xFF2C2C2E),
    ),
    ChatScheme(
      id: 'pure',
      name: '纯黑蓝',
      brightness: Brightness.dark,
      bg: Color(0xFF000000),
      selfBubble: Color(0xFF0B6BC4),
      otherBubble: Color(0xFF26252A),
    ),
  ];

  static ChatScheme? byId(String? id) {
    if (id == null) return null;
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
