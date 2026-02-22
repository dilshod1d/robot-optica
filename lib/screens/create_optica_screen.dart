import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/common/app_loader.dart';

class CreateOpticaScreen extends StatefulWidget {
  const CreateOpticaScreen({super.key});

  @override
  State<CreateOpticaScreen> createState() => _CreateOpticaScreenState();
}

class _CreateOpticaScreenState extends State<CreateOpticaScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  String _buildPhone(String local) {
    final digits = local.replaceAll(RegExp(r'\\D'), '');
    if (digits.isEmpty) return '';
    return '+998$digits';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Optika qo'shing"),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Davom etish uchun siz optika yaratishingiz kerak',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Optika nomi'),
              ),
              _phoneInput(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          final phone = _buildPhone(_phone.text);
                          if (_name.text.isEmpty || phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Barcha maydonlarni to'ldiring"),
                              ),
                            );
                            return;
                          }

                          await auth.createOptica(
                            name: _name.text.trim(),
                            phone: phone,
                          );
                        },
                  child: auth.isLoading
                      ? const AppLoader(
                          size: 20,
                          fill: false,
                        )
                      : const Text("Optika qo'shish"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Telefon', style: TextStyle(color: Colors.grey)),
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
                controller: _phone,
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
