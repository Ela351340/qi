import 'package:flutter/services.dart';

import '../../models/sticker.dart';

/// 两套表情包：AI 自己发的、用户在面板里挑的。互不干扰。
class StickerCatalog {
  final StickerPack aiPack;
  final StickerPack userPack;

  const StickerCatalog({required this.aiPack, required this.userPack});

  static StickerCatalog? _cache;

  /// 带缓存：表情包是只读资源，加载一次就够。
  /// 这也让测试不必等异步 I/O 完成才发送消息。
  ///
  /// 开源版本**不带任何第三方表情图**：pack.json 可以是空的，
  /// 甚至文件不存在——那种情况下返回空包，而不是让 App 起不来。
  static Future<StickerCatalog> load({bool force = false}) async {
    if (!force && _cache != null) return _cache!;
    final ai = await _loadPackString('assets/stickers/ai/pack.json');
    final user = await _loadPackString('assets/stickers/user/pack.json');
    final result = StickerCatalog(
      aiPack: StickerPack.fromJsonString(ai, assetDir: 'assets/stickers/ai'),
      userPack:
          StickerPack.fromJsonString(user, assetDir: 'assets/stickers/user'),
    );
    _cache = result;
    return result;
  }

  static Future<String> _loadPackString(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (_) {
      // 资源缺失当作空包处理
      return '{"packName":"","stickers":[]}';
    }
  }

  /// 模型给的标签 → 表情。找不到返回 null，调用方应当静默丢弃。
  Sticker? findForAi(String tag) {
    final t = tag.trim();
    return aiPack.tagIndex[t];
  }

  bool get aiHasStickers => aiPack.stickers.isNotEmpty;
  bool get userHasStickers => userPack.stickers.isNotEmpty;
}
