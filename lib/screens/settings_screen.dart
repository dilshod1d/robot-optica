import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/sms_config_model.dart';
import '../screens/settings/loyalty_card_setup_screen.dart';
import '../screens/settings/sms_template_setup_screen.dart';
import '../services/optica_service.dart';
import '../services/sms_scheduler_service.dart';
import '../utils/device_info_utils.dart';
import '../widgets/common/app_loader.dart';
import '../widgets/common/responsive_frame.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _opticaService = OpticaService();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _formattingPhone = false;

  bool _loading = true;

  bool _smsEnabled = false;
  bool _smsForVisits = true;
  bool _smsForPayments = true;
  bool _smsForPrescriptions = true;
  String _smsLanguage = SmsConfigModel.languageCyrillic;

  TimeOfDay _smsTime = const TimeOfDay(hour: 9, minute: 0);

  bool _visitSendOnCreate = true;
  bool _visitSendBefore = true;
  bool _visitSendOnDate = true;

  bool _debtSendOnCreate = false;
  bool _debtSendBefore = false;
  bool _debtSendOnDue = true;
  bool _debtRepeatEnabled = false;

  final _visitDaysBeforeCtrl = TextEditingController();
  final _visitMaxCtrl = TextEditingController();
  final _debtDaysBeforeCtrl = TextEditingController();
  final _debtRepeatDaysCtrl = TextEditingController();
  final _debtMaxCtrl = TextEditingController();

  String? _activeSmsDeviceId;
  String? _localDeviceId;

  @override
  void initState() {
    super.initState();
    _init();
    _phoneCtrl.addListener(_handlePhoneInput);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneCtrl.removeListener(_handlePhoneInput);
    _visitDaysBeforeCtrl.dispose();
    _visitMaxCtrl.dispose();
    _debtDaysBeforeCtrl.dispose();
    _debtRepeatDaysCtrl.dispose();
    _debtMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final opticaId = auth.opticaId;
    if (opticaId == null) return;

    _localDeviceId = await getDeviceId();
    final data = await _opticaService.getOptica(opticaId);

    _nameCtrl.text = data['name'] ?? '';
    _phoneCtrl.text = _extractLocalPhone(data['phone'] ?? '');

    _smsEnabled = data['smsEnabled'] ?? (data['smsEnabledDeviceId'] != null);
    _smsForVisits = data['smsForVisits'] ?? true;
    _smsForPayments = data['smsForPayments'] ?? true;
    _smsForPrescriptions = data['smsForPrescriptions'] ?? true;
    _activeSmsDeviceId = data['smsEnabledDeviceId'];

    final config = SmsConfigModel.fromMap(data);
    _smsTime = TimeOfDay(hour: config.dailyHour, minute: config.dailyMinute);
    _smsLanguage = config.smsLanguage;

    _visitSendOnCreate = config.visitSendOnCreate;
    _visitSendBefore = config.visitSendBefore;
    _visitSendOnDate = config.visitSendOnDate;

    _debtSendOnCreate = config.debtSendOnCreate;
    _debtSendBefore = config.debtSendBefore;
    _debtSendOnDue = config.debtSendOnDueDate;
    _debtRepeatEnabled = config.debtRepeatEnabled;

    _visitDaysBeforeCtrl.text = config.visitDaysBefore.toString();
    _visitMaxCtrl.text = config.visitMaxCount.toString();
    _debtDaysBeforeCtrl.text = config.debtDaysBefore.toString();
    _debtRepeatDaysCtrl.text = config.debtRepeatDays.toString();
    _debtMaxCtrl.text = config.debtMaxCount.toString();

    setState(() => _loading = false);
  }

  // --------------------------------------------------
  // OPTICA EDIT
  // --------------------------------------------------

  void _openEditOpticaSheet(AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Optika-ni tahrirlash',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Optika nomi'),
              ),
              const SizedBox(height: 16),
              _phoneInput(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final phone = _buildPhone(_phoneCtrl.text);
                    if (_nameCtrl.text.trim().isEmpty || phone.isEmpty) {
                      _showError("Barcha maydonlarni to'ldiring");
                      return;
                    }
                    await _opticaService.updateOptica(
                      opticaId: auth.opticaId!,
                      name: _nameCtrl.text.trim(),
                      phone: phone,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Optica yangilandi')),
                    );
                    setState(() {});
                  },
                  child: const Text('Saqlash'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // SMS ACTIONS
  // --------------------------------------------------
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _extractLocalPhone(String phone) {
    return _sanitizeLocalPhone(phone);
  }

  String _buildPhone(String local) {
    final digits = _sanitizeLocalPhone(local);
    if (digits.isEmpty) return '';
    return '+998$digits';
  }

  String _formatPhone(String local) {
    if (local.trim().isEmpty) return '';
    return '+998${_sanitizeLocalPhone(local)}';
  }

  void _handlePhoneInput() {
    if (_formattingPhone) return;
    final sanitized = _sanitizeLocalPhone(_phoneCtrl.text);
    if (sanitized == _phoneCtrl.text) return;
    _formattingPhone = true;
    _phoneCtrl.value = _phoneCtrl.value.copyWith(
      text: sanitized,
      selection: TextSelection.collapsed(offset: sanitized.length),
    );
    _formattingPhone = false;
  }

  String _sanitizeLocalPhone(String input) {
    var digits = input.replaceAll(RegExp(r'\\D'), '');
    while (digits.startsWith('998') && digits.length > 9) {
      digits = digits.substring(3);
    }
    if (digits.length > 9) {
      digits = digits.substring(digits.length - 9);
    }
    return digits;
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    String? helper,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
      ),
    );
  }

  Widget _phoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Telefon raqami', style: TextStyle(color: Colors.grey)),
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
                controller: _phoneCtrl,
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


  Future<void> _toggleSms(bool enable, AuthProvider auth) async {

    if (_localDeviceId == null) {
      _showError('SMS faqat Android qurilmalarda ishlaydi.');
      return;
    }

    try {
      if (enable) {
        await _opticaService.enableSmsForDevice(
          opticaId: auth.opticaId!,
          deviceId: _localDeviceId!,
        );
        setState(() {
          _smsEnabled = true;
          _activeSmsDeviceId = _localDeviceId;
        });
        await SmsSchedulerService().scheduleDailySms(
          opticaId: auth.opticaId!,
          hour: _smsTime.hour,
          minute: _smsTime.minute,
        );
        await SmsSchedulerService().scheduleQueueProcessing(
          opticaId: auth.opticaId!,
        );
      } else {
        await _opticaService.disableSms(auth.opticaId!);
        setState(() {
          _smsEnabled = false;
          _activeSmsDeviceId = null;
        });
        await SmsSchedulerService().cancelScheduledSms();
      }
    } catch (e) {
      _showError(
        enable
            ? "SMSni yoqib bo'lmadi. Qaytadan urinib ko'ring."
            : "SMS oʻchirib boʻlmadi. Qaytadan urinib koʻring.",
      );
    }
  }






  Future<void> _confirmAndTransferSms(AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("SMS ushbu qurilmaga o'tkazilsinmi?"),
        content: const Text(
          "Bu boshqa qurilmada SMS yuborishni darhol to'xtatadi va uni bu qurilmada faollashtiradi.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("O'tkazish"),
          ),
        ],
      ),
    );

    if (confirmed != true || _localDeviceId == null) return;

    await _opticaService.enableSmsForDevice(
      opticaId: auth.opticaId!,
      deviceId: _localDeviceId!,
    );

    setState(() {
      _activeSmsDeviceId = _localDeviceId;
      _smsEnabled = true;
    });

    await SmsSchedulerService().scheduleDailySms(
      opticaId: auth.opticaId!,
      hour: _smsTime.hour,
      minute: _smsTime.minute,
    );
    await SmsSchedulerService().scheduleQueueProcessing(
      opticaId: auth.opticaId!,
    );
  }

  Future<void> _pickSmsTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _smsTime,
    );

    if (picked != null) {
      setState(() => _smsTime = picked);
    }
  }

  int _parseInt(TextEditingController controller, int fallback,
      {int min = 0, int max = 365}) {
    final raw = controller.text.trim();
    final value = int.tryParse(raw) ?? fallback;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  Future<void> _saveSmsRules(AuthProvider auth) async {
    final visitDaysBefore = _parseInt(_visitDaysBeforeCtrl, 1, min: 0, max: 365);
    final visitMax = _parseInt(_visitMaxCtrl, 3, min: 0, max: 100);
    final debtDaysBefore = _parseInt(_debtDaysBeforeCtrl, 1, min: 1, max: 365);
    final debtRepeatDays = _parseInt(_debtRepeatDaysCtrl, 3, min: 1, max: 365);
    final debtMax = _parseInt(_debtMaxCtrl, 3, min: 0, max: 100);

    await _opticaService.updateSmsConfigFields(
      opticaId: auth.opticaId!,
      data: {
        'smsDailyHour': _smsTime.hour,
        'smsDailyMinute': _smsTime.minute,
        'smsVisitOnCreate': _visitSendOnCreate,
        'smsVisitBeforeEnabled': _visitSendBefore,
        'smsVisitDaysBefore': visitDaysBefore,
        'smsVisitOnDate': _visitSendOnDate,
        'smsVisitMaxCount': visitMax,
        'smsDebtOnCreate': _debtSendOnCreate,
        'smsDebtBeforeEnabled': _debtSendBefore,
        'smsDebtDaysBefore': debtDaysBefore,
        'smsDebtOnDueDate': _debtSendOnDue,
        'smsDebtRepeatEnabled': _debtRepeatEnabled,
        'smsDebtRepeatDays': debtRepeatDays,
        'smsDebtMaxCount': debtMax,
        'smsForPrescriptions': _smsForPrescriptions,
        'smsLanguage': _smsLanguage,
      },
    );

    if (_smsEnabled && _localDeviceId == _activeSmsDeviceId) {
      await SmsSchedulerService().scheduleDailySms(
        opticaId: auth.opticaId!,
        hour: _smsTime.hour,
        minute: _smsTime.minute,
      );
      await SmsSchedulerService().scheduleQueueProcessing(
        opticaId: auth.opticaId!,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SMS sozlamalari saqlandi')),
    );
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  Future<void> _confirmLogout(AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Chiqishni tasdiqlaysizmi?"),
        content: const Text("Hisobdan chiqishni xohlaysizmi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Chiqish"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (_loading) {
      return const Scaffold(
        body: AppLoader(),
      );
    }

    final isThisDeviceActive =
        _localDeviceId != null && _localDeviceId == _activeSmsDeviceId;

    String _roleLabel(String? role) {
      if (role == null) return '';

      switch (role) {
        case 'owner':
          return 'Ega';
        case 'admin':
          return 'Administrator';
        case 'staff':
          return 'Xodim';
        default:
          return role;
      }
    }


    return Scaffold(
      appBar: AppBar(title: const Text('Sozlamalar')),
      body: ResponsiveFrame(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
          // ---------------- ACCOUNT ----------------
          const Text('Hisob',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(user?.email ?? ''),
              subtitle: Text('Rol: ${_roleLabel(user?.role)}'),
            ),
          ),

          const SizedBox(height: 24),

          // ---------------- OPTICA ----------------
          const Text('Optika',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(_nameCtrl.text),
              subtitle: Text(_formatPhone(_phoneCtrl.text)),
              trailing: TextButton(
                onPressed: () => _openEditOpticaSheet(auth),
                child: const Text('Tahrirlash'),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ---------------- LOYALTY ----------------
          const Text('Loyalty karta',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.card_membership),
              title: const Text("Loyalty karta sozlamalari"),
              subtitle: const Text("Chegirma foizi, logo, QR va mijoz ulash"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoyaltyCardSetupScreen(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ---------------- SMS ----------------
          const Text('SMS konfiguratsiyasi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('SMSni yoqish'),
                  subtitle: const Text(
                    "Bir vaqtning o'zida faqat bitta Android qurilma SMS yuborishi mumkin",
                  ),
                  value: _smsEnabled,
                  onChanged: (v) => _toggleSms(v, auth),
                ),

                const Divider(),

                ListTile(
                  leading: const Icon(Icons.phone_android),
                  title: const Text('Faol SMS qurilmasi'),
                  subtitle: Text(
                    !_smsEnabled
                        ? "SMS o'chirilgan"
                        : isThisDeviceActive
                        ? 'Ushbu qurilma'
                        : 'Boshqa qurilma',
                  ),
                  trailing: (!_smsEnabled || isThisDeviceActive)
                      ? const Chip(
                    label: Text('Faol'),
                  )
                      : OutlinedButton(
                    onPressed: () => _confirmAndTransferSms(auth),
                    child: const Text("Ushbu qurilmaga o'tkazish"),
                  ),
                ),

                if (_smsEnabled) const Divider(),

                if (_smsEnabled)
                  SwitchListTile(
                    title: const Text('Tashriflar uchun SMS'),
                    value: _smsForVisits,
                    onChanged: (v) {
                      setState(() => _smsForVisits = v);
                      _opticaService.updateSmsSettings(
                        opticaId: auth.opticaId!,
                        visits: v,
                      );
                    },
                  ),

                if (_smsEnabled)
                  SwitchListTile(
                    title: const Text("To'lovlar uchun SMS"),
                    value: _smsForPayments,
                    onChanged: (v) {
                      setState(() => _smsForPayments = v);
                      _opticaService.updateSmsSettings(
                        opticaId: auth.opticaId!,
                        payments: v,
                      );
                    },
                  ),

                if (_smsEnabled)
                  SwitchListTile(
                    title: const Text("Retseptlar uchun SMS"),
                    value: _smsForPrescriptions,
                    onChanged: (v) {
                      setState(() => _smsForPrescriptions = v);
                      _opticaService.updateSmsConfigFields(
                        opticaId: auth.opticaId!,
                        data: {'smsForPrescriptions': v},
                      );
                    },
                  ),

                if (_smsEnabled) const Divider(),

                if (_smsEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SMS tili',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Lotin'),
                              selected: _smsLanguage ==
                                  SmsConfigModel.languageLatin,
                              onSelected: (selected) {
                                if (!selected) return;
                                setState(() => _smsLanguage =
                                    SmsConfigModel.languageLatin);
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Кирилл'),
                              selected: _smsLanguage ==
                                  SmsConfigModel.languageCyrillic,
                              onSelected: (selected) {
                                if (!selected) return;
                                setState(() => _smsLanguage =
                                    SmsConfigModel.languageCyrillic);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'SMS matni tanlangan alifboda yuboriladi',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                if (_smsEnabled) const Divider(),

                if (_smsEnabled)
                  ListTile(
                    leading: const Icon(Icons.message_outlined),
                    title: const Text("SMS shablonlari"),
                    subtitle: const Text("Har bir SMS matnini sozlang"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (auth.opticaId == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SmsTemplateSetupScreen(
                            opticaId: auth.opticaId!,
                          ),
                        ),
                      );
                    },
                  ),

                if (_smsEnabled) const Divider(),

                if (_smsEnabled)
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('SMS yuborish vaqti'),
                    subtitle: Text(_smsTime.format(context)),
                    trailing: TextButton(
                      onPressed: _pickSmsTime,
                      child: const Text('O‘zgartirish'),
                    ),
                  ),

                if (_smsEnabled) const Divider(),

                if (_smsEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tashrif SMS qoidalari',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text("Yaratilganda yuborish"),
                          value: _visitSendOnCreate,
                          onChanged: (v) => setState(() => _visitSendOnCreate = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text("Necha kun oldin yuborish"),
                          value: _visitSendBefore,
                          onChanged: (v) => setState(() => _visitSendBefore = v),
                        ),
                        _numberField(
                          label: "Kunlar (oldin)",
                          controller: _visitDaysBeforeCtrl,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text("Tashrif kuni yuborish"),
                          value: _visitSendOnDate,
                          onChanged: (v) => setState(() => _visitSendOnDate = v),
                        ),
                        const SizedBox(height: 8),
                        _numberField(
                          label: "Maksimal SMS soni (tashrif)",
                          controller: _visitMaxCtrl,
                        ),
                      ],
                    ),
                  ),

                if (_smsEnabled) const Divider(),

                if (_smsEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Qarz SMS qoidalari",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text("Yaratilganda yuborish"),
                          value: _debtSendOnCreate,
                          onChanged: (v) =>
                              setState(() => _debtSendOnCreate = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text("Muddatdan oldin yuborish"),
                          value: _debtSendBefore,
                          onChanged: (v) =>
                              setState(() => _debtSendBefore = v),
                        ),
                        _numberField(
                          label: "Kunlar (oldin)",
                          controller: _debtDaysBeforeCtrl,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text("Muddatida yuborish"),
                          value: _debtSendOnDue,
                          onChanged: (v) => setState(() => _debtSendOnDue = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text("Kechikkanidan so‘ng takror yuborish"),
                          value: _debtRepeatEnabled,
                          onChanged: (v) =>
                              setState(() => _debtRepeatEnabled = v),
                        ),
                        _numberField(
                          label: "Takror oralig‘i (kun)",
                          controller: _debtRepeatDaysCtrl,
                        ),
                        const SizedBox(height: 8),
                        _numberField(
                          label: "Maksimal SMS soni (qarz)",
                          controller: _debtMaxCtrl,
                        ),
                      ],
                    ),
                  ),

                if (_smsEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _saveSmsRules(auth),
                        child: const Text("SMS sozlamalarini saqlash"),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ---------------- LOGOUT ----------------
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Hisobdan chiqish",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text("Joriy sessiyani yakunlash"),
              onTap: () => _confirmLogout(auth),
            ),
          ),

          const SizedBox(height: 16),
        ],
        ),
      ),
    );
  }
}
