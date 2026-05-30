import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'log_service.dart';

/// 本地通知服务
class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _notificationId = 0;

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _plugin.initialize(initSettings);
      _initialized = true;
    } catch (e) {
      LogService.error('通知服务初始化失败', e);
    }
  }

  Future<void> showDownloadComplete(String videoName, String episodeName) async {
    if (!_initialized) return;
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
