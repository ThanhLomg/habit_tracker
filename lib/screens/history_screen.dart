import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_item.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử hoàn thành'),
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<HabitItem>('habitsBoxV2').listenable(),
        builder: (context, Box<HabitItem> box, _) {
          // Lọc ra các thói quen đã hoàn thành
          final completedHabits = box.values.where((habit) => habit.isCompleted).toList();

          if (completedHabits.isEmpty) {
            return const Center(
              child: Text('Chưa có thói quen nào được hoàn thành.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completedHabits.length,
            itemBuilder: (context, index) {
              final habit = completedHabits[index];
              return Card(
                color: Colors.green[50],
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(
                    habit.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Tạo ngày: ${habit.createdAt.day}/${habit.createdAt.month}/${habit.createdAt.year}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}