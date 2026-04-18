import 'package:hive/hive.dart';

part 'daily_record.g.dart';

@HiveType(typeId: 2)
class DailyRecord extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final int completedHabitsCount;

  @HiveField(2)
  final List<String> completedHabitNames;

  @HiveField(3)
  final int completedTasks;

  @HiveField(4)
  final int totalTasks;

  DailyRecord({
    required this.date,
    required this.completedHabitsCount,
    this.completedHabitNames = const [], // Mặc định là mảng rỗng
    this.completedTasks = 0,
    this.totalTasks = 0,
  });
}