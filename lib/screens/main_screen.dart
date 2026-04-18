import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
// Import các trang
import 'home_screen.dart';
import 'achievements_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import 'add_habit_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final Color mainAppColor = const Color(0xFF4A90E2);
  late Box _settingsBox; // 🟢 [CẬP NHẬT]

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settingsBox'); // 🟢 [CẬP NHẬT]
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const AchievementsScreen(),
    const ProgressScreen(),
    const SettingsScreen(),
  ];

  void _openAddHabitScreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, a, b) => const AddHabitScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 [CẬP NHẬT]: Lắng nghe Settings để đổi màu BottomBar
    return ValueListenableBuilder(
      valueListenable: _settingsBox.listenable(keys: ['isDarkMode']),
      builder: (context, box, _) {
        bool isDarkMode = box.get('isDarkMode', defaultValue: false);
        Color navBgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

        return Scaffold(
          body: _screens[_currentIndex],
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openAddHabitScreen(context),
            backgroundColor: mainAppColor,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: Colors.white, size: 32),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            elevation: 10,
            color: navBgColor, // 🟢 Áp dụng màu nền tối cho thanh điều hướng
            child: SizedBox(
              height: 65,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_filled, 0, 'Trang chủ', isDarkMode),
                  _buildNavItem(Icons.emoji_events, 1, 'Thành tựu', isDarkMode),
                  const SizedBox(width: 48),
                  _buildNavItem(Icons.pie_chart, 2, 'Tiến trình', isDarkMode),
                  _buildNavItem(Icons.person, 3, 'Cá nhân', isDarkMode),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, int index, String label, bool isDarkMode) {
    final isSelected = _currentIndex == index;
    // 🟢 Chỉnh màu icon khi không chọn ở mode tối
    final color = isSelected ? mainAppColor : (isDarkMode ? Colors.grey[600] : Colors.grey.shade400);

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      splashColor: Colors.transparent, highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: isSelected ? 28 : 24),
          const SizedBox(height: 4),
          Text(
              label,
              style: TextStyle(
                color: color, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              )
          ),
        ],
      ),
    );
  }
}