import 'package:hive/hive.dart';

part 'habit_item.g.dart';

@HiveType(typeId: 0)
class HabitItem extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  bool isCompleted;

  @HiveField(2)
  DateTime createdAt;

  // Giờ nhắc nhở (0-23)
  @HiveField(3)
  int? reminderHour;

  // Phút nhắc nhở (0-59)
  @HiveField(4)
  int? reminderMinute;

  @HiveField(5)
  String? note;

  // 🔥 THÊM MỚI: Lưu mã (codePoint) của Icon sếp đã chọn
  @HiveField(6)
  int? iconCodePoint;

  HabitItem({
    required this.name,
    this.isCompleted = false,
    required this.createdAt,
    this.reminderHour,
    this.reminderMinute,
    this.note,
    this.iconCodePoint, // 🔥 Thêm vào hàm khởi tạo
  });
}