import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/sync_service.dart';
import '../models/daily_record.dart';

class SyncManagerWidget extends StatefulWidget {
  const SyncManagerWidget({Key? key}) : super(key: key);

  @override
  State<SyncManagerWidget> createState() => _SyncManagerWidgetState();
}

class _SyncManagerWidgetState extends State<SyncManagerWidget> {
  final SyncService _syncService = SyncService();
  bool _isLoading = false;

  // ==========================================
  // 🟢 XỬ LÝ SAO LƯU (BACKUP)
  // ==========================================
  void _handleBackup() async {
    setState(() => _isLoading = true);

    // Chờ 5 giây theo đúng yêu cầu của sếp để tạo cảm giác "đang xử lý"
    await Future.delayed(const Duration(seconds: 5));

    try {
      final settingsBox = Hive.box('settingsBox');
      final historyBox = Hive.box<DailyRecord>('historyBox');

      // 🔥 FIX QUAN TRỌNG: Ép Hive ghi toàn bộ dữ liệu tạm thời xuống ổ cứng
      // Tránh việc dữ liệu vừa đồng bộ xong chưa kịp cập nhật vào hàm tính Streak
      await historyBox.flush();

      // Kiểm tra hoặc tạo User ID nếu chưa có
      String userID = settingsBox.get('userID', defaultValue: '');
      if (userID.isEmpty) {
        userID = _syncService.generateSyncId();
        await settingsBox.put('userID', userID);
      }

      // Lấy streak thật sau khi đã flush dữ liệu
      int realStreak = _syncService.calculateCurrentStreak();

      // Đẩy toàn bộ dữ liệu (Habits, History, Profile) lên Cloud
      await _syncService.backupData(userID, realStreak);

      if (!mounted) return;
      _showSuccessDialog(userID, realStreak);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text("Lỗi sao lưu: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // 🔵 XỬ LÝ ĐỒNG BỘ (RESTORE)
  // ==========================================
  void _handleRestore() {
    TextEditingController idController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.sync_problem, color: Colors.orange),
            SizedBox(width: 10),
            Text('Đồng bộ dữ liệu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nhập ID cũ để tải dữ liệu về máy này.'),
            const SizedBox(height: 15),
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                hintText: 'MÃ ID (VÍ DỤ: wbx7mhhj)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HỦY')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              String inputId = idController.text.trim().toUpperCase();
              if (inputId.isEmpty) return;

              Navigator.pop(context); // Đóng dialog nhập ID
              setState(() => _isLoading = true);

              try {
                // Tải dữ liệu và Hợp nhất (Merge)
                await _syncService.restoreData(inputId);

                // Cập nhật lại ID máy hiện tại thành ID vừa đồng bộ
                await Hive.box('settingsBox').put('userID', inputId);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.green,
                    content: Text('✅ Đồng bộ thành công! Dữ liệu đã được cập nhật.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                _showError(e.toString());
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('ĐỒNG BỘ NGAY', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  void _showSuccessDialog(String syncId, int streak) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sao lưu thành công! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Streak hiện tại: $streak ngày',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 15),
            const Text('Mã ID khôi phục của bạn:'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: SelectableText(
                syncId,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Hãy lưu mã này để đổi máy không bị mất Streak nhé!',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: syncId));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã chép mã ID vào bộ nhớ tạm!")));
            },
            child: const Text('COPY ID & ĐÓNG'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Thông báo"),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("ĐÃ RÕ"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.blue.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (_isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 15),
                  Text("Đang kết nối Cloud... (5s)", style: TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w500))
                ],
              )
            else ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_sync, color: Colors.blue, size: 24),
                  SizedBox(width: 10),
                  Text("Quản lý dữ liệu Cloud", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleBackup,
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: const Text("Sao lưu"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleRestore,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text("Đồng bộ"),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                    ),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}