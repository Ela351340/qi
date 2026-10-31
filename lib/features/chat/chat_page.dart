import 'dart:async';
import 'dart:math';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/llm/llm_client.dart';
import '../../core/llm/llm_provider.dart';
import '../../core/llm/sticker_tag.dart';
import '../../core/memory/memory_prompt.dart';
import '../../core/memory/memory_store.dart';
import '../../core/notify/notification_service.dart';
import '../../core/notify/quiet_hours.dart';
import '../../core/stickers/ai_sticker_store.dart';
import '../../core/stickers/sticker_catalog.dart';
import '../../core/chat/attachment_store.dart';
import '../../core/settings/feature_prefs.dart';
import '../../core/stickers/user_sticker_store.dart';
import '../../core/voice/tts_service.dart';
import '../../core/storage/conversation_store.dart';
import '../../core/storage/settings_store.dart';
import '../../models/app_settings.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../models/memory_item.dart';
import '../../models/sticker.dart';
import '../../shared/app_chrome.dart';
import '../../theme/app_theme.dart';
import '../memory/memory_page.dart';
import '../settings/settings_page.dart';
import '../stickers/sticker_panel.dart';
import 'widgets/conversation_drawer.dart';
import 'widgets/message_bubble.dart';

class ChatPage extends StatefulWidget {
  final bool initialPanelOpen;

  /// 测试注入点：给一条假的流，就不用真连模型。
  final Stream<LlmDelta> Function(List<ChatMessage> history)? streamOverride;

  final LlmProvider? providerOverride;
  final String? systemPromptOverride;

  /// 测试用：把发图概率钉成固定值，避免随机导致用例时好时坏。
  final int? stickerProbabilityOverride;

  /// 首次启动是否灌演示消息。正式版会关掉。
  final bool seedDemo;

  /// Conversation id passed in from the home page.
  final String? initialConversationId;

  /// True when opened from the home page's New chat button.
  final bool forceNew;

  /// 测试用：直接给一份表情包，跳过资源加载
  final StickerCatalog? catalogOverride;

