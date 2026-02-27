import 'package:flutter/material.dart';
import 'package:robot_optica/widgets/common/app_loader.dart';
import 'package:robot_optica/widgets/common/responsive_frame.dart';
import '../../models/care_item.dart';
import '../../services/prescription_service.dart';

class CreateCareItemSheet extends StatefulWidget {
  final String opticaId;
  const CreateCareItemSheet({super.key, required this.opticaId});

  @override
  State<CreateCareItemSheet> createState() => _CreateCareItemSheetState();
}

class _CreateCareItemSheetState extends State<CreateCareItemSheet> {
  final _titleController = TextEditingController();
  final _instructionController = TextEditingController();
  final _dosageController = TextEditingController();
  final _durationController = TextEditingController(); // 👈 NEW (optional)

  bool _loading = false;

  final _service = PrescriptionService();

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header("Yangi parvarish vositasi qo‘shish"),
          const SizedBox(height: 20),

          _input("Nomi", _titleController),
          const SizedBox(height: 12),

          _input("Qo‘llanma (ixtiyoriy)", _instructionController, maxLines: 3),
          const SizedBox(height: 12),

          _input("Dozasi (kuniga nechta marta)", _dosageController,
              isNumber: true),
          const SizedBox(height: 12),

          _input("Davomiyligi (kunlarda)", _durationController,
              isNumber: true),

          const SizedBox(height: 24),

          SizedBox(
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
                  : const Text("Saqlash"),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // UI HELPERS
  // --------------------------------------------------

  Widget _header(String title) {
    return Row(
      children: [
        const Icon(Icons.medical_services_outlined),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  Widget _input(
      String label,
      TextEditingController controller, {
        int maxLines = 1,
        bool isNumber = false,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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


  // --------------------------------------------------
  // SAVE
  // --------------------------------------------------

  Future<void> _save() async {
    if (_titleController.text.isEmpty ||
        _dosageController.text.isEmpty ||
        _durationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Majburiy maydonlarni to‘ldiring")),
      );
      return;
    }

    setState(() => _loading = true);

    final dosage = int.parse(_dosageController.text.trim());

    final duration = int.parse(_durationController.text.trim());

    try {
      final item = CareItem(
        id: '',
        title: _titleController.text.trim(),
        instruction: _instructionController.text.trim(),
        dosage: dosage,
        duration: duration,
      );


      await _service.createCareItem(widget.opticaId, item);

      Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saqlab bo‘lmadi: $e")),
      );
    }
  }
}
