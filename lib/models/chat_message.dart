enum ChatRole { user, bot, system }

enum ChatStatus { done, streaming, failed }

/// 附件类型：图片内联显示，视频/文件显示卡片
enum AttachmentKind { image, video, file }

/// 一条消息。表情包用 [sticker] 承载，[text] 为空时表示这一条只有表情。
class ChatMessage {
  final ChatRole role;
  final String? text;
  final String? sticker;
  final DateTime time;
  final ChatStatus status;

  /// 附件本地路径（图片/视频/文件），用户消息才可能有
  final String? attachment;

  /// 附件类型；路径为空时忽略
  final AttachmentKind? attachmentKind;

  /// 原始文件名，用来显示、也方便以后做"另存为"
  final String? attachmentName;

  /// 字节大小
  final int? attachmentSize;

  const ChatMessage({
    required this.role,
    this.text,
    this.sticker,
    required this.time,
    this.status = ChatStatus.done,
    this.attachment,
    this.attachmentKind,
    this.attachmentName,
    this.attachmentSize,
  });

  bool get isSticker => sticker != null;

  bool get hasAttachment => attachment != null;

  ChatMessage copyWith({
    String? text,
    String? sticker,
    DateTime? time,
    ChatStatus? status,
    String? attachment,
    AttachmentKind? attachmentKind,
    String? attachmentName,
    int? attachmentSize,
  }) {
    return ChatMessage(
      role: role,
      text: text ?? this.text,
      sticker: sticker ?? this.sticker,
      time: time ?? this.time,
      status: status ?? this.status,
      attachment: attachment ?? this.attachment,
      attachmentKind: attachmentKind ?? this.attachmentKind,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentSize: attachmentSize ?? this.attachmentSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role.name,
        if (text != null) 'text': text,
        if (sticker != null) 'sticker': sticker,
        'time': time.toIso8601String(),
        if (attachment != null) 'attachment': attachment,
        if (attachmentKind != null) 'kind': attachmentKind!.name,
        if (attachmentName != null) 'name': attachmentName,
        if (attachmentSize != null) 'size': attachmentSize,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: ChatRole.values.firstWhere(
          (r) => r.name == j['role'],
          orElse: () => ChatRole.bot,
        ),
        text: j['text'] as String?,
        sticker: j['sticker'] as String?,
        time: DateTime.tryParse((j['time'] ?? '').toString()) ?? DateTime.now(),
        attachment: j['attachment'] as String?,
        attachmentKind: AttachmentKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => AttachmentKind.file,
        ),
        attachmentName: j['name'] as String?,
        attachmentSize: (j['size'] as num?)?.toInt(),
      );
}

/// 演示数据，真实数据来自本地存储。
List<ChatMessage> demoMessages() {
  final base = DateTime(2026, 10, 30, 22, 40);
  return [
    ChatMessage(
      role: ChatRole.bot,
      text: '你回来了。今天怎么这么晚？',
      time: base,
    ),
    ChatMessage(
      role: ChatRole.user,
      text: '加班，刚到家',
      time: base.add(const Duration(minutes: 1)),
    ),
    ChatMessage(
      role: ChatRole.bot,
      text: '吃饭了吗？别又拿泡面糊弄。',
      time: base.add(const Duration(minutes: 2)),
    ),
    ChatMessage(
      role: ChatRole.user,
      text: '还没',
      time: base.add(const Duration(minutes: 3)),
    ),
    ChatMessage(
      role: ChatRole.bot,
      sticker: '🙄',
      time: base.add(const Duration(minutes: 4)),
    ),
    ChatMessage(
      role: ChatRole.bot,
      text: '我就知道。厨房还有昨天剩的汤，热一下。',
      time: base.add(const Duration(minutes: 4, seconds: 20)),
    ),
    ChatMessage(
      role: ChatRole.user,
      text: '好，等下弄',
      time: base.add(const Duration(minutes: 6)),
    ),
    ChatMessage(
      role: ChatRole.system,
      text: '对方撤回了一条消息',
      time: base.add(const Duration(minutes: 8)),
    ),
    ChatMessage(
      role: ChatRole.bot,
      text: '那你快去吧，冷了就不好喝了。',
      time: base.add(const Duration(minutes: 9)),
    ),
  ];
}
