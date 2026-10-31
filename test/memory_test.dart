import 'package:chat_app/core/memory/memory_prompt.dart';
import 'package:chat_app/models/chat_message.dart';
import 'package:chat_app/models/memory_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('markdown 往返', () {
    test('正常行能解析出日期、内容和来源', () {
      final item = MemoryItem.parseLine(
        '- [2026-10-30] 用户叫阿岚 | 与云若的对话',
        MemoryItem.fact,
      );
      expect(item, isNotNull);
      expect(item!.text, '用户叫阿岚');
      expect(item.source, '与云若的对话');
      expect(item.createdAt.year, 2026);
      expect(item.category, MemoryItem.fact);
    });

    test('没有来源也能解析', () {
      final item = MemoryItem.parseLine('- [2026-01-01] 喜欢下雨天', MemoryItem.profile);
      expect(item?.text, '喜欢下雨天');
      expect(item?.source, '');
    });

    test('用户手改留下的脏行被跳过，不抛异常', () {
      expect(MemoryItem.parseLine('随便写的一行', MemoryItem.fact), isNull);
      expect(MemoryItem.parseLine('- []', MemoryItem.fact), isNull);
      expect(MemoryItem.parseLine('', MemoryItem.fact), isNull);
      expect(MemoryItem.parseLine('- [2026-01-01]   ', MemoryItem.fact), isNull);
    });

    test('序列化再解析回来内容不变', () {
      final item = MemoryItem(
        category: MemoryItem.episode,
        text: '约好周末去看海',
        createdAt: DateTime(2026, 5, 4),
        source: '会话 A',
      );
      final back = MemoryItem.parseLine(item.toMarkdownLine(), item.category);
      expect(back?.text, item.text);
      expect(back?.source, item.source);
      expect(back?.createdAt.month, 5);
      expect(back?.createdAt.day, 4);
    });
  });

  group('注入上下文', () {
    test('没有记忆时不注入任何东西', () {
      expect(buildMemoryBlock(const []), '');
    });

    test('有记忆时带上标签和内容', () {
      final block = buildMemoryBlock([
        MemoryItem(
          category: MemoryItem.fact,
          text: '用户养了一只猫',
          createdAt: DateTime(2026, 1, 1),
        ),
      ]);
      expect(block, contains('你记得的事'));
      expect(block, contains('事实：用户养了一只猫'));
      expect(block, contains('不要复述清单'));
    });

    test('超长时按时间倒序截断，最老的丢掉', () {
      final items = [
        for (var i = 0; i < 40; i++)
          MemoryItem(
            category: MemoryItem.fact,
            text: '第$i条记忆内容${'很长的内容' * 3}',
            createdAt: DateTime(2026, 1, 1).add(Duration(days: i)),
          ),
      ];
      final block = buildMemoryBlock(items, maxChars: 200);
      expect(block.length, lessThan(400));
      // 最新的在里面，最老的被截掉
      expect(block, contains('第39条'));
      expect(block, isNot(contains('第0条')));
    });
  });

  group('解析模型输出', () {
    test('三种类别都能认', () {
      final items = parseExtracted(
        '[事实] 用户叫阿岚\n'
        '[事件] 周末约了看海\n'
        '[画像] 怕冷，不喜欢被追问',
        source: '会话 A',
      );
      expect(items.length, 3);
      expect(items[0].category, MemoryItem.fact);
      expect(items[1].category, MemoryItem.episode);
      expect(items[2].category, MemoryItem.profile);
      expect(items[0].source, '会话 A');
    });

    test('带项目符号、中文方括号、多余空行都能容忍', () {
      final items = parseExtracted(
        '好的，我整理如下：\n\n'
        '- 【事实】用户在做游戏策划\n'
        '* [画像] 说话偏冷静\n'
        '以上就是全部。',
      );
      expect(items.length, 2);
      expect(items[0].text, '用户在做游戏策划');
      expect(items[1].text, '说话偏冷静');
    });

    test('模型胡说八道时返回空，不抛异常', () {
      expect(parseExtracted('抱歉，我无法完成。'), isEmpty);
      expect(parseExtracted(''), isEmpty);
    });

    test('总结提示词里包含对话内容并限定格式', () {
      final prompt = buildSummarizePrompt([
        ChatMessage(
          role: ChatRole.user,
          text: '我叫阿岚，做游戏策划',
          time: DateTime(2026, 1, 1),
        ),
        ChatMessage(
          role: ChatRole.bot,
          text: '记住了',
          time: DateTime(2026, 1, 1),
        ),
      ]);
      expect(prompt, contains('用户：我叫阿岚，做游戏策划'));
      expect(prompt, contains('[事实]'));
      expect(prompt, contains('最多 6 条'));
    });
  });
}
