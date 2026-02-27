import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/customer_model.dart';
import '../../models/sms_config_model.dart';
import '../../models/sms_log_model.dart';
import '../../optica_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/customer_service.dart';
import '../../services/optica_service.dart';
import '../../services/sms_log_service.dart';
import '../../services/sms_service.dart';
import '../../utils/device_info_utils.dart';
import '../../utils/sms_delay_jitter.dart';
import '../../utils/sms_sanitizer.dart';
import '../../utils/sms_types.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/responsive_frame.dart';

class MarketingSmsScreen extends StatefulWidget {
  const MarketingSmsScreen({super.key});

  @override
  State<MarketingSmsScreen> createState() => _MarketingSmsScreenState();
}

class _MarketingSmsScreenState extends State<MarketingSmsScreen> {
  final TextEditingController _messageController = TextEditingController();
  final CustomerService _customerService = CustomerService();
  final SmsService _smsService = SmsService();
  final SmsLogService _smsLogService = SmsLogService();
  final OpticaService _opticaService = OpticaService();
  final Uuid _uuid = const Uuid();

  bool _loadingRecipients = false;
  int _totalCustomers = 0;
  int _eligibleCustomers = 0;
  int _noPhoneCustomers = 0;
  int _optOutCustomers = 0;

  bool _sending = false;
  bool _cancelRequested = false;
  int _processed = 0;
  int _success = 0;
  int _failed = 0;
  int _skipped = 0;
  String? _currentName;

