import 'package:firebase_database/firebase_database.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_item.dart';
import '../models/daily_record.dart';
import 'dart:math';

class SyncService {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  String generateSyncId() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  int calculateCurrentStreak() {
    final historyBox = Hive.box<DailyRecord>('historyBox');
    if (historyBox.isEmpty) return 0;

    // Lấy danh sách các ngày đã hoàn thành, loại bỏ giờ phút giây để so sánh chuẩn
    List<DateTime> dates = historyBox.values
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toList();

    // Sắp xếp từ gần đây nhất về xa nhất
    dates.sort((a, b) => b.compareTo(a));
    dates = dates.toSet().toList(); // Loại bỏ các ngày trùng lặp nếu có

    int streak = 0;
    DateTime now = DateTime.now();
    DateTime checkDate = DateTime(now.year, now.month, now.day);

    // Kiểm tra nếu hôm nay chưa làm, thì bắt đầu tính từ hôm qua
    if (!dates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    for (var date in dates) {
      if (date.isAtSameMomentAs(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (date.isBefore(checkDate)) {
        break; // Bị đứt chuỗi
      }
    }
    return streak;
  }

  // //CẬP NHẬT: Thêm thông tin User vào hàm Backup
  Future<void> backupData(String userID, int streak) async {
    final habitBox = Hive.box<HabitItem>('habitsBoxV2');
    final historyBox = Hive.box<DailyRecord>('historyBox');
    final settingsBox = Hive.box('settingsBox');

    final Map<String, dynamic> habitsMap = {};
    for (var key in habitBox.keys) {
      final habit = habitBox.get(key);
      if (habit != null) {
        habitsMap[key.toString()] = {
          'name': habit.name,
          'reminderHour': habit.reminderHour,
          'reminderMinute': habit.reminderMinute,
          'isCompleted': habit.isCompleted,
          'createdAt': habit.createdAt.toIso8601String(),
          'note': habit.note,
          'iconCodePoint': habit.iconCodePoint, // 🔥 CẬP NHẬT: Đẩy mã Icon lên mây
        };
      }
    }

    final Map<String, dynamic> historyMap = {};
    for (var key in historyBox.keys) {
      final record = historyBox.get(key);
      if (record != null) {
        historyMap[key.toString()] = {
          'date': record.date.toIso8601String(),
          'completedHabitsCount': record.completedHabitsCount,
          'completedHabitNames': record.completedHabitNames,
          'completedTasks': record.completedTasks,
          'totalTasks': record.totalTasks,
        };
      }
    }

    // //CẬP NHẬT: Lưu thêm Profile (Tên, Avatar, Màu viền)
    await _db.ref('users/$userID').set({
      'profile': {
        'userName': settingsBox.get('userName', defaultValue: 'Người dùng mới'),
        'avatarPath': settingsBox.get('avatarPath'),
        'isAvatarFile': settingsBox.get('isAvatarFile', defaultValue: false),
        'frameColorValue': settingsBox.get('frameColorValue'),
      },
      'streak': streak,
      'lastSync': ServerValue.timestamp,
      'habits': habitsMap,
      'history': historyMap,
    });
  }

  // //CẬP NHẬT: Tải thêm Profile về khi Restore
  Future<void> restoreData(String targetID) async {
    final snapshot = await _db.ref('users/$targetID').get();
    if (!snapshot.exists) throw "ID này không tồn tại sếp ơi!";

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final habitBox = Hive.box<HabitItem>('habitsBoxV2');
    final historyBox = Hive.box<DailyRecord>('historyBox');
    final settingsBox = Hive.box('settingsBox');

    // //CẬP NHẬT: Restore Profile
    if (data['profile'] != null) {
      var p = data['profile'];
      await settingsBox.put('userName', p['userName']);
      // Lưu ý: Chỉ đồng bộ link ảnh, nếu là file cục bộ từ máy cũ thì máy mới sẽ không thấy
      if (p['isAvatarFile'] == false) {
        await settingsBox.put('avatarPath', p['avatarPath']);
        await settingsBox.put('isAvatarFile', false);
      }
      await settingsBox.put('frameColorValue', p['frameColorValue']);
    }

    // Restore Habits & History
    if (data['habits'] != null) {
      Map habits = data['habits'];
      habits.forEach((key, val) {
        habitBox.put(int.parse(key), HabitItem(
          name: val['name'],
          reminderHour: val['reminderHour'],
          reminderMinute: val['reminderMinute'],
          isCompleted: val['isCompleted'] ?? false,
          createdAt: DateTime.parse(val['createdAt']),
          note: val['note'],
          iconCodePoint: val['iconCodePoint'], // 🔥 CẬP NHẬT: Lấy mã Icon từ mây về
        ));
      });
    }

    if (data['history'] != null) {
      Map history = data['history'];
      history.forEach((key, val) {
        historyBox.put(key, DailyRecord(
          date: DateTime.parse(val['date']),
          completedHabitsCount: val['completedHabitsCount'] ?? 0,
          completedHabitNames: List<String>.from(val['completedHabitNames'] ?? []),
          completedTasks: val['completedTasks'] ?? 0,
          totalTasks: val['totalTasks'] ?? 0,
        ));
      });
    }
  }
}