  const ChatPage({
    super.key,
    this.initialPanelOpen = false,
    this.streamOverride,
    this.providerOverride,
    this.systemPromptOverride,
    this.stickerProbabilityOverride,
    this.seedDemo = true,
    this.initialConversationId,
    this.forceNew = false,
    this.catalogOverride,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final TextEditingController _input = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ConversationStore _store = ConversationStore();
  final SettingsStore _settingsStore = SettingsStore();
  final LlmClient _client = LlmClient();
  final StickerGate _gate = StickerGate();

  StickerCatalog? _catalog;
  AppSettings _settings = defaultSettings();

  final MemoryStore _memoryStore = MemoryStore();
  final UserStickerStore _userStickerStore = UserStickerStore();
  final AiStickerStore _aiStickerStore = AiStickerStore();
  List<AiSticker> _aiStickers = const [];
  final ImagePicker _picker = ImagePicker();
  final AttachmentStore _attachments = AttachmentStore();
  List<File> _userStickerFiles = const [];
  List<MemoryItem> _memories = const [];
  String? _memoryDir;

  /// App 在前台就不弹通知，避免自己在看还被打扰。
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  late List<Conversation> _conversations;
  int _activeIndex = 0;
  late bool _panelOpen = widget.initialPanelOpen;
  bool _sending = false;

  /// 面板停在哪一页：0 emoji / 1 我的 / 2 她的 / 3 附件
  int _panelTab = 0;

  /// 输入框有没有字（决定显示 + 还是发送），单独记避免整页重建
  bool _hasText = false;
  StreamSubscription<LlmDelta>? _sub;

  /// 发给模型的历史上限。防止上下文无限膨胀吃内存、烧 token。
  static const int _maxHistoryForModel = 40;

  Conversation get _active => _conversations[_activeIndex];
  List<ChatMessage> get _messages => _active.messages;

  LlmProvider get _provider =>
      widget.providerOverride ??
      _settings.providers.firstWhere(
        (p) => p.id == _settings.activeProviderId,
        orElse: () => _settings.providers.first,
      );

  int get _stickerProbability =>
      widget.stickerProbabilityOverride ?? _settings.stickerProbability;

  /// 头像/背景的字节缓存。
  ///
  /// 这里必须缓存：`Uint8List.fromList` 每次都生成新对象，Flutter 的
  /// MemoryImage 用字节对象本身当缓存键，结果就是**每次 build 都重新解码**。
  /// 打字时整页重建几十次，头像就被反复解码几十次，直接卡成幻灯片。
  Uint8List? _aiAvatarBytes;
  Uint8List? _userAvatarBytes;
  Uint8List? _bgImageBytes;

  void _refreshImageCaches() {
    final ai = AppSettings.decodeAvatar(_settings.aiAvatarBase64);
    final user = AppSettings.decodeAvatar(_settings.userAvatarBase64);
    final bg = AppSettings.decodeAvatar(_settings.bgImageBase64);
    _aiAvatarBytes = ai == null ? null : Uint8List.fromList(ai);
    _userAvatarBytes = user == null ? null : Uint8List.fromList(user);
    _bgImageBytes = bg == null ? null : Uint8List.fromList(bg);
  }

  Uint8List? get _aiAvatar => _aiAvatarBytes;

  Uint8List? get _userAvatar => _userAvatarBytes;

  String get _systemPrompt =>
      widget.systemPromptOverride ??
      (_settings.personaText.trim().isEmpty
          ? AppConfig.defaultSystemPrompt
          : _settings.personaText);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 先给一个同步的初始状态，保证首帧就有内容，不会闪空白。
    _conversations = [
      if (widget.seedDemo)
        Conversation(
          id: 'seed',
          title: '与云若的对话',
          messages: demoMessages(),
          createdAt: DateTime(2026, 10, 30, 22, 40),
          updatedAt: DateTime(2026, 10, 30, 22, 49),
        ),
    ];
    if (_conversations.isEmpty) _conversations.add(Conversation.empty());
    // 只在"有没有字"发生变化时重建，否则每敲一个字都重建整页，
    // 消息一多就卡成幻灯片。
    _input.addListener(() {
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _restore();
    _loadStickers();
    _loadUserStickers();
    _loadFeatures();
    _loadAiStickers();
    _loadSettings();
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    final items = await _memoryStore.loadAll();
    final dir = await _memoryStore.directoryPath();
    if (!mounted) return;
    setState(() {
      _memories = items;
      _memoryDir = dir;
    });
  }

  Future<void> _loadSettings() async {
    final s = await _settingsStore.load();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _refreshImageCaches();
    });
  }

  Future<void> _openMemory() async {
    Navigator.of(context).maybePop();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoryPage(
          initial: _memories,
          dirPath: _memoryDir,
          onSummarize: _summarizeMemory,
          onChanged: (items) async {
            _memories = items;
            await _memoryStore.saveAll(items);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  /// 让模型把当前对话整理成记忆条目。用主 provider，一次性调用。
  Future<List<MemoryItem>> _summarizeMemory() async {
    final prompt = buildSummarizePrompt(_messages);
    final buffer = StringBuffer();
    await for (final delta in _client.streamChat(
      provider: _provider,
      systemPrompt: '你是记忆整理助手。严格按用户要求的格式输出条目，不要任何解释。',
      messages: [
        ChatMessage(
          role: ChatRole.user,
          text: prompt,
          time: DateTime.now(),
        ),
      ],
      maxTokens: 600,
    )) {
      buffer.write(delta.content);
    }
    return parseExtracted(buffer.toString(), source: _active.title);
  }

  Future<void> _openSettings() async {
    Navigator.of(context).maybePop(); // 先关抽屉
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          initial: _settings,
          onChanged: (s) {
            setState(() {
      _settings = s;
      _refreshImageCaches();
    });
            _settingsStore.save(s);
          },
        ),
      ),
    );
  }

  // ---------- 语音 / 主动聊天 / 自动记忆 ----------

  int _msgsSinceSummary = 0;

  Future<void> _loadFeatures() async {
    await FeaturePrefs.load();
    TtsService.enabled = FeaturePrefs.voiceEnabled;
    await TtsService.setPitch(FeaturePrefs.ttsPitch);
    if (FeaturePrefs.ttsVoice.isNotEmpty) {
      await TtsService.selectVoice(FeaturePrefs.ttsVoice, 'zh-CN');
    }
    if (!mounted) return;
    setState(() {});
  }

  /// 她说完了，读出来（仅在开启语音时）
  Future<void> _speakIfEnabled(String text) async {
    // 测试里注入了假的流，不要去碰真实 TTS 平台通道
    if (widget.streamOverride != null) return;
    if (!FeaturePrefs.voiceEnabled) return;
    await TtsService.speak(text);
  }

  /// 聊够一定轮数就顺手把记忆整理掉，不用用户手动点
  Future<void> _autoSummarizeIfDue() async {
    if (widget.streamOverride != null) return;
    if (!FeaturePrefs.autoMemoryEnabled) return;
    if (_sending) return;
    _msgsSinceSummary++;
    if (_msgsSinceSummary < 6) return;
    _msgsSinceSummary = 0;
    try {
      final items = await _summarizeMemory();
      if (items.isEmpty || !mounted) return;
      final merged = [..._memories];
      for (final it in items) {
        final dup = merged.any((m) =>
            m.text.trim() == it.text.trim() && m.category == it.category);
        if (!dup) merged.add(it);
      }
      if (merged.length == _memories.length) return;
      await _memoryStore.saveAll(merged);
      if (!mounted) return;
      setState(() => _memories = merged);
    } catch (_) {
      // 后台整理失败不该打断聊天
    }
  }

  /// 主动开口：很久没聊了，她说一句话，并通过通知提醒
  Future<void> _maybeProactive() async {
    if (widget.streamOverride != null) return;
    if (!FeaturePrefs.proactiveEnabled) return;
    if (_sending) return;

    final now = DateTime.now();
    // 0 点到 10 点之间不打扰（睡觉时间）
    if (now.hour < 10) return;

    final msgs = _messages;
    final last = msgs.isEmpty ? now : msgs.last.time;
    final gap = now.difference(last);
    if (gap.inHours < FeaturePrefs.proactiveHours) return;

    // 随机窗口：到了该开口的时间还没到点，就先不开口
    if (FeaturePrefs.proactiveNextAt > 0 &&
        now.millisecondsSinceEpoch < FeaturePrefs.proactiveNextAt) {
      return;
    }

    // 免打扰时段内不开口
    if (_settings.quietEnabled &&
        isInQuietHours(
          now: now,
          start: _settings.quietStart,
          end: _settings.quietEnd,
        )) {
      return;
    }

    try {
      final buffer = StringBuffer();
      final prompt = '现在没有人跟你说话，隔了${gap.inHours}小时。'
          '用你本来的语气主动说一句话（不超过 20 字），'
          '可以问一句、可以只说自己在做什么，不要寒暄客套，不要加引号。';
      await for (final d in _client.streamChat(
        provider: _provider,
        systemPrompt: _effectiveSystemPrompt,
        messages: [
          ..._messages.take(5).where((m) => m.text != null),
          ChatMessage(
            role: ChatRole.user,
            text: prompt,
            time: DateTime.now(),
            status: ChatStatus.done,
          ),
        ],
        temperature: 0.9,
        maxTokens: 80,
      )) {
        if (d.content.isNotEmpty) buffer.write(d.content);
      }
      final text = buffer.toString().trim();
      if (text.isEmpty || !mounted) return;
      final cleaned = StickerTag.strip(text);
      setState(() {
        _messages.add(ChatMessage(
          role: ChatRole.bot,
          text: cleaned.isEmpty ? text : cleaned,
          time: DateTime.now(),
        ));
        _active.updatedAt = DateTime.now();
      });
      _persist();
      if (_lifecycle != AppLifecycleState.resumed) {
        await NotificationService.show(
          title: _settings.aiName.isEmpty ? '她' : _settings.aiName,
          body: cleaned.isEmpty ? text : cleaned,
        );
      }
      await _speakIfEnabled(cleaned.isEmpty ? text : cleaned);
      // 说完了，重新掷一次骰子：基准小时 + 0~150 分钟的随机偏移
      await _scheduleNextProactive();
    } catch (_) {
      // 主动开口失败就静默，别弹错误打扰用户
    }
  }

  /// 安排下一次主动开口的时间（随机化，避免每天同一时刻出现）
  Future<void> _scheduleNextProactive() async {
    final base = Duration(hours: FeaturePrefs.proactiveHours);
    final jitter = Duration(minutes: 15 + Random().nextInt(150));
    final next = DateTime.now().add(base + jitter);
    await FeaturePrefs.setNextAt(next.millisecondsSinceEpoch);
  }

  Future<void> _loadStickers() async {
    if (widget.catalogOverride != null) {
      setState(() => _catalog = widget.catalogOverride);
      return;
    }
    try {
      final c = await StickerCatalog.load();
      if (!mounted) return;
      setState(() => _catalog = c);
    } catch (_) {
      // 资源缺失不该影响聊天
    }
  }

  /// 人设 + 记忆 + 表情协议。
  /// 记忆放人设后面：先立人格，再补事实，模型不容易被记忆带跑。
  String get _effectiveSystemPrompt {
    final base = _systemPrompt;
    final buffer = StringBuffer(base);
    final memoryBlock = buildMemoryBlock(_memories);
    if (memoryBlock.isNotEmpty) buffer.write('\n$memoryBlock');
    final c = _catalog;
    if (c != null && c.aiHasStickers) {
      buffer.write('\n${AppConfig.stickerInstructions(c.aiPack.promptList)}');
    }
    return buffer.toString();
  }

  Future<void> _restore() async {
    final saved = await _store.load();
    if (!mounted) return;

    // 从首页「开始新对话」进来：载入已有会话后，新建一个并选中。
    // 没有这段的话，会直接打开第一张已有会话卡片。
    if (widget.forceNew) {
      setState(() {
        _conversations = saved;
        _activeIndex = 0;
      });
      _createConversation(closeDrawer: false);
      return;
    }

    if (saved.isEmpty) return;
    setState(() {
      _conversations = saved;
      final want = widget.initialConversationId;
      final idx = want == null ? -1 : saved.indexWhere((c) => c.id == want);
      _activeIndex = idx >= 0 ? idx : 0;
    });
  }

  Future<void> _persist() => _store.save(_conversations);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      _maybeProactive();
    }
  }

  /// 收到回复后在后台时提醒一次。免打扰时段内静默。
  Future<void> _maybeNotify(String text) async {
    final s = _settings;
    if (!s.notifyEnabled) return;
    if (_lifecycle == AppLifecycleState.resumed) return; // 人正在看，别打扰
    if (s.quietEnabled &&
        isInQuietHours(
          now: DateTime.now(),
          start: s.quietStart,
          end: s.quietEnd,
        )) {
      return;
    }
    final body = text.replaceAll('\n', ' ').trim();
    if (body.isEmpty) return;
    await NotificationService.show(
      title: s.aiName.isEmpty ? '新消息' : s.aiName,
      body: body.length > 120 ? '${body.substring(0, 120)}…' : body,
    );
  }

  @override
  void dispose() {
    _dropOverlays();
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _client.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // 退场瞬间就把浮层收掉：等 dispose 会拖到转场动画结束，能看见残留
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) => _dropOverlays(),
      child: _buildScaffold(size),
    );
  }

  /// 立刻移除所有挂在 Overlay 上的浮层（菜单、顶部提示）
  void _dropOverlays() {
    _menuEntry?.remove();
    _menuEntry = null;
    _topToast?.remove();
    _topToast = null;
  }

  @override
  void deactivate() {
    _dropOverlays();
    super.deactivate();
  }

  Widget _buildScaffold(Size size) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: C.bg,
      drawer: ConversationDrawer(
        conversations: _conversations,
        activeId: _active.id,
        enabled: !_sending,
        onSelect: _selectConversation,
        onDelete: _deleteConversation,
        onCreate: _createConversation,
        onOpenSettings: _openSettings,
        onOpenMemory: _openMemory,
        ownerName: _settings.userNick.isEmpty ? '我' : _settings.userNick,
        ownerAvatar: _userAvatar,
      ),
      body: appOverlay(
        context,
        Stack(
          children: [
            Positioned.fill(child: _chatBackground()),
            Column(
              children: [
                // 顶栏颜色铺满状态栏区域，避免和状态栏之间出现断层
                statusBarFilled(context, color: C.surface3, child: _topBar()),
                // 键盘弹出只影响布局，别让消息区跟着重绘
                Expanded(
                  child: RepaintBoundary(
                    child: _messageList(size.width),
                  ),
                ),
                // 底部同理：输入栏/表情面板的颜色铺到手势条区域
                bottomBarFilled(
                  context,
                  color: C.surface3,
                  child: Column(
                    children: [
                      _inputBar(),
                      if (_panelOpen)
                        StickerPanel(
                          screenHeight: size.height,
                          onPickEmoji: (e) => setState(() {
                            _input.text += String.fromCharCode(
                              int.parse(e.code, radix: 16),
                            );
                          }),
                          onAddSticker: _addSticker,
                          userPack: _catalog?.userPack,
                          userFiles: _userStickerFiles,
                          aiPack: _catalog?.aiPack,
                          aiUserStickers: _aiStickers,
                          onAddAiSticker: _addAiSticker,
                          onDeleteAiSticker: _removeAiSticker,
                          initialTab: _panelTab,
                          onPickImage: _pickImagesAttach,
                          onPickVideo: _pickVideoAttach,
                          onPickFile: _pickFileAttach,
                          onPickFileSticker: _sendFileSticker,
                          onPickAssetSticker: _sendAssetSticker,
                          onDeleteSticker: _removeSticker,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _selectConversation(String id) {
    final i = _conversations.indexWhere((c) => c.id == id);
    if (i < 0) return;
    setState(() => _activeIndex = i);
    Navigator.of(context).maybePop();
  }

  void _createConversation({bool closeDrawer = true}) {
    final c = Conversation.empty();
    // 新会话用她的人设开场白起头，比空白页有温度
    final greeting = _settings.personaGreeting.trim();
    if (greeting.isNotEmpty) {
      c.messages.add(ChatMessage(
        role: ChatRole.bot,
        text: greeting,
        time: DateTime.now(),
      ));
    }
    setState(() {
      _conversations.insert(0, c);
      _activeIndex = 0;
    });
    _persist();
    if (closeDrawer) Navigator.of(context).maybePop();
  }

  void _deleteConversation(String id) {
    if (_conversations.length <= 1) return; // 至少留一个
    setState(() {
      _conversations.removeWhere((c) => c.id == id);
      if (_activeIndex >= _conversations.length) {
        _activeIndex = _conversations.length - 1;
      }
    });
    _persist();
  }

  /// 聊天区实际用的背景色。
  /// 深色主题下强制纯黑；浅色下跟随设置（0 = 跟随主题）。
  Color get _chatBgColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) return Colors.black;
    return _settings.bgColor == 0 ? C.bg : Color(_settings.bgColor);
  }

  /// 背景层：纯色，或一张图。图会压暗 55%，保证气泡和文字对比度。
  Widget _chatBackground() {
    final bytes = _bgImageBytes;
    if (bytes == null) {
      return ColoredBox(color: _chatBgColor);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          bytes,
          fit: BoxFit.cover,
          // 背景图按屏幕宽度解码，原图直接上会吃内存又卡
          cacheWidth: 1080,
          filterQuality: FilterQuality.low,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0x8C000000)),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Container(
      height: AppMetrics.topBarHeight,
      decoration: BoxDecoration(
        color: C.surface3,
        border: Border(
          bottom: BorderSide(color: C.border, width: 1),
        ),
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
          const SizedBox(width: 2),
          _headerAvatar(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _settings.aiName,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title,
                ),
                const SizedBox(height: 2),
                Text(
                  _sending ? '正在输入…' : '在线',
                  style: AppText.subtitle,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu_rounded, size: 22),
            color: C.textPrimary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _headerAvatar() {
    final bytes = _aiAvatar;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: C.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: bytes == null
          ? Text(
              _settings.aiName.isEmpty ? '云' : _settings.aiName.characters.first,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: C.textSecondary,
              ),
            )
          : Image.memory(bytes, fit: BoxFit.cover),
    );
  }

  /// 长按消息：贴着这条消息弹一个小气泡（复制 / 撤回 / 删除）
  Future<void> _openMessageMenu(int index, BuildContext bubbleCtx) async {
    if (index < 0 || index >= _messages.length) return;
    final m = _messages[index];
    final isUser = m.role == ChatRole.user;
    final canCopy = (m.text ?? '').isNotEmpty;
    final items = <_MenuAction>[
      if (canCopy)
        const _MenuAction(Icons.copy_rounded, '复制', 'copy'),
      if (isUser) const _MenuAction(Icons.undo_rounded, '撤回', 'recall'),
      const _MenuAction(Icons.delete_outline_rounded, '删除', 'delete',
          danger: true),
    ];

    // 定位：以气泡中心为锚点，尽量放上方；放不下就放下面
    final box = bubbleCtx.findRenderObject() as RenderBox?;
    final screen = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;
    Offset origin = Offset(screen.width / 2 - 60, screen.height / 2);
    double bubbleW = 120;
    if (box != null && box.hasSize) {
      origin = box.localToGlobal(Offset.zero);
      bubbleW = box.size.width;
    }

    final itemW = 54.0;
    final menuW = items.length * itemW + 16;
    const menuH = 54.0;
    var left = origin.dx + bubbleW / 2 - menuW / 2;
    left = left.clamp(8.0, screen.width - menuW - 8);

    // 默认摆在气泡正上方（三角朝下指向气泡）；顶部放不开才翻到下方
    var below = false;
    var top = origin.dy - menuH - 14;
    if (top < safeTop + 8) {
      top = origin.dy + 52;
      below = true;
    }
    final arrowX =
        (origin.dx + bubbleW / 2 - left).clamp(18.0, menuW - 18);

    final completer = Completer<String?>();
    late OverlayEntry entry;
    void close([String? v]) {
      if (entry.mounted) entry.remove();
      if (_menuEntry == entry) _menuEntry = null;
      if (!completer.isCompleted) completer.complete(v);
    }

    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // 点空白处关闭
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => close(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: _menuBubble(
              menuW: menuW,
              itemW: itemW,
              arrowX: arrowX,
              arrowBelow: !below,
              items: items,
              onTap: (v) => close(v),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(entry);
    // 记下引用：页面被 pop / 销毁时一起移除，避免菜单残留在别的界面
    _menuEntry = entry;

    final action = await completer.future;
    if (!mounted || action == null) return;

    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.text ?? ''));
        if (!mounted) return;
        _toast('已复制');
        break;
      case 'recall':
        setState(() {
          _messages[index] = ChatMessage(
            role: ChatRole.system,
            text: '你撤回了一条消息',
            time: DateTime.now(),
          );
        });
        _persist();
        _toast('你撤回了一条消息');
        break;
      case 'delete':
        setState(() => _messages.removeAt(index));
        _persist();
        _toast('已删除');
        break;
    }
  }

  /// 贴着气泡的小菜单：圆角胶囊 + 一个指向消息的小三角
  Widget _menuBubble({
    required double menuW,
    required double itemW,
    required double arrowX,
    required bool arrowBelow,
    required List<_MenuAction> items,
    required ValueChanged<String> onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuFill =
        isDark ? const Color(0xFF2A2A33) : C.surface1;

    final bubble = Container(
      width: menuW,
      height: 46,
      decoration: BoxDecoration(
        // 无描边、无"底部投影"：offset 归零就不会在下方留一道深色线。
        // 深色主题下表面色是纯黑，会和背景糊住，所以用一个中性灰。
        color: menuFill,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final it in items)
            SizedBox(
              width: itemW,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(it.value),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      it.icon,
                      size: 17,
                      color: it.danger ? C.danger : C.textPrimary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      it.label,
                      style: AppText.meta.copyWith(
                        fontSize: 10,
                        color: it.danger ? C.danger : C.textSecondary,
                        // 明确关掉装饰：Overlay 里会继承到带下划线的样式
                        decoration: TextDecoration.none,
                        decorationColor: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    final arrow = Transform.rotate(
      angle: 0.785398, // 45°，做成小三角
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: menuFill),
      ),
    );

    return SizedBox(
      width: menuW,
      height: 54,
      child: Stack(
        // 不裁剪：小三角要能探出去一点，才能真正“指”到气泡
        clipBehavior: Clip.none,
        children: [
          Positioned(
            // 默认菜单在气泡上方，三角在底部
            top: arrowBelow ? 0 : 8,
            left: 0,
            right: 0,
            child: bubble,
          ),
          Positioned(
            left: arrowX - 3,
            top: arrowBelow ? 43 : 3,
            child: arrow,
          ),
        ],
      ),
    );
  }

  /// QQ 风格的顶部提醒：淡入 + 轻微下滑，1.5 秒自动消失。
  /// 撤回/删除/复制这类反馈走它，不用底部 SnackBar，避免挡住输入栏。
  /// 长按菜单的浮层，页面销毁时要一起移除
  OverlayEntry? _menuEntry;

  OverlayEntry? _topToast;

  void _showTopToast(String text) {
    _topToast?.remove();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 10,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * -10),
                  child: child,
                ),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: C.surface1.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: C.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: AppText.meta.copyWith(color: C.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    _topToast = entry;
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_topToast == entry) {
        entry.remove();
        _topToast = null;
      }
    });
  }

  void _toast(String text) => _showTopToast(text);

  Widget _messageList(double screenWidth) {
    final items = <Widget>[];
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final prev = i > 0 ? _messages[i - 1] : null;
      final showTime = prev == null ||
          m.time.difference(prev.time).inMinutes >= 5 ||
          m.role == ChatRole.system;
      if (showTime && m.role != ChatRole.system) {
        items.add(TimeDivider(time: m.time));
      }
      items.add(
        // 用 Builder 拿到这条气泡自己的 context，长按菜单才能贴着它弹出来
        Builder(
          builder: (bubbleCtx) => MessageBubble(
            message: m,
            screenWidth: screenWidth,
            onRetry: m.status == ChatStatus.failed ? () => _retry(i) : null,
            onLongPress: m.role == ChatRole.system
                ? null
                : () => _openMessageMenu(i, bubbleCtx),
            selfAvatar: _userAvatar,
            otherAvatar: _aiAvatar,
            selfLabel: _settings.userNick.isEmpty ? '我' : _settings.userNick,
            otherLabel: _settings.aiName.isEmpty ? '云' : _settings.aiName,
            selfColor: _settings.bubbleSelfColor == 0
                ? C.bubbleSelf
                : Color(_settings.bubbleSelfColor),
            otherColor: _settings.bubbleOtherColor == 0
                ? C.bubbleOther
                : Color(_settings.bubbleOtherColor),
          ),
        ),
      );
    }
    // reverse: true 让消息贴底，跟 QQ 一致；数据仍按正序喂进来。
    return ListView(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: items.reversed.toList(),
    );
  }

  Widget _inputBar() {
    return Container(
      decoration: BoxDecoration(
        // 底部操作栏和顶部导航栏同色，整体像一条外壳
        color: C.surface3,
        border: Border(top: BorderSide(color: C.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Icon(Icons.mic_none_rounded,
                size: 22, color: C.textTertiary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              // 高度跟着内容走：一行时 44，最多长到 5 行
              constraints: const BoxConstraints(
                minHeight: AppMetrics.inputFieldHeight,
                maxHeight: AppMetrics.inputFieldHeight + 4 * 22,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: C.surface2,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: C.border, width: 1),
              ),
              child: TextField(
                controller: _input,
                style: AppText.bodySmall,
                cursorColor: C.accent,
                // 输入框自己处理换行；发送交给右侧按钮，不抢回车
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '',
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _panelOpen = !_panelOpen),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                _panelOpen
                    ? Icons.keyboard_alt_outlined
                    : Icons.emoji_emotions_outlined,
                size: 23,
                color: _panelOpen
                    ? C.accent
                    : C.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 2),
            _sendButton(_hasText),
        ],
      ),
    );
  }

  /// 空输入时是「+」，有字时变成实心圆形发送键 —— 状态一眼可见。
  /// 右侧两个键：有字才出现发送圆钮，最右边的「+」常驻，点了进附件区
  Widget _sendButton(bool hasText) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasText)
          GestureDetector(
            key: const Key('send-button'),
            onTap: _send,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(
                color: C.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  size: 20, color: Colors.white),
            ),
          ),
        const SizedBox(width: 2),
        GestureDetector(
          key: const Key('attach-button'),
          onTap: () => setState(() {
            // 常驻加号：直达附件区
            _panelTab = 3;
            _panelOpen = true;
          }),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              Icons.add_rounded,
              size: 24,
              color: _panelOpen && _panelTab == 3
                  ? C.accent
                  : C.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(ChatMessage(
        role: ChatRole.user,
        text: text,
        time: DateTime.now(),
      ));
      _active.retitleIfNeeded();
      _input.clear();
      _panelOpen = false;
    });
    _persist();
    await _requestReply();
  }

  Future<void> _loadAiStickers() async {
    final list = await _aiStickerStore.load();
    if (!mounted) return;
    setState(() => _aiStickers = list);
  }

  /// 给她加一张表情：选图 + 填标签（标签要和模型输出的一致才用得上）
  Future<void> _addAiSticker() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    final tagCtrl = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('给这张图配个标签', style: AppText.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '她靠标签挑表情：回复里出现 [s:标签] 才会发对应那张。'
              '标签对不上就用不了，建议用：开心 生气 难过 谢谢 晚安 早安 加油',
              style: AppText.meta.copyWith(color: C.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tagCtrl,
              autofocus: true,
              style: AppText.bodySmall,
              cursorColor: C.accent,
              decoration: InputDecoration(
                hintText: '例如：开心',
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
            onPressed: () {
              final v = tagCtrl.text.trim();
              if (v.isNotEmpty) Navigator.of(ctx).pop(v);
            },
            child: Text('添加',
                style: AppText.bodySmall.copyWith(color: C.accent)),
          ),
        ],
      ),
    );
    if (tag == null || !mounted) return;

    final ok = await _aiStickerStore.add(bytes, tag);
    await _loadAiStickers();
    if (!mounted) return;
    _toast(ok ? '已添加：$tag' : '添加失败');
  }

  Future<void> _removeAiSticker(AiSticker s) async {
    await _aiStickerStore.remove(s);
    await _loadAiStickers();
    if (mounted) _toast('已删除');
  }

  void _addAttachmentMessage({
    required String path,
    required AttachmentKind kind,
    required String name,
    required int size,
  }) {
    setState(() {
      _messages.add(ChatMessage(
        role: ChatRole.user,
        time: DateTime.now(),
        attachment: path,
        attachmentKind: kind,
        attachmentName: name,
        attachmentSize: size,
      ));
      _active.updatedAt = DateTime.now();
      _panelOpen = false;
    });
    _persist();
  }

  Future<void> _pickImagesAttach() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;
    for (final x in picked) {
      final bytes = await x.readAsBytes();
      final saved = await _attachments.save(bytes, x.name);
      _addAttachmentMessage(
        path: saved.path,
        kind: AttachmentKind.image,
        name: x.name,
        size: bytes.length,
      );
    }
  }

  Future<void> _pickVideoAttach() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final saved = await _attachments.saveFromPath(picked.path, picked.name);
    final size = await saved.length();
    _addAttachmentMessage(
      path: saved.path,
      kind: AttachmentKind.video,
      name: picked.name,
      size: size,
    );
  }

  Future<void> _pickFileAttach() async {
    // file_picker 13 起改成静态方法，直接返回 PlatformFile 列表
    final picked = await FilePicker.pickFiles();
    final f = picked.isEmpty ? null : picked.first;
    if (f == null || f.path == null) return;
    final saved = await _attachments.saveFromPath(f.path!, f.name);
    // v13 的 PlatformFile 没有 size 字段，落盘后直接问文件系统
    final size = await saved.length();
    _addAttachmentMessage(
      path: saved.path,
      kind: AttachmentKind.file,
      name: f.name,
      size: size,
    );
  }

  /// 发内置表情（asset 路径）
  void _sendAssetSticker(String assetPath) {
    setState(() {
      _messages.add(ChatMessage(
        role: ChatRole.user,
        sticker: assetPath,
        time: DateTime.now(),
      ));
      _active.updatedAt = DateTime.now();
      _panelOpen = false;
    });
    _persist();
  }

  Future<void> _loadUserStickers() async {
    final files = await _userStickerStore.load();
    if (!mounted) return;
    setState(() => _userStickerFiles = files);
  }

  /// 从相册批量导入表情，存到应用目录
  Future<void> _addSticker() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;
    for (final x in picked) {
      await _userStickerStore.add(await x.readAsBytes());
    }
    await _loadUserStickers();
  }

  /// 发一张自己导入的表情
  void _sendFileSticker(File file) {
    setState(() {
      _messages.add(ChatMessage(
        role: ChatRole.user,
        sticker: file.path,
        time: DateTime.now(),
      ));
      _active.updatedAt = DateTime.now();
      _panelOpen = false;
    });
    _persist();
  }

  /// 长按删除自己导入的表情（先确认，避免误删）
  Future<void> _removeSticker(File file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('删除这个表情？', style: AppText.title),
        content: Text(
          '删除后聊天里已发出的这张不受影响。',
          style: AppText.bodySmall.copyWith(color: C.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消',
                style: AppText.bodySmall.copyWith(color: C.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('删除',
                style: AppText.bodySmall.copyWith(color: C.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _userStickerStore.remove(file);
    await _loadUserStickers();
  }


  Future<void> _retry(int failedIndex) async {
    if (_sending) return;
    setState(() => _messages.removeAt(failedIndex));
    await _requestReply();
  }

  Future<void> _requestReply() async {
    final placeholderIndex = _messages.length;
    setState(() {
      _sending = true;
      _messages.add(ChatMessage(
        role: ChatRole.bot,
        text: '',
        time: DateTime.now(),
        status: ChatStatus.streaming,
      ));
    });

    // 只把最近 N 条发给模型，避免上下文和内存无限增长。
    final all = _messages.sublist(0, placeholderIndex);
    final history = all.length > _maxHistoryForModel
        ? all.sublist(all.length - _maxHistoryForModel)
        : all;

    // 附件对模型来说要变成文字，否则它只看到一条空消息
    final prepared = history.map((m) {
      if (!m.hasAttachment) return m;
      final tag = switch (m.attachmentKind) {
        AttachmentKind.image => '[图片]',
        AttachmentKind.video => '[视频]',
        _ => '[文件]',
      };
      final name = m.attachmentName ?? '';
      return m.copyWith(
        text: '${m.text ?? ''}$tag${name.isEmpty ? '' : ' $name'}'.trim(),
      );
    }).toList();

    final stream = widget.streamOverride != null
        ? widget.streamOverride!(prepared)
        : _client.streamChat(
            provider: _provider,
            systemPrompt: _effectiveSystemPrompt,
            messages: prepared,
          );

    var buffer = '';
    var reasoning = '';
    try {
      await for (final delta in stream) {
        if (delta.content.isNotEmpty) buffer += delta.content;
        if (delta.reasoning.isNotEmpty) reasoning += delta.reasoning;
        if (!mounted) return;
        if (delta.content.isEmpty) continue; // 思考过程不显示，等正文
        setState(() {
          _messages[placeholderIndex] = _messages[placeholderIndex]
              .copyWith(text: buffer, status: ChatStatus.streaming);
        });
      }
      if (!mounted) return;
      // 正文一直没来（模型把预算全花在思考上），退化成显示思考内容，
      // 总比让用户对着空气好。
      final rawText = buffer.isNotEmpty ? buffer : reasoning.trim();
      final tags = StickerTag.extract(rawText);
      final cleaned = StickerTag.strip(rawText);
      // 模型发了标记也要过概率闸门；标签对不上就当作没发。
      // 先查内置表情库，再查用户给她加的表情（按标签匹配）。
      Sticker? sticker;
      String? customPath;
      if (tags.isNotEmpty && _gate.shouldSend(_stickerProbability)) {
        final builtin = _catalog?.findForAi(tags.first);
        if (builtin != null) {
          sticker = builtin;
        } else {
          for (final s in _aiStickers) {
            if (s.tag == tags.first) {
              customPath = s.file.path;
              break;
            }
          }
        }
      }

      setState(() {
        if (cleaned.isEmpty && (sticker != null || customPath != null)) {
          // 整条回复就是一个表情，别留一个空气泡
          _messages.removeAt(placeholderIndex);
        } else {
          final shown = cleaned.isEmpty ? '（模型没有返回内容）' : cleaned;
          _messages[placeholderIndex] = _messages[placeholderIndex].copyWith(
            text: shown,
            status: cleaned.isEmpty ? ChatStatus.failed : ChatStatus.done,
          );
        }
        if (sticker != null || customPath != null) {
          _messages.add(ChatMessage(
            role: ChatRole.bot,
            sticker: customPath ?? _catalog!.aiPack.assetPathOf(sticker!),
            time: DateTime.now(),
          ));
        }
        _active.updatedAt = DateTime.now();
        _sending = false;
      });
      _persist();
      await _maybeNotify(cleaned.isEmpty ? (sticker?.label ?? '') : cleaned);
      await _speakIfEnabled(cleaned.isEmpty ? '' : cleaned);
      await _autoSummarizeIfDue();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages[placeholderIndex] = _messages[placeholderIndex].copyWith(
          text: e.toString(),
          status: ChatStatus.failed,
        );
        _sending = false;
      });
      _persist();
    }
  }
}

/// 长按菜单里的一项
class _MenuAction {
  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  const _MenuAction(this.icon, this.label, this.value, {this.danger = false});
}
