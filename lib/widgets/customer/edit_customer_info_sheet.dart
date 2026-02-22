import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';

import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';

class EditCustomerInfoSheet extends StatefulWidget {
  final CustomerModel? customer;
  final bool isEdit;

  const EditCustomerInfoSheet({
    super.key,
    this.customer,
    this.isEdit = false,
  });

  @override
  State<EditCustomerInfoSheet> createState() => _EditCustomerInfoSheetState();
}

class _EditCustomerInfoSheetState extends State<EditCustomerInfoSheet> {
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController phoneController;

  late bool _visitsSms;
  late bool _debtsSms;

  bool _saved = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    firstNameController =
        TextEditingController(text: widget.customer?.firstName ?? "");
    lastNameController =
        TextEditingController(text: widget.customer?.lastName ?? "");
    phoneController = TextEditingController(
      text: _extractLocalPhone(widget.customer?.phone ?? ""),
    );

    _visitsSms = widget.customer?.visitsSmsEnabled ?? true;
    _debtsSms = widget.customer?.debtsSmsEnabled ?? true;
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  String _extractLocalPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\\D'), '');
    if (digits.startsWith('998')) {
      return digits.substring(3);
    }
    return digits;
  }

  String _buildPhone(String local) {
    final digits = local.replaceAll(RegExp(r'\\D'), '');
    if (digits.isEmpty) return '';
    return '+998$digits';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 20,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _saved ? _successView() : _formView(),
      ),
    );
  }

  // ================= FORM =================

  Widget _formView() {
    return Column(
      key: const ValueKey("form"),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 20),

        _input("Ism", firstNameController, TextInputType.name),
        const SizedBox(height: 12),
        _input("Familya (ixtiyoriy)", lastNameController, TextInputType.name),
        const SizedBox(height: 12),

        _phoneInput(),
        const SizedBox(height: 20),

        const Divider(),
        const SizedBox(height: 8),

        _switchRow(
          label: "Tashrif uchun sms",
          value: _visitsSms,
          onChanged: (v) => setState(() => _visitsSms = v),
        ),

        _switchRow(
          label: "Qarz uchun sms",
          value: _debtsSms,
          onChanged: (v) => setState(() => _debtsSms = v),
        ),

        const SizedBox(height: 24),
        _saveButton(),
      ],
    );
  }

  // ================= SUCCESS =================

  Widget _successView() {
    return Column(
      key: const ValueKey("success"),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 72),
        const SizedBox(height: 12),
        Text(
          widget.isEdit ? "Xaridor yangilandi" : "Xaridoq qo'shildi",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Yaxshi"),
          ),
        ),
      ],
    );
  }

  // ================= UI PARTS =================

  Widget _header() {
    return Row(
      children: [
        Icon(widget.isEdit ? Icons.edit : Icons.person_add),
        const SizedBox(width: 8),
        Text(
          widget.isEdit ? "Xaridorni tahirlash" : "Yangi xaridor qo'shish",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _input(
      String label,
      TextEditingController controller,
      TextInputType type,
      ) {
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

  Widget _phoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Telefon", style: TextStyle(color: Colors.grey)),
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
                controller: phoneController,
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

  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _save,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _loading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: AppLoader(
            size: 20,
            fill: false,
          ),
        )
            : Text(widget.isEdit ? "O'zgarishlarni saqlash" : "Xaridor qo'shish"),
      ),
    );
  }

  // ================= LOGIC =================

  Future<void> _save() async {
    if (_loading) return;

    final firstName = firstNameController.text.trim();
    final lastNameRaw = lastNameController.text.trim();
    final lastName = lastNameRaw.isEmpty ? null : lastNameRaw;
    final phone = _buildPhone(phoneController.text);

    if (firstName.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ism va telefon raqami talab qilinadi")),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final customerProvider = context.read<CustomerProvider>();

    final opticaId = authProvider.opticaId;

    if (opticaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Optika topilmadi")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final duplicate = await customerProvider.checkDuplicate(
        opticaId: opticaId,
        phone: phone,
        firstName: firstName,
        lastName: lastName,
        excludeCustomerId: widget.isEdit ? widget.customer?.id : null,
      );

      if (duplicate.phoneExists || duplicate.nameExists) {
        final messages = <String>[];
        if (duplicate.phoneExists) {
          messages.add("Bu telefon raqamli mijoz mavjud");
        }
        if (duplicate.nameExists) {
          messages.add("Bu ismli mijoz mavjud");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messages.join(". "))),
        );
        setState(() => _loading = false);
        return;
      }

      if (widget.isEdit) {
        await customerProvider.updateCustomerInfo(
          opticaId: opticaId,
          customerId: widget.customer!.id,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
        );

        await customerProvider.setVisitsSmsEnabled(
          opticaId: opticaId,
          customerId: widget.customer!.id,
          enabled: _visitsSms,
        );

        await customerProvider.setDebtsSmsEnabled(
          opticaId: opticaId,
          customerId: widget.customer!.id,
          enabled: _debtsSms,
        );
      } else {
        final newCustomer = CustomerModel.create(
          opticaId: opticaId,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
        ).copyWith(
          visitsSmsEnabled: _visitsSms,
          debtsSmsEnabled: _debtsSms,
        );

        await customerProvider.createCustomer(
          opticaId: opticaId,
          customer: newCustomer,
        );
      }

      setState(() => _saved = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }
}
