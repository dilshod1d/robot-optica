import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../screens/inventory/barcode_scanner_screen.dart';
import '../../services/inventory_service.dart';
import '../../utils/barcode_keyboard_listener.dart';
import '../../utils/inventory_categories.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/responsive_frame.dart';
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

  int _columnsForWidth(double width) {
    if (width < 520) return 1;
    if (width < 760) return 2;
    if (width < 1000) return 3;
    if (width < 1240) return 4;
    if (width < 1480) return 5;
    if (width < 1720) return 6;
    if (width < 1960) return 7;
    return 8;
  }

  Widget _productCard(ProductModel product, bool lowStock) {
    final categoryLabel =
        inventoryCategories[product.category] ?? product.category;
    final inStock = product.stockQty > 0;
    final stockColor = !inStock
        ? Colors.red
        : (lowStock ? Colors.orange : Colors.green);

    return InkWell(
      onTap: () => _openForm(product: product),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          Colors.blueGrey.shade50,
                          Colors.blueGrey.shade100,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.remove_red_eye_outlined,
                        size: 24,
                        color: Colors.blueGrey.shade300,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: _chip(
                    label: categoryLabel,
                    background: Colors.white.withOpacity(0.9),
                    foreground: Colors.blueGrey.shade700,
                  ),
                ),
                if (lowStock || !inStock)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _chip(
                      label: !inStock ? "Tugagan" : "Qoldiq past",
                      background: stockColor.withOpacity(0.12),
                      foreground: stockColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              product.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  product.price.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "UZS",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                _chip(
                  label: "Stok: ${product.stockQty}",
                  background: stockColor.withOpacity(0.12),
                  foreground: stockColor,
                ),
              ],
            ),
            const SizedBox(height: 3),
            if ((product.sku ?? '').isNotEmpty ||
                (product.barcode ?? '').isNotEmpty)
              Text(
                (product.sku ?? '').isNotEmpty
                    ? "SKU: ${product.sku}"
                    : "Barcode: ${product.barcode}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

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
    return ResponsiveFrame(
      maxWidth: 1800,
      child: Column(
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

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = _columnsForWidth(constraints.maxWidth);
                    if (columns <= 1) {
                      return ListView.separated(
                        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 80),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final product = list[index];
                          final lowStock =
                              product.minStock > 0 && product.stockQty <= product.minStock;
                          return _productCard(product, lowStock);
                        },
                      );
                    }

                    const spacing = 8.0;
                    final availableWidth =
                        constraints.maxWidth - (12 * 2);
                    final itemWidth =
                        (availableWidth - (spacing * (columns - 1))) /
                            columns;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 80),
                      child: Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: list.map((product) {
                          final lowStock =
                              product.minStock > 0 && product.stockQty <= product.minStock;

                          return SizedBox(
                            width: itemWidth,
                            child: _productCard(product, lowStock),
                          );
                        }).toList(),
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
      ),
    );
  }
}
