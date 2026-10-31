import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/storage/conversation_store.dart';
import '../../core/storage/settings_store.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/app_settings.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../shared/app_chrome.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_page.dart';
import '../settings/settings_page.dart';

/// 首页：App 打开看到的是「她」和最近的会话，
/// 而不是直接砸一脸聊天记录 —— 这样顶部的返回键才有意义。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ConversationStore _store = ConversationStore();
  final SettingsStore _settingsStore = SettingsStore();
  List<Conversation> _conversations = const [];
  AppSettings _settings = defaultSettings();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var list = await _store.load();
    final s = await _settingsStore.load();
    // 首次使用：先把默认会话落盘，这样首页就能看到它
    if (list.isEmpty) {
      final name = s.aiName.trim().isEmpty ? '她' : s.aiName.trim();
      list = [
        Conversation(
          id: 'seed',
          title: '与$name的对话',
          messages: demoMessages(),
          createdAt: DateTime(2026, 10, 30, 22, 40),
          updatedAt: DateTime(2026, 10, 30, 22, 49),
        ),
      ];
      await _store.save(list);
    }
    if (!mounted) return;
    setState(() {
      _conversations = list;
      _settings = s;
    });
  }

  Future<void> _openChat({String? conversationId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => conversationId == null
            // 没有指定会话 = 新建一个，而不是复用第一张卡片
            ? const ChatPage(forceNew: true)
            : ChatPage(initialConversationId: conversationId),
      ),
    );
    await _load();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          initial: _settings,
          onChanged: (next) {
            setState(() => _settings = next);
            _settingsStore.save(next);
          },
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: appOverlay(
        context,
        Column(
          children: [
            // 首页顶栏本身没有独立底色，用页面背景色填满状态栏区域即可
            statusBarFilled(context, color: c.bg, child: _topBar(c)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _heroCard(c),
                  const SizedBox(height: 22),
                  if (_conversations.isNotEmpty) _recentHeader(c),
                  for (final conv in _conversations) _conversationTile(c, conv),
                  if (_conversations.isEmpty) _emptyHint(c),
                ],
              ),
            ),
            _newChatButton(c),
          ],
        ),
      ),
    );
  }

  Widget _topBar(AppColors c) {
    return SizedBox(
      height: AppMetrics.topBarHeight,
      child: Row(
        children: [
          const SizedBox(width: 18),
          Text(
            '她',
            style: AppText.title.copyWith(color: c.textPrimary),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              final next =
                  ThemeController.mode.value == 'dark' ? 'light' : 'dark';
              ThemeController.set(next);
              setState(() {});
            },
            icon: Icon(
              ThemeController.mode.value == 'dark'
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 21,
            ),
            color: c.textSecondary,
            tooltip: '切换明暗',
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined, size: 21),
            color: c.textSecondary,
            tooltip: '设置',
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _heroCard(AppColors c) {
    final bytes = AppSettings.decodeAvatar(_settings.aiAvatarBase64);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.borderStrong),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.accentSoft,
            c.surface2,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.surface1,
              borderRadius: BorderRadius.circular(20),
              // 透明边框：不要那圈紫色描边，让头像本身干净
              border: Border.all(color: Colors.transparent),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: bytes == null
                ? Text(
                    _settings.aiName.isEmpty
                        ? '云'
                        : _settings.aiName.characters.first,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  )
                : Image.memory(
                    Uint8List.fromList(bytes),
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _settings.aiName.isEmpty ? '未命名' : _settings.aiName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _settings.personaTagline,
                  style: AppText.meta.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentHeader(AppColors c) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          '最近的对话',
          style: AppText.sectionLabel.copyWith(color: c.textTertiary),
        ),
      );

  Widget _conversationTile(AppColors c, Conversation conv) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.surface2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openChat(conversationId: conv.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conv.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySmall.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _preview(conv),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta.copyWith(color: c.textTertiary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: c.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 会话卡片上的最后一条消息预览
  String _preview(Conversation c) {
    for (var i = c.messages.length - 1; i >= 0; i--) {
      final m = c.messages[i];
      if (m.role == ChatRole.system) continue;
      if (m.isSticker) return '[表情]';
      final t = (m.text ?? '').replaceAll('\n', ' ').trim();
      if (t.isNotEmpty) return t;
    }
    return '还没有消息';
  }

  Widget _emptyHint(AppColors c) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          child: Text(
            '还没有对话，点下面的按钮跟她说第一句话',
            style: AppText.meta.copyWith(color: c.textTertiary),
          ),
        ),
      );

  Widget _newChatButton(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            key: const Key('new-chat'),
            onPressed: () => _openChat(),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 19),
            label: const Text(
              '开始新对话',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
