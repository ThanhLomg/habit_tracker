import 'dart:ui' show Color;
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'email_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // ID Kênh thông báo - Sếp phải giữ ID này đồng nhất ở mọi nơi
  static const String _channelId = 'habit_channel_id';
  static const String _channelName = 'Habit Reminders';

  static Future<void> init() async {
    // 1. Khởi tạo múi giờ
    tz.initializeTimeZones();
    try {
      var vnLocation = tz.getLocation('Asia/Ho_Chi_Minh');
      tz.setLocalLocation(vnLocation);
    } catch (e) {
      print("Lỗi thiết lập múi giờ: $e");
    }

    // 2. Cấu hình icon và cài đặt ban đầu
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

    // 3. Xử lý riêng cho Android (Tạo Kênh và Xin quyền)
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // 🔥 BẮT BUỘC: Tạo Notification Channel cho bản Release APK
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Nhắc nhở thực hiện thói quen hàng ngày',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidImplementation?.createNotificationChannel(channel);

      // Xin quyền gửi thông báo (Android 13+)
      await androidImplementation?.requestNotificationsPermission();

      // Xin quyền Báo thức chính xác (Exact Alarm)
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  // Cấu hình chi tiết thông báo hiển thị
  static NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Nhắc nhở thực hiện thói quen hàng ngày',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        // Đảm bảo icon @mipmap/ic_launcher tồn tại trong res/mipmap
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF4A90E2),
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  // Đặt lịch thông báo theo thời gian thói quen
  static Future<void> scheduleHabitNotifications({
    required int id,
    required String title,
    required DateTime scheduledTime,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    // Nếu thời gian đã trôi qua thì đặt cho ngày mai
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    try {
      // Thông báo chính đúng giờ
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
      await EmailService.sendEmailReminder(title);

      print("✅ Đã đặt lịch thông báo và gửi email nhắc nhở cho: $title");

      // Thông báo nhắc nhở muộn (sau 6 tiếng)
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
      print("❌ Lỗi đặt lịch: $e");
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