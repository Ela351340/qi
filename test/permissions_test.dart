import 'package:chat_app/core/notify/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 权限与通知的降级行为。
///
/// 这些用例跑在 Dart VM 上，没有安卓通道；插件调用会失败。
/// 要求是：**失败也不能抛出去**，否则聊天会被通知搞挂。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('申请通知权限失败时返回 false，不抛异常', () async {
    final granted = await NotificationService.requestPermission();
    expect(granted, isFalse);
  });

  test('发通知在没有平台支持时不抛异常', () async {
    await expectLater(
      NotificationService.show(title: '测试', body: '内容'),
      completes,
    );
  });

  test('清空通知不抛异常', () async {
    await expectLater(NotificationService.cancelAll(), completes);
  });
}
