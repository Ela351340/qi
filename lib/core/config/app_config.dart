import '../llm/llm_provider.dart';

/// 全局默认配置。
///
/// provider 是「列表 + 选中项」的结构，不是单个 baseUrl：
/// 现在开发期用本地 Ollama，正式用 DashScope，以后换更强的本地模型
/// 只要在这里（或设置页）改一项，业务代码一行都不用动。
class AppConfig {
  static const String defaultProviderId = 'ollama-local';

  static const List<LlmProvider> defaultProviders = [
    LlmProvider(
      id: 'ollama-local',
      name: '本地 Ollama（本机）',
      // 电脑上跑（web 预览 / 桌面调试）用这个
      baseUrl: 'http://127.0.0.1:11434/v1',
      model: 'qwen3:8b',
    ),
    LlmProvider(
      id: 'ollama-lan',
      name: '本地 Ollama（局域网）',
      // 手机上用这个；IP 变了就改这里
      baseUrl: 'http://192.168.1.10:11434/v1',
      model: 'qwen3:8b',
    ),
    LlmProvider(
      id: 'dashscope',
      name: '阿里云 DashScope',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      model: 'qwen3.6-plus',
      // apiKey 由用户在设置页填，不写进代码
    ),
  ];

  /// 有标记时真正发图的概率（0-100）。35 约等于三条回复一张图，
  /// 这个数值参考 AstrBot meme_manager 的默认值。
  static const int stickerProbability = 35;

  /// 追加到人设后面的表情协议。标签清单由表情包动态生成。
  static String stickerInstructions(String tagList) => '''
## 表情
你可以在回复里加一个表情标记，格式：[s:标签]
可用标签：$tagList
规则：
- 一次最多一个，放在句子末尾
- 只在情绪明显时用：开心、无语、累、生气、道谢、道歉、说晚安
- 不要解释这个标记，也不要让用户看到它
- 不要每句都加，普通陈述句不要加
''';

  /// 人设占位。真实人设后续从 persona.md 读，这里只保证能跑。
  static const String defaultSystemPrompt = '''
你是「云若」。

## 说话方式
- 句子短，一般不超过两行
- 不说教、不总结、不加「希望对你有帮助」这类话
- 不确定就直接说不确定，不要编

## 绝对不做
- 不主动提自己是 AI / 模型 / 助手
- 不跳出角色解释设定
- 不重复用户说过的话
''';
}
