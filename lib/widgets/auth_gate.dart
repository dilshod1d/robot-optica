import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robot_optica/providers/auth_provider.dart';
import 'package:robot_optica/screens/dashboard_screen.dart';
import 'package:robot_optica/screens/create_optica_screen.dart';
import 'package:robot_optica/screens/signin_screen.dart';
import 'common/app_loader.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // 1. Still initializing auth
    if (auth.isLoading) {
      return Scaffold(
        body: const AppLoader()
      );
    }

    // 2. Not authenticated
    if (auth.user == null) {
       return const SignInScreen();
    }

    // 3. Authenticated but no optica → FORCE creation
    if (auth.needsOpticaCreation) {
      return const CreateOpticaScreen();
    }

    // 4. Fully ready
    return const  DashboardScreen();
  }
}




