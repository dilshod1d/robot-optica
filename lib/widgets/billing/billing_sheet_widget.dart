import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import 'package:robot_optica/widgets/common/responsive_frame.dart';
import '../../models/billing_model.dart';
import '../../models/customer_model.dart';
import '../../services/billing_service.dart';


enum BillingStatusUI { unpaid, partial, paid }

class BillingSheet extends StatefulWidget {
  final String opticaId;
  final CustomerModel customer;

  const BillingSheet({
    super.key,
    required this.opticaId,
    required this.customer,
  });

  @override
  State<BillingSheet> createState() => _BillingSheetState();
}

class _BillingSheetState extends State<BillingSheet> {
  final totalController = TextEditingController();
  final paidController = TextEditingController();
  final forController = TextEditingController();
  final service = BillingFirebaseService();

  String paymentMethod = "Cash";
  BillingStatusUI status = BillingStatusUI.unpaid;

  bool _userEditedPaid = false;
  bool _isAutoUpdatingPaid = false;
  bool _saved = false;
  bool _loading = false;

  double _total = 0;
  double _paid = 0;
  DateTime? _dueDate;


  BillingModel? _createdBilling;

  @override
  void initState() {
    super.initState();
    totalController.addListener(_onTotalChanged);
    paidController.addListener(_onPaidChanged);
  }

  void _onTotalChanged() {
    if (!_userEditedPaid) {
      _isAutoUpdatingPaid = true;
      paidController.text = totalController.text;
      paidController.selection = TextSelection.fromPosition(
        TextPosition(offset: paidController.text.length),
      );
      _isAutoUpdatingPaid = false;
    }
    _recalculate();
  }

  void _onPaidChanged() {
    if (_isAutoUpdatingPaid) return;
    _userEditedPaid = true;
    _recalculate();
  }

  void _recalculate() {
    final total = double.tryParse(totalController.text) ?? 0;
    final paid = double.tryParse(paidController.text) ?? 0;

    if (paid <= 0) {
      status = BillingStatusUI.unpaid;
    } else if (paid < total) {
      status = BillingStatusUI.partial;
    } else {
      status = BillingStatusUI.paid;
    }

    if (paid > total) {
      _isAutoUpdatingPaid = true;
      paidController.text = totalController.text;
      paidController.selection = TextSelection.fromPosition(
        TextPosition(offset: paidController.text.length),
      );
      _isAutoUpdatingPaid = false;
    }

    setState(() {});
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Widget _dueDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("To'lov muddati", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDueDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 10),
                Text(
                  _dueDate == null
                      ? "Sana tanlang"
                      : "${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}",
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(totalController.text) ?? 0;
    final paid = double.tryParse(paidController.text) ?? 0;
    final remaining = total > paid ? total - paid : 0.0;

    return SheetFrame(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _saved ? _successView(remaining) : _formView(remaining),
      ),
    );
  }

  Widget _formView(double remaining) {
    return Column(
      key: const ValueKey("form"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header("Hisob-kitob"),
        const SizedBox(height: 20),

        _input("Jami summa", totalController, TextInputType.number),
        const SizedBox(height: 12),

        _input("To'langan summa", paidController, TextInputType.number),
        const SizedBox(height: 12),

        _statusRow(remaining),
        const SizedBox(height: 12),
        if (status != BillingStatusUI.paid) ...[
          const SizedBox(height: 12),
          _dueDatePicker(),
        ],


        _input("Nima uchun? (ixtiyoriy)", forController, TextInputType.text),
        const SizedBox(height: 16),

        if ((double.tryParse(paidController.text) ?? 0) > 0)
          _paymentMethodSelector(),

        const SizedBox(height: 24),
        _saveButton(),
      ],
    );
  }

