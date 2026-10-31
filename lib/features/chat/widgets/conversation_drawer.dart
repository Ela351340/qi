import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../models/chat_message.dart';
import '../../../models/conversation.dart';
import '../../../theme/app_theme.dart';

/// 会话列表抽屉。结构照 Telegram / WeChat 的会话列表：
/// 顶部资料头 → 新建按钮 → 带头像和预览的会话行 → 底部设置。
class ConversationDrawer extends StatelessWidget {
  final List<Conversation> conversations;
  final String activeId;
  final bool enabled;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;
  final VoidCallback onCreate;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenMemory;

  /// 顶部资料头用的名字与头像
  final String ownerName;
  final Uint8List? ownerAvatar;

  const ConversationDrawer({
    super.key,
    required this.conversations,
    required this.activeId,
    required this.onSelect,
    required this.onDelete,
    required this.onCreate,
    required this.ownerName,
    this.ownerAvatar,
    this.onOpenSettings,
    this.onOpenMemory,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: C.surface3,
      child: SafeArea(
        child: Column(
          children: [
            _header(),
            Divider(height: 1, color: C.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: _newChatButton(),
            ),
            Expanded(
              child: conversations.isEmpty
                  ? _empty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      itemCount: conversations.length,
                      itemBuilder: (context, i) => _conversationRow(i),
                    ),
            ),
            Divider(height: 1, color: C.border),
            _footerRow(
              icon: Icons.psychology_alt_outlined,
              label: '记忆',
              onTap: onOpenMemory,
            ),
            Padding(
              padding: EdgeInsets.only(left: 46),
              child: Divider(height: 1, color: C.border),
            ),
            _footerRow(
              icon: Icons.settings_outlined,
              label: '设置',
              onTap: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Row(
        children: [
          _avatar(ownerName, ownerAvatar, 46, 15),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ownerName, style: AppText.title),
                const SizedBox(height: 3),
                Text(
                  '${conversations.length} 个会话 · 仅存本机',
                  style: AppText.subtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _newChatButton() {
    return InkWell(
      onTap: enabled ? onCreate : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: C.accentSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 19, color: C.accent),
            SizedBox(width: 6),
            Text(
              '新建对话',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: C.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined,
              size: 28, color: C.textTertiary),
          const SizedBox(height: 10),
          Text('还没有会话', style: AppText.meta),
        ],
      ),
    );
  }

  Widget _conversationRow(int i) {
    final c = conversations[i];
    final selected = c.id == activeId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? C.surface2 : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? () => onSelect(c.id) : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            child: Row(
              children: [
                _avatar(c.title, null, 42, 14),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? C.textPrimary
                              : C.textPrimary
                                  .withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _preview(c),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta.copyWith(
                          fontSize: 12,
                          color: C.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _timeLabel(c.updatedAt),
                      style: AppText.meta.copyWith(
                        fontSize: 11,
                        color: selected
                            ? C.accent
                            : C.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: enabled ? () => onDelete(c.id) : null,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 14, color: C.textTertiary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footerRow({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(icon, size: 19, color: C.textSecondary),
              const SizedBox(width: 12),
              Text(label, style: AppText.bodySmall),
              const Spacer(),
              Icon(Icons.chevron_right,
                  size: 18, color: C.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  /// 会话行的头像：有图用图，没图用标题首字（底色由标题散列决定，避免全灰）
  Widget _avatar(String seed, Uint8List? bytes, double size, double radius) {
    final char = seed.isEmpty ? '?' : seed.characters.first;
    final palette = [
      const Color(0xFF2B2555),
      const Color(0xFF1B2A24),
      const Color(0xFF2A2118),
      const Color(0xFF1F2430),
      const Color(0xFF2A1B22),
    ];
    final color = palette[seed.hashCode.abs() % palette.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: C.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: bytes == null
          ? Text(
              char,
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w600,
                color: C.textPrimary.withValues(alpha: 0.85),
              ),
            )
          : Image.memory(bytes, fit: BoxFit.cover),
    );
  }

  /// 最后一条消息的预览：表情消息显示「[表情]」
  static String _preview(Conversation c) {
    for (var i = c.messages.length - 1; i >= 0; i--) {
      final m = c.messages[i];
      if (m.role == ChatRole.system) continue;
      if (m.isSticker) return '[表情]';
      final t = (m.text ?? '').replaceAll('\n', ' ').trim();
      if (t.isNotEmpty) return t;
    }
    return '还没有消息';
  }

  static String _timeLabel(DateTime t) {
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    String two(int v) => v.toString().padLeft(2, '0');
    if (sameDay) return '${two(t.hour)}:${two(t.minute)}';
    if (t.year == now.year) return '${two(t.month)}/${two(t.day)}';
    return '${t.year}/${two(t.month)}/${two(t.day)}';
  }
}
