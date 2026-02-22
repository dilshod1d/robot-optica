import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

Future<String?> getDeviceId() async {
  if (!Platform.isAndroid) return null;

  final info = DeviceInfoPlugin();
  final android = await info.androidInfo;

  return android.id; // stable per device
}
