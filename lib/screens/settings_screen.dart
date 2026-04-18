import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../services/sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Box _settingsBox;
  final ImagePicker _picker = ImagePicker();
  final SyncService _syncService = SyncService();

  final List<String> _avatars = [
    'https://cdn-icons-png.flaticon.com/512/4140/4140048.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140047.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140039.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140051.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140040.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140052.png',
  ];

  final List<Color> _availableColors = [
    Colors.transparent, Colors.red, Colors.pink, Colors.purple,
    Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue,
    Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen,
    Colors.lime, Colors.yellow, Colors.amber, Colors.orange,
    Colors.deepOrange, Colors.brown, Colors.grey, Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settingsBox');
  }

  // ==========================================
  // XỬ LÝ LIÊN KẾT (URL LAUNCHER)
  // ==========================================
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) _showErrorDialog("Lỗi", "Thiết bị của bạn không hỗ trợ mở liên kết này!");
      }
    } catch (e) {
      if (mounted) _showErrorDialog("Lỗi", "Không thể mở liên kết: $e");
    }
  }

  void _showContactModal() {
    bool isDarkMode = _settingsBox.get('isDarkMode', defaultValue: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("Liên hệ Hỗ trợ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 20),

            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.email_rounded, color: Colors.white)),
              title: Text("Gửi Email cho chúng tôi", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
              subtitle: Text("Phản hồi trong 24h", style: TextStyle(color: Colors.grey[500])),
              onTap: () {
                Navigator.pop(context);
                _launchURL("mailto:plong08082004@gmail.com?subject=Hỗ trợ ứng dụng Habit Tracker");
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.chat_bubble_rounded, color: Colors.white)),
              title: Text("Nhắn tin Zalo", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
              subtitle: Text("Chat trực tiếp với đội ngũ", style: TextStyle(color: Colors.grey[500])),
              onTap: () {
                Navigator.pop(context);
                _launchURL("https://zalo.me/0983299484");
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // LOGIC ĐỒNG BỘ & SAO LƯU
  // ==========================================
  void _handleBackup() async {
    String userID = _settingsBox.get('userID', defaultValue: 'UNKNOWN');
    int currentStreak = _syncService.calculateCurrentStreak();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 20),
            const Text("Đang sao lưu lên mây...", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Streak hiện tại: $currentStreak ngày",
                style: const TextStyle(fontSize: 13, color: Colors.blueAccent, fontWeight: FontWeight.w500)),
            const SizedBox(height: 5),
            const Text("Chờ mình chút !!", style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 5));

    try {
      await _syncService.backupData(userID, currentStreak);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green, content: Text('✅ Đã sao lưu thành công! (Streak: $currentStreak ngày)')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog("Lỗi sao lưu", "Không thể kết nối máy chủ. Bạn kiểm tra mạng nhé!");
      }
    }
  }

  void _showSyncDialog(BuildContext context) {
    TextEditingController idController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.cloud_sync_rounded, color: Colors.green), SizedBox(width: 10), Text('Đồng bộ dữ liệu')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nhập ID cũ để tải dữ liệu.'),
            const SizedBox(height: 15),
            TextField(
              controller: idController,
              decoration: InputDecoration(hintText: "Nhập ID (Ví dụ: AB123456)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.vpn_key_outlined)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              String tid = idController.text.trim().toUpperCase();
              if (tid.isNotEmpty) {
                Navigator.pop(context);
                _processSync(tid);
              }
            },
            child: const Text('Đồng bộ ngay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _processSync(String targetID) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    try {
      await _syncService.restoreData(targetID);
      await _settingsBox.put('userID', targetID);

      if (mounted) {
        Navigator.pop(context);
        _showSuccessAnimation(targetID);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog("Lỗi đồng bộ", e.toString());
      }
    }
  }

  // --- UI HELPERS ---
  void _showErrorDialog(String title, String msg) {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(title, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đã rõ"))]));
  }

  void _showSuccessAnimation(String newID) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Text('Đã đồng bộ thành công với ID: $newID')]), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _settingsBox.put('avatarPath', image.path);
        await _settingsBox.put('isAvatarFile', true);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) { debugPrint("Lỗi chọn ảnh: $e"); }
  }

  void _showAvatarOptions() {
    bool isDarkMode = _settingsBox.get('isDarkMode', defaultValue: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Thay đổi ảnh đại diện', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _pickImageFromGallery, icon: const Icon(Icons.photo_library, color: Colors.white), label: const Text("Chọn ảnh từ thiết bị", style: TextStyle(color: Colors.white, fontSize: 16)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A90E2), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 20),
            const Text('Hoặc chọn Avatar có sẵn', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Wrap(spacing: 15, runSpacing: 15, alignment: WrapAlignment.center, children: _avatars.map((url) => GestureDetector(onTap: () async { await _settingsBox.put('avatarPath', url); await _settingsBox.put('isAvatarFile', false); if (mounted) Navigator.pop(context); }, child: CircleAvatar(radius: 35, backgroundColor: Colors.blue.shade50, backgroundImage: NetworkImage(url)))).toList())
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Chọn màu khung viền", textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(width: double.maxFinite, child: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: _availableColors.map((color) {
          bool isNone = color == Colors.transparent;
          return GestureDetector(onTap: () { _settingsBox.put('frameColorValue', color.value); Navigator.pop(context); }, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: isNone ? Colors.grey[200] : color, shape: BoxShape.circle, border: isNone ? Border.all(color: Colors.grey, width: 1) : null, boxShadow: isNone ? [] : [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)]), child: isNone ? const Icon(Icons.block, size: 20, color: Colors.grey) : null));
        }).toList())),
      ),
    );
  }

  void _editName() {
    String currentName = _settingsBox.get('userName', defaultValue: 'Người dùng mới');
    TextEditingController nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tên của bạn là gì?', style: TextStyle(fontSize: 18)),
        content: TextField(controller: nameController, decoration: InputDecoration(hintText: "Nhập tên mới", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A90E2)), onPressed: () { if (nameController.text.trim().isNotEmpty) _settingsBox.put('userName', nameController.text.trim()); Navigator.pop(context); }, child: const Text('Lưu', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  void _showInfoModal(String title, String content) {
    bool isDarkMode = _settingsBox.get('isDarkMode', defaultValue: false);
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => Container(height: MediaQuery.of(context).size.height * 0.8, decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))), padding: const EdgeInsets.all(24), child: Column(children: [Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))), const SizedBox(height: 20), Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)), const SizedBox(height: 20), Expanded(child: SingleChildScrollView(child: Text(content, style: TextStyle(fontSize: 15, height: 1.6, color: isDarkMode ? Colors.grey[300] : Colors.black87)))), const SizedBox(height: 20), ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text("Tôi đã hiểu"))])));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _settingsBox.listenable(),
      builder: (context, Box box, _) {
        String userID = box.get('userID', defaultValue: '');
        if (userID.isEmpty) {
          userID = _syncService.generateSyncId();
          Future.microtask(() => box.put('userID', userID));
        }
        String userName = box.get('userName', defaultValue: 'Người dùng mới');
        String avatarPath = box.get('avatarPath', defaultValue: _avatars[0]);
        bool isAvatarFile = box.get('isAvatarFile', defaultValue: false);
        bool isDarkMode = box.get('isDarkMode', defaultValue: false);
        int frameColorValue = box.get('frameColorValue', defaultValue: Colors.transparent.value);
        Color currentFrameColor = Color(frameColorValue);
        bool hasFrame = currentFrameColor != Colors.transparent;

        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF4F7FC),
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text("Cài đặt", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Avatar & Name Section
              Center(
                child: Column(children: [
                  Stack(alignment: Alignment.center, children: [
                    if (hasFrame) Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: currentFrameColor, width: 4), boxShadow: [BoxShadow(color: currentFrameColor.withOpacity(0.5), blurRadius: 15)])),
                    GestureDetector(onTap: _showAvatarOptions, child: CircleAvatar(radius: 50, backgroundColor: Colors.grey[300], backgroundImage: isAvatarFile ? FileImage(File(avatarPath)) as ImageProvider : NetworkImage(avatarPath))),
                    Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: _showAvatarOptions, child: const CircleAvatar(radius: 18, backgroundColor: Color(0xFF4A90E2), child: Icon(Icons.camera_alt, size: 18, color: Colors.white)))),
                  ]),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(userName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)), IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.grey), onPressed: _editName)]),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text("ID: $userID", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2))),
                ]),
              ),
              const SizedBox(height: 30),

              // Cá nhân hóa
              _buildSectionTitle("Cá nhân hóa", isDarkMode),
              _buildSettingCard(isDarkMode, child: Column(children: [
                ListTile(leading: const Icon(Icons.auto_awesome, color: Colors.amber), title: Text("Thay đổi viền Avatar", style: TextStyle(fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : Colors.black87)), trailing: Container(width: 24, height: 24, decoration: BoxDecoration(color: currentFrameColor, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300))), onTap: _showColorPicker),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.dark_mode_rounded, color: Colors.purple), title: Text("Chế độ ban đêm", style: TextStyle(fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : Colors.black87)), trailing: CupertinoSwitch(value: isDarkMode, activeColor: Colors.purple, onChanged: (value) => box.put('isDarkMode', value))),
              ])),
              const SizedBox(height: 20),

              // Dữ liệu & Đồng bộ
              _buildSectionTitle("Dữ liệu & Đồng bộ", isDarkMode),
              _buildSettingCard(isDarkMode, child: Column(children: [
                ListTile(leading: const Icon(Icons.cloud_upload, color: Colors.blue), title: Text("Sao lưu lên Cloud", style: TextStyle(fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : Colors.black87)), trailing: Icon(Icons.chevron_right, color: isDarkMode ? Colors.white : Colors.black87), onTap: _handleBackup),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.sync, color: Colors.green), title: Text("Đồng bộ từ ID khác", style: TextStyle(fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : Colors.black87)), trailing: Icon(Icons.chevron_right, color: isDarkMode ? Colors.white : Colors.black87), onTap: () => _showSyncDialog(context)),
              ])),
              const SizedBox(height: 20),

              // Hỗ trợ & Liên hệ (TÍNH NĂNG MỚI)
              _buildSectionTitle("Hỗ trợ cộng đồng", isDarkMode),
              _buildSettingCard(isDarkMode, child: Column(children: [
                _buildListTile("Trung tâm hỗ trợ", Icons.headset_mic_rounded, isDarkMode, _showContactModal),
              ])),
              const SizedBox(height: 20),

              // Thông tin & Pháp lý
              _buildSectionTitle("Thông tin & Pháp lý", isDarkMode),
              _buildSettingCard(isDarkMode, child: Column(children: [
                _buildListTile(
                    "Chính sách bảo mật",
                    Icons.verified_user_rounded,
                    isDarkMode,
                        () => _showInfoModal(
                        "Chính sách bảo mật",
                        "Quyền riêng tư của bạn là ưu tiên hàng đầu của chúng tôi.\n\n"
                            "1. Dữ liệu thói quen và streak được lưu trữ cục bộ trên thiết bị và đồng bộ an toàn qua Google Firebase khi bạn yêu cầu.\n"
                            "2. Chúng tôi KHÔNG chia sẻ, bán hoặc cung cấp dữ liệu của bạn cho bất kỳ bên thứ ba nào.\n"
                            "3. Mọi dữ liệu có thể được xóa vĩnh viễn khỏi hệ thống Cloud khi bạn yêu cầu.\n\n"
                            "Ứng dụng tuân thủ các tiêu chuẩn bảo mật hiện hành để đảm bảo trải nghiệm an toàn nhất."
                    )
                ),
                const Divider(height: 1),
                _buildListTile(
                    "Điều khoản dịch vụ",
                    Icons.gavel_rounded,
                    isDarkMode,
                        () => _showInfoModal(
                        "Điều khoản dịch vụ",
                        "Chào mừng bạn đến với kỷ nguyên của sự kỷ luật.\n\n"
                            "• Ứng dụng cung cấp công cụ theo dõi thói quen cá nhân. Kết quả đạt được phụ thuộc vào sự nỗ lực của chính người dùng.\n"
                            "• Bạn chịu trách nhiệm bảo mật Mã khôi phục (Sync ID) của mình.\n"
                            "• Chúng tôi không chịu trách nhiệm về việc mất dữ liệu nếu bạn không thực hiện sao lưu định kỳ lên hệ thống Cloud."
                    )
                ),
                const Divider(height: 1),
                _buildListTile(
                    "Về ứng dụng v1.0.0",
                    Icons.info_outline_rounded,
                    isDarkMode,
                        () => _showInfoModal(
                        "Habit Tracker",
                        "Phiên bản: 1.0.0 (Build 2026)\n\n"
                            "Được thiết kế với triết lý 'Tối giản để Hiệu quả', ứng dụng giúp bạn loại bỏ sự trì hoãn và xây dựng lối sống khoa học hơn.\n\n"
                            "Cảm ơn bạn đã lựa chọn chúng tôi để đồng hành trên con đường chinh phục những mục tiêu mới. Mọi ý kiến đóng góp xin gửi về hòm thư hỗ trợ trong phần Liên hệ."
                    )
                ),
              ])),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) => Padding(padding: const EdgeInsets.only(left: 8, bottom: 8), child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.grey[400] : Colors.grey[600])));
  Widget _buildSettingCard(bool isDarkMode, {required Widget child}) => Container(decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]), child: child);
  Widget _buildListTile(String title, IconData icon, bool isDarkMode, VoidCallback onTap) => ListTile(leading: Icon(icon, size: 22, color: isDarkMode ? Colors.grey[400] : Colors.grey[700]), title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : Colors.black87)), trailing: Icon(Icons.chevron_right, size: 20, color: isDarkMode ? Colors.white : Colors.black87), onTap: onTap);
}