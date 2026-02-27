import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import 'package:robot_optica/widgets/common/responsive_frame.dart';
import '../../models/care_item.dart';
import '../../models/care_plan_model.dart';
import '../../models/customer_model.dart';
import '../../models/prescription_item.dart';
import '../../services/prescription_service.dart';

class AddCarePlanSheet extends StatefulWidget {
  final String? visitId;
  final CustomerModel customer;

  const AddCarePlanSheet({
    super.key,
    this.visitId,
    required this.customer,
  });

  @override
  State<AddCarePlanSheet> createState() => _AddCarePlanSheetState();
}

class _AddCarePlanSheetState extends State<AddCarePlanSheet> {
  final generalAdviceController = TextEditingController();
  // final List<Map<String, dynamic>> selectedItems = [];
  final List<PrescriptionItem> selectedItems = [];

  bool _saved = false;
  bool _loading = false;

  final _service = PrescriptionService();

  bool _sendSms = true;

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _saved ? _successView() : _formView(),
      ),
    );
  }

  // --------------------------------------------------
  // FORM VIEW
  // --------------------------------------------------

  Widget _formView() {
    return Column(
      key: const ValueKey("form"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header("Yangi retsept"),
        const SizedBox(height: 20),

        _addItemButton(),
        const SizedBox(height: 12),

        ...selectedItems.map(_itemCard),

        const SizedBox(height: 12),

        _input("Umumiy tavsiya (ixtiyoriy)", generalAdviceController),

        const SizedBox(height: 24),
        Row(
          children: [
            Checkbox(
              value: _sendSms,
              onChanged: (v) {
                setState(() => _sendSms = v ?? true);
              },
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                "Retsept bo‘yicha SMS eslatma yuborish",
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _saveButton(),
      ],
    );
  }

  void _updateItem(
    PrescriptionItem oldItem,
    PrescriptionItem newItem,
  ) {
    final index = selectedItems.indexOf(oldItem);
    if (index == -1) return;

    setState(() {
      selectedItems[index] = newItem;
    });
  }

  // --------------------------------------------------
  // SUCCESS VIEW
  // --------------------------------------------------

  Widget _successView() {
    return Column(
      key: const ValueKey("success"),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 72, color: Colors.green),
        const SizedBox(height: 12),
        const Text(
          "Retsept saqlandi",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        ...selectedItems.map((item) {
          return _row(
            item.title,
            "${item.dosage}× kuniga • ${item.duration ?? '-'} kun",
          );
        }),


        if (generalAdviceController.text.isNotEmpty)
          _row("Tavsiya", generalAdviceController.text),

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

  // --------------------------------------------------
  // UI PIECES
  // --------------------------------------------------

  Widget _header(String title) {
    return Row(
      children: [
        const Icon(Icons.medical_services_outlined),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _addItemButton() {
    return OutlinedButton.icon(
      onPressed: _selectCareItem,
      icon: const Icon(Icons.add),
      label: const Text("Yangi vosita qo‘shish"),
    );
  }

  Widget _itemCard(PrescriptionItem item) {
    final itemIndex = selectedItems.indexOf(item);
    return Container(
      key: ValueKey('care_item_$itemIndex'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() => selectedItems.remove(item));
                },
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),

          if (item.instruction.isNotEmpty) ...[
            Text(
              item.instruction,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],

          _numberInput(
            label: "Dozasi (kuniga)",
            value: item.dosage,
            onChanged: (v) {
              if (v == null) return;

              _updateItem(
                item,
                PrescriptionItem(
                  careItemId: item.careItemId,
                  title: item.title,
                  instruction: item.instruction,
                  dosage: v,
                  duration: item.duration,
                  notes: item.notes,
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          _numberInput(
            label: "Davomiyligi (kun)",
            value: item.duration,
            onChanged: (v) {
              _updateItem(
                item,
                PrescriptionItem(
                  careItemId: item.careItemId,
                  title: item.title,
                  instruction: item.instruction,
                  dosage: item.dosage,
                  duration: v ?? 7,
                  notes: item.notes,
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          _textInput(
            label: "Izohlar",
            value: item.notes ?? '',
            onChanged: (v) {
              _updateItem(
                item,
                PrescriptionItem(
                  careItemId: item.careItemId,
                  title: item.title,
                  instruction: item.instruction,
                  dosage: item.dosage,
                  duration: item.duration,
                  notes: v,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _numberInput({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return TextFormField(
      initialValue: value?.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (val) => onChanged(int.tryParse(val)),
    );
  }

  Widget _textInput({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: onChanged,
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
          maxLines: 3,
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

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _save,
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: AppLoader(
                  size: 20,
                  fill: false,
                ),
              )
            : const Text("Retseptni saqlash"),
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

  // --------------------------------------------------
  // LOGIC
  // --------------------------------------------------

  Future<void> _selectCareItem() async {
    final careItems = await _service.fetchCareItems(widget.customer.opticaId);

    final selected = await showModalBottomSheet<CareItem>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: careItems.map((item) {
            return ListTile(
              title: Text(item.title),
              subtitle: item.instruction.trim().isEmpty
                  ? null
                  : Text(item.instruction),
              onTap: () => Navigator.pop(context, item),
            );
          }).toList(),
        );
      },
    );

    if (selected != null) {
      final item = PrescriptionItem(
        careItemId: selected.id,
        title: selected.title,
        instruction: selected.instruction,
        dosage: selected.dosage,
        duration: selected.duration ?? 7,
      );
      setState(() {
        selectedItems.add(item);
      });
    }
  }
  Future<void> _save() async {
    if (selectedItems.isEmpty) return;

    setState(() => _loading = true);

    try {
      // final items = selectedItems.map((e) {
      //   return PrescriptionItem(
      //     careItemId: e['careItemId'],
      //     title: e['title'],
      //     instruction: e['instruction'],
      //     dosage: e['dosage'],
      //     duration: e['duration'],
      //     notes: e['notes'],
      //   );
      // }).toList();
      final items = selectedItems;


      final plan = CarePlanModel(
        id: '',
        visitId: widget.visitId,
        customerId: widget.customer.id,
        items: items,
        generalAdvice: generalAdviceController.text,
        createdAt: DateTime.now(),
      );

      await _service.createCarePlan(
        widget.customer.opticaId,
        plan,
        sendSms: _sendSms,
      );
      setState(() {
        _saved = true;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saqlab bo‘lmadi: $e")),
      );
    }
  }

}
