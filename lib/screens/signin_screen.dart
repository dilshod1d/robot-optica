import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../optica_theme.dart';
import '../widgets/auth_form.dart';
import '../widgets/common/app_loader.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const _rememberKey = 'authRememberMe';
  static const _rememberEmailKey = 'authRememberEmail';

  bool _loadingPrefs = true;
  bool _rememberMe = false;
  String _initialEmail = '';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberKey) ?? false;
    final email = prefs.getString(_rememberEmailKey) ?? '';
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      _initialEmail = remember ? email : '';
      _loadingPrefs = false;
    });
  }

  Future<String?> _submit(String email, String password) async {
    setState(() => _errorText = null);

    final error = await Provider.of<AuthProvider>(context, listen: false)
        .signIn(email, password);

    if (!mounted) return error;

    if (error != null) {
      setState(() => _errorText = _friendlyError(error));
      return error;
    }

    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool(_rememberKey, true);
      await prefs.setString(_rememberEmailKey, email);
    } else {
      await prefs.setBool(_rememberKey, false);
      await prefs.remove(_rememberEmailKey);
    }

    return null;
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('user-not-found')) {
      return "Bunday foydalanuvchi topilmadi.";
    }
    if (lower.contains('wrong-password')) {
      return "Parol noto‘g‘ri.";
    }
    if (lower.contains('invalid-email')) {
      return "Email manzili noto‘g‘ri.";
    }
    if (lower.contains('network-request-failed')) {
      return "Internetga ulanishda xatolik. Qayta urinib ko‘ring.";
    }
    if (lower.contains('too-many-requests')) {
      return "Ko‘p urinishlar. Birozdan so‘ng qayta urinib ko‘ring.";
    }
    if (lower.contains('user-disabled')) {
      return "Bu foydalanuvchi bloklangan.";
    }
    return "Kirishda xatolik yuz berdi. Qayta urinib ko‘ring.";
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPrefs) {
      return const Scaffold(body: Center(child: AppLoader()));
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF1F8FF),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: OpticaColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -20,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        _brandHeader(),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: AuthForm(
                            onSubmit: _submit,
                            initialEmail: _initialEmail,
                            rememberMe: _rememberMe,
                            onRememberChanged: (value) =>
                                setState(() => _rememberMe = value),
                            errorText: _errorText,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          "Optika boshqaruvi uchun yagona kirish",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brandHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: OpticaColors.primary.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.remove_red_eye_outlined,
            color: OpticaColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Robot Optica",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Kirish oynasi",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}
