import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/sms_service.dart';


class SmsTestWidget extends StatefulWidget {
  const SmsTestWidget({super.key});

  @override
  State<SmsTestWidget> createState() => _SmsTestWidgetState();
}

class _SmsTestWidgetState extends State<SmsTestWidget> {
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  String _status = '';

  final SmsService _smsService = SmsService();

  Future<void> _sendSms() async {
    final phone = _buildPhone(_phoneController.text);
    final message = _messageController.text.trim();

    if (phone.isEmpty || message.isEmpty) {
      setState(() => _status = "❗ Enter phone and message");
      return;
    }

    setState(() => _status = "⏳ Sending...");

    try {
      final success = await _smsService.sendSms(
        phone: phone,
        message: message,
        onStatus: (statusMsg) {
          debugPrint("SMS STATUS: $statusMsg");
          setState(() => _status = statusMsg);
        },
      );

      if (!success) {
        setState(() => _status = "❌ Failed to send SMS");
      }
    } catch (e, s) {
      debugPrint("SMS ERROR: $e");
      debugPrintStack(stackTrace: s);
      setState(() => _status = "❌ Error: $e");
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _buildPhone(String local) {
    final digits = local.replaceAll(RegExp(r'\\D'), '');
    if (digits.isEmpty) return '';
    return '+998$digits';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SMS Test")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _phoneInput(),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Message"),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _sendSms,
              child: const Text("Send SMS"),
            ),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _phoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phone Number', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
              child: const Text(
                '+998',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(12),
                    ),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
