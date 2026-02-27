import 'package:flutter/material.dart';
import '../../models/sms_config_model.dart';
import '../../services/optica_service.dart';
import '../../utils/sms_template_defaults.dart';
import '../../utils/sms_types.dart';
import '../../optica_theme.dart';
import '../../widgets/common/responsive_frame.dart';

class SmsTemplateSetupScreen extends StatefulWidget {
  final String opticaId;

  const SmsTemplateSetupScreen({
    super.key,
    required this.opticaId,
  });

  @override
  State<SmsTemplateSetupScreen> createState() => _SmsTemplateSetupScreenState();
}

class _SmsTemplateSetupScreenState extends State<SmsTemplateSetupScreen> {
  final OpticaService _opticaService = OpticaService();

  bool _loading = true;
  bool _saving = false;
  String _language = SmsConfigModel.languageCyrillic;

  final Map<String, TextEditingController> _latinCtrls = {};
  final Map<String, TextEditingController> _cyrillicCtrls = {};
  final Map<String, FocusNode> _focusNodes = {};
  late final TextEditingController _prescriptionItemLatinCtrl;
  late final TextEditingController _prescriptionItemCyrillicCtrl;
  late final FocusNode _prescriptionItemFocus;

  final List<_TemplateSection> _sections = const [
    _TemplateSection(
      title: "Tashrif (yaratildi)",
      type: SmsLogTypes.visitCreated,
      variables: [
        '{firstName}',
        '{lastName}',
        '{visitDate}',
        '{visitReason}',
        '{opticaName}',
        '{opticaPhone}'
      ],
    ),
    _TemplateSection(
      title: "Tashrif (oldin)",
      type: SmsLogTypes.visitBefore,
      variables: [
        '{firstName}',
        '{lastName}',
        '{visitDate}',
        '{visitReason}',
        '{opticaName}',
        '{opticaPhone}'
      ],
    ),
    _TemplateSection(
      title: "Tashrif (kuni)",
      type: SmsLogTypes.visitOnDate,
      variables: [
        '{firstName}',
        '{lastName}',
        '{visitDate}',
        '{visitReason}',
        '{opticaName}',
        '{opticaPhone}'
      ],
    ),
    _TemplateSection(
      title: "Qarz (yaratildi)",
      type: SmsLogTypes.debtCreated,
      variables: [
        '{firstName}',
        '{lastName}',
        '{amount}',
        '{dueDate}',
        '{opticaName}',
        '{opticaPhone}'
      ],
    ),
    _TemplateSection(
      title: "Qarz (oldin)",
      type: SmsLogTypes.debtBefore,
      variables: [
        '{firstName}',
        '{lastName}',
        '{amount}',
        '{dueDate}',
        '{opticaName}',
        '{opticaPhone}'
      ],
    ),
    _TemplateSection(
      title: "Qarz (muddat)",
      type: SmsLogTypes.debtDue,
      variables: [
        '{firstName}',
        '{lastName}',
        '{amount}',
        '{dueDate}',
        '{opticaName}',
        '{opticaPhone}'
      ],
    ),
    _TemplateSection(
      title: "Qarz (kechikdi)",
      type: SmsLogTypes.debtRepeat,
      variables: [
        '{firstName}',
        '{lastName}',
        '{amount}',
        '{dueDate}',
        '{opticaName}',
        '{opticaPhone}'
      ],
    ),
    _TemplateSection(
      title: "Qarz (to'landi)",
      type: SmsLogTypes.debtPaid,
      variables: [
        '{firstName}',
        '{lastName}',
        '{paidAmount}',
        '{opticaName}',
        '{opticaPhone}'
      ],
    ),
    _TemplateSection(
      title: "Retsept",
      type: SmsLogTypes.prescriptionCreated,
      variables: [
        '{firstName}',
        '{lastName}',
        '{items}',
        '{opticaName}',
        '{opticaPhone}'
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    for (final section in _sections) {
      _latinCtrls[section.type] = TextEditingController();
      _cyrillicCtrls[section.type] = TextEditingController();
      _focusNodes[section.type] = FocusNode();
    }
    _prescriptionItemLatinCtrl = TextEditingController();
    _prescriptionItemCyrillicCtrl = TextEditingController();
    _prescriptionItemFocus = FocusNode();
    _load();
  }

  @override
  void dispose() {
    for (final ctrl in _latinCtrls.values) {
      ctrl.dispose();
    }
    for (final ctrl in _cyrillicCtrls.values) {
      ctrl.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _prescriptionItemLatinCtrl.dispose();
    _prescriptionItemCyrillicCtrl.dispose();
    _prescriptionItemFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _opticaService.getOptica(widget.opticaId);
      final config = SmsConfigModel.fromMap(data);

      _language = config.smsLanguage;

      final defaultsLatin = SmsTemplateDefaults.latin;
      final defaultsCyr = SmsTemplateDefaults.cyrillic;

      for (final section in _sections) {
        final key = section.type;
        _latinCtrls[key]!.text =
            (config.smsTemplatesLatin[key]?.trim().isNotEmpty ?? false)
                ? config.smsTemplatesLatin[key]!
                : (defaultsLatin[key] ?? '');
        _cyrillicCtrls[key]!.text =
            (config.smsTemplatesCyrillic[key]?.trim().isNotEmpty ?? false)
                ? config.smsTemplatesCyrillic[key]!
                : (defaultsCyr[key] ?? '');
      }

      _prescriptionItemLatinCtrl.text =
          config.prescriptionItemTemplateLatin.trim().isNotEmpty
              ? config.prescriptionItemTemplateLatin
              : SmsTemplateDefaults.prescriptionItemLatin;
      _prescriptionItemCyrillicCtrl.text =
          config.prescriptionItemTemplateCyrillic.trim().isNotEmpty
              ? config.prescriptionItemTemplateCyrillic
              : SmsTemplateDefaults.prescriptionItemCyrillic;
    } catch (_) {
      // ignore load errors; show defaults
      final defaultsLatin = SmsTemplateDefaults.latin;
      final defaultsCyr = SmsTemplateDefaults.cyrillic;
      for (final section in _sections) {
        final key = section.type;
        _latinCtrls[key]!.text = defaultsLatin[key] ?? '';
        _cyrillicCtrls[key]!.text = defaultsCyr[key] ?? '';
      }
      _prescriptionItemLatinCtrl.text =
          SmsTemplateDefaults.prescriptionItemLatin;
      _prescriptionItemCyrillicCtrl.text =
          SmsTemplateDefaults.prescriptionItemCyrillic;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _opticaService.updateSmsConfigFields(
        opticaId: widget.opticaId,
        data: {
          'smsTemplatesLatin': _collect(_latinCtrls),
          'smsTemplatesCyrillic': _collect(_cyrillicCtrls),
          'smsPrescriptionItemTemplateLatin':
              _prescriptionItemLatinCtrl.text.trim(),
          'smsPrescriptionItemTemplateCyrillic':
              _prescriptionItemCyrillicCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SMS shablonlari saqlandi")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SMS shablonlarini saqlashda xatolik")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, String> _collect(Map<String, TextEditingController> ctrls) {
    return ctrls.map((key, ctrl) => MapEntry(key, ctrl.text.trim()));
  }

  void _insertVariable(TextEditingController ctrl, String variable) {
    final text = ctrl.text;
    final selection = ctrl.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;

    final newText = text.replaceRange(start, end, variable);
    ctrl.text = newText;
    ctrl.selection = TextSelection.collapsed(offset: start + variable.length);
  }

  void _resetToDefault(_TemplateSection section) {
    final defaults = _language == SmsConfigModel.languageLatin
        ? SmsTemplateDefaults.latin
        : SmsTemplateDefaults.cyrillic;
    final ctrl = _language == SmsConfigModel.languageLatin
        ? _latinCtrls[section.type]!
        : _cyrillicCtrls[section.type]!;
    ctrl.text = defaults[section.type] ?? '';
  }

  void _resetItemTemplateToDefault() {
    final isLatin = _language == SmsConfigModel.languageLatin;
    final ctrl = isLatin ? _prescriptionItemLatinCtrl : _prescriptionItemCyrillicCtrl;
    ctrl.text = isLatin
        ? SmsTemplateDefaults.prescriptionItemLatin
        : SmsTemplateDefaults.prescriptionItemCyrillic;
  }

  @override
  Widget build(BuildContext context) {
    final isLatin = _language == SmsConfigModel.languageLatin;
    return Scaffold(
      appBar: AppBar(
        title: const Text("SMS shablonlari"),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    "Saqlash",
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveFrame(
              maxWidth: 1100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              applyPaddingWhenNarrow: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const Text(
                    "Shablonlar SMS tiliga qarab yuboriladi. Har bir bo‘limni tahrir qiling va kerakli o‘zgaruvchilarni qo‘shing.",
                    style: TextStyle(color: OpticaColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Lotin'),
                        selected: isLatin,
                        onSelected: (v) {
                          if (v) setState(() => _language = SmsConfigModel.languageLatin);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Кирилл'),
                        selected: !isLatin,
                        onSelected: (v) {
                          if (v) setState(() => _language = SmsConfigModel.languageCyrillic);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final section in _sections) ...[
                    _TemplateEditor(
                      section: section,
                      controller: isLatin
                          ? _latinCtrls[section.type]!
                          : _cyrillicCtrls[section.type]!,
                      focusNode: _focusNodes[section.type]!,
                      onInsert: _insertVariable,
                      onReset: () => _resetToDefault(section),
                    ),
                    const SizedBox(height: 16),
                  ],
                    _TemplateEditor(
                      section: const _TemplateSection(
                        title: "Retsept (har bir dori qatori)",
                        type: "prescription-item",
                        variables: [
                          '{index}',
                          '{itemName}',
                          '{itemInstruction}',
                          '{itemDosage}',
                          '{itemDuration}',
                          '{itemNotes}',
                        ],
                      ),
                      controller: isLatin
                          ? _prescriptionItemLatinCtrl
                          : _prescriptionItemCyrillicCtrl,
                      focusNode: _prescriptionItemFocus,
                      onInsert: _insertVariable,
                      onReset: _resetItemTemplateToDefault,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TemplateSection {
  final String title;
  final String type;
  final List<String> variables;

  const _TemplateSection({
    required this.title,
    required this.type,
    required this.variables,
  });
}

class _TemplateEditor extends StatelessWidget {
  final _TemplateSection section;
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(TextEditingController controller, String variable) onInsert;
  final VoidCallback onReset;

  const _TemplateEditor({
    required this.section,
    required this.controller,
    required this.focusNode,
    required this.onInsert,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              TextButton(
                onPressed: onReset,
                child: const Text("Standart"),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "O‘zgaruvchilar",
            style: TextStyle(fontSize: 12, color: OpticaColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final variable in section.variables)
                ActionChip(
                  label: Text(variable),
                  onPressed: () => onInsert(controller, variable),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: "SMS matni...",
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