  Widget _successView(double remaining) {
    return Column(
      key: const ValueKey("success"),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 72, color: Colors.green),
        const SizedBox(height: 12),
        const Text(
          "Invoys tayyor",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        _row("Jami", _total.toStringAsFixed(2)),
        _row("To'langan", _paid.toStringAsFixed(2)),
        _row("Qolgan", remaining.toStringAsFixed(2)),
        _row("Holati", status.name.toUpperCase()),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _createdBilling),
            child: const Text("Yaxshi"),
          ),
        )
      ],
    );
  }

  Widget _header(String title) {
    return Row(
      children: [
        const Icon(Icons.receipt_long),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _statusRow(double remaining) {
    Color color;
    String label;

    switch (status) {
      case BillingStatusUI.unpaid:
        color = Colors.red;
        label = "To'lanmagan";
        break;
      case BillingStatusUI.partial:
        color = Colors.orange;
        label = "Qisman to'langan";
        break;
      case BillingStatusUI.paid:
        color = Colors.green;
        label = "To'langan";
        break;
    }

    return Row(
      children: [
        Chip(
          label: Text(label),
          backgroundColor: color.withOpacity(0.1),
          labelStyle: TextStyle(color: color),
        ),
        const Spacer(),
        if (status != BillingStatusUI.paid)
          Text(
            "Qolgan: $remaining",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
      ],
    );
  }

  Widget _input(String label, TextEditingController controller, TextInputType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: type,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  static const _paymentMethods = [
    {'value': 'Cash', 'label': 'Naqd'},
    {'value': 'Terminal', 'label': 'Terminal'},
    {'value': 'Transfer', 'label': "Pul ko'chirish"},
  ];

  String _paymentMethodLabel(String value) {
    for (final method in _paymentMethods) {
      if (method['value'] == value) {
        return method['label']!;
      }
    }
    return value;
  }

  Widget _paymentMethodSelector() {
    final methods = _paymentMethods;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("To'lov usuli", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: methods.map((method) {
            final value = method['value']!;
            final label = method['label']!;
            final isActive = paymentMethod == value;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: isActive,
                onSelected: (_) => setState(() => paymentMethod = value),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _save,
        child: _loading
            ? const AppLoader(
                size: 20,
                fill: false,
              )
            : const Text("Saqlash"),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final total = double.tryParse(totalController.text) ?? 0;
    final paid = double.tryParse(paidController.text) ?? 0;

    if (total <= 0) return;

    setState(() => _loading = true);

    final now = Timestamp.now();
    final due = _dueDate != null ? Timestamp.fromDate(_dueDate!) : now;
    final billingId = FirebaseFirestore.instance.collection("x").doc().id;

    final fullName = [
      widget.customer.firstName,
      widget.customer.lastName,
    ].where((e) => e != null && e.trim().isNotEmpty).join(' ');


    final billing = BillingModel(
      id: billingId,
      opticaId: widget.opticaId,
      customerId: widget.customer.id,
      customerName: fullName,
      amountDue: total,
      amountPaid: 0,
      dueDate: due,
      createdAt: now,
      updatedAt: now,
      reminderSentCount: 0,
    );

    await service.createBilling(
      opticaId: widget.opticaId,
      billing: billing,
      initialPaidAmount: paid,
    );

    if (paid > 0) {
      await service.applyPayment(
        opticaId: widget.opticaId,
        billing: billing,
        amount: paid,
        note:
            "Dastlabki to'lov • ${_paymentMethodLabel(paymentMethod)} • ${forController.text}",
      );

      final remainingAfter = total - paid;
      if (remainingAfter > 0) {
        final updatedBilling = billing.copyWith(
          amountPaid: paid,
          updatedAt: Timestamp.now(),
        );
        await service.queueDebtSmsOnCreate(
          opticaId: widget.opticaId,
          billing: updatedBilling,
        );
      }
    }

    _total = total;
    _paid = paid;
    _createdBilling = billing;

    setState(() {
      _loading = false;
      _saved = true;
    });
  }
}
