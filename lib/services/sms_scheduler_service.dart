import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../background_tasks.dart';
import '../models/sms_config_model.dart';
import '../services/optica_service.dart';
import '../utils/device_info_utils.dart';

class SmsSchedulerService {
  static const int _dailyAlarmId = 1001;
  static const int _queueAlarmId = 1002;
  final OpticaService _opticaService = OpticaService();

  Future<void> scheduleDailySms({
    required String opticaId,
    required int hour,
    required int minute,
  }) async {
    if (!Platform.isAndroid) return;

    await AndroidAlarmManager.initialize();

    final now = DateTime.now();
    var startAt = DateTime(now.year, now.month, now.day, hour, minute);
    if (startAt.isBefore(now)) {
      startAt = startAt.add(const Duration(days: 1));
    }

    await AndroidAlarmManager.cancel(_dailyAlarmId);
    await AndroidAlarmManager.periodic(
      const Duration(hours: 24),
      _dailyAlarmId,
      executeScheduledSms,
      startAt: startAt,
      allowWhileIdle: true,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: {'opticaId': opticaId, 'task': 'daily'},
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('smsOpticaId', opticaId);
    await prefs.setInt('smsDailyHour', hour);
    await prefs.setInt('smsDailyMinute', minute);

    final localDeviceId = await getDeviceId();
    if (localDeviceId != null) {
      await prefs.setString('smsLocalDeviceId', localDeviceId);
    }
  }

  Future<void> scheduleQueueProcessing({
    required String opticaId,
  }) async {
    if (!Platform.isAndroid) return;

    await AndroidAlarmManager.initialize();
    await AndroidAlarmManager.cancel(_queueAlarmId);
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 15),
      _queueAlarmId,
      executeScheduledSms,
      allowWhileIdle: true,
      exact: false,
      wakeup: true,
      rescheduleOnReboot: true,
      params: {'opticaId': opticaId, 'task': 'queue'},
    );
  }

  Future<void> cancelScheduledSms() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.initialize();
    await AndroidAlarmManager.cancel(_dailyAlarmId);
    await AndroidAlarmManager.cancel(_queueAlarmId);
  }

  Future<void> syncWithOptica(String opticaId) async {
    if (!Platform.isAndroid) return;

    final data = await _opticaService.getOptica(opticaId);
    final config = SmsConfigModel.fromMap(data);
    final localDeviceId = await getDeviceId();
    final activeDeviceId = data['smsEnabledDeviceId'] as String?;

    final isActiveDevice =
        localDeviceId != null && activeDeviceId != null && localDeviceId == activeDeviceId;

    if (!config.isSmsEnabled || !isActiveDevice) {
      await cancelScheduledSms();
      return;
    }

    await scheduleDailySms(
      opticaId: opticaId,
      hour: config.dailyHour,
      minute: config.dailyMinute,
    );
    await scheduleQueueProcessing(opticaId: opticaId);
  }
}
