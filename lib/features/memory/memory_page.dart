import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/memory_item.dart';
import '../../shared/app_chrome.dart';
import '../../theme/app_theme.dart';

/// 记忆页：看得见、改得动、删得掉。
/// 大肥鱼那份研究里最强调的一点就是「人工可管理」，这个页面的存在就是为了它。
class MemoryPage extends StatefulWidget {
  final List<MemoryItem> initial;
  final Future<void> Function(List<MemoryItem>) onChanged;
  final String? dirPath;

  /// 由聊天页提供：调模型把最近的对话整理成条目。
  final Future<List<MemoryItem>> Function()? onSummarize;

  const MemoryPage({
    super.key,
    required this.initial,
    required this.onChanged,
    this.dirPath,
    this.onSummarize,
  });

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  late List<MemoryItem> _items = List.of(widget.initial);
  final TextEditingController _input = TextEditingController();
  String _category = MemoryItem.fact;
  bool _summarizing = false;

  Future<void> _summarize() async {
    final fn = widget.onSummarize;
    if (fn == null || _summarizing) return;
    setState(() => _summarizing = true);
    try {
      final added = await fn();
      if (!mounted) return;
      if (added.isEmpty) {
        _toast('这次对话里没提炼出值得记的东西');
      } else {
        await _commit([...added, ..._items]);
        if (mounted) _toast('新增 ${added.length} 条');
      }
    } catch (e) {
      if (mounted) _toast('整理失败：$e');
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _commit(List<MemoryItem> next) async {
    setState(() => _items = next);
    await widget.onChanged(next);
  }

  Future<void> _add() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await _commit([
      MemoryItem(
        category: _category,
        text: text,
        createdAt: DateTime.now(),
        source: '手动添加',
      ),
      ..._items,
    ]);
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _edit(MemoryItem item) async {
    final ctrl = TextEditingController(text: item.text);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(MemoryItem.labelOf(item.category), style: AppText.title),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          minLines: 2,
          style: AppText.bodySmall,
          cursorColor: C.accent,
          decoration: InputDecoration(
            hintText: '这条记忆的内容',
            hintStyle: TextStyle(color: C.textTertiary),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消',
                style: AppText.bodySmall
                    .copyWith(color: C.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('保存',
                style: AppText.bodySmall.copyWith(color: C.accent)),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    await _commit([
      for (final i in _items)
        if (identical(i, item))
          MemoryItem(
            category: item.category,
            text: text,
            createdAt: item.createdAt,
            source: item.source,
          )
        else
          i,
    ]);
  }

  Future<void> _delete(MemoryItem item) async {
    await _commit([for (final i in _items) if (!identical(i, item)) i]);
  }

  Future<void> _copyAll() async {
    final text = _items
        .map((i) => i.toMarkdownLine())
        .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast('已复制，可以粘贴到任何地方保存');
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text ?? '';
    if (raw.trim().isEmpty) {
      if (mounted) _toast('剪贴板是空的');
      return;
    }
    final parsed = <MemoryItem>[];
    // 支持带标题分组的格式，也支持裸行
    var category = MemoryItem.fact;
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.startsWith('# ')) {
        final label = t.substring(2).trim();
        if (label == '事件') category = MemoryItem.episode;
        if (label == '画像') category = MemoryItem.profile;
        if (label == '事实') category = MemoryItem.fact;
        continue;
      }
      final item = MemoryItem.parseLine(t, category);
      if (item != null) parsed.add(item);
    }
    if (parsed.isEmpty) {
      if (mounted) _toast('没解析出条目，格式应为 - [2026-01-01] 内容');
      return;
    }
    await _commit([...parsed, ..._items]);
    if (mounted) _toast('导入 ${parsed.length} 条');
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _infoCard(),
                  const SizedBox(height: 8),
                  for (final category in MemoryItem.categories)
                    ..._categorySection(category),
                  const SizedBox(height: 8),
                  Text(
                    '共 ${_items.length} 条',
                    style: AppText.meta.copyWith(color: C.textTertiary),
                  ),
                ],
              ),
            ),
            _addBar(),
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
          const Text('记忆', style: AppText.title),
          const Spacer(),
          IconButton(
            onPressed: _copyAll,
            icon: const Icon(Icons.copy_all_outlined, size: 19),
            color: C.textSecondary,
            tooltip: '复制全部',
          ),
          IconButton(
            onPressed: _importFromClipboard,
            icon: const Icon(Icons.content_paste_rounded, size: 19),
            color: C.textSecondary,
            tooltip: '从剪贴板导入',
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined,
                  size: 16, color: C.textSecondary),
              const SizedBox(width: 8),
              Text('存在本地文件里', style: AppText.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.dirPath ?? '…/memory/  （facts.md / episodes.md / profile.md）',
            style: AppText.meta.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            '一行一条，格式：- [2026-01-01] 内容 | 来源。'
            '导出后可以用任何编辑器改，再粘回来。',
            style: AppText.meta.copyWith(
              fontSize: 11,
              color: C.textTertiary,
            ),
          ),
          if (widget.onSummarize != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: _summarize,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: C.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: C.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_summarizing)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: C.accent,
                        ),
                      )
                    else
                      Icon(Icons.auto_awesome,
                          size: 15, color: C.accent),
                    const SizedBox(width: 8),
                    Text(
                      _summarizing ? '正在整理…' : '从最近的对话整理记忆',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: C.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _categorySection(String category) {
    final list = _items.where((i) => i.category == category).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8, left: 4),
        child: Row(
          children: [
            Text(MemoryItem.labelOf(category), style: AppText.sectionLabel),
            const SizedBox(width: 6),
            Text('${list.length}',
                style: AppText.meta.copyWith(color: C.textTertiary)),
          ],
        ),
      ),
      if (list.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: C.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.border, width: 1),
          ),
          child: Text('还没有', style: AppText.meta),
        )
      else
        Container(
          decoration: BoxDecoration(
            color: C.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.border, width: 1),
          ),
          child: Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: C.border),
                _itemRow(list[i]),
              ],
            ],
          ),
        ),
    ];
  }

  Widget _itemRow(MemoryItem item) {
    return InkWell(
      onTap: () => _edit(item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.text, style: AppText.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    [
                      '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')}',
                      if (item.source.isNotEmpty) item.source,
                    ].join(' · '),
                    style:
                        AppText.meta.copyWith(fontSize: 11, color: C.textTertiary),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _delete(item),
              icon: const Icon(Icons.close_rounded, size: 15),
              color: C.textTertiary,
              tooltip: '删除这条',
            ),
          ],
        ),
      ),
    );
  }

  Widget _addBar() {
    return Container(
      decoration: BoxDecoration(
        color: C.surface3,
        border: Border(top: BorderSide(color: C.border, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: bottomBarFilled(
        context,
        color: C.surface3,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final c in MemoryItem.categories)
                        ChoiceChip(
                          label: Text(
                            MemoryItem.labelOf(c),
                            style: TextStyle(
                              fontSize: 11,
                              color: _category == c
                                  ? Colors.white
                                  : C.textSecondary,
                            ),
                          ),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                          backgroundColor: C.surface2,
                          selectedColor: C.accent,
                          side: BorderSide(color: C.border),
                          visualDensity: VisualDensity.compact,
                          showCheckmark: false,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: C.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.border),
                    ),
                    child: TextField(
                      controller: _input,
                      style: AppText.bodySmall,
                      cursorColor: C.accent,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        border: InputBorder.none,
                        hintText: '手动加一条…',
                        hintStyle:
                            TextStyle(color: C.textTertiary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              key: const Key('memory-add'),
              onTap: _add,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: C.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_upward_rounded,
                    size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
