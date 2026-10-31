import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/notify/notification_service.dart';
import '../../core/notify/quiet_hours.dart';
import '../../core/settings/feature_prefs.dart';
import '../../core/voice/tts_service.dart';
import '../../core/llm/llm_provider.dart';
import '../../core/theme/chat_schemes.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/app_settings.dart';
import '../../shared/app_chrome.dart';
import '../../theme/app_theme.dart';
import '../avatar/avatar_crop_page.dart';
import '../persona/persona_page.dart';

/// 设置页。结构照 Telegram / iOS 设置那套：
/// 顶部资料卡 → 分组卡片 → 每行「图标 + 标题 + 当前值 + 箭头」。
class SettingsPage extends StatefulWidget {
  final AppSettings initial;
  final ValueChanged<AppSettings> onChanged;

  const SettingsPage({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettings _s = widget.initial;
  final ImagePicker _picker = ImagePicker();

  /// 气泡配色：浅色在前，深色在后
  static const List<int> _swatches = [
    // 浅色
    0xFFFDE8EC,
    0xFFF7EFE3,
    0xFFE9DCC8,
    0xFFFBEFD5,
    0xFFD8F3E3,
    0xFFD6E8FA,
    0xFFE4E0FA,
    0xFFDCF8C6,
    0xFFEEFFDE,
    0xFF95EC69,
    // 中间调
    0xFF0B6BC4,
    0xFF0A84FF,
    0xFFFF8A80,
    0xFF31C48D,
    0xFFE5484D,
    // 深色
    0xFF23252E,
    0xFF1F2430,
    0xFF1B2A24,
    0xFF2A2118,
    0xFF2A1B22,
    0xFF2B2555,
    0xFF1F1F25,
    0xFF101014,
  ];

  /// 聊天背景预设：浅色 / 中性 / 深色都有，不再只有深色
  static const List<int> _bgSwatches = [
    // 浅色
    0xFFFAF7F2,
    0xFFF4F4F7,
    0xFFEDEDED,
    0xFFE7EBF0,
    0xFFECE5DD,
    0xFFF3ECE2,
    0xFFEAF3EA,
    0xFFF7EEF2,
    // 中性
    0xFFDDE4EC,
    0xFFD9D5CE,
    // 深色
    0xFF23252E,
    0xFF1B1B22,
    0xFF12161F,
    0xFF1A1420,
    0xFF101C18,
    0xFF0A0A0C,
    0xFF000000,
  ];

  void _update(AppSettings next) {
    setState(() => _s = next);
    widget.onChanged(next);
  }

  /// 从相册选一张：原图原样取出，不缩放、不重编码
  Future<Uint8List?> _galleryBytes() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return picked.readAsBytes();
  }

  /// 点头像 → 弹来源菜单（拍照 / 相册 / 调整当前）→ 裁剪 → 立即生效。
  /// 这是 QQ 的做法：每次点都让你选来源，而不是直接拿旧图去裁。
  Future<void> _editAvatar({required bool forAi}) async {
    final existing = AppSettings.decodeAvatar(
      forAi ? _s.aiAvatarBase64 : _s.userAvatarBase64,
    );
    final c = C;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(),
              const SizedBox(height: 10),
              _avatarSheetItem(
                icon: Icons.photo_library_outlined,
                label: '从手机相册选择',
                value: 'gallery',
              ),
              _avatarSheetItem(
                icon: Icons.photo_camera_outlined,
                label: '拍照',
                value: 'camera',
              ),
              if (existing != null)
                _avatarSheetItem(
                  icon: Icons.crop_rounded,
                  label: '调整当前头像',
                  value: 'adjust',
                ),
              const SizedBox(height: 4),
              _avatarSheetItem(
                icon: Icons.close_rounded,
                label: '取消',
                value: 'cancel',
                danger: false,
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null || action == 'cancel') return;

    Uint8List? source;
    switch (action) {
      case 'gallery':
        source = await _galleryBytes();
        break;
      case 'camera':
        source = await _cameraBytes();
        break;
      case 'adjust':
        source = existing == null ? null : Uint8List.fromList(existing);
        break;
    }
    if (source == null || !mounted) return;
    await _cropAndSave(bytes: source, forAi: forAi, canPickAnother: true);
  }

  Widget _avatarSheetItem({
    required IconData icon,
    required String label,
    required String value,
    bool danger = false,
  }) {
    final color = danger ? C.danger : C.textPrimary;
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(label, style: AppText.bodySmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  /// 拍照取一张（不压缩）
  Future<Uint8List?> _cameraBytes() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return null;
    return picked.readAsBytes();
  }

  /// 进裁剪页，确认后直接存下来（QQ 也是裁完立即生效，没有二次确认）
  Future<void> _cropAndSave({
    required Uint8List bytes,
    required bool forAi,
    bool canPickAnother = true,
  }) async {
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => AvatarCropPage(
          bytes: bytes,
          onPickAnother: canPickAnother ? _galleryBytes : null,
        ),
      ),
    );
    if (cropped == null) return;
    final b64 = base64Encode(cropped);
    _update(forAi
        ? _s.copyWith(aiAvatarBase64: b64)
        : _s.copyWith(userAvatarBase64: b64));
  }

