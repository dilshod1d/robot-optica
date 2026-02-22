import 'package:flutter/material.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';

class AuthForm extends StatefulWidget {
  final Future<String?> Function(String email, String password) onSubmit;
  final String? initialEmail;
  final bool rememberMe;
  final ValueChanged<bool>? onRememberChanged;
  final String? errorText;

  const AuthForm({
    super.key,
    required this.onSubmit,
    this.initialEmail,
    this.rememberMe = false,
    this.onRememberChanged,
    this.errorText,
  });

  @override
  _AuthFormState createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFocus = FocusNode();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _showPassword = false;

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      await widget.onSubmit(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? '';
  }

  @override
  void didUpdateWidget(covariant AuthForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldInitial = oldWidget.initialEmail ?? '';
    final newInitial = widget.initialEmail ?? '';
    if (oldInitial != newInitial &&
        _emailController.text.trim() == oldInitial.trim()) {
      _emailController.text = newInitial;
    }
  }

  @override
  void dispose() {
    _passwordFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Kirish",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Profilingizga kirish uchun email va parolingizni kiriting.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            if (widget.errorText != null && widget.errorText!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.errorText!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('email'),
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email manzil',
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_passwordFocus),
              validator: (val) => val != null && val.contains('@')
                  ? null
                  : 'Email manzilingiz noto‘g‘ri',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('password'),
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Parol',
                prefixIcon: const Icon(Icons.lock_outline),
                filled: true,
                fillColor: Colors.grey.shade50,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              obscureText: !_showPassword,
              focusNode: _passwordFocus,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _isSubmitting ? null : _submit(),
              validator: (val) => val != null && val.length >= 6
                  ? null
                  : 'Parol kamida 6 ta belgidan iborat bo‘lishi kerak',
            ),
            const SizedBox(height: 12),
            if (widget.onRememberChanged != null)
              Row(
                children: [
                  Checkbox(
                    value: widget.rememberMe,
                    onChanged: _isSubmitting
                        ? null
                        : (value) =>
                            widget.onRememberChanged?.call(value ?? false),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Yodda saqlash",
                    style: TextStyle(fontSize: 13.5),
                  ),
                ],
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: AppLoader(
                          size: 18,
                          fill: false,
                        ),
                      )
                    : const Icon(Icons.login),
                label: Text(_isSubmitting ? 'Kirish...' : 'Kirish'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
