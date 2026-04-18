import 'dart:ui' show Color;
import 'dart:io'; // //CẬP NHẬT: Để kiểm tra nền tảng Android/iOS
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // //CẬP NHẬT: Khởi tạo kèm theo xin quyền Báo thức chính xác (Exact Alarm)
  static Future<void> init() async {
    tz.initializeTimeZones();

    try {
      var vnLocation = tz.getLocation('Asia/Ho_Chi_Minh');
      tz.setLocalLocation(vnLocation);
    } catch (e) {
      print("Lỗi thiết lập múi giờ: $e");
    }

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings
    );

    await _notificationsPlugin.initialize(settings);

    // //CẬP NHẬT: Xin quyền thông báo (Android 13+) và quyền Báo thức chính xác
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // Xin quyền gửi thông báo
      await androidImplementation?.requestNotificationsPermission();

      // 🔥 //CẬP NHẬT: Quan trọng nhất để sửa lỗi exact_alarms_not_permitted
      // Hàm này sẽ kiểm tra và yêu cầu người dùng bật quyền "Báo thức & nhắc nhở" trong cài đặt máy
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  static NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'habit_channel_id',
        'Habit Reminders',
        channelDescription: 'Nhắc nhở thực hiện thói quen',
        importance: Importance.max,
        priority: Priority.high,
        color: Color(0xFF4A90E2),
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  static Future<void> showInstantNotification() async {
    await _notificationsPlugin.show(
      999,
      'Sếp ơi!',
      'Nút Test hoạt động! Quyền và âm thanh đã OK 🚀',
      _notificationDetails(),
    );
  }

  static Future<void> scheduleHabitNotifications({
    required int id,
    required String title,
    required DateTime scheduledTime,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // //CẬP NHẬT: Thêm try-catch riêng ở đây để tránh crash khi chưa có quyền
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        'Đến giờ rồi!',
        'Đã đến lúc thực hiện: $title',
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      tz.TZDateTime lateTime = scheduledDate.add(const Duration(hours: 6));
      tz.TZDateTime midnight = tz.TZDateTime(tz.local, scheduledDate.year, scheduledDate.month, scheduledDate.day, 23, 59);

      if (lateTime.isBefore(midnight)) {
        await _notificationsPlugin.zonedSchedule(
          id + 1000,
          'Habit Tracker',
          'Bạn vẫn còn thói quen chưa làm nè: $title',
          lateTime,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      print("✅ Đã đặt lịch: $title vào lúc $scheduledDate");
    } catch (e) {
      print("❌ Không thể đặt báo thức chính xác: $e");
    }
  }

  static Future<void> cancelLateNotification(int id) async {
    await _notificationsPlugin.cancel(id + 1000);
  }

  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    await _notificationsPlugin.cancel(id + 1000);
  }
}