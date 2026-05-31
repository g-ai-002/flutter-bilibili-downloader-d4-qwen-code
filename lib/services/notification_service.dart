import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'log_service.dart';

/// 本地通知服务
///
/// `flutter_local_notifications` 仅支持 Android / iOS / macOS / Linux。
/// 在 Windows 等不支持的平台上调用插件内部会出现 `LateInitializationError`
/// (Issue #6 评论日志已观察到)。这里通过 `_supported` 平台守卫 +
/// 全量 try/catch 双重防御，确保通知不可用时只是静默降级而不影响其它功能。
class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _available = false;
  int _notificationId = 0;

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  bool get isAvailable => _available;

  bool get _supported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true; // 即便失败也只 init 一次，避免反复抛错刷日志
    if (!_supported) {
      LogService.info('当前平台不支持本地通知，已跳过通知服务初始化');
      return;
    }
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
        linux: linuxSettings,
      );
      await _plugin.initialize(initSettings);
      _available = true;
    } catch (e, st) {
      LogService.error('通知服务初始化失败', e, st);
      _available = false;
    }
  }

  Future<void> showDownloadComplete(String videoName, String episodeName) async {
    if (!_initialized || !_available || !_supported) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'download_channel',
        '下载通知',
        channelDescription: '视频下载完成通知',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        linux: LinuxNotificationDetails(),
      );
      await _plugin.show(
        _notificationId++,
        '下载完成',
        '$episodeName 已下载完成',
        details,
      );
    } catch (e) {
      LogService.error('发送通知失败', e);
    }
  }
}
