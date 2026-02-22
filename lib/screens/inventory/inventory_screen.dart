import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../services/inventory_service.dart';
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
  String _query = '';

  static const Map<String, String> _categories = {
    'frame': "Ko'zoynak",
    'lens': 'Linza',
    'contact_lens': 'Kontakt linza',
    'accessory': 'Aksesuar',
    'service': 'Xizmat',
    'other': 'Boshqa',
  };

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
            decoration: const InputDecoration(
              hintText: "Mahsulot nomi yoki shtrix-kod",
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
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

              final list = _filter(snapshot.data ?? []);

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
                                  _categories[product.category] ?? 'Boshqa',
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
