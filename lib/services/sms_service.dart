import 'package:telephony/telephony.dart';

class SmsService {
  final Telephony _telephony = Telephony.instance;

  Future<bool> sendSms({
    required String phone,
    required String message,
    required Function(String) onStatus,
  }) async {
    try {
      onStatus("📡 Requesting permission");
      final granted = await _telephony.requestSmsPermissions;
      if (granted != true) {
        onStatus("❌ SMS permission denied");
        return false;
      }
      onStatus("📨 Sending SMS");
      await _telephony.sendSms(
        to: phone,
        message: message,
        isMultipart: true,
        statusListener: (SendStatus status) {
          onStatus("📬 Status: $status");
        },
      );

      onStatus("✅ SMS sent");
      return true;
    } catch (e) {
      onStatus("❌ Error: $e");
      rethrow;
    }
  }
}


