import 'package:chat_app/core/stickers/sticker_catalog.dart';
import 'package:chat_app/models/sticker.dart';
import 'package:flutter_test/flutter_test.dart';

/// 开源版本不自带任何第三方表情图，所以这里只验证：
/// 1. 资源为空/缺失时不会崩
/// 2. 用户自己放进去的表情包能正常解析、按标签命中
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('空表情包能加载，不抛异常', () async {
    final c = await StickerCatalog.load(force: true);
    expect(c.aiPack.stickers, isEmpty);
    expect(c.userPack.stickers, isEmpty);
    expect(c.aiHasStickers, isFalse);
    expect(c.userHasStickers, isFalse);
    // 没图时查标签应当安全返回 null
    expect(c.findForAi('晚安'), isNull);
  });

  test('自备表情包：标签与别名都能命中', () {
    const json = '''
{
  "packName": "测试包",
  "stickers": [
    {"id": "01", "file": "01.png", "label": "晚安", "tags": ["睡觉", "困"]},
    {"id": "02", "file": "02.png", "label": "加油", "tags": ["打气"]}
  ]
}
''';
    final pack = StickerPack.fromJsonString(json, assetDir: 'assets/x');
    expect(pack.stickers.length, 2);
    expect(pack.tagIndex['晚安']?.id, '01');
    expect(pack.tagIndex['睡觉']?.id, '01');
    expect(pack.tagIndex['加油']?.id, '02');
    expect(pack.assetPathOf(pack.stickers.first), 'assets/x/01.png');
  });
}
