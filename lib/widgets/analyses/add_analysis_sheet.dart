import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:robot_optica/widgets/common/ai_analyze_loader.dart';
import '../../models/eye_measurement.dart';
import '../../models/eye_scan_result.dart';
import '../../models/eye_side.dart';
import '../../services/eye_scan_service.dart';

class AddAnalysisSheet extends StatefulWidget {
  final String customerId;
  final String? visitId;
  final String opticaId;
  const AddAnalysisSheet({super.key, required this.customerId, this.visitId, required this.opticaId});

  @override
  State<AddAnalysisSheet> createState() => _AddAnalysisSheetState();
}

class _AddAnalysisSheetState extends State<AddAnalysisSheet> {
  final EyeScanService _service = EyeScanService();

  bool _loading = false;
  bool _saved = false;

  EyeScanResult? _report;
  Uint8List? _imageBytes;

  Future<void> _scan(BuildContext context) async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Kamera"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text("Galereya"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final image = await picker.pickImage(source: source);
    if (image == null) return;

    try {
      setState(() {
        _loading = true;
        _report = null;
        _imageBytes = null;
      });

      final bytes = await File(image.path).readAsBytes();
      final result = await _service.scanImage(bytes);

      setState(() {
        _report = result;
        _imageBytes = bytes;
      });
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 20,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _saved
              ? _successView()
              : _report == null
              ? _scanView()
              : _reviewView(),
        ),
      ),
    );
  }

  Widget _scanView() {
    return Column(
      key: const ValueKey("scan"),
      mainAxisSize: MainAxisSize.min,
      children: [
        _header("Yangi ko'z tahlili"),
        const SizedBox(height: 24),

        if (_loading)
          const AiAnalyzeLoader()
         else ...[
          ElevatedButton.icon(
            onPressed: () => _scan(context),
            icon: const Icon(Icons.document_scanner),
            label: const Text("Skanerlash"),
          ),
        ],
      ],
    );
  }

  Widget _reviewView() {
    return SingleChildScrollView(
      key: const ValueKey("review"),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header("Analizni ko'rish"),
          const SizedBox(height: 16),


          _infoCard("Skanerlash ma'lumotlari", [
            _editableRow("Sana", _report!.date ?? ""),
            _editableRow("Qorachiq masofasi", _report!.pd ?? ""),
          ]),

          const SizedBox(height: 16),

          _eyeCard("O'ng ko'z", _report!.right),
          const SizedBox(height: 16),
          _eyeCard("Chap ko'z", _report!.left),

          const SizedBox(height: 24),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _report = null;
                      _imageBytes = null;
                    });
                  },
                  child: const Text("Bekor qilish"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text("Analizni saqlash"),
                ),
              ),
            ],
          ),

        ],
      ),
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
          "Analizni saqlash",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
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
        const Icon(Icons.remove_red_eye),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }



  Widget _infoCard(String title, List<Widget> children) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }

  Widget _eyeCard(String title, EyeSide side) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _tableHeader(),

          ...side.readings.map((e) => _editableMeasurementRow(e)),

          if (side.avg != null) ...[
            const Divider(height: 24),
            const Text("O'rtacha",
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _editableMeasurementRow(side.avg!, bold: true),
          ],

          const SizedBox(height: 12),
          _editableRow("Sferik ko‘rsatkich", side.se ?? ""),
        ]),
      ),
    );
  }

  Widget _tableHeader() {
    return Row(children: const [
      Expanded(
          child:
          Text("Sfera", style: TextStyle(fontWeight: FontWeight.w600))),
      Expanded(
          child:
          Text("Silindr", style: TextStyle(fontWeight: FontWeight.w600))),
      Expanded(
          child: Text("Astigmatizm o‘qi", style: TextStyle(fontWeight: FontWeight.w600))),
    ]);
  }

  Widget _editableMeasurementRow(EyeMeasurement m, {bool bold = false}) {
    final style =
    TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: _inlineEditCell(m.sphere, (v) => m.sphere = v, style)),
        Expanded(
            child:
            _inlineEditCell(m.cylinder, (v) => m.cylinder = v, style)),
        Expanded(child: _inlineEditCell(m.axis, (v) => m.axis = v, style)),
      ]),
    );
  }

  Widget _editableRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label)),
        _inlineEditCell(value, (v) {}, const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _inlineEditCell(
      String value, Function(String) onSave, TextStyle style) {
    return GestureDetector(
      onTap: () async {
        final newValue = await _inlineEdit(value);
        if (newValue != null) {
          setState(() => onSave(newValue));
        }
      },
      child: Text(value, style: style),
    );
  }

  Future<String?> _inlineEdit(String initial) async {
    final controller = TextEditingController(text: initial);

    return showModalBottomSheet<String>(
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
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, autofocus: true),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text),
                  child: const Text("Saqlash"),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_report == null) return;

    try {
      setState(() => _loading = true);

      await _service.saveAnalysis(
        opticaId: widget.opticaId,
        customerId: widget.customerId,
        visitId: widget.visitId,
        scan: _report!,
      );

      setState(() {
        _saved = true;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saqlab bo'lmadi: $e")),
      );
    }
  }

}
