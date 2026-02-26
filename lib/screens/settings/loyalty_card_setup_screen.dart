import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/customer_model.dart';
import '../../models/loyalty_config_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/customer_service.dart';
import '../../services/loyalty_card_service.dart';
import '../../services/loyalty_card_store.dart';
import '../../services/optica_service.dart';
import '../../widgets/common/app_loader.dart';
import '../../utils/loyalty_utils.dart';

class LoyaltyCardSetupScreen extends StatefulWidget {
  const LoyaltyCardSetupScreen({super.key});

  @override
  State<LoyaltyCardSetupScreen> createState() => _LoyaltyCardSetupScreenState();
}

class _LoyaltyCardSetupScreenState extends State<LoyaltyCardSetupScreen> {
  final _opticaService = OpticaService();
  final _customerService = CustomerService();
  final _cardService = LoyaltyCardService();
  final _cardStore = LoyaltyCardStore();
  final _picker = ImagePicker();

  final _phoneCtrl = TextEditingController();
  final _taplinkCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _minPurchaseCtrl = TextEditingController();

  Uint8List? _logoBytes;
  String? _logoBase64;
  Uint8List? _frontBgBytes;
  String? _frontBgBase64;
  Uint8List? _backBgBytes;
  String? _backBgBase64;
  double _frontOverlay = 0.85;
  double _backOverlay = 0.85;
  String _opticaName = '';

  bool _loading = true;
  bool _saving = false;
  bool _generating = false;

  CustomerModel? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _taplinkCtrl.dispose();
    _discountCtrl.dispose();
    _minPurchaseCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final opticaId = auth.opticaId;
    if (opticaId == null) return;

    final data = await _opticaService.getOptica(opticaId);
    final config = LoyaltyConfigModel.fromMap(data);

    _opticaName = (data['name'] ?? '').toString();
    _phoneCtrl.text = _extractLocalPhone(config.phone);
    _taplinkCtrl.text = config.taplinkUrl;
    _discountCtrl.text =
        config.discountPercent.toStringAsFixed(0);
    _minPurchaseCtrl.text = config.minPurchasesForDiscount.toString();
    _logoBytes = config.logoBytes;
    _logoBase64 = config.logoBase64;
    _frontBgBytes = config.frontBackgroundBytes;
    _frontBgBase64 = config.frontBackgroundBase64;
    _backBgBytes = config.backBackgroundBytes;
    _backBgBase64 = config.backBackgroundBase64;
    _frontOverlay = config.frontOverlayOpacity;
    _backOverlay = config.backOverlayOpacity;

