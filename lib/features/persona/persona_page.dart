import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/llm/llm_client.dart';
import '../../core/web/web_search.dart';
import '../../models/app_settings.dart';
import '../../models/chat_message.dart';
import '../../shared/app_chrome.dart';
import '../../theme/app_theme.dart';

/// 人格卡片：一眼看清「她是谁」，并且能直接改。
///
/// 卡片本身是只读展示（像一张角色卡），下面的编辑区负责修改，
/// 这样既有「成品感」，又不牺牲可编辑性。
class PersonaPage extends StatefulWidget {
  final AppSettings initial;
  final ValueChanged<AppSettings> onChanged;

  const PersonaPage({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<PersonaPage> createState() => _PersonaPageState();
}

class _PersonaPageState extends State<PersonaPage> {
  late AppSettings _s = widget.initial;
  late final TextEditingController _name =
      TextEditingController(text: _s.aiName);
  late final TextEditingController _tagline =
      TextEditingController(text: _s.personaTagline);
  late final TextEditingController _traits =
      TextEditingController(text: _s.personaTraits.join('、'));
  late final TextEditingController _greeting =
      TextEditingController(text: _s.personaGreeting);
  late final TextEditingController _body =
      TextEditingController(text: _s.personaText);

  @override
  void dispose() {
    for (final c in [_name, _tagline, _traits, _greeting, _body]) {
      c.dispose();
    }
    super.dispose();
  }

  void _update(AppSettings next) {
    setState(() => _s = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: appOverlay(
        context,
        Column(
          children: [
            statusBarFilled(context, color: C.surface3, child: _topBar()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  _card(),
                  const SizedBox(height: 14),
                  _enrichButton(),
                  const SizedBox(height: 20),
                  _section('基本信息'),
                  _cardBox([
                    _field('名字', _name,
                        onChanged: (v) => _update(_s.copyWith(aiName: v))),
                    _field('一句话', _tagline,
                        onChanged: (v) =>
                            _update(_s.copyWith(personaTagline: v))),
                    _field('性格标签', _traits,
                        hint: '用顿号分开，例如：话不多、嘴硬心软',
                        onChanged: (v) => _update(
                              _s.copyWith(personaTraits: v
                                  .split(RegExp(r'[、,，]'))
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList()),
                            )),
                    _field('开场白', _greeting,
                        hint: '新建对话时她说的第一句',
                        onChanged: (v) =>
                            _update(_s.copyWith(personaGreeting: v))),
                  ]),
                  _section('人设正文'),
                  _cardBox([
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: TextField(
                        controller: _body,
                        maxLines: null,
                        minLines: 8,
                        style: AppText.bodySmall.copyWith(height: 1.55),
                        cursorColor: C.accent,
                        onChanged: (v) =>
                            _update(_s.copyWith(personaText: v)),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: '写她是谁、怎么说话、绝对不做什么',
                          hintStyle:
                              TextStyle(color: C.textTertiary),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    '这段会作为系统提示词发给模型，写得越具体她越像。',
                    style: AppText.meta.copyWith(
                      fontSize: 11,
                      color: C.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      height: AppMetrics.topBarHeight,
      decoration: BoxDecoration(
        color: C.surface3,
        border: Border(bottom: BorderSide(color: C.border, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left, size: 26),
            color: C.textPrimary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: 6),
          const Text('人格', style: AppText.title),
        ],
      ),
    );
  }

  /// 联网补全人格：搜索她是谁，让模型把资料整理成结构化人设
  Widget _enrichButton() {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _enriching ? null : _enrichFromWeb,
        style: OutlinedButton.styleFrom(
          foregroundColor: C.accent,
          side: BorderSide(color: C.accent.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _enriching
            ? SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: C.accent,
                ),
              )
            : const Icon(Icons.travel_explore_rounded, size: 18),
        label: Text(
          _enriching ? '正在检索…' : '联网补全人格',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  bool _enriching = false;

  /// 步骤：搜她的名字 → 抓几页正文 → 让模型总结成结构化人设 → 回填表单
  Future<void> _enrichFromWeb() async {
    final name = _s.aiName.trim().isEmpty ? '她' : _s.aiName.trim();

    final kwCtrl = TextEditingController(text: name);
    final keywords = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('让她去查点什么', style: AppText.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '会联网搜索这个名字，把资料整理成她的人设。\n'
              '可以加上作品名、出处等限定词，查得更准。',
              style: AppText.meta.copyWith(color: C.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kwCtrl,
              autofocus: true,
              style: AppText.bodySmall,
              cursorColor: C.accent,
              decoration: InputDecoration(
                hintText: '例如：云若 小说 角色设定',
                hintStyle: AppText.meta.copyWith(color: C.textTertiary),
                filled: true,
                fillColor: C.surface3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: C.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消',
                style: AppText.bodySmall.copyWith(color: C.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(kwCtrl.text.trim()),
            child: Text('开始',
                style: AppText.bodySmall.copyWith(color: C.accent)),
          ),
        ],
      ),
    );
    if (keywords == null || keywords.isEmpty || !mounted) return;

    setState(() => _enriching = true);
    try {
      // 1. 搜索
      final results = await WebSearch.search(keywords, limit: 5);
      if (results.isEmpty) {
        _toast('没搜到结果（可能网络不通，或被搜索引擎拦了）');
        return;
      }

      // 2. 抓前两页正文（控制体积，别把上下文塞爆）
      final buffer = StringBuffer();
      for (final r in results.take(3)) {
        buffer.writeln('【${r.title}】${r.snippet}');
      }
      for (final r in results.take(2)) {
        final text = await WebSearch.fetchText(r.url, maxChars: 2500);
        if (text.isNotEmpty) buffer.writeln('\n--- ${r.title} ---\n$text');
      }

      // 3. 让模型整理成结构化人设
      final client = LlmClient();
      final provider = _s.providers.firstWhere(
        (p) => p.id == _s.activeProviderId,
        orElse: () => _s.providers.first,
      );
      final out = StringBuffer();
      await for (final d in client.streamChat(
        provider: provider,
        systemPrompt:
            '你是角色设定编辑。根据给定的公开资料，提炼出一个可扮演的角色设定。'
            '只输出 JSON，不要解释，不要代码块标记。',
        messages: [
          ChatMessage(
            role: ChatRole.user,
            text: '角色名：$name\n\n资料：\n${buffer.toString()}\n\n'
                '请输出 JSON，字段：\n'
                '{"tagline":"一句话气质(≤12字)",'
                '"traits":["标签1","标签2","标签3"],'
                '"greeting":"她开口的第一句(≤20字)",'
                '"persona":"人设正文(150-300字，用第二人称写她，包含说话方式、在意什么、如何表达关心)"}',
            time: DateTime.now(),
          ),
        ],
        temperature: 0.7,
        maxTokens: 900,
      )) {
        if (d.content.isNotEmpty) out.write(d.content);
      }
      client.dispose();

      final parsed = _parsePersonaJson(out.toString());
      if (parsed == null) {
        _toast('模型没给出可用结果，再试一次？');
        return;
      }
      if (!mounted) return;
      _update(_s.copyWith(
        personaTagline: parsed['tagline'] ?? _s.personaTagline,
        personaTraits: (parsed['traits'] as List?)?.cast<String>() ??
            _s.personaTraits,
        personaGreeting: parsed['greeting'] ?? _s.personaGreeting,
        personaText: parsed['persona'] ?? _s.personaText,
      ));
      // 表单控制器要跟着更新，否则界面还显示旧文字
      _tagline.text = _s.personaTagline;
      _traits.text = _s.personaTraits.join('、');
      _greeting.text = _s.personaGreeting;
      _body.text = _s.personaText;
      _toast('人格已补全，看看合不合意');
    } catch (e) {
      _toast('出错了：$e');
    } finally {
      if (mounted) setState(() => _enriching = false);
    }
  }

  Map<String, dynamic>? _parsePersonaJson(String raw) {
    var s = raw.trim();
    // 模型可能包了代码块
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    s = s.substring(start, end + 1);
    try {
      final map = jsonDecode(s);
      return map is Map<String, dynamic> ? map : null;
    } catch (_) {
      return null;
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8, left: 6),
        child: Text(title, style: AppText.sectionLabel),
      );

  Widget _cardBox(List<Widget> children) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, color: C.border));
      }
      rows.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: C.surface2,
        borderRadius: BorderRadius.circular(AppMetrics.cardRadius),
        border: Border.all(color: C.border, width: 1),
      ),
      child: Column(children: rows),
    );
  }

  /// 她是谁 —— 这张卡是页面主体
  Widget _card() {
    final bytes = AppSettings.decodeAvatar(_s.aiAvatarBase64);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 参考 Radix violet / Tailwind violet 的成熟色阶：
    // 浅色用 violet-2 → white，深色用 violet-12 压到近黑，右上角一团紫光。
    final gradient = isDark
        ? const [Color(0xFF241B3F), Color(0xFF0B0B12)]
        : const [Color(0xFFF2EDFF), Color(0xFFFFFFFF)];
    final glow = isDark ? const Color(0x4D7C5CFF) : const Color(0x33C4B5FD);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF3A2F63) : const Color(0xFFE3DBFF),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x66000000) : const Color(0x148B5CF6),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 右上角紫光，让纯色卡片不显得平
            Positioned(
              right: -60,
              top: -70,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glow, glow.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: C.surface3,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.55),
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                child: bytes == null
                    ? Text(
                        _s.aiName.isEmpty ? '云' : _s.aiName.characters.first,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: C.textPrimary,
                        ),
                      )
                    : Image.memory(Uint8List.fromList(bytes),
                        fit: BoxFit.cover, filterQuality: FilterQuality.high),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _s.aiName.isEmpty ? '未命名' : _s.aiName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: C.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _s.personaTagline,
                      style: AppText.meta.copyWith(
                        color: C.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_s.personaTraits.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final trait in _s.personaTraits)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: C.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: C.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      trait,
                      style: TextStyle(
                        fontSize: 12,
                        color: C.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (_s.personaGreeting.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                // 用主题表面色而不是半透明黑：浅色主题下黑蒙层会让文字糊成一团
                color: C.surface1,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('她开口的第一句',
                      style: AppText.sectionLabel.copyWith(fontSize: 10)),
                  const SizedBox(height: 6),
                  Text(
                    '「${_s.personaGreeting}」',
                    style: AppText.body.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(label, style: AppText.meta),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppText.bodySmall,
              cursorColor: C.accent,
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppText.meta.copyWith(
                  fontSize: 11,
                  color: C.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
