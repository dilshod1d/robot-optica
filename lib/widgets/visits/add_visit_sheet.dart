import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robot_optica/widgets/common/responsive_frame.dart';
import '../../models/customer_model.dart';
import '../../models/visit_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/visit_provider.dart';
import '../common/app_loader.dart';


class AddVisitSheet extends StatefulWidget {
  final CustomerModel customer;

  const AddVisitSheet({
    super.key, required this.customer
  });

  @override
  State<AddVisitSheet> createState() => _AddVisitSheetState();
}

class _AddVisitSheetState extends State<AddVisitSheet> {
  final reasonController = TextEditingController();
  final noteController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  bool _saved = false;

  String _savedReason = "";
  String _savedNote = "";
  DateTime _savedDate = DateTime.now();

  bool _sendingSms = false;


  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _saved ? _successView() : _formView(),
      ),
    );
  }

  Widget _formView() {
    return Column(
      key: const ValueKey("form"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header("${widget.customer.firstName} uchun tashrif qo'shish"),
        const SizedBox(height: 20),

        _input("Tashrif Sababi", reasonController),
        const SizedBox(height: 12),

        _datePicker(),
        const SizedBox(height: 12),

        _input("Izohlar (ixtiyoriy)", noteController),
        const SizedBox(height: 24),
        _saveButton(),
      ],
    );
  }

  Widget _successView() {
    return Column(
      key: const ValueKey("success"),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 72, color: Colors.green),
        const SizedBox(height: 12),
        const Text(
          "Tashrif saqlandi",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        _row("Sababi", _savedReason),
        _row("Sana", _formatDate(_savedDate)),
        if (_savedNote.isNotEmpty) _row("Izohlar", _savedNote),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Yaxshi"),
          ),
        )
      ],
    );
  }

  Widget _header(String title) {
    return Row(
      children: [
        const Icon(Icons.event_note),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _input(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
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

  Widget _datePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Sana", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Text(_formatDate(selectedDate)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _sendingSms ? null : _save,
        child: _sendingSms
            ? const SizedBox(
          height: 22,
          width: 22,
          child: AppLoader(
            size: 22,
            fill: false,
          ),
        )
            : const Text("Tashrifni saqlash"),
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _save() async {

    if (reasonController.text.trim().isEmpty) return;

    setState(() => _sendingSms = true);

    final visitProvider = context.read<VisitProvider>();
    final authProvider = context.read<AuthProvider>();
    final opticaId = authProvider.opticaId;

    final visit = VisitModel.create(
      customerId: widget.customer.id,
      customerName: widget.customer.firstName,
      reason: reasonController.text.trim(),
      note: noteController.text.trim(),
      visitDate: selectedDate,
    );

    await visitProvider.addVisit(opticaId!, visit);
    await visitProvider.fetchVisitsByCustomer(opticaId, widget.customer.id);

    _savedReason = reasonController.text;
    _savedNote = noteController.text;
    _savedDate = selectedDate;

    setState(() {
      _sendingSms = false;
      _saved = true;
    });
  }

  String _formatDate(DateTime date) {
    const months = [
      'yanvar',
      'fevral',
      'mart',
      'aprel',
      'may',
      'iyun',
      'iyul',
      'avgust',
      'sentyabr',
      'oktyabr',
      'noyabr',
      'dekabr',
    ];

    final monthName = months[date.month - 1];
    return "${date.day} $monthName";
  }






}