  @override
  Widget build(BuildContext context) {
    final opticaId = context.watch<AuthProvider>().opticaId;
    if (opticaId == null) {
      return const Scaffold(body: AppLoader());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Marketing SMS"),
        actions: [
          IconButton(
            onPressed: _sending ? null : _refreshRecipients,
            icon: const Icon(Icons.refresh),
            tooltip: "Yangilash",
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveFrame(
          maxWidth: 1100,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              _infoBanner(),
              const SizedBox(height: 16),

              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Xabar"),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      maxLines: 6,
                      enabled: !_sending,
                      decoration: InputDecoration(
                        hintText: "Marketing xabaringizni shu yerga yozing...",
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Qabul qiluvchilar"),
                    const SizedBox(height: 10),
                    if (_loadingRecipients)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: AppLoader(size: 28, fill: false),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _statTile(
                                  label: "Jami mijoz",
                                  value: _totalCustomers.toString(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _statTile(
                                  label: "SMS ruxsatli",
                                  value: _eligibleCustomers.toString(),
                                  valueColor: OpticaColors.visited,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _statTile(
                                  label: "Telefon yo'q",
                                  value: _noPhoneCustomers.toString(),
                                  valueColor: OpticaColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _statTile(
                                  label: "SMS o‘chirilgan",
                                  value: _optOutCustomers.toString(),
                                  valueColor: OpticaColors.missed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (_sending) _progressCard(),

              const SizedBox(height: 8),

              _sectionTitle("Harakatlar"),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _sending ? "Yuborilmoqda..." : "Barcha mijozlarga yuborish",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _canSend() ? _confirmSend : null,
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshRecipients();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool _canSend() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return false;
    if (_sending || _loadingRecipients) return false;
    return _eligibleCustomers > 0;
  }

  Future<void> _previewMessage() async {
    final opticaId = context.read<AuthProvider>().opticaId;
    if (opticaId == null) return;

    SmsConfigModel? config;
    try {
      config = await _opticaService.getSmsConfig(opticaId);
    } catch (_) {
      config = null;
    }

    final text = _buildFinalMessage(config: config);
    if (text.trim().isEmpty) return;
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Oldindan ko'rish"),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Yopish"),
          ),
        ],
      ),
    );
  }

  void _confirmSend() {
    final text = _buildFinalMessage();
    if (text.trim().isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yuborishni tasdiqlash"),
        content: Text(
          "Bu xabarni $_eligibleCustomers mijozga yuboradi. Ishonchingiz komilmi?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendMessage();
            },
            child: const Text("Yuborish"),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final baseText = _messageController.text.trim();
    if (baseText.isEmpty) return;

    final opticaId = context.read<AuthProvider>().opticaId;
    if (opticaId == null) return;

    if (!Platform.isAndroid) {
      _showSnack("SMS faqat Android qurilmada yuboriladi.");
      return;
    }

    setState(() {
      _sending = true;
      _cancelRequested = false;
      _processed = 0;
      _success = 0;
      _failed = 0;
      _skipped = 0;
      _currentName = null;
    });

    try {
      final config = await _opticaService.getSmsConfig(opticaId);
      final localDeviceId = await getDeviceId();
      if (!config.isSmsEnabled) {
        _showSnack("SMS sozlamalari o‘chirilgan.");
        return;
      }
      if (config.smsEnabledDeviceId == null) {
        _showSnack("SMS uchun faol qurilma tanlanmagan.");
        return;
      }
      if (localDeviceId == null || localDeviceId != config.smsEnabledDeviceId) {
        _showSnack("SMS boshqa qurilmada yoqilgan. Sozlamalarni tekshiring.");
        return;
      }

      final customers = await _customerService.fetchAllCustomers(
        opticaId: opticaId,
      );

      final recipients = customers.where((c) {
        final phone = c.phone.trim();
        return phone.isNotEmpty && _isCustomerSmsEnabled(c);
      }).toList();

      final noPhone = customers.where((c) => c.phone.trim().isEmpty).length;
      final optOut = customers
          .where((c) => c.phone.trim().isNotEmpty && !_isCustomerSmsEnabled(c))
          .length;

      setState(() {
        _totalCustomers = customers.length;
        _eligibleCustomers = recipients.length;
        _noPhoneCustomers = noPhone;
        _optOutCustomers = optOut;
      });

      if (recipients.isEmpty) {
        _showSnack("Yuborish uchun mijoz topilmadi.");
        return;
      }

      final message = _buildFinalMessage(config: config);
      if (message.trim().isEmpty) {
        _showSnack("Xabar matni bo‘sh yoki yaroqsiz.");
        return;
      }

      for (final customer in recipients) {
        if (_cancelRequested) break;

        final phone = customer.phone.trim();
        if (phone.isEmpty) {
          _skipped += 1;
          _processed += 1;
          if (mounted) setState(() {});
          continue;
        }

        if (mounted) {
          setState(() {
            _currentName = _displayName(customer);
          });
        }

        bool success = false;
        try {
          success = await _smsService.sendSms(
            phone: phone,
            message: message,
            onStatus: (_) {},
          );
        } catch (_) {
          success = false;
        }

        if (success) {
          _success += 1;
          final log = SmsLogModel(
            id: _uuid.v4(),
            customerId: customer.id,
            phone: phone,
            debtId: null,
            visitId: null,
            prescriptionId: null,
            message: message,
            type: SmsLogTypes.marketing,
            sentAt: DateTime.now(),
          );
          try {
            await _smsLogService.logSms(opticaId: opticaId, log: log);
          } catch (_) {}
        } else {
          _failed += 1;
        }

        _processed += 1;
        if (mounted) setState(() {});
        await Future.delayed(smsDelayWithJitter());
      }

      if (_cancelRequested) {
        _showSnack("Yuborish to‘xtatildi.");
      } else {
        _showSnack(
          "Yuborish tugadi. Muvaffaqiyatli: $_success, Xatolik: $_failed.",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _cancelRequested = false;
          _currentName = null;
        });
      }
    }
  }

  Future<void> _refreshRecipients() async {
    final opticaId = context.read<AuthProvider>().opticaId;
    if (opticaId == null) return;
    if (_loadingRecipients) return;

    setState(() => _loadingRecipients = true);
    try {
      final customers = await _customerService.fetchAllCustomers(
        opticaId: opticaId,
      );
      final total = customers.length;
      final noPhone = customers.where((c) => c.phone.trim().isEmpty).length;
      final optOut = customers
          .where((c) => c.phone.trim().isNotEmpty && !_isCustomerSmsEnabled(c))
          .length;
      final eligible = customers.where((c) {
        final phone = c.phone.trim();
        return phone.isNotEmpty && _isCustomerSmsEnabled(c);
      }).length;

      if (!mounted) return;
      setState(() {
        _totalCustomers = total;
        _noPhoneCustomers = noPhone;
        _optOutCustomers = optOut;
        _eligibleCustomers = eligible;
      });
    } finally {
      if (mounted) setState(() => _loadingRecipients = false);
    }
  }

  bool _isCustomerSmsEnabled(CustomerModel customer) {
    return customer.visitsSmsEnabled || customer.debtsSmsEnabled;
  }

  String _buildFinalMessage({SmsConfigModel? config}) {
    final base = _messageController.text.trim();
    if (base.isEmpty) return "";
    final allowUnicode = config?.isSmsCyrillic ?? true;
    return smsSanitize(base, allowUnicode: allowUnicode);
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blueGrey.shade600),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "SMS faqat faol qurilmadan yuboriladi. "
              "Xabarlar orasida tasodifiy 5–10 soniya kechikish bo‘ladi.",
              style: TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: OpticaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor ?? OpticaColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard() {
    final total = _eligibleCustomers;
    final progress = total == 0 ? 0.0 : _processed / total;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Jarayon"),
          const SizedBox(height: 8),
          Text(
            "Yuborilmoqda: $_processed / $total",
            style: const TextStyle(color: OpticaColors.textSecondary),
          ),
          if (_currentName != null) ...[
            const SizedBox(height: 6),
            Text(
              "Hozir: $_currentName",
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(OpticaColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  label: "Muvaffaqiyatli",
                  value: _success.toString(),
                  valueColor: OpticaColors.visited,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statTile(
                  label: "Xatolik",
                  value: _failed.toString(),
                  valueColor: OpticaColors.missed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  label: "O‘tkazib yuborildi",
                  value: _skipped.toString(),
                  valueColor: OpticaColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: OutlinedButton.icon(
                    onPressed: _cancelRequested
                        ? null
                        : () => setState(() => _cancelRequested = true),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text("To‘xtatish"),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _displayName(CustomerModel customer) {
    final full = "${customer.firstName} ${customer.lastName ?? ""}".trim();
    return full.isEmpty ? customer.phone : full;
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
