import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
  }

  Future<void> showSeasonChangeAlert(String message) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'season_change',
        '계절 전환 알림',
        channelDescription: '계절이 바뀔 때 옷 보관/꺼내기 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(1, '옷장지도', message, details);
  }
}
