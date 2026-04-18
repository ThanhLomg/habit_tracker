import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/daily_record.dart';
import '../models/habit_item.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  // --- LOGIC 1: HÀM TÍNH CHUỖI NGÀY TỔNG THỂ (CHO CÁI CÂY) ---
  int _calculateOverallStreak(Box<DailyRecord> historyBox) {
    int streak = 0;
    DateTime checkDate = DateTime.now();

    while (true) {
      String dateStr = checkDate.toIso8601String().split('T')[0];
      DailyRecord? record = historyBox.get(dateStr);

      // Nếu ngày đó có hoàn thành ít nhất 1 thói quen
      if (record != null && record.completedTasks > 0) {
        streak++;
        // Lùi về 1 ngày trước đó để kiểm tra tiếp
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        // Nếu hôm nay chưa check gì, nhưng hôm qua có check thì chuỗi vẫn chưa đứt (chỉ là chưa check hôm nay thôi)
        if (streak == 0 && checkDate.day == DateTime.now().day) {
          checkDate = checkDate.subtract(const Duration(days: 1));
          continue;
        }
        break; // Đứt chuỗi, dừng vòng lặp
      }
    }
    return streak;
  }

  // --- LOGIC 2: HÀM TÍNH TOP 3 THÓI QUEN BỀN BỈ NHẤT ---
  List<Map<String, dynamic>> _calculateTopHabits(Box<DailyRecord> historyBox) {
    final habitsBox = Hive.box<HabitItem>('habitsBoxV2');
    List<Map<String, dynamic>> habitStreaks = [];

    // Lấy tên tất cả thói quen đang có
    List<String> activeHabits = habitsBox.values.map((e) => e.name).toList();

    for (String habitName in activeHabits) {
      int streak = 0;
      DateTime checkDate = DateTime.now();

      while (true) {
        String dateStr = checkDate.toIso8601String().split('T')[0];
        DailyRecord? record = historyBox.get(dateStr);

        if (record != null && record.completedHabitNames.contains(habitName)) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          if (streak == 0 && checkDate.day == DateTime.now().day) {
            checkDate = checkDate.subtract(const Duration(days: 1));
            continue;
          }
          break;
        }
      }

      // Chỉ thêm vào danh sách nếu có streak > 0
      if (streak > 0) {
        habitStreaks.add({
          'name': habitName,
          'streak': streak,
          'icon': _getHabitIcon(habitName),
        });
      }
    }

    // Sắp xếp giảm dần theo số ngày và lấy Top 3
    habitStreaks.sort((a, b) => b['streak'].compareTo(a['streak']));
    return habitStreaks.take(3).toList();
  }

  // Hàm phụ: Lấy icon tự động theo tên (giống hệt bên AddHabitScreen)
  String _getHabitIcon(String name) {
    final text = name.toLowerCase();
    String url = 'https://cdn-icons-png.flaticon.com/512/11629/11629399.png';
    if (text.contains('nước') || text.contains('uống')) url = 'https://cdn-icons-png.flaticon.com/512/3105/3105807.png';
    else if (text.contains('chạy') || text.contains('tập') || text.contains('gym')) url = 'https://cdn-icons-png.flaticon.com/512/195/195496.png';
    else if (text.contains('sách') || text.contains('đọc') || text.contains('học')) url = 'https://cdn-icons-png.flaticon.com/512/3145/3145765.png';
    else if (text.contains('ngủ') || text.contains('giấc')) url = 'https://cdn-icons-png.flaticon.com/512/3094/3094837.png';
    return url;
  }

  // Hàm phụ: Lấy màu ngẫu nhiên cho đẹp
  Color _getHabitColor(int index) {
    List<Color> colors = [const Color(0xFF42A5F5), const Color(0xFFFFB74D), const Color(0xFF66BB6A)];
    return colors[index % colors.length];
  }

  String _getTreeAssetPath(int streak) {
    if (streak < 4) return 'assets/images/tree_stage_1.png';
    if (streak < 14) return 'assets/images/tree_stage_2.png';
    if (streak < 30) return 'assets/images/tree_stage_3.png';
    return 'assets/images/tree_stage_4.png';
  }

  String _getTreeMessage(int streak) {
    if (streak == 0) return 'Hãy hoàn thành thói quen để gieo hạt nhé!';
    if (streak < 4) return 'Mầm non hy vọng đã gieo xuống!';
    if (streak < 14) return 'Cây non đang vươn mình mạnh mẽ!';
    if (streak < 30) return 'Sự kiên trì của bạn đang đơm hoa!';
    return 'Tuyệt vời! Một cái cây vững chãi!';
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 LẮNG NGHE CHẾ ĐỘ DARK MODE TẠI ĐÂY
    return ValueListenableBuilder(
        valueListenable: Hive.box('settingsBox').listenable(),
        builder: (context, settingsBox, _) {
          final isDarkMode = settingsBox.get('isDarkMode', defaultValue: false);

          // KHAI BÁO BẢNG MÀU ĐỘNG
          final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFC);
          final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
          final textColor = isDarkMode ? Colors.white : Colors.black87;
          final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

          // Lắng nghe sự thay đổi của HistoryBox
          return ValueListenableBuilder(
              valueListenable: Hive.box<DailyRecord>('historyBox').listenable(),
              builder: (context, Box<DailyRecord> historyBox, _) {

                // TÍNH TOÁN DỮ LIỆU THỰC TẾ NGAY TẠI ĐÂY
                int totalStreakDays = _calculateOverallStreak(historyBox);
                List<Map<String, dynamic>> topHabits = _calculateTopHabits(historyBox);

                return Scaffold(
                  backgroundColor: bgColor, // 🟢 ĐỔI MÀU NỀN
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    centerTitle: true,
                    automaticallyImplyLeading: false,
                    title: Text(
                      'Thành tựu',
                      style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold), // 🟢 ĐỔI MÀU CHỮ APPBAR
                    ),
                  ),
                  body: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          'Quyết tâm của bạn',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4A90E2)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getTreeMessage(totalStreakDays),
                          style: TextStyle(fontSize: 15, color: subTextColor, fontWeight: FontWeight.w500), // 🟢 ĐỔI MÀU CHỮ PHỤ
                        ),
                        const SizedBox(height: 40),

                        // WIDGET CÁI CÂY
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 240, height: 240,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [const Color(0xFF81C784).withValues(alpha: 0.3), Colors.transparent],
                                  stops: const [0.2, 1.0],
                                ),
                              ),
                            ),
                            ScaleTransition(
                              scale: _breathingAnimation,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    _getTreeAssetPath(totalStreakDays),
                                    height: 180, fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: cardColor, // 🟢 ĐỔI MÀU NỀN THẺ
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: isDarkMode ? [] : [BoxShadow(color: Colors.green.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))], // 🟢 ẨN BÓNG KHI TỐI
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 20),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$totalStreakDays Ngày',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor), // 🟢 ĐỔI MÀU CHỮ
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 50),

                        // WIDGET TOP 3
                        if (topHabits.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Tiên phong 3 bền 🔥', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)), // 🟢 ĐỔI MÀU CHỮ
                          ),
                          const SizedBox(height: 20),
                          Column(
                            children: topHabits.asMap().entries.map((entry) {
                              int index = entry.key;
                              var habit = entry.value;
                              Color itemColor = _getHabitColor(index);

                              Widget rankIcon = Text(index == 0 ? '🥇' : index == 1 ? '🥈' : '🥉', style: const TextStyle(fontSize: 24));

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardColor, // 🟢 ĐỔI MÀU NỀN THẺ
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: isDarkMode ? [] : [BoxShadow(color: Colors.blue.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))], // 🟢 ẨN BÓNG KHI TỐI
                                ),
                                child: Row(
                                  children: [
                                    rankIcon,
                                    const SizedBox(width: 16),
                                    Container(
                                      width: 50, height: 50, padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: itemColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                                      child: Image.network(habit['icon']),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(habit['name'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)), // 🟢 ĐỔI MÀU CHỮ
                                          const SizedBox(height: 4),
                                          Text('Giữ vững phong độ', style: TextStyle(fontSize: 13, color: subTextColor)), // 🟢 ĐỔI MÀU CHỮ PHỤ
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('${habit['streak']}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: itemColor)),
                                        Text('ngày', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subTextColor)), // 🟢 ĐỔI MÀU CHỮ PHỤ
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ] else ...[
                          // Nếu chưa có thói quen nào đạt streak
                          Center(
                            child: Text('Bạn chưa có chuỗi thói quen nào.\nHãy đánh dấu hoàn thành ngay nhé!',
                                textAlign: TextAlign.center, style: TextStyle(color: subTextColor)), // 🟢 ĐỔI MÀU CHỮ PHỤ
                          )
                        ],
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                );
              }
          );
        }
    );
  }
}