  Future<void> _pickImage({required bool forAi, bool forBg = false}) async {
    // 背景图：压到 1080 宽，够用又不占地方
    if (forBg) {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (picked == null) return;
      _update(_s.copyWith(
        bgImageBase64: base64Encode(await picked.readAsBytes()),
      ));
      return;
    }
    await _editAvatar(forAi: forAi);
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                children: [
                  const SizedBox(height: 16),
                  _profileCard(),
                  _section('配色方案'),
                  _card([
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _schemeWrap(),
                    ),
                  ]),
                  _section('外观'),
                  _card([
                    _row(
                      icon: Icons.badge_outlined,
                      title: '人格卡片',
                      trailing: _value(_s.personaTagline),
                      onTap: _openPersona,
                    ),
                    _row(
                      icon: Icons.face_retouching_natural_rounded,
                      title: '她的头像',
                      trailing: _avatarPreview(_s.aiAvatarBase64),
                      onTap: () => _pickImage(forAi: true),
                    ),
                    _row(
                      icon: Icons.person_outline_rounded,
                      title: '我的头像',
                      trailing: _avatarPreview(_s.userAvatarBase64),
                      onTap: () => _pickImage(forAi: false),
                    ),
                    _row(
                      icon: Icons.wallpaper_rounded,
                      title: '聊天背景',
                      trailing: _bgPreview(),
                      onTap: _openBackgroundSheet,
                    ),
                    _row(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: '气泡颜色',
                      trailing: _bubblePreview(),
                      onTap: _openBubbleSheet,
                    ),
                  ]),
                  _section('对话'),
                  _card([
                    _sliderRow(
                      icon: Icons.emoji_emotions_outlined,
                      label: '主动发表情的概率',
                      value: _s.stickerProbability,
                      hint: _s.stickerProbability == 0
                          ? '从不主动发'
                          : '约每 ${(100 / _s.stickerProbability).round()} 条回复发一张',
                      onChanged: (v) =>
                          _update(_s.copyWith(stickerProbability: v)),
                    ),
                  ]),
                  _section('她'),
                  _card([
                    _switchRow(
                      icon: Icons.record_voice_over_outlined,
                      label: '语音朗读回复',
                      value: FeaturePrefs.voiceEnabled,
                      onChanged: (v) async {
                        await FeaturePrefs.setVoice(v);
                        TtsService.enabled = v;
                        setState(() {});
                      },
                    ),
                    if (FeaturePrefs.voiceEnabled)
                      _row(
                        icon: Icons.graphic_eq_rounded,
                        title: '音色',
                        trailing: _value(FeaturePrefs.ttsVoice.isEmpty
                            ? '系统默认'
                            : FeaturePrefs.ttsVoice.split('-').last),
                        onTap: _pickVoice,
                      ),
                    _switchRow(
                      icon: Icons.auto_awesome_outlined,
                      label: '自动整理记忆',
                      value: FeaturePrefs.autoMemoryEnabled,
                      onChanged: (v) async {
                        await FeaturePrefs.setAutoMemory(v);
                        setState(() {});
                      },
                    ),
                    _switchRow(
                      icon: Icons.waving_hand_outlined,
                      label: '主动找你说话',
                      value: FeaturePrefs.proactiveEnabled,
                      onChanged: (v) async {
                        await FeaturePrefs.setProactive(v);
                        if (v) {
                          await NotificationService.requestPermission();
                        }
                        setState(() {});
                      },
                    ),
                    if (FeaturePrefs.proactiveEnabled)
                      _row(
                        icon: Icons.timer_outlined,
                        title: '多久没聊就开口',
                        trailing: _value('${FeaturePrefs.proactiveHours} 小时'),
                        onTap: _pickProactiveHours,
                      ),
                  ]),
                  _section('通知'),
                  _card([
                    _switchRow(
                      icon: Icons.notifications_none_rounded,
                      label: '收到回复时提醒',
                      value: _s.notifyEnabled,
                      onChanged: (v) async {
                        _update(_s.copyWith(notifyEnabled: v));
                        if (v) await NotificationService.requestPermission();
                      },
                    ),
                    _switchRow(
                      icon: Icons.nightlight_outlined,
                      label: '免打扰时段',
                      value: _s.quietEnabled,
                      onChanged: (v) => _update(_s.copyWith(quietEnabled: v)),
                    ),
                    if (_s.quietEnabled) ...[
                      _row(
                        icon: Icons.schedule_rounded,
                        title: '开始',
                        trailing: _value(_s.quietStart),
                        onTap: () => _editTime(isStart: true),
                      ),
                      _row(
                        icon: Icons.schedule_rounded,
                        title: '结束',
                        trailing: _value(_s.quietEnd),
                        onTap: () => _editTime(isStart: false),
                      ),
                    ],
                  ]),
                  _section('模型服务'),
                  _card([
                    ...List.generate(
                      _s.providers.length,
                      (i) => _providerRow(i),
                    ),
                    // 自己加一个服务商：任何 OpenAI 兼容接口都能填
                    _row(
                      icon: Icons.add_rounded,
                      title: '添加模型服务',
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: C.textTertiary,
                      ),
                      onTap: _addProvider,
                    ),
                    _row(
                      icon: Icons.wifi_tethering_rounded,
                      title: '测试连接',
                      trailing: Icon(Icons.chevron_right,
                          size: 18, color: C.textTertiary),
                      onTap: _testProvider,
                    ),
                  ]),
                  _section('关于'),
                  _card([
                    _row(
                      icon: Icons.info_outline_rounded,
                      title: '版本',
                      // 构建号写死在这里，方便一眼确认装的是哪一版
                      trailing: _value('1.5.0 (构建 49)'),
                    ),
                    _row(
                      icon: Icons.code_rounded,
                      title: '开源许可',
                      // 打开 Flutter 内置的许可证页，自动列出所有依赖的完整许可证
                      trailing: _value('MIT'),
                      onTap: _openLicenses,
                    ),
                    _row(
                      icon: Icons.emoji_emotions_outlined,
                      title: '表情图形',
                      // Twemoji 要求署名，商用允许（CC-BY 4.0）
                      trailing: _value('Twemoji · CC-BY 4.0'),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 顶栏 ----------

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
          const Text('设置', style: AppText.title),
        ],
      ),
    );
  }

  // ---------- 资料卡 ----------

  Widget _profileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.border, width: 1),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickImage(forAi: true),
            child: Stack(
              children: [
                _avatarBox(_s.aiAvatarBase64, '云', 56),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: C.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.surface2, width: 2),
                    ),
                    child: const Icon(Icons.edit,
                        size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const ValueKey('ai-name-field'),
                  initialValue: _s.aiName,
                  style: AppText.title,
                  cursorColor: C.accent,
                  onChanged: (v) => _update(_s.copyWith(aiName: v)),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text('角色资料 · 点左侧头像可换', style: AppText.subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarBox(String? b64, String fallback, double size) {
    final bytes = AppSettings.decodeAvatar(b64);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: C.surface3,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: bytes == null
          ? Text(
              fallback,
              style: TextStyle(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w600,
                color: C.textSecondary,
              ),
            )
          : Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover),
    );
  }

  // ---------- 通用行 ----------

  /// 配色方案：一次设定背景 + 双方气泡 + 主题明暗，避免自己拼出撞色
  Widget _schemeWrap() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ChatScheme.all.map((s) {
        final selected = _s.bgColor == s.bg.toARGB32() &&
            _s.bubbleSelfColor == s.selfBubble.toARGB32() &&
            _s.bubbleOtherColor == s.otherBubble.toARGB32() &&
            _s.bgImageBase64 == null;
        return GestureDetector(
          key: ValueKey('scheme-${s.id}'),
          onTap: () => _applyScheme(s),
          child: Container(
            width: 96,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
            decoration: BoxDecoration(
              color: C.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? C.accent : C.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      for (final color in s.preview)
                        Expanded(
                          child: Container(height: 14, color: color),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta.copyWith(
                    fontSize: 11,
                    color: selected ? C.accent : C.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _applyScheme(ChatScheme s) {
    final isDarkNow = Theme.of(context).brightness == Brightness.dark;

    // 深色模式下背景强制纯黑：选方案只换气泡颜色，不动背景、不切主题
    if (isDarkNow) {
      _update(_s.copyWith(
        bubbleSelfColor: s.selfBubble.toARGB32(),
        bubbleOtherColor: s.otherBubble.toARGB32(),
      ));
      return;
    }

    _update(_s.copyWith(
      bgColor: s.bg.toARGB32(),
      bubbleSelfColor: s.selfBubble.toARGB32(),
      bubbleOtherColor: s.otherBubble.toARGB32(),
      clearBgImage: true,
    ));
    // 浅色下选到深色方案：切到深色，背景自然是黑
    if (s.isDark) ThemeController.set('dark');
    if (mounted) setState(() {});
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8, left: 6),
        child: Text(title, style: AppText.sectionLabel),
      );

  Widget _card(List<Widget> children) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 46),
          child: Divider(height: 1, color: C.border),
        ));
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

  /// 图标放进柔色小方块里 —— 这是「成品感」最省力的一招。
  Widget _iconBox(IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: C.accentSoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 17, color: C.accent),
    );
  }

  Widget _value(String text) => Text(
        text,
        style: AppText.meta.copyWith(color: C.textSecondary),
      );

  Widget _chevron() => Icon(Icons.chevron_right,
      size: 18, color: C.textTertiary);

  Widget _row({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            _iconBox(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppText.bodySmall)),
            ?trailing,
            if (onTap != null) const SizedBox(width: 4),
            if (onTap != null) _chevron(),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
      child: Row(
        children: [
          _iconBox(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppText.bodySmall)),
          Switch(value: value, activeThumbColor: Colors.white,
              activeTrackColor: C.accent, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _sliderRow({
    required IconData icon,
    required String label,
    required int value,
    required String hint,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppText.bodySmall)),
              _value('$value%'),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: C.accent,
              inactiveTrackColor: C.border,
              thumbColor: Colors.white,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Text(hint, style: AppText.meta.copyWith(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _providerRow(int index) {
    final p = _s.providers[index];
    final active = p.id == _s.activeProviderId;
    return InkWell(
      onTap: () => _update(_s.copyWith(activeProviderId: p.id)),
      onLongPress: () => _editProvider(index),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: active ? C.accentSoft : C.surface3,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                active ? Icons.check_rounded : Icons.memory_rounded,
                size: 16,
                color: active ? C.accent : C.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: AppText.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    p.model,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _editProvider(index),
              icon: const Icon(Icons.tune_rounded, size: 18),
              color: C.textTertiary,
              tooltip: '编辑',
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 预览小件 ----------

  /// 背景的当前状态用「文字」显示，避免和气泡那两个色点看起来一样
  Widget _bgPreview() {
    final bytes = AppSettings.decodeAvatar(_s.bgImageBase64);
    final label = bytes != null
        ? '图片'
        : (_s.bgColor == 0 ? '跟随主题' : '纯色');
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: bytes != null
                  ? C.surface2
                  : (_s.bgColor == 0 ? C.bg : Color(_s.bgColor)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: C.borderStrong, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes == null
                ? null
                : Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppText.meta.copyWith(color: C.textSecondary)),
        ],
      ),
    );
  }

  Widget _bubblePreview() {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        children: [
          _dot(_s.bubbleSelfColor == 0 ? C.bubbleSelf.toARGB32() : _s.bubbleSelfColor),
          const SizedBox(width: 4),
          _dot(_s.bubbleOtherColor == 0 ? C.bubbleOther.toARGB32() : _s.bubbleOtherColor),
        ],
      ),
    );
  }

  Widget _dot(int color) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Color(color),
          shape: BoxShape.circle,
          border: Border.all(color: C.borderStrong, width: 1),
        ),
      );

  // ---------- 弹层 ----------

  Future<void> _openPersona() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PersonaPage(
          initial: _s,
          onChanged: (next) {
            setState(() => _s = next);
            widget.onChanged(next);
          },
        ),
      ),
    );
    // 回来时同步一次，免得人格页改的名字没反映到设置页
    if (mounted) setState(() {});
  }

  Future<void> _openBackgroundSheet() async {
    String? flash;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('聊天背景', style: AppText.title),
                  const Spacer(),
                  if (flash != null) _flashPill(flash!),
                ],
              ),
              const SizedBox(height: 18),
              Text('纯色', style: AppText.sectionLabel),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(_bgSwatches.length, (i) {
                  final c = _bgSwatches[i];
                  final selected = c == _s.bgColor && _s.bgImageBase64 == null;
                  return GestureDetector(
                    key: ValueKey('bg-swatch-$i'),
                    onTap: () {
                      _update(_s.copyWith(bgColor: c, clearBgImage: true));
                      flash = '背景 · ${_bgName(c)}';
                      setSheet(() {});
                      Future.delayed(const Duration(milliseconds: 900), () {
                        if (!mounted) return;
                        flash = null;
                        setSheet(() {});
                      });
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(c),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: selected
                              ? C.accent
                              : C.borderStrong,
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 22),
              Text('图片', style: AppText.sectionLabel),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _sheetButton(
                      icon: Icons.photo_library_outlined,
                      label: '从相册选',
                      onTap: () async {
                        await _pickImage(forAi: false, forBg: true);
                        setSheet(() {});
                      },
                    ),
                  ),
                  if (_s.bgImageBase64 != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _sheetButton(
                        icon: Icons.restart_alt_rounded,
                        label: '移除图片',
                        onTap: () {
                          _update(_s.copyWith(clearBgImage: true));
                          setSheet(() {});
                        },
                      ),
                    ),
                  ],
                ],
              ),
              if (_s.bgImageBase64 != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    Uint8List.fromList(
                      AppSettings.decodeAvatar(_s.bgImageBase64)!,
                    ),
                    height: 90,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBubbleSheet() async {
    String? flash;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('气泡颜色', style: AppText.title),
                  const Spacer(),
                  if (flash != null) _flashPill(flash!),
                ],
              ),
              const SizedBox(height: 18),
              _colorPicker(
                label: '我的气泡',
                id: 'self',
                current: _s.bubbleSelfColor,
                onPick: (c) {
                  _update(_s.copyWith(bubbleSelfColor: c));
                  flash = '我的气泡 · ${_colorName(c)}';
                  setSheet(() {});
                  Future.delayed(const Duration(milliseconds: 900), () {
                    if (!mounted) return;
                    flash = null;
                    setSheet(() {});
                  });
                },
              ),
              const SizedBox(height: 18),
              _colorPicker(
                label: '她的气泡',
                id: 'other',
                current: _s.bubbleOtherColor,
                onPick: (c) {
                  _update(_s.copyWith(bubbleOtherColor: c));
                  flash = '她的气泡 · ${_colorName(c)}';
                  setSheet(() {});
                  Future.delayed(const Duration(milliseconds: 900), () {
                    if (!mounted) return;
                    flash = null;
                    setSheet(() {});
                  });
                },
              ),
              const SizedBox(height: 14),
              Text(
                '两边设成同一个颜色，就是不区分',
                style: AppText.meta.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 选色后短暂出现的小冒泡
  Widget _flashPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: C.accentSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: AppText.meta.copyWith(fontSize: 11, color: C.accent),
      ),
    );
  }

  /// 背景预设色的名字
  static String _bgName(int value) {
    switch (value) {
      case 0xFF0E0E11:
        return '近黑';
      case 0xFF12161F:
        return '深蓝';
      case 0xFF1A1420:
        return '暗紫';
      case 0xFF101C18:
        return '墨绿';
      case 0xFF1F1614:
        return '深褐';
      case 0xFF1B1B22:
        return '石板';
      case 0xFF0A0A0C:
        return '纯黑';
      case 0xFF23252E:
        return '钢灰';
      default:
        return '自定义';
    }
  }

  /// 给常见预设色起个名字，选色提示里显示
  static String _colorName(int value) {
    switch (value) {
      case 0xFFFDE8EC:
        return '樱花';
      case 0xFFF7EFE3:
        return '米白';
      case 0xFFE9DCC8:
        return '亚麻';
      case 0xFFFBEFD5:
        return '奶油';
      case 0xFFD8F3E3:
        return '薄荷';
      case 0xFFD6E8FA:
        return '天蓝';
      case 0xFFE4E0FA:
        return '淡紫';
      case 0xFFDCF8C6:
        return '浅绿';
      case 0xFFEEFFDE:
        return '嫩绿';
      case 0xFF95EC69:
        return '微信绿';
      case 0xFF0B6BC4:
        return 'iMessage 蓝';
      case 0xFF0A84FF:
        return '亮蓝';
      case 0xFFFF8A80:
        return '珊瑚';
      case 0xFF31C48D:
        return '青绿';
      case 0xFFE5484D:
        return '朱红';
      case 0xFF23252E:
        return '石板';
      case 0xFF1F2430:
        return '藏蓝';
      case 0xFF1B2A24:
        return '墨绿';
      case 0xFF2A2118:
        return '咖啡';
      case 0xFF2A1B22:
        return '酒红';
      case 0xFF2B2555:
        return '暗紫';
      case 0xFF1F1F25:
        return '深灰';
      case 0xFF101014:
        return '近黑';
      default:
        return '自定义';
    }
  }

  Widget _sheetHandle() => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: C.borderStrong,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _sheetButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: C.surface3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: C.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: AppText.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _colorPicker({
    required String label,
    required String id,
    required int current,
    required ValueChanged<int> onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.bodySmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(_swatches.length, (i) {
            final c = _swatches[i];
            final selected = c == current;
            return GestureDetector(
              key: ValueKey('swatch-$id-$i'),
              onTap: () => onPick(c),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        selected ? C.accent : C.borderStrong,
                    width: selected ? 2 : 1,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Future<void> _editTime({required bool isStart}) async {
    final current = parseHhMm(isStart ? _s.quietStart : _s.quietEnd) ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final value = formatHhMm(picked.hour * 60 + picked.minute);
    _update(isStart
        ? _s.copyWith(quietStart: value)
        : _s.copyWith(quietEnd: value));
  }

  Future<void> _editProvider(int index) async {
    final p = _s.providers[index];
    final urlCtrl = TextEditingController(text: p.baseUrl);
    final keyCtrl = TextEditingController(text: p.apiKey);
    final modelCtrl = TextEditingController(text: p.model);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(p.name, style: AppText.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField('接口地址', urlCtrl, hint: 'https://…/v1'),
              const SizedBox(height: 14),
              _dialogField('API Key', keyCtrl, hint: '本地模型可留空', obscure: true),
              const SizedBox(height: 14),
              _dialogField('模型名', modelCtrl, hint: 'qwen3:8b'),
            ],
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
                style:
                    AppText.bodySmall.copyWith(color: C.accent)),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final next = List.of(_s.providers);
    next[index] = p.copyWith(
      baseUrl: urlCtrl.text.trim(),
      apiKey: keyCtrl.text.trim(),
      model: modelCtrl.text.trim(),
    );
    _update(_s.copyWith(providers: next));
  }

  /// 发一个最小请求验证当前服务是否可用，把真实状态码/报错原文摊开给用户看
  Future<void> _testProvider() async {
    final p = _s.providers.firstWhere(
      (x) => x.id == _s.activeProviderId,
      orElse: () => _s.providers.first,
    );
    final uri = Uri.parse('${p.normalizedBaseUrl}/chat/completions');
    final key = p.sanitizedApiKey;

    String result;
    var ok = false;
    var reachable = false;
    var statusCode = 0;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      if (key.isNotEmpty) {
        req.headers.set('Authorization', 'Bearer $key');
      }
      req.add(utf8.encode(jsonEncode({
        'model': p.model,
        'stream': false,
        'max_tokens': 8,
        'messages': [
          {'role': 'user', 'content': 'ping'},
        ],
        ...p.extraBody,
      })));
      final resp = await req.close().timeout(const Duration(seconds: 20));
      final body = await resp.transform(utf8.decoder).join();
      reachable = true;
      statusCode = resp.statusCode;
      ok = resp.statusCode == 200;
      final short = body.length > 240 ? body.substring(0, 240) : body;
      result = 'HTTP ${resp.statusCode}\n\n$short';
      client.close();
    } catch (e) {
      result = '连不上：$e\n\n地址：$uri';
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              ok
                  ? Icons.check_circle_outline
                  : (reachable
                      ? Icons.report_problem_outlined
                      : Icons.cloud_off_rounded),
              size: 20,
              color: ok ? C.accent : C.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // 把"连不上网络"和"服务器拒绝"分开，不然永远在猜
                ok
                    ? '连接正常'
                    : (reachable
                        ? '服务器拒绝（HTTP $statusCode）'
                        : '无法连接'),
                style: AppText.title,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${p.name} · ${p.model}',
                style: AppText.meta.copyWith(color: C.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                uri.toString(),
                style: AppText.meta.copyWith(
                  fontSize: 11,
                  color: C.textTertiary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: C.surface3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.border),
                ),
                child: SelectableText(
                  result,
                  style: AppText.meta.copyWith(
                    fontSize: 11,
                    height: 1.4,
                    color: C.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('关闭',
                style: AppText.bodySmall.copyWith(color: C.accent)),
          ),
        ],
      ),
    );
  }

  /// 添加一个自定义模型服务（任何 OpenAI 兼容接口）
  /// 打开许可证页：Flutter 会把所有依赖的 LICENSE 文本聚合展示，
  /// 选 TTS 音色（列出手机里所有中文音色）
  Future<void> _pickVoice() async {
    final voices = await TtsService.chineseVoices();
    if (!mounted) return;
    final picked = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: C.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            const SizedBox(height: 8),
            if (voices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  '这台手机的语音引擎没有中文音色。\n'
                  '装一个语音引擎（如 Google 语音服务、讯飞语记）后再来看。',
                  textAlign: TextAlign.center,
                  style: AppText.meta.copyWith(color: C.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      title: Text('系统默认',
                          style: AppText.bodySmall.copyWith(color: C.accent)),
                      onTap: () => Navigator.of(ctx)
                          .pop({'name': '', 'locale': 'zh-CN'}),
                    ),
                    for (final v in voices)
                      ListTile(
                        title: Text(
                          v['name']!,
                          style: AppText.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          v['locale']!,
                          style: AppText.meta.copyWith(
                              fontSize: 10, color: C.textTertiary),
                        ),
                        trailing: FeaturePrefs.ttsVoice == v['name']
                            ? Icon(Icons.check, size: 18, color: C.accent)
                            : null,
                        onTap: () => Navigator.of(ctx).pop(v),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await FeaturePrefs.setTtsVoice(picked['name'] ?? '');
    await TtsService.selectVoice(
      picked['name'] ?? '',
      picked['locale'] ?? 'zh-CN',
    );
    setState(() {});
  }

  /// 主动聊天：多久没聊就开口
  Future<void> _pickProactiveHours() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: C.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            const SizedBox(height: 8),
            for (final h in [2, 4, 6, 12, 24])
              InkWell(
                onTap: () => Navigator.of(ctx).pop(h),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    '$h 小时',
                    style: AppText.bodySmall.copyWith(
                      color: h == FeaturePrefs.proactiveHours
                          ? C.accent
                          : C.textPrimary,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await FeaturePrefs.setProactiveHours(picked);
    setState(() {});
  }

  /// 这正好满足 BSD/Apache 的署名与随包分发义务。
  void _openLicenses() {
    showLicensePage(
      context: context,
      applicationName: '栖',
      applicationVersion: '1.5.0',
      applicationLegalese: '本应用源码以 MIT 许可发布。\n'
          '表情图形来自 Twemoji（CC-BY 4.0，署名：Twitter, Inc. and other contributors）。',
    );
  }

  Future<void> _addProvider() async {
    final nameCtrl = TextEditingController(text: '自定义');
    final urlCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    final modelCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: C.surface2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('添加模型服务', style: AppText.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('快速选择',
                  style: AppText.meta.copyWith(color: C.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _presetChip('DeepSeek', () => setDlg(() {
                        nameCtrl.text = 'DeepSeek';
                        urlCtrl.text = 'https://api.deepseek.com/v1';
                        modelCtrl.text = 'deepseek-flash';
                      })),
                  _presetChip('通义千问', () => setDlg(() {
                        nameCtrl.text = '通义千问';
                        urlCtrl.text =
                            'https://dashscope.aliyuncs.com/compatible-mode/v1';
                        modelCtrl.text = 'qwen-plus';
                      })),
                  _presetChip('本机 Ollama', () => setDlg(() {
                        nameCtrl.text = '本地 Ollama';
                        urlCtrl.text = 'http://127.0.0.1:11434/v1';
                        modelCtrl.text = 'qwen3:8b';
                      })),
                ],
              ),
              const SizedBox(height: 16),
              _dialogField('名称', nameCtrl, hint: '我的服务'),
              const SizedBox(height: 14),
              _dialogField('接口地址', urlCtrl, hint: 'https://…/v1'),
              const SizedBox(height: 14),
              _dialogField('API Key', keyCtrl, hint: '本地模型可留空', obscure: true),
              const SizedBox(height: 14),
              _dialogField('模型名', modelCtrl,
                  hint: 'deepseek-flash / qwen-plus / qwen3:8b'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消',
                style:
                    AppText.bodySmall.copyWith(color: C.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text('添加', style: AppText.bodySmall.copyWith(color: C.accent)),
          ),
        ],
      ),
      ),
    );

    if (saved != true) return;
    if (!mounted) return;
    final url = urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('接口地址不能为空')),
      );
      return;
    }
    // 模型名必填：留空会让服务端直接拒绝，报错信息还很难懂
    final model = modelCtrl.text.trim();
    if (model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('模型名不能为空，例如 deepseek-flash'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final name = nameCtrl.text.trim().isEmpty ? '自定义' : nameCtrl.text.trim();
    final id = 'custom-${DateTime.now().millisecondsSinceEpoch}';
    final provider = LlmProvider(
      id: id,
      name: name,
      baseUrl: url,
      apiKey: keyCtrl.text.trim(),
      model: model,
    );
    _update(_s.copyWith(
      providers: [..._s.providers, provider],
      activeProviderId: id,
    ));
  }

  /// 预设选项小胶囊
  Widget _presetChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: C.accentSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppText.meta.copyWith(
            fontSize: 12,
            color: C.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 头像预览：有图显示图，没图显示占位图标
  Widget _avatarPreview(String? base64) {
    final bytes = AppSettings.decodeAvatar(base64);
    if (bytes == null) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Icon(Icons.add_a_photo_outlined, size: 17, color: C.textTertiary),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.memory(
          Uint8List.fromList(bytes),
          width: 26,
          height: 26,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController c,
      {String? hint, bool obscure = false}) {
    return TextField(
      controller: c,
      style: AppText.bodySmall,
      cursorColor: C.accent,
      obscureText: obscure,
      enableSuggestions: !obscure,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppText.meta,
        hintStyle: AppText.meta.copyWith(color: C.textTertiary),
        filled: true,
        fillColor: C.surface3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: C.accent),
        ),
      ),
    );
  }
}
