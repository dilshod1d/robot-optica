import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robot_optica/utils/check_online.dart';
import 'firebase_options.dart';
import 'services/scheduler_service.dart';


@pragma('vm:entry-point')
Future<void> executeScheduledSms(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final opticaId = params["opticaId"] as String? ?? prefs.getString('smsOpticaId');
  final task = params["task"] as String? ?? 'daily';

  if (opticaId == null) {
    print("No opticaId passed to background task");
    return;
  }

  final isOnline = await checkOnline();
  print('isOnline $isOnline');

  if (!isOnline) {
    print('Device offline, will retry later.');
    return;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final scheduler = SchedulerService(opticaId: opticaId);
  if (task == 'queue') {
    await scheduler.runQueueJob();
  } else {
    await scheduler.runDailySmsJob();
  }

  print('running jobs for opticaId: $opticaId');
}



//
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/widgets.dart';
// import 'package:robot_optica/utils/check_online.dart';
// import 'firebase_options.dart';
// import 'services/scheduler_service.dart';
//
// @pragma('vm:entry-point')
// Future<void> executeScheduledSms(String opticaId) async {
//   WidgetsFlutterBinding.ensureInitialized();
//   final isOnline = await checkOnline();
//   print('isOnline $isOnline');
//   if (!isOnline) {
//     print('Device offline, will retry later.');
//     return;  // Exit early if no internet
//   }
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//   final scheduler = SchedulerService(opticaId: opticaId);
//   await scheduler.runDailySmsJob();
//   print('running jobs for opticaId: $opticaId');
// }
