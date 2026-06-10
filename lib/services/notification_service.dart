import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    // Android 13(API 33)+ 는 런타임 권한 없이는 알림이 표시되지 않음
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
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

  Future<void> showNeglectedAlert(int count) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'neglected_clothes',
        '방치 옷 알림',
        channelDescription: '오래 입지 않은 옷 정리 알림',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      2,
      '옷장지도',
      '오래 입지 않은 옷이 $count벌 있어요. 정리할 때가 됐을지도 몰라요!',
      details,
    );
  }

  Future<void> showLaundryAlert(int count) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'laundry_needed',
        '세탁 알림',
        channelDescription: '세탁이 필요한 옷 알림',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      3,
      '옷장지도',
      '세탁이 필요한 옷이 $count벌 있어요. 세탁 후 상쾌하게 입어보세요!',
      details,
    );
  }
}
