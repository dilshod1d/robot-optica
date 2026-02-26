import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../screens/inventory/barcode_scanner_screen.dart';
import '../../services/inventory_service.dart';
import '../../utils/inventory_categories.dart';
import '../../utils/barcode_keyboard_listener.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/inventory/product_form_sheet.dart';

class InventoryScreen extends StatefulWidget {
  final String opticaId;

  const InventoryScreen({super.key, required this.opticaId});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _service = InventoryService();
  final _searchController = TextEditingController();
  String _query = '';
  List<ProductModel> _productsCache = [];
  int _barcodeToken = -1;

  @override
  void initState() {
    super.initState();
    _barcodeToken = BarcodeKeyboardListener.instance.pushHandler(
      _handleKeyboardScan,
      minLength: 4,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    BarcodeKeyboardListener.instance.removeHandler(_barcodeToken);
    super.dispose();
  }

  void _openForm({ProductModel? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ProductFormSheet(
        opticaId: widget.opticaId,
        product: product,
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );

    if (code == null || code.trim().isEmpty) return;
    _handleBarcodeInput(code);
  }

  void _handleKeyboardScan(String code) {
    _handleBarcodeInput(code, showSnack: true);
  }

  void _handleBarcodeInput(String code, {bool showSnack = true}) {
    final normalized = code.trim();
    if (normalized.isEmpty) return;

    _searchController.text = normalized;
    _searchController.selection =
        TextSelection.fromPosition(TextPosition(offset: normalized.length));
    setState(() => _query = normalized);

    if (_productsCache.isEmpty) {
      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mahsulotlar yuklanmoqda")),
        );
      }
      return;
    }

    ProductModel? product;
    for (final p in _productsCache) {
      if ((p.barcode ?? '').trim() == normalized ||
          (p.sku ?? '').trim() == normalized) {
        product = p;
        break;
      }
    }

    if (product == null) {
      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mahsulot topilmadi")),
        );
      }
      return;
    }

    _openForm(product: product);
  }

  List<ProductModel> _filter(List<ProductModel> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;

    return items.where((p) {
      final name = p.name.toLowerCase();
      final sku = (p.sku ?? '').toLowerCase();
      final barcode = (p.barcode ?? '').toLowerCase();
      return name.contains(q) || sku.contains(q) || barcode.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Mahsulot nomi yoki shtrix-kod",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scanBarcode,
                tooltip: "Skanerlash",
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            onEditingComplete: () => FocusScope.of(context).unfocus(),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ProductModel>>(
            stream: _service.watchProducts(widget.opticaId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoader();
              }

              if (snapshot.hasError) {
                return const Center(child: Text("Nimadir noto'g'ri ketdi"));
              }

              _productsCache = snapshot.data ?? [];
              final list = _filter(_productsCache);

              if (list.isEmpty) {
                return EmptyState(
                  title: _query.trim().isEmpty
                      ? "Mahsulotlar yo'q"
                      : "Mahsulot topilmadi",
                  subtitle: _query.trim().isEmpty
                      ? "Hozircha inventar bo'sh"
                      : "Qidiruv bo'yicha mos mahsulot yo'q",
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 80),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = list[index];
                  final lowStock =
                      product.minStock > 0 && product.stockQty <= product.minStock;

                  return InkWell(
                    onTap: () => _openForm(product: product),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  inventoryCategoryLabel(product.category),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${product.price.toStringAsFixed(0)} UZS",
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "${product.stockQty} dona",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: lowStock ? Colors.red : Colors.black,
                                ),
                              ),
                              if (lowStock)
                                const Text(
                                  "Qoldiq past",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              heroTag: 'inventory_fab',
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }
}
