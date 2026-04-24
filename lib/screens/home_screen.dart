import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_item.dart';
import '../models/daily_record.dart';
import '../services/notification_service.dart';
import 'add_habit_screen.dart';
import 'settings_screen.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _showAllHabits = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNewDay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNewDay();
      // Không cần setState ở đây vì ValueListenableBuilder sẽ lo việc update UI khi data thay đổi
    }
  }

  void _checkNewDay() {
    final settingsBox = Hive.box('settingsBox');
    String todayStr = DateTime.now().toIso8601String().split('T')[0];
    String lastOpenedDate = settingsBox.get('lastOpenedDate', defaultValue: '');

    if (lastOpenedDate.isNotEmpty && lastOpenedDate != todayStr) {
      final habitsBox = Hive.box<HabitItem>('habitsBoxV2');
      for (var habit in habitsBox.values) {
        habit.isCompleted = false;
        habit.save();
      }
    }
    settingsBox.put('lastOpenedDate', todayStr);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 12) return 'Chào buổi sáng 🌤️';
    if (hour >= 12 && hour < 18) return 'Chào buổi chiều ☕';
    return 'Chào buổi tối 🌙';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final weekdays = ['CN', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];
    final weekday = weekdays[now.weekday == 7 ? 0 : now.weekday];
    return '$weekday, ngày ${now.day} tháng ${now.month} năm ${now.year}';
  }

  // Hàm xóa đã được tối ưu: Chỉ cần xóa trong DB, UI sẽ tự update nhờ ValueListenableBuilder
  void _deleteHabit(HabitItem habit) async {
    if (habit.key != null) {
      await NotificationService.cancelNotification(habit.key as int);
    }
    await habit.delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa thói quen'), duration: Duration(seconds: 1)),
      );
    }
  }

  Widget _getHabitIcon(HabitItem habit) {
    if (habit.iconCodePoint != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          IconData(habit.iconCodePoint!, fontFamily: 'MaterialIcons'),
          color: Colors.blue,
          size: 26,
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.star_rounded, color: Colors.amber, size: 26),
      );
    }
  }

  void _updateDailyHistory() async {
    final habitsBox = Hive.box<HabitItem>('habitsBoxV2');
    final historyBox = Hive.box<DailyRecord>('historyBox');
    final now = DateTime.now();
    String todayStr = now.toIso8601String().split('T')[0];

    List<HabitItem> allHabits = habitsBox.values.toList();
    List<HabitItem> completedHabits = allHabits.where((h) => h.isCompleted).toList();

    final record = DailyRecord(
      date: now,
      completedHabitsCount: completedHabits.length,
      totalTasks: allHabits.length,
      completedTasks: completedHabits.length,
      completedHabitNames: completedHabits.map((h) => h.name).toList(),
    );
    await historyBox.put(todayStr, record);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settingsBox').listenable(),
      builder: (context, Box settingsBox, _) {
        final isDarkMode = settingsBox.get('isDarkMode', defaultValue: false);
        final userName = settingsBox.get('userName', defaultValue: 'Bạn');
        final avatarPath = settingsBox.get('avatarPath', defaultValue: 'https://cdn3d.iconscout.com/3d/premium/thumb/boy-avatar-6299533-5187871.png');
        final isAvatarFile = settingsBox.get('isAvatarFile', defaultValue: false);

        final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFC);
        final textColor = isDarkMode ? Colors.white : Colors.black87;
        final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 70,
            titleSpacing: 20,
            automaticallyImplyLeading: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Xin chào, $userName 👋',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  _getGreeting(),
                  style: TextStyle(fontSize: 14, color: subTextColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
                child: Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: isDarkMode ? Colors.blue[900] : Colors.blue[100],
                    backgroundImage: isAvatarFile
                        ? FileImage(File(avatarPath)) as ImageProvider
                        : NetworkImage(avatarPath),
                  ),
                ),
              ),
            ],
          ),
          // CHỈ DÙNG 1 ValueListenableBuilder DUY NHẤT CHO DATA CHÍNH
          body: ValueListenableBuilder<Box<HabitItem>>(
            valueListenable: Hive.box<HabitItem>('habitsBoxV2').listenable(),
            builder: (context, box, _) {
              List<HabitItem> habits = box.values.toList();

              // Sắp xếp: Thói quen chưa xong lên đầu
              habits.sort((a, b) {
                if (a.isCompleted && !b.isCompleted) return 1;
                if (!a.isCompleted && b.isCompleted) return -1;
                return 0;
              });

              bool hasMoreThan5 = habits.length > 5;
              List<HabitItem> displayHabits = (_showAllHabits || !hasMoreThan5)
                  ? habits
                  : habits.take(5).toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: 100),
                physics: const BouncingScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Text(_getFormattedDate(), style: TextStyle(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500)),
                  ),
                  _buildWeeklyCalendar(isDarkMode),
                  _buildPromoBanner(context, isDarkMode),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Thói quen hàng ngày', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        if (hasMoreThan5)
                          TextButton(
                            onPressed: () => setState(() => _showAllHabits = !_showAllHabits),
                            child: Text(_showAllHabits ? 'Thu gọn' : 'Xem tất cả',
                                style: TextStyle(color: isDarkMode ? Colors.blue[300] : Colors.blue[600], fontSize: 13, fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                  ),

                  if (habits.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Text('Chưa có thói quen nào.\nHãy bắt đầu ngay!', textAlign: TextAlign.center, style: TextStyle(color: subTextColor, fontSize: 15)),
                      ),
                    )
                  else
                    AnimatedSize(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.fastOutSlowIn,
                      alignment: Alignment.topCenter,
                      child: Column(
                        children: displayHabits.map((habit) {
                          return HabitCard(
                            key: ValueKey(habit.key),
                            habit: habit,
                            thumbnailWidget: _getHabitIcon(habit),
                            onDelete: () => _deleteHabit(habit),
                            onComplete: _updateDailyHistory,
                            isDarkMode: isDarkMode,
                          );
                        }).toList(),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // --- WIDGET HELPER ---
  Widget _buildWeeklyCalendar(bool isDarkMode) {
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    List<String> dayNames = ['Hai', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          DateTime day = monday.add(Duration(days: index));
          bool isToday = day.day == now.day && day.month == now.month && day.year == now.year;
          return Column(
            children: [
              Text(dayNames[index], style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? const Color(0xFF4A90E2) : (isDarkMode ? const Color(0xFF1E1E1E) : Colors.white),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                alignment: Alignment.center,
                child: Text('${day.day}', style: TextStyle(color: isToday ? Colors.white : (isDarkMode ? Colors.white : Colors.black87), fontWeight: isToday ? FontWeight.bold : FontWeight.w500, fontSize: 15)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPromoBanner(BuildContext context, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF90CAF9)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        boxShadow: isDarkMode ? [] : [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Thêm 1 thói quen mới", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text("Đừng để thời gian trôi vô nghĩa, hãy tạo ngay cho mình những thói quen mới nào !!", style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddHabitScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), elevation: 0),
                  child: const Text("Đặt nhắc nhở ngay", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(top: 10, right: 10, child: Icon(Icons.star_rounded, color: Colors.yellow[300], size: 24)),
                  Positioned(bottom: 20, left: 0, child: Icon(Icons.circle, color: Colors.greenAccent[200], size: 10)),
                  Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue[800]?.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 36))),
                  Positioned(left: 5, top: 15, child: Transform.rotate(angle: -0.2, child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFFFB74D), size: 32))),
                  Container(width: 54, height: 54, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))]), child: Icon(Icons.schedule_rounded, color: Colors.blue[600], size: 34)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- HABIT CARD WIDGET ---
class HabitCard extends StatefulWidget {
  final HabitItem habit;
  final Widget thumbnailWidget;
  final VoidCallback onDelete;
  final VoidCallback onComplete;
  final bool isDarkMode;

  const HabitCard({
    super.key,
    required this.habit,
    required this.thumbnailWidget,
    required this.onDelete,
    required this.onComplete,
    required this.isDarkMode,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> with TickerProviderStateMixin {
  late AnimationController _cardScaleController;
  late Animation<double> _cardScaleAnimation;
  late AnimationController _burstController;
  late Animation<double> _burstScaleAnimation;
  late Animation<double> _burstOpacityAnimation;

  bool _isLocallyCompleted = false;

  @override
  void initState() {
    super.initState();
    _isLocallyCompleted = widget.habit.isCompleted;
    _cardScaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _cardScaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(_cardScaleController);
    _burstController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _burstScaleAnimation = Tween<double>(begin: 1.0, end: 3.5).animate(CurvedAnimation(parent: _burstController, curve: Curves.easeOut));
    _burstOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_burstController);
  }

  @override
  void dispose() {
    _cardScaleController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  void _handleTap() async {
    if (_isLocallyCompleted) return;

    if (widget.habit.reminderHour != null && widget.habit.reminderMinute != null) {
      final now = DateTime.now();
      final habitTime = DateTime(now.year, now.month, now.day, widget.habit.reminderHour!, widget.habit.reminderMinute!);

      if (now.isBefore(habitTime)) {
        String timeStr = '${widget.habit.reminderHour.toString().padLeft(2, '0')}:${widget.habit.reminderMinute.toString().padLeft(2, '0')}';
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chưa đến giờ ($timeStr)! Hãy kiên nhẫn đợi thêm nhé ⏳'),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
    }

    await _cardScaleController.forward();
    _cardScaleController.reverse();
    _burstController.forward(from: 0.0);

    setState(() => _isLocallyCompleted = true);
    await Future.delayed(const Duration(milliseconds: 700));
    widget.habit.isCompleted = true;
    widget.habit.save();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    String timeString = widget.habit.reminderHour != null
        ? '${widget.habit.reminderHour.toString().padLeft(2, '0')}:${widget.habit.reminderMinute.toString().padLeft(2, '0')}'
        : '--:--';

    return Dismissible(
      key: Key(widget.habit.key.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDelete(),
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ScaleTransition(
        scale: _cardScaleAnimation,
        child: GestureDetector(
          onTap: _handleTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: widget.isDarkMode ? [] : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28, height: 28,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ScaleTransition(
                        scale: _burstScaleAnimation,
                        child: FadeTransition(
                          opacity: _burstOpacityAnimation,
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withValues(alpha: 0.4)),
                          ),
                        ),
                      ),
                      Icon(
                        _isLocallyCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: _isLocallyCompleted ? Colors.blue : Colors.grey,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 44, height: 44, child: widget.thumbnailWidget),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.habit.name,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isLocallyCompleted ? Colors.grey : (widget.isDarkMode ? Colors.white : Colors.black),
                            decoration: _isLocallyCompleted ? TextDecoration.lineThrough : null
                        ),
                      ),
                      if (widget.habit.note != null && widget.habit.note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            widget.habit.note!,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(timeString, style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}