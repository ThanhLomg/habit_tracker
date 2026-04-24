import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';

class EmailService {
  static const String serviceId = 'service_6ossvlx';
  static const String templateId = 'template_0rejn6h';
  static const String publicKey = 'nGAQFQ-3GWPME7WJr';

  static Future<void> sendEmailReminder(String habitName) async {
    final settingsBox = Hive.box('settingsBox');
    final userEmail = settingsBox.get('userEmail', defaultValue: '');

    if (userEmail.isEmpty) {
      print('⚠️ Email trống, không gửi!');
      return;
    }

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost', // Giữ cái này để tránh lỗi CORS
        },
        body: json.encode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey, // Lưu ý: Một số version API cũ dùng user_id, sếp thử cả 2 nếu lỗi
          'template_params': {
            'user_email': userEmail,
            'habit_name': habitName,
          }
        }),
      );

      if (response.statusCode == 200) {
        print('✅ EmailJS: Gửi thành công tới $userEmail');
      } else {
        print('❌ EmailJS Lỗi (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('❌ Lỗi kết nối: $e');
    }
  }
}