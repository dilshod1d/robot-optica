import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:telephony/telephony.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robot_optica/providers/auth_provider.dart';
import 'package:robot_optica/providers/customer_provider.dart';
import 'package:robot_optica/providers/sms_provider.dart';
import 'package:robot_optica/providers/visit_provider.dart';
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
    print('trying to ru job');
    await telephony.requestPhoneAndSmsPermissions;
    await AndroidAlarmManager.initialize();
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
