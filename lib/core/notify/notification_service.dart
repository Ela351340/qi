import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 系统通知。所有调用都吞异常 —— 通知失败不该影响聊天本身。
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _inited = false;

  static Future<void> _ensureInit() async {
    if (_inited) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings: settings);
      _inited = true;
    } catch (_) {
      // 平台不支持（比如桌面/测试环境）
    }
  }

  /// 安卓 13+ 需要运行时权限。返回是否拿到。
  static Future<bool> requestPermission() async {
    await _ensureInit();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return true;
      return await android.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    await _ensureInit();
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          '聊天消息',
          channelDescription: '对方发来新消息时提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      // 固定 id：新通知覆盖旧的，不在通知栏堆一长串
      await _plugin.show(
        id: 1,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    await _ensureInit();
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
