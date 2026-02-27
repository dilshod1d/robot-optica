import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/product_model.dart';
import '../../services/inventory_service.dart';
import '../../utils/inventory_categories.dart';
import '../../utils/barcode_keyboard_listener.dart';
import '../common/app_loader.dart';
import '../common/responsive_frame.dart';
import '../../screens/inventory/barcode_scanner_screen.dart';

class ProductFormSheet extends StatefulWidget {
  final String opticaId;
  final ProductModel? product;

  const ProductFormSheet({
    super.key,
    required this.opticaId,
    this.product,
  });

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();

  final _service = InventoryService();
  final _uuid = const Uuid();

  bool _saving = false;
  bool _showAdvanced = false;
  int _barcodeToken = -1;

  String _category = 'frame';


  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameController.text = p.name;
      _priceController.text = p.price.toStringAsFixed(0);
      _costController.text = p.cost > 0 ? p.cost.toStringAsFixed(0) : '';
      _stockController.text = p.stockQty.toString();
      _minStockController.text = p.minStock > 0 ? p.minStock.toString() : '';
      _skuController.text = p.sku ?? '';
      _barcodeController.text = p.barcode ?? '';
      _category = inventoryCategories.containsKey(p.category) ? p.category : 'other';
    }

    _barcodeToken = BarcodeKeyboardListener.instance.pushHandler(
      _handleKeyboardScan,
      minLength: 4,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    BarcodeKeyboardListener.instance.removeHandler(_barcodeToken);
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    final stockQty = int.tryParse(_stockController.text.trim()) ?? 0;
    final minStock = int.tryParse(_minStockController.text.trim()) ?? 0;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nom va narxni kiriting")),
      );
      return;
    }

    setState(() => _saving = true);

    final now = Timestamp.now();
    final id = widget.product?.id ?? _uuid.v4();

    final product = ProductModel(
      id: id,
      opticaId: widget.opticaId,
      name: name,
      category: _category,
      sku: _skuController.text.trim().isEmpty
          ? null
          : _skuController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      cost: cost,
      price: price,
      stockQty: stockQty,
      minStock: minStock,
      unit: 'pcs',
      createdAt: widget.product?.createdAt ?? now,
      updatedAt: now,
      active: widget.product?.active ?? true,
    );

    try {
      await _service.upsertProduct(
        opticaId: widget.opticaId,
        product: product,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saqlashda xatolik")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(
          title: "Shtrix-kodni skanerlash",
          hint: "Mahsulot shtrix-kodini skan qiling",
        ),
      ),
    );

    if (code == null || code.trim().isEmpty) return;
    _setBarcode(code);
  }

  void _handleKeyboardScan(String code) {
    _setBarcode(code);
  }

  void _setBarcode(String code) {
    final normalized = code.trim();
    if (normalized.isEmpty) return;
    _barcodeController.text = normalized;
    _barcodeController.selection =
        TextSelection.fromPosition(TextPosition(offset: normalized.length));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return SheetFrame(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEdit ? "Mahsulotni tahrirlash" : "Mahsulot qo'shish",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Mahsulot nomi",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: "Kategoriya",
                  border: OutlineInputBorder(),
                ),
                items: inventoryCategories.entries
                    .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _category = val ?? 'frame'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Sotuv narxi",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Soni",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                child: Row(
                  children: [
                    Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
                    const SizedBox(width: 4),
                    Text(_showAdvanced ? "Qo'shimcha maydonlarni yopish" : "Qo'shimcha maydonlar"),
                  ],
                ),
              ),

              if (_showAdvanced) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Tannarx (ixtiyoriy)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _minStockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Minimal qoldiq",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _skuController,
                  decoration: const InputDecoration(
                    labelText: "SKU (ixtiyoriy)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _barcodeController,
                  decoration: InputDecoration(
                    labelText: "Shtrix-kod (ixtiyoriy)",
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scanBarcode,
                      tooltip: "Skanerlash",
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const AppLoader(size: 20, fill: false)
                  : const Text("Saqlash"),
            ),
          ),
        ],
      ),
    );
  }
}
