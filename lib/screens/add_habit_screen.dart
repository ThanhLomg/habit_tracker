import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_item.dart';
import '../services/notification_service.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  TimeOfDay? _selectedTime;
  bool _isReminderOn = true;

  // 🟢 1. KHAI BÁO BIẾN LƯU ICON VÀ KHO ICON
  IconData _selectedIcon = Icons.star_rounded;

  final Map<String, List<IconData>> _iconCategories = {
    "Sức khỏe & Thể thao": [
      Icons.directions_run_rounded, Icons.fitness_center_rounded, Icons.self_improvement_rounded,
      Icons.water_drop_rounded, Icons.directions_bike_rounded, Icons.sports_gymnastics_rounded,
      Icons.monitor_weight_rounded, Icons.restaurant_menu_rounded,
    ],
    "Học tập & Công việc": [
      Icons.menu_book_rounded, Icons.language_rounded, Icons.code_rounded,
      Icons.computer_rounded, Icons.edit_note_rounded, Icons.work_rounded,
      Icons.lightbulb_circle_rounded, Icons.draw_rounded,
    ],
    "Tài chính & Mua sắm": [
      Icons.savings_rounded, Icons.shopping_cart_rounded, Icons.receipt_long_rounded,
      Icons.wallet_rounded, Icons.account_balance_rounded, Icons.monetization_on_rounded,
    ],
    "Sinh hoạt & Thư giãn": [
      Icons.bedtime_rounded, Icons.music_note_rounded, Icons.cleaning_services_rounded,
      Icons.local_cafe_rounded, Icons.pets_rounded, Icons.park_rounded,
      Icons.checkroom_rounded, Icons.home_rounded,
    ]
  };

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // 🟢 2. HÀM HIỂN THỊ KHO ICON (Đã đồng bộ Dark Mode)
  void _showIconPicker(bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
        ),
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            Text("Chọn Biểu Tượng", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: _iconCategories.keys.length,
                itemBuilder: (context, index) {
                  String category = _iconCategories.keys.elementAt(index);
                  List<IconData> icons = _iconCategories[category]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(category, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[400], fontSize: 14)),
                      ),
                      Wrap(
                        spacing: 15,
                        runSpacing: 15,
                        children: icons.map((icon) => GestureDetector(
                          onTap: () {
                            setState(() { _selectedIcon = icon; });
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              color: _selectedIcon == icon
                                  ? Colors.blue
                                  : (isDarkMode ? Colors.grey[800] : Colors.grey[100]),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              color: _selectedIcon == icon
                                  ? Colors.white
                                  : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveHabit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên thói quen!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final int uniqueId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final newHabit = HabitItem(
      name: name,
      reminderHour: _selectedTime?.hour,
      reminderMinute: _selectedTime?.minute,
      isCompleted: false,
      createdAt: DateTime.now(),
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      iconCodePoint: _selectedIcon.codePoint,
    );

    final box = Hive.box<HabitItem>('habitsBoxV2');
    await box.put(uniqueId, newHabit);

    if (_isReminderOn && _selectedTime != null) {
      final now = DateTime.now();
      DateTime scheduledDate = DateTime(
          now.year, now.month, now.day,
          _selectedTime!.hour, _selectedTime!.minute
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      try {
        await NotificationService.scheduleHabitNotifications(
          id: uniqueId,
          title: name,
          scheduledTime: scheduledDate,
        );
        debugPrint('✅ Đã đặt lịch: $name vào lúc $scheduledDate với ID: $uniqueId');
      } catch (e) {
        debugPrint('❌ Lỗi đặt chuông: $e');
      }
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: Hive.box('settingsBox').listenable(),
        builder: (context, settingsBox, _) {
          final isDarkMode = settingsBox.get('isDarkMode', defaultValue: false);

          final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF4F7FC);
          final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
          final textColor = isDarkMode ? Colors.white : Colors.black87;
          final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

          return Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: textColor),
              title: Text('Thêm Thói Quen', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // 🟢 3. GIAO DIỆN NÚT CHỌN ICON
                  Center(
                    child: GestureDetector(
                      onTap: () => _showIconPicker(isDarkMode), // Gọi hàm mở Modal ở đây
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_selectedIcon, color: Colors.blue, size: 36),
                            const SizedBox(width: 16),
                            const Text("Đổi Biểu Tượng", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Tên thói quen',
                      labelStyle: TextStyle(color: subTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: isDarkMode ? BorderSide.none : const BorderSide(color: Colors.grey),
                      ),
                      filled: true,
                      fillColor: cardColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _noteController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Ghi chú (Tùy chọn)',
                      labelStyle: TextStyle(color: subTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: isDarkMode ? BorderSide.none : const BorderSide(color: Colors.grey),
                      ),
                      filled: true,
                      fillColor: cardColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Thời gian nhắc nhở', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                    subtitle: Text(
                      _selectedTime != null
                          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                          : 'Chưa đặt',
                      style: TextStyle(color: subTextColor),
                    ),
                    trailing: const Icon(Icons.access_time_filled, color: Color(0xFF4A90E2)),
                    onTap: () => _selectTime(context),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nhận nhắc nhở', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                      CupertinoSwitch(
                        value: _isReminderOn, activeTrackColor: const Color(0xFF4A90E2),
                        onChanged: (value) => setState(() => _isReminderOn = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _saveHabit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Lưu Thói Quen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }
}