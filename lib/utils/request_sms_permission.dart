import 'package:permission_handler/permission_handler.dart';

Future<void> requestSmsPermission() async {
  final status = await Permission.sms.status;
  if (!status.isGranted) {
    await Permission.sms.request();
  }
}

