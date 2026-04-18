import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz; // Import để nạp dữ liệu múi giờ

// Import services và models
import 'services/notification_service.dart';
import 'models/habit_item.dart';
import 'models/daily_record.dart';
import 'screens/main_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Màu chủ đạo của ứng dụng
const mainAppColor = Color(0xFF279EC8);

void main() async {
  // Đảm bảo Flutter đã sẵn sàng trước khi gọi các plugin (Firebase, Hive)
  WidgetsFlutterBinding.ensureInitialized();

  // 🟢 THÊM: Khởi tạo dữ liệu múi giờ (Phải có cái này thì thông báo mới chạy được sếp nhé)
  tz.initializeTimeZones();

  // 1. Khởi tạo Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Khởi tạo Database Hive (Nên khởi tạo Database trước khi init Notification để tránh xung đột)
  await Hive.initFlutter();

  // 3. Đăng ký các Adapter
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(HabitItemAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(DailyRecordAdapter());

  // 4. Mở các Box dữ liệu cần dùng
  await Hive.openBox<HabitItem>('habitsBoxV2');
  await Hive.openBox<DailyRecord>('historyBox');
  await Hive.openBox('settingsBox');

  // 5. Khởi tạo dịch vụ thông báo (Đã bao gồm xin quyền trong file service sếp đã sửa)
  await NotificationService.init();

  runApp(const HabitTrackerApp());
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe settingsBox để thay đổi giao diện Sáng/Tối ngay lập tức
    return ValueListenableBuilder(
      valueListenable: Hive.box('settingsBox').listenable(keys: ['isDarkMode']),
      builder: (context, box, child) {
        bool isDarkMode = box.get('isDarkMode', defaultValue: false);

        return MaterialApp(
          title: 'Habit Tracker',
          debugShowCheckedModeBanner: false,

          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: mainAppColor,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFF),
          ),

          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: mainAppColor,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
          ),

          home: const MainScreen(),
        );
      },
    );
  }
}