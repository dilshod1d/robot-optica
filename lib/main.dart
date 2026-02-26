import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:telephony/telephony.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robot_optica/providers/auth_provider.dart';
import 'package:robot_optica/providers/customer_provider.dart';
import 'package:robot_optica/providers/sms_provider.dart';
import 'package:robot_optica/providers/visit_provider.dart';
import 'package:robot_optica/services/optica_service.dart';
import 'package:robot_optica/utils/device_info_utils.dart';
import 'package:robot_optica/widgets/auth_gate.dart';
import 'app_theme.dart';
import 'firebase_options.dart';

final telephony = Telephony.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (Platform.isAndroid) {
    try {
      final firebaseUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        final opticaId = userDoc.data()?['activeOpticaId'] as String?;
        final localDeviceId = await getDeviceId();
        if (opticaId != null && localDeviceId != null) {
          final optica = await OpticaService().getOpticaById(opticaId);
          if (optica?.smsEnabledDeviceId == localDeviceId) {
            await telephony.requestPhoneAndSmsPermissions;
            await AndroidAlarmManager.initialize();
          }
        }
      }
    } catch (_) {
      // Ignore startup SMS setup failures
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, CustomerProvider?>(
          create: (_) => null,
          update: (_, auth, previous) {
            final opticaId = auth.user?.activeOpticaId;

            if (opticaId == null) return null;

            return CustomerProvider(opticaId: opticaId);
          },
        ),
        ChangeNotifierProvider(create: (_) => VisitProvider()),
        ChangeNotifierProvider(create: (_) => SmsProvider()),
      ],
      child: MaterialApp(
        title: 'Robot Optica',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: const AuthGate(),
      ),
    );
  }
}
