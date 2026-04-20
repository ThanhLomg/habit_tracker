import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';
import '../models/habit_item.dart';
import '../models/daily_record.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late DateTime _selectedDate;
  late DateTime _today;
  late int _daysInMonth;

  late AnimationController _listAnimationController;
  late Box<HabitItem> _habitsBox;
  late Box<DailyRecord> _historyBox;
  late Box _settingsBox;

  bool _isCompletedVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initDates();

    _habitsBox = Hive.box<HabitItem>('habitsBoxV2');
    _historyBox = Hive.box<DailyRecord>('historyBox');
    _settingsBox = Hive.box('settingsBox');

    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final realToday = DateTime(now.year, now.month, now.day);
      if (_today != realToday) {
        setState(() {
          _today = realToday;
          _selectedDate = realToday;
          _daysInMonth = DateUtils.getDaysInMonth(_today.year, _today.month);
        });
      }
    }
  }

  void _initDates() {
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selectedDate = _today;
    _daysInMonth = DateUtils.getDaysInMonth(_today.year, _today.month);
  }

  void _onDaySelected(int day) {
    DateTime tappedDate = DateTime(_today.year, _today.month, day);
    if (tappedDate.isAfter(_today)) return;

    setState(() {
      _selectedDate = tappedDate;
      _isCompletedVisible = false;
    });

    _listAnimationController.reset();
    _listAnimationController.forward();
  }

  String _getRandomSubtitle(String habitName, String state) {
    final random = Random(habitName.hashCode ^ _selectedDate.hashCode);

    final List<String> completedSubtitles = [
      'Tuyệt vời! 🎉', 'Hoàn thành xuất sắc 🫡', 'Làm tốt lắm!',
      'Tiếp tục phát huy nhé!', 'Quá đỉnh! 🔥', 'Đỉnh của chóp!'
    ];

    final List<String> missedSubtitles = [
      'Tiếc quá 🥲', 'Bị lãng quên...', 'Đừng bỏ cuộc nhé! 💪',
      'Ngày mai làm lại nhé!', 'Cố gắng vào lần sau'
    ];

    final List<String> pendingSubtitles = [
      'Chưa làm', 'Cố lên nào! 💪', 'Nhớ hoàn thành nhé',
      'Đừng quên mình nhé! 🥱', 'Sắp xong rồi!'
    ];

    if (state == 'completed') {
      return completedSubtitles[random.nextInt(completedSubtitles.length)];
    } else if (state == 'missed') {
      return missedSubtitles[random.nextInt(missedSubtitles.length)];
    } else {
      return pendingSubtitles[random.nextInt(pendingSubtitles.length)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: _settingsBox.listenable(keys: ['isDarkMode']),
        builder: (context, settingsBox, _) {
          bool isDarkMode = settingsBox.get('isDarkMode', defaultValue: false);

          Color bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF4F7FC);
          Color cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
          Color textColor = isDarkMode ? Colors.white : Colors.black87;

          return ValueListenableBuilder<Box<DailyRecord>>(
            valueListenable: _historyBox.listenable(),
            builder: (context, historyBox, _) {
              return ValueListenableBuilder<Box<HabitItem>>(
                valueListenable: _habitsBox.listenable(),
                builder: (context, habitsBox, _) {
                  bool isTodaySelected = _selectedDate.isAtSameMomentAs(_today);
                  String selectedDateStr = _selectedDate.toIso8601String().split('T')[0];

                  List<String> completedNames = [];
                  List<String> pendingOrMissedNames = [];
                  int totalTasks = 0;
                  int tasksDone = 0;
                  double completionRate = 0.0;

                  List<HabitItem> activeHabits = habitsBox.values.toList();
                  List<String> allActiveHabitNames = activeHabits.map((e) => e.name).toList();

                  if (isTodaySelected) {
                    completedNames = activeHabits.where((h) => h.isCompleted).map((h) => h.name).toList();
                    pendingOrMissedNames = activeHabits.where((h) => !h.isCompleted).map((h) => h.name).toList();
                    totalTasks = activeHabits.length;
                    tasksDone = completedNames.length;
                    completionRate = totalTasks == 0 ? 0.0 : tasksDone / totalTasks;
                  } else {
                    DailyRecord? record = historyBox.get(selectedDateStr);

                    if (record != null) {
                      completedNames = record.completedHabitNames;
                      // 🔥 SỬA TẠI ĐÂY: Dùng record.totalTasks thay vì completedHabitsCount
                      totalTasks = record.totalTasks;
                      tasksDone = record.completedTasks;
                      completionRate = totalTasks == 0 ? 0.0 : tasksDone / totalTasks;

                      int missedCount = totalTasks - tasksDone;
                      if (missedCount > 0) {
                        List<String> potentialMissed = allActiveHabitNames.where((name) => !completedNames.contains(name)).toList();
                        pendingOrMissedNames = potentialMissed.take(missedCount).toList();

                        // 🔥 SỬA TẠI ĐÂY: Fallback nếu thói quen đã bị sếp xóa khỏi danh sách hiện tại
                        while (pendingOrMissedNames.length < missedCount) {
                          pendingOrMissedNames.add("Thói quen đã xóa");
                        }
                      }
                    } else {
                      totalTasks = 0;
                      tasksDone = 0;
                      completionRate = 0.0;
                    }
                  }

                  return Scaffold(
                    backgroundColor: bgColor,
                    appBar: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      title: Text(
                        'Tiến trình',
                        style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    body: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeatmapMonth(isDarkMode, cardColor, textColor),
                          const SizedBox(height: 24),
                          if (totalTasks > 0)
                            _buildDailyProgressCard(completionRate, tasksDone, isDarkMode, cardColor, textColor),
                          const SizedBox(height: 24),
                          Text(
                            isTodaySelected ? 'Nhiệm vụ hôm nay' : 'Lịch sử ngày ${_selectedDate.day}/${_selectedDate.month}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          const SizedBox(height: 16),
                          if (totalTasks == 0 && !isTodaySelected)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text('Không có dữ liệu cho ngày này.\nCó vẻ bạn đã nghỉ ngơi 💤',
                                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], height: 1.5)),
                              ),
                            )
                          else
                            _buildStatusList(completedNames, pendingOrMissedNames, isTodaySelected, isDarkMode, cardColor, textColor),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        }
    );
  }

  Widget _buildHeatmapMonth(bool isDarkMode, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDarkMode ? [] : [BoxShadow(color: Colors.blue.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tháng ${_today.month}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.grey[400] : Colors.black54)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _daysInMonth,
            itemBuilder: (context, index) {
              int day = index + 1;
              DateTime cellDate = DateTime(_today.year, _today.month, day);

              bool isSelected = day == _selectedDate.day;
              bool isFuture = cellDate.isAfter(_today);
              bool isToday = cellDate.isAtSameMomentAs(_today);

              double rate = 0.0;
              if (isToday) {
                List<HabitItem> active = _habitsBox.values.toList();
                if (active.isNotEmpty) {
                  rate = active.where((h) => h.isCompleted).length / active.length;
                }
              } else if (!isFuture) {
                String dateStr = cellDate.toIso8601String().split('T')[0];
                DailyRecord? record = _historyBox.get(dateStr);
                // 🔥 SỬA TẠI ĐÂY: Dùng record.totalTasks thay vì completedHabitsCount
                if (record != null && record.totalTasks > 0) {
                  rate = record.completedTasks / record.totalTasks;
                }
              }

              Color boxColor;
              if (isFuture) {
                boxColor = isDarkMode ? Colors.grey[800]! : const Color(0xFFEEEEEE);
              } else if (rate == 0) {
                boxColor = isDarkMode ? Colors.grey[850]! : Colors.grey[100]!;
              } else if (rate <= 0.3) {
                boxColor = isDarkMode ? const Color(0xFF1565C0) : const Color(0xFF90CAF9);
              } else if (rate <= 0.7) {
                boxColor = isDarkMode ? const Color(0xFF1976D2) : const Color(0xFF42A5F5);
              } else {
                boxColor = isDarkMode ? const Color(0xFF2196F3) : const Color(0xFF1E88E5);
              }

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + (index * 10)),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: GestureDetector(
                      onTap: () => _onDaySelected(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: boxColor,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected ? Border.all(color: textColor, width: 2) : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: boxColor.withValues(alpha: 0.6), blurRadius: 8, offset: const Offset(0, 4))]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          day.toString(),
                          style: TextStyle(
                            color: rate > 0.4 && !isFuture ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.black54),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyProgressCard(double completionRate, int tasksDone, bool isDarkMode, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70, height: 70,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(value: 1, strokeWidth: 8, color: Colors.white.withValues(alpha: 0.5)),
                TweenAnimationBuilder<double>(
                  key: ValueKey(completionRate),
                  tween: Tween<double>(begin: 0.0, end: completionRate),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CircularProgressIndicator(
                      value: value, strokeWidth: 8, backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                      strokeCap: StrokeCap.round,
                    );
                  },
                ),
                Center(
                  child: Text('${(completionRate * 100).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A90E2))),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completionRate == 1.0 ? 'Hoàn hảo!' : completionRate >= 0.5 ? 'Rất tốt!' : 'Cố gắng lên!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.grey[400] : Colors.black54, height: 1.4),
                    children: [
                      const TextSpan(text: 'Đã thực hiện '),
                      TextSpan(text: '$tasksDone thói quen', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A90E2))),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatusList(List<String> completed, List<String> pendingOrMissed, bool isToday, bool isDarkMode, Color cardColor, Color textColor) {
    List<Widget> listItems = [];
    int delayIndex = 0;

    if (pendingOrMissed.isNotEmpty) {
      listItems.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text("Cần chú ý", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
      ));

      for (String name in pendingOrMissed) {
        bool isMissed = !isToday;
        String randomSubtitle = _getRandomSubtitle(name, isMissed ? 'missed' : 'pending');

        listItems.add(_buildAnimatedListItem(
          name: name,
          icon: isMissed ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded,
          iconColor: isMissed ? Colors.redAccent : Colors.grey.shade400,
          bgColor: isMissed ? (isDarkMode ? const Color(0x33FFCDD2) : const Color(0xFFFFEBEE)) : (isDarkMode ? Colors.grey[800]! : Colors.grey.shade100),
          subtitle: randomSubtitle,
          subtitleColor: isMissed ? Colors.redAccent : Colors.grey.shade500,
          delayIndex: delayIndex++,
          isDarkMode: isDarkMode, cardColor: cardColor, textColor: textColor,
        ));
      }
    }

    if (completed.isNotEmpty) {
      listItems.add(
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _isCompletedVisible = !_isCompletedVisible;
                });
                if (_isCompletedVisible) {
                  _listAnimationController.forward(from: 0.0);
                }
              },
              icon: Icon(_isCompletedVisible ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              label: Text(_isCompletedVisible ? "Ẩn thói quen đã xong" : "Xem ${completed.length} thói quen đã xong"),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[500]),
            ),
          )
      );

      if (_isCompletedVisible) {
        for (String name in completed) {
          String randomSubtitle = _getRandomSubtitle(name, 'completed');

          listItems.add(_buildAnimatedListItem(
            name: name,
            icon: Icons.check_circle_rounded,
            iconColor: Colors.green,
            bgColor: isDarkMode ? const Color(0x33C8E6C9) : const Color(0xFFE8F5E9),
            subtitle: randomSubtitle,
            subtitleColor: Colors.green,
            delayIndex: delayIndex++,
            isDarkMode: isDarkMode, cardColor: cardColor, textColor: textColor,
          ));
        }
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: listItems);
  }

  Widget _buildAnimatedListItem({
    required String name, required IconData icon, required Color iconColor,
    required Color bgColor, required String subtitle, required Color subtitleColor, required int delayIndex,
    required bool isDarkMode, required Color cardColor, required Color textColor
  }) {
    final delay = delayIndex * 0.1;
    final slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _listAnimationController, curve: Interval(delay.clamp(0.0, 1.0), 1.0, curve: Curves.easeOutBack)),
    );
    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _listAnimationController, curve: Interval(delay.clamp(0.0, 1.0), 1.0, curve: Curves.easeIn)),
    );

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDarkMode ? [] : [BoxShadow(color: Colors.blue.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: subtitleColor, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}