    setState(() => _loading = false);
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
    if (digits.startsWith('998')) {
      return '+$digits';
    }
    return '+998$digits';
  }

  void _handlePhoneInput(String value) {
    final digits = value.replaceAll(RegExp(r'\\D'), '');
    final normalized = digits.startsWith('998') ? digits.substring(3) : digits;
    if (normalized != value) {
      _phoneCtrl.text = normalized;
      _phoneCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: normalized.length));
    }
    setState(() {});
  }

  double _parsePercent() {
    final raw = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    if (raw < 0) return 0;
    if (raw > 100) return 100;
    return raw;
  }

  LoyaltyConfigModel _buildConfig() {
    return LoyaltyConfigModel(
      title: '',
      phone: _buildPhone(_phoneCtrl.text),
      taplinkUrl: _taplinkCtrl.text.trim(),
      discountPercent: _parsePercent(),
      logoBase64: _logoBase64,
      frontBackgroundBase64: _frontBgBase64,
      backBackgroundBase64: _backBgBase64,
      frontOverlayOpacity: _frontOverlay,
      backOverlayOpacity: _backOverlay,
      minPurchasesForDiscount: _parseMinPurchases(),
    );
  }

  int _parseMinPurchases() {
    final raw = int.tryParse(_minPurchaseCtrl.text.trim()) ?? 1;
    if (raw < 1) return 1;
    if (raw > 999) return 999;
    return raw;
  }

  Future<bool> _ensureGalleryPermission() async {
    if (!Platform.isIOS && !Platform.isAndroid) return true;

    Permission permission = Platform.isIOS ? Permission.photos : Permission.photos;
    var status = await permission.request();

    if (status.isGranted || status.isLimited) return true;

    if (!Platform.isIOS) {
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;
      if (storageStatus.isPermanentlyDenied) {
        await _showPermissionDialog();
      }
      return false;
    }

    if (status.isPermanentlyDenied) {
      await _showPermissionDialog();
    }
    return false;
  }

  Future<void> _showPermissionDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ruxsat kerak"),
        content: const Text(
          "Galereyadan rasm tanlash uchun ruxsat bering.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Yopish"),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text("Sozlamalar"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLogo() async {
    final ok = await _ensureGalleryPermission();
    if (!ok) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _logoBytes = bytes;
      _logoBase64 = base64Encode(bytes);
    });
  }

  Future<void> _pickBackground({required bool isFront}) async {
    final ok = await _ensureGalleryPermission();
    if (!ok) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 85.6, ratioY: 54),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      maxWidth: 1200,
      maxHeight: 760,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: isFront ? "Old tomon fonini kesish" : "Orqa tomon fonini kesish",
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: isFront ? "Old tomon fonini kesish" : "Orqa tomon fonini kesish",
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) return;

    final bytes = await File(cropped.path).readAsBytes();
    setState(() {
      if (isFront) {
        _frontBgBytes = bytes;
        _frontBgBase64 = base64Encode(bytes);
      } else {
        _backBgBytes = bytes;
        _backBgBase64 = base64Encode(bytes);
      }
    });
  }

  Future<void> _saveConfig({bool showToast = true}) async {
    final auth = context.read<AuthProvider>();
    final opticaId = auth.opticaId;
    if (opticaId == null) return;

    setState(() => _saving = true);
    final config = _buildConfig();

    await _opticaService.updateLoyaltyConfigFields(
      opticaId: opticaId,
      data: config.toMap(),
    );

    setState(() => _saving = false);

    if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Loyalty sozlamalari saqlandi")),
      );
    }
  }

  Future<void> _generatePdf() async {
    final auth = context.read<AuthProvider>();
    final opticaId = auth.opticaId;
    if (opticaId == null) return;

    final allowWithoutCustomer = _selectedCustomer == null;

    setState(() => _generating = true);
    try {
      await _saveConfig(showToast: false);

      if (!allowWithoutCustomer && _selectedCustomer != null) {
        await _customerService.setLoyaltyEnabled(
          opticaId: opticaId,
          customerId: _selectedCustomer!.id,
          enabled: true,
        );
      }

      final card = await _cardStore.createCard(
        opticaId: opticaId,
        customerId: allowWithoutCustomer ? null : _selectedCustomer?.id,
      );

      if (!allowWithoutCustomer && _selectedCustomer != null) {
        await _customerService.setLoyaltyEnabled(
          opticaId: opticaId,
          customerId: _selectedCustomer!.id,
          enabled: true,
        );
      }

      final pdf = await _cardService.buildLoyaltyCardPdf(
        config: _buildConfig(),
        opticaName: _opticaName,
        opticaId: opticaId,
        cardId: card.id,
        customer: allowWithoutCustomer ? null : _selectedCustomer,
      );

      final pdfName =
          _buildPdfName(allowWithoutCustomer ? null : _selectedCustomer);
      final info = await Printing.info();
      if (!info.canPrint) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Printer mavjud emas")),
          );
        }
        return;
      }
      await Printing.layoutPdf(
        name: pdfName,
        format: PdfPageFormat(85.6 * PdfPageFormat.mm, 54 * PdfPageFormat.mm),
        dynamicLayout: !Platform.isMacOS,
        onLayout: (_) async => pdf,
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _buildPdfName(CustomerModel? customer) {
    if (customer == null) return 'loyalty_card.pdf';
    final full = "${customer.firstName} ${customer.lastName ?? ""}".trim();
    if (full.isEmpty) return 'loyalty_card.pdf';
    final safe = full
        .replaceAll(RegExp(r'[\\\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
    if (safe.isEmpty) return 'loyalty_card.pdf';
    final fileBase = safe.toLowerCase().replaceAll(' ', '_');
    return "$fileBase.pdf";
  }

  Future<CustomerModel?> _pickCustomer() {
    return showModalBottomSheet<CustomerModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CustomerPickerSheet(
        opticaId: context.read<AuthProvider>().opticaId!,
        service: _customerService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: AppLoader());
    }

    final brand = _opticaName;
    final discount = _parsePercent();
    final taplink = _taplinkCtrl.text.trim();
    final phone = _buildPhone(_phoneCtrl.text);
    final customerName = _selectedCustomer == null
        ? ''
        : "${_selectedCustomer!.firstName} ${_selectedCustomer!.lastName ?? ""}"
            .trim();

    return Scaffold(
      appBar: AppBar(title: const Text("Loyalty karta")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Loyalty karta sozlamalari",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Global qoidalar",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _discountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: "Loyalty chegirma (%)",
                      border: OutlineInputBorder(),
                      suffixText: "%",
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _minPurchaseCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: "Minimal xaridlar soni (global)",
                      helperText: "Chegirma barcha kartalar uchun shu qoidaga ko'ra ishlaydi",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Karta dizayni",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _logoPreview(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Logo",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickLogo,
                                  icon: const Icon(Icons.photo),
                                  label: const Text("Tanlash"),
                                ),
                                if (_logoBytes != null)
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _logoBytes = null;
                                      _logoBase64 = null;
                                    }),
                                    child: const Text("Olib tashlash"),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _phoneField(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _taplinkCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: "Taplink URL",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Fonga rasm (ixtiyoriy)",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _backgroundPicker(
                          label: "Old tomon",
                          bytes: _frontBgBytes,
                          overlay: _frontOverlay,
                          onPick: () => _pickBackground(isFront: true),
                          onClear: () => setState(() {
                            _frontBgBytes = null;
                            _frontBgBase64 = null;
                          }),
                          onOverlayChanged: (v) => setState(() => _frontOverlay = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _backgroundPicker(
                          label: "Orqa tomon",
                          bytes: _backBgBytes,
                          overlay: _backOverlay,
                          onPick: () => _pickBackground(isFront: false),
                          onClear: () => setState(() {
                            _backBgBytes = null;
                            _backBgBase64 = null;
                          }),
                          onOverlayChanged: (v) => setState(() => _backOverlay = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Mijoz (ixtiyoriy)",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _customerSelectCard(customerName),
          const SizedBox(height: 6),
      const Text(
            "QR karta yaratilganda unikal bo'ladi. Mijoz keyinroq biriktiriladi.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          const Text(
            "Oldindan ko‘rish",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 210,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _cardPreviewFront(
                  brand: brand,
                  discount: discount,
                  customerName: customerName,
                ),
                const SizedBox(width: 12),
                _cardPreviewBack(
                  brand: brand,
                  phone: phone,
                  taplink: taplink,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : () => _saveConfig(),
              child: _saving
                  ? const AppLoader(size: 18, fill: false)
                  : const Text("Saqlash"),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generating ? null : _generatePdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: _generating
                  ? const AppLoader(size: 18, fill: false)
                  : const Text("PDF generatsiya qilish"),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _logoPreview() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: _logoBytes == null
          ? const Icon(Icons.image_outlined, color: Colors.grey)
          : ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                _logoBytes!,
                fit: BoxFit.cover,
              ),
            ),
    );
  }

  Widget _phoneField() {
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
                onChanged: _handlePhoneInput,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _customerSelectCard(String customerName) {
    final hasCustomer = _selectedCustomer != null;
    final label = hasCustomer
        ? customerName
        : "Mijoz tanlang (ixtiyoriy)";
    final helper = hasCustomer ? _selectedCustomer!.phone : "Mijozga kartani ulash";

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await _pickCustomer();
        if (picked != null) {
          setState(() => _selectedCustomer = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: hasCustomer ? Colors.black : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    helper,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (hasCustomer)
              IconButton(
                onPressed: () => setState(() => _selectedCustomer = null),
                icon: const Icon(Icons.close, size: 18),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _cardPreviewFront({
    required String brand,
    required double discount,
    required String customerName,
  }) {
    final auth = context.read<AuthProvider>();
    final opticaId = auth.opticaId ?? '';
    final loyaltyQr = opticaId.isEmpty
        ? null
        : buildLoyaltyQrData(
            opticaId: opticaId,
            cardId: "PREVIEW",
          );

    return _cardShell(
      backgroundBytes: _frontBgBytes,
      overlayOpacity: _frontOverlay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _logoPreviewSmall(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.isEmpty ? "Brend" : brand,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Text(
                      "Loyalty Card",
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${discount.toStringAsFixed(0)}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Mijoz:",
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customerName.isEmpty
                              ? "________________"
                              : customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: loyaltyQr == null
                    ? const Center(
                        child: Text("QR", style: TextStyle(color: Colors.grey)),
                      )
                    : QrImageView(
                        data: loyaltyQr,
                        gapless: false,
                        padding: const EdgeInsets.all(6),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardPreviewBack({
    required String brand,
    required String phone,
    required String taplink,
  }) {
    final qrData = taplink.isEmpty ? null : taplink;

    return _cardShell(
      backgroundBytes: _backBgBytes,
      overlayOpacity: _backOverlay,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand.isEmpty ? "Brend" : brand,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                if (phone.isNotEmpty)
                  Text(
                    "Telefon: $phone",
                    style: const TextStyle(fontSize: 11),
                  ),
                if (taplink.isNotEmpty)
                  Text(
                    taplink,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: qrData == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.qr_code_2, color: Colors.grey),
                          SizedBox(height: 4),
                          Text(
                            "QR",
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: QrImageView(
                              data: qrData,
                              gapless: false,
                              padding: const EdgeInsets.all(4),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Text(
                                "Follow",
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Bizni kuzating",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardShell({
    required Widget child,
    Uint8List? backgroundBytes,
    double overlayOpacity = 0.85,
  }) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (backgroundBytes != null)
              Positioned.fill(
                child: Image.memory(
                  backgroundBytes,
                  fit: BoxFit.cover,
                ),
              ),
            if (backgroundBytes != null)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(overlayOpacity),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _backgroundPicker({
    required String label,
    required Uint8List? bytes,
    required double overlay,
    required VoidCallback onPick,
    required VoidCallback onClear,
    required ValueChanged<double> onOverlayChanged,
  }) {
    final percent = (overlay * 100).round();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: bytes == null
                ? const Center(
                    child: Icon(Icons.image_outlined, color: Colors.grey),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPick,
                  child: const Text("Tanlash"),
                ),
              ),
              const SizedBox(width: 8),
              if (bytes != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                  tooltip: "Olib tashlash",
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Kontrast: $percent%",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Slider(
            value: overlay,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: onOverlayChanged,
          ),
        ],
      ),
    );
  }

  Widget _logoPreviewSmall() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: _logoBytes == null
          ? const Icon(Icons.image_outlined, size: 18, color: Colors.grey)
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                _logoBytes!,
                fit: BoxFit.cover,
              ),
            ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final String opticaId;
  final CustomerService service;

  const _CustomerPickerSheet({
    required this.opticaId,
    required this.service,
  });

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _query = '';

  List<CustomerModel> _filter(List<CustomerModel> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;

    return list.where((c) {
      final name = '${c.firstName} ${c.lastName ?? ""}'.toLowerCase();
      return name.contains(q) || c.phone.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).viewPadding.bottom +
              16,
        ),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Mijoz tanlash",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  hintText: "Ism yoki telefon bo'yicha qidiruv",
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<List<CustomerModel>>(
                  stream: widget.service.watchCustomers(widget.opticaId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const AppLoader();
                    }

                    if (snapshot.hasError) {
                      return const Center(
                          child: Text("Nimadir noto'g'ri ketdi"));
                    }

                    final list = _filter(snapshot.data ?? []);

                    if (list.isEmpty) {
                      return const Center(child: Text("Mijoz topilmadi"));
                    }

                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = list[index];
                        final name =
                            "${customer.firstName} ${customer.lastName ?? ""}"
                                .trim();

                        return ListTile(
                          title: Text(name),
                          subtitle: Text(customer.phone),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, customer),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
