import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../models/billing_model.dart';
import '../../models/customer_model.dart';
import '../../models/loyalty_config_model.dart';
import '../../models/product_model.dart';
import '../../models/sale_item.dart';
import '../../models/sale_model.dart';
import '../../screens/inventory/barcode_scanner_screen.dart';
import '../../utils/barcode_keyboard_listener.dart';
import '../../utils/scan_sound.dart';
import '../../services/customer_service.dart';
import '../../services/inventory_service.dart';
import '../../services/loyalty_card_store.dart';
import '../../services/optica_service.dart';
import '../../services/sales_service.dart';
import '../../widgets/common/app_loader.dart';
import '../../utils/loyalty_utils.dart';

class PosScreen extends StatefulWidget {
  final String opticaId;

  const PosScreen({super.key, required this.opticaId});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _inventoryService = InventoryService();
  final _salesService = SalesService();
  final _customerService = CustomerService();
  final _loyaltyCardStore = LoyaltyCardStore();
  final _opticaService = OpticaService();
  final _uuid = const Uuid();
  final _searchController = TextEditingController();

  String _query = '';
  final List<_CartItem> _cart = [];
  CustomerModel? _selectedCustomer;
  List<ProductModel> _productsCache = [];
  LoyaltyConfigModel? _loyaltyConfig;
  int _barcodeToken = -1;

  static const List<String> _paymentMethods = [
    'Naqd',
    'Karta',
    "O'tkazma",
  ];
  static const String _discountPercent = 'percent';
  static const String _discountFixed = 'fixed';

  @override
  void initState() {
    super.initState();
    _loadLoyaltyConfig();
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

  Future<void> _loadLoyaltyConfig() async {
    try {
      final config = await _opticaService.getLoyaltyConfig(widget.opticaId);
      if (!mounted) return;
      setState(() => _loyaltyConfig = config);
    } catch (_) {
      // ignore failures; POS can continue without loyalty config
    }
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

  Future<void> _scanBarcode() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _PosScanScreen(
          cart: _cart,
          onScan: _handleScan,
          onCheckout: () {
            if (_cart.isEmpty) return;
            Future.microtask(_checkout);
          },
        ),
      ),
    );
  }

  _ScanFeedback? _handleScan(String code) {
    final normalized = code.trim();
    if (normalized.isEmpty) return null;

    _searchController.text = normalized;
    _searchController.selection =
        TextSelection.fromPosition(TextPosition(offset: normalized.length));
    setState(() => _query = normalized);

    if (_productsCache.isEmpty) {
      return const _ScanFeedback(
        message: "Mahsulotlar yuklanmoqda",
        success: false,
      );
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
      return const _ScanFeedback(
        message: "Mahsulot topilmadi",
        success: false,
      );
    }

    final added = _addToCartInternal(product);
    if (added) {
      setState(() {});
      return _ScanFeedback(
        message: "${product.name} savatga qo'shildi",
        success: true,
      );
    }
    return const _ScanFeedback(
      message: "Stok yetarli emas",
      success: false,
    );
  }

  void _handleKeyboardScan(String code) {
    final feedback = _handleScan(code);
    if (feedback == null || !mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(feedback.message)),
    );
  }

  double get _total {
    return _cart.fold(0, (sum, item) => sum + item.total);
  }

  bool _addToCartInternal(ProductModel product) {
    final index = _cart.indexWhere((e) => e.product.id == product.id);
    final currentQty = index >= 0 ? _cart[index].quantity : 0;

    if (product.stockQty <= currentQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Stok yetarli emas")),
      );
      return false;
    }

    if (index >= 0) {
      _cart[index] = _cart[index].copyWith(quantity: currentQty + 1);
    } else {
      _cart.add(_CartItem(product: product, quantity: 1));
    }
    return true;
  }

  void _addToCart(ProductModel product) {
    if (_addToCartInternal(product)) {
      setState(() {});
    }
  }

  void _removeFromCartInternal(ProductModel product) {
    final index = _cart.indexWhere((e) => e.product.id == product.id);
    if (index < 0) return;

    final current = _cart[index];
    if (current.quantity <= 1) {
      _cart.removeAt(index);
    } else {
      _cart[index] = current.copyWith(quantity: current.quantity - 1);
    }
  }

  void _removeFromCart(ProductModel product) {
    _removeFromCartInternal(product);
    setState(() {});
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;

    String paymentMethod = _paymentMethods.first;
    final noteController = TextEditingController();
    String discountType = _discountPercent;
    final discountController = TextEditingController(text: '0');
    final paidController =
        TextEditingController(text: _total.toStringAsFixed(0));
    bool paidEdited = false;
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));
    bool saving = false;
    final double loyaltyPercent =
        ((_loyaltyConfig?.discountPercent ?? 0).clamp(0, 100)).toDouble();
    final int loyaltyMinPurchases =
        (_loyaltyConfig?.minPurchasesForDiscount ?? 1).clamp(1, 999).toInt();
    bool loyaltyApplied = false;
    String manualDiscountType = discountType;
    double manualDiscountValue = 0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double subtotal() => _total;

            double _parseNumber(String raw) {
              return double.tryParse(raw.trim()) ?? 0;
            }

            double _clampDiscountValue(double value, double subtotal) {
              if (value < 0) return 0;
              if (discountType == _discountPercent) {
                return value > 100 ? 100 : value;
              }
              return value > subtotal ? subtotal : value;
            }

            String _formatNumber(double value) {
              if (value % 1 == 0) {
                return value.toStringAsFixed(0);
              }
              return value.toStringAsFixed(2);
            }

            double discountValue() {
              final raw = _parseNumber(discountController.text);
              return _clampDiscountValue(raw, subtotal());
            }

            double discountAmount() {
              final value = discountValue();
              if (discountType == _discountPercent) {
                return subtotal() * (value / 100);
              }
              return value;
            }

            double totalAfterDiscount() {
              final total = subtotal() - discountAmount();
              return total < 0 ? 0.0 : total;
            }

            void _syncDiscountController() {
              final clamped = discountValue();
              final text = _formatNumber(clamped);
              if (discountController.text != text) {
                discountController.text = text;
                discountController.selection =
                    TextSelection.fromPosition(TextPosition(offset: text.length));
              }
            }

            bool _isLoyaltyEligible() {
              final purchases = _selectedCustomer?.loyaltyPurchaseCount ?? 0;
              return loyaltyPercent > 0 &&
                  (_selectedCustomer?.loyaltyEnabled ?? false) &&
                  purchases >= loyaltyMinPurchases;
            }

            void _cacheManualDiscount() {
              manualDiscountType = discountType;
              manualDiscountValue = _parseNumber(discountController.text);
            }

            void _applyLoyalty(bool apply) {
              if (apply) {
                if (!loyaltyApplied) {
                  _cacheManualDiscount();
                }
                discountType = _discountPercent;
                discountController.text = loyaltyPercent.toStringAsFixed(0);
                loyaltyApplied = true;
              } else {
                loyaltyApplied = false;
                discountType = manualDiscountType;
                discountController.text =
                    _formatNumber(_clampDiscountValue(manualDiscountValue, subtotal()));
              }
            }

            void _refreshLoyalty() {
              final eligible = _isLoyaltyEligible();
              if (!eligible) {
                if (loyaltyApplied) {
                  _applyLoyalty(false);
                }
                return;
              }
              // Do not auto-apply loyalty; only apply when user toggles.
            }

            void update(VoidCallback fn) {
              fn();
              _refreshLoyalty();
              _syncDiscountController();
              if (!paidEdited) {
                paidController.text = totalAfterDiscount().toStringAsFixed(0);
                paidController.selection = TextSelection.fromPosition(
                  TextPosition(offset: paidController.text.length),
                );
              }
              setState(() {});
              setModalState(() {});
            }

            _refreshLoyalty();

            Future<void> scanLoyaltyCard() async {
              final code = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => const BarcodeScannerScreen(
                    title: "Loyalty kartani skanerlash",
                    hint: "Kamerani loyalty QR kodga yo'naltiring",
                  ),
                ),
              );

              if (code == null || code.trim().isEmpty) return;

              final parsed = parseLoyaltyQrData(code);
              if (parsed == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Loyalty QR noto'g'ri")),
                );
                return;
              }

              if (parsed.opticaId != widget.opticaId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Bu karta boshqa optikaga tegishli")),
                );
                return;
              }

              final card = await _loyaltyCardStore.getCard(
                opticaId: widget.opticaId,
                cardId: parsed.cardId,
              );

              if (card == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Loyalty karta topilmadi")),
                );
                return;
              }

              CustomerModel? customer;

              if (card.isLinked) {
                customer = await _customerService.getCustomer(
                  opticaId: widget.opticaId,
                  customerId: card.customerId!,
                );
                if (customer == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Mijoz topilmadi")),
                  );
                  return;
                }

                if (!customer.loyaltyEnabled) {
                  await _customerService.setLoyaltyEnabled(
                    opticaId: widget.opticaId,
                    customerId: customer.id,
                    enabled: true,
                  );
                  customer = customer.copyWith(loyaltyEnabled: true);
                }
              } else {
                final selected = _selectedCustomer;
                String? action;
                if (selected != null) {
                  action = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Karta biriktirilmagan"),
                      content: Text(
                        "Kartani ${selected.firstName} ${selected.lastName ?? ""} mijoziga biriktirasizmi?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, "cancel"),
                          child: const Text("Bekor"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, "other"),
                          child: const Text("Boshqa mijoz"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, "selected"),
                          child: const Text("Biriktirish"),
                        ),
                      ],
                    ),
                  );
                } else {
                  action = "other";
                }

                if (action == "selected") {
                  customer = selected;
                } else if (action == "other") {
                  customer = await _pickCustomer();
                } else {
                  return;
                }

                if (customer == null) return;

                await _loyaltyCardStore.linkCard(
                  opticaId: widget.opticaId,
                  cardId: card.id,
                  customerId: customer.id,
                );

                await _customerService.setLoyaltyEnabled(
                  opticaId: widget.opticaId,
                  customerId: customer.id,
                  enabled: true,
                );
              }

              final effectiveCustomer = customer == null
                  ? null
                  : (customer.loyaltyEnabled
                      ? customer
                      : customer.copyWith(loyaltyEnabled: true));

              update(() {
                if (loyaltyApplied) {
                  _applyLoyalty(false);
                }
                _selectedCustomer = effectiveCustomer;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("${effectiveCustomer?.firstName ?? "Mijoz"} loyalty kartasi qo'llandi"),
                ),
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    const Text(
                      "Savat",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    ..._cart.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    "${item.product.price.toStringAsFixed(0)} UZS",
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => update(() => _removeFromCartInternal(item.product)),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(item.quantity.toString()),
                            IconButton(
                              onPressed: () => update(() => _addToCartInternal(item.product)),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${item.total.toStringAsFixed(0)}",
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    const Divider(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Subtotal",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${subtotal().toStringAsFixed(0)} UZS",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE6E9EF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Chegirma",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              Text(
                                "-${discountAmount().toStringAsFixed(0)} UZS",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          if ((_selectedCustomer?.loyaltyEnabled ?? false) &&
                              loyaltyPercent > 0) ...[
                            const SizedBox(height: 10),
                            Builder(
                              builder: (context) {
                                final purchases =
                                    _selectedCustomer?.loyaltyPurchaseCount ?? 0;
                                final remaining =
                                    (loyaltyMinPurchases - purchases).clamp(0, 999);
                                final eligible = _isLoyaltyEligible();

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE6E9EF)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.card_membership, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Loyalty chegirma (${loyaltyPercent.toStringAsFixed(0)}%)",
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          Switch(
                                            value: loyaltyApplied,
                                            onChanged: eligible
                                                ? (value) => update(() {
                                                      _applyLoyalty(value);
                                                    })
                                                : null,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      if (eligible && !loyaltyApplied)
                                        Text(
                                          "Chegirma tayyor: -${(subtotal() * (loyaltyPercent / 100)).toStringAsFixed(0)} UZS",
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      if (eligible && loyaltyApplied)
                                        const Text(
                                          "Loyalty chegirma qo'llanildi",
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      if (!eligible)
                                        Text(
                                          "Chegirma uchun ${remaining} ta xarid qolgan ($purchases/$loyaltyMinPurchases)",
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text("Foiz (%)"),
                                  selected: discountType == _discountPercent,
                                  onSelected: loyaltyApplied
                                      ? null
                                      : (_) => update(() {
                                            discountType = _discountPercent;
                                            discountController.text = '0';
                                          }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text("Summasi (UZS)"),
                                  selected: discountType == _discountFixed,
                                  onSelected: loyaltyApplied
                                      ? null
                                      : (_) => update(() {
                                            discountType = _discountFixed;
                                            discountController.text = '0';
                                          }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: discountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            enabled: !loyaltyApplied,
                            decoration: InputDecoration(
                              labelText: discountType == _discountPercent
                                  ? "Chegirma foizi"
                                  : "Chegirma summasi",
                              suffixText: discountType == _discountPercent ? "%" : "UZS",
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => update(() {}),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (discountType == _discountPercent
                                    ? [5, 10, 15, 20]
                                    : [5000, 10000, 20000, 50000])
                                .map((value) {
                              final label = discountType == _discountPercent
                                  ? "$value%"
                                  : "${value.toString()} UZS";
                              return InkWell(
                                onTap: loyaltyApplied
                                    ? null
                                    : () => update(() {
                                          discountController.text = value.toString();
                                        }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE6E9EF)),
                                  ),
                                  child: Text(
                                    label,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Jami",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${totalAfterDiscount().toStringAsFixed(0)} UZS",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: paidController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: "To'langan summa",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        paidEdited = true;
                        update(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final paidAmount =
                            double.tryParse(paidController.text.trim()) ?? 0;
                        final remaining = totalAfterDiscount() - paidAmount;
                        final remainingText = remaining > 0
                            ? "Qolgan: ${remaining.toStringAsFixed(0)} UZS"
                            : remaining < 0
                                ? "To'lov ortiqcha kiritilgan"
                                : "To'liq to'landi";
                        final remainingColor = remaining > 0
                            ? Colors.red
                            : remaining < 0
                                ? Colors.orange
                                : Colors.green;

                        return Text(
                          remainingText,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: remainingColor,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    Builder(
                      builder: (context) {
                        final paidAmount =
                            double.tryParse(paidController.text.trim()) ?? 0;
                        final remaining = totalAfterDiscount() - paidAmount;
                        const isRequired = false;

                        final hasCustomer = _selectedCustomer != null;
                        final label = isRequired
                            ? "Xaridor (majburiy)"
                            : "Xaridor (ixtiyoriy)";
                        final name = hasCustomer
                            ? "${_selectedCustomer!.firstName} ${_selectedCustomer!.lastName ?? ""}"
                                .trim()
                            : "Xaridor tanlang";
                        final helper = hasCustomer
                            ? _selectedCustomer!.phone
                            : "Ism yoki telefon bo‘yicha qidiruv";
                        final borderColor = Colors.grey.shade300;

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final picked = await _pickCustomer();
                            if (picked != null) {
                              update(() {
                                if (loyaltyApplied) {
                                  _applyLoyalty(false);
                                }
                                _selectedCustomer = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 36,
                                  width: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: hasCustomer
                                              ? Colors.black
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
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
                                    onPressed: () =>
                                        update(() {
                                          if (loyaltyApplied) {
                                            _applyLoyalty(false);
                                          }
                                          _selectedCustomer = null;
                                        }),
                                    icon: const Icon(Icons.close, size: 18),
                                    tooltip: "Tozalash",
                                  ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: scanLoyaltyCard,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text("Loyalty kartani skanerlash"),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Builder(
                      builder: (context) {
                        final paidAmount =
                            double.tryParse(paidController.text.trim()) ?? 0;
                        final remaining = totalAfterDiscount() - paidAmount;

                        if (remaining <= 0) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "To'lov muddati",
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: dueDate,
                                  firstDate: now,
                                  lastDate: DateTime(now.year + 5),
                                );
                                if (picked != null) {
                                  update(() => dueDate = picked);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  "${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}",
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),

                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: const InputDecoration(
                        labelText: "To'lov usuli",
                        border: OutlineInputBorder(),
                      ),
                      items: _paymentMethods
                          .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m),
                      ))
                          .toList(),
                      onChanged: (val) => setModalState(() => paymentMethod = val ?? _paymentMethods.first),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: "Izoh (ixtiyoriy)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                          update(() => saving = true);

                          final paidAmount =
                              double.tryParse(paidController.text.trim()) ?? 0;

                          final items = _cart.map((c) {
                            return SaleItem(
                              productId: c.product.id,
                              name: c.product.name,
                              category: c.product.category,
                              quantity: c.quantity,
                              price: c.product.price,
                              cost: c.product.cost,
                            );
                          }).toList();

                          final subtotal = items.fold<double>(
                            0,
                                (sum, item) => sum + item.total,
                          );
                          final discountValueParsed = _clampDiscountValue(
                            _parseNumber(discountController.text),
                            subtotal,
                          );
                          final discountTotal = discountType == _discountPercent
                              ? subtotal * (discountValueParsed / 100)
                              : discountValueParsed;
                          final total = (subtotal - discountTotal) < 0
                              ? 0.0
                              : (subtotal - discountTotal);
                          final remaining = total - paidAmount;
                          final discountTypeValue = discountType;

                          if (paidAmount < 0 || paidAmount > total) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("To'lov summasi noto'g'ri"),
                              ),
                            );
                            update(() => saving = false);
                            return;
                          }

                          final shouldCreateBilling =
                              remaining > 0 && _selectedCustomer != null;
                          final billingId =
                              shouldCreateBilling ? _uuid.v4() : null;

                          final sale = SaleModel(
                            id: _uuid.v4(),
                            opticaId: widget.opticaId,
                            customerId: _selectedCustomer?.id,
                            customerName: _selectedCustomer == null
                                ? null
                                : "${_selectedCustomer!.firstName} ${_selectedCustomer!.lastName ?? ""}"
                                    .trim(),
                            billingId: billingId,
                            items: items,
                            subtotal: subtotal,
                            discount: discountTotal,
                            discountType: discountTypeValue,
                            discountValue: discountValueParsed,
                            total: total,
                            paidAmount: paidAmount,
                            dueAmount: remaining > 0 ? remaining : 0,
                            paymentMethod: paymentMethod,
                            note: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                            createdAt: Timestamp.now(),
                          );

                          BillingModel? billing;
                          if (shouldCreateBilling) {
                            final now = Timestamp.now();
                            billing = BillingModel(
                              id: billingId!,
                              opticaId: widget.opticaId,
                              customerId: _selectedCustomer!.id,
                              customerName:
                                  "${_selectedCustomer!.firstName} ${_selectedCustomer!.lastName ?? ""}"
                                      .trim(),
                              amountDue: total,
                              amountPaid: paidAmount,
                              dueDate: Timestamp.fromDate(dueDate),
                              createdAt: now,
                              updatedAt: now,
                            );
                          }

                          try {
                            await _salesService.createSale(
                              opticaId: widget.opticaId,
                              sale: sale,
                              billing: billing,
                            );
                            update(() => _cart.clear());
                            update(() => _selectedCustomer = null);
                            if (mounted) Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Sotuv yakunlandi")),
                            );
                          } catch (e) {
                            print('error $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Sotuvda xatolik")),
                            );
                          } finally {
                            update(() => saving = false);
                          }
                        },
                        child: saving
                            ? const AppLoader(size: 20, fill: false)
                            : const Text("Sotish"),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      noteController.dispose();
      paidController.dispose();
      discountController.dispose();
    });
  }

  Future<CustomerModel?> _pickCustomer() async {
    return showModalBottomSheet<CustomerModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return _CustomerPickerSheet(
          opticaId: widget.opticaId,
          service: _customerService,
        );
      },
    );
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
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ProductModel>>(
            stream: _inventoryService.watchProducts(widget.opticaId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoader();
              }

              if (snapshot.hasError) {
                print('Error: ${snapshot.error}');
                return const Center(child: Text("Nimadir noto'g'ri ketdi"));
              }

              _productsCache = snapshot.data ?? [];
              final list = _filter(_productsCache);

              if (list.isEmpty) {
                return const Center(child: Text("Mahsulot topilmadi"));
              }

              return ListView.separated(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 90),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = list[index];
                  final inCart = _cart.firstWhere(
                        (e) => e.product.id == product.id,
                    orElse: () => _CartItem(product: product, quantity: 0),
                  );

                  return Container(
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
                                "${product.price.toStringAsFixed(0)} UZS",
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Stok: ${product.stockQty}",
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        if (inCart.quantity > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${inCart.quantity}x",
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(64, 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: product.stockQty <= 0 ? null : () => _addToCart(product),
                          child: const Text("Qo'shish"),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Savat: ${_cart.length} ta | ${_total.toStringAsFixed(0)} UZS",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(64, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onPressed: _cart.isEmpty ? null : _checkout,
                child: const Text("To'lov"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartItem {
  final ProductModel product;
  final int quantity;

  const _CartItem({required this.product, required this.quantity});

  double get total => product.price * quantity;

  _CartItem copyWith({int? quantity}) {
    return _CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class _ScanFeedback {
  final String message;
  final bool success;

  const _ScanFeedback({required this.message, required this.success});
}

class _PosScanScreen extends StatefulWidget {
  final List<_CartItem> cart;
  final _ScanFeedback? Function(String code) onScan;
  final VoidCallback? onCheckout;

  const _PosScanScreen({
    required this.cart,
    required this.onScan,
    this.onCheckout,
  });

  @override
  State<_PosScanScreen> createState() => _PosScanScreenState();
}

class _PosScanScreenState extends State<_PosScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _checkingPermission = true;
  bool _hasPermission = false;
  bool _permanentlyDenied = false;
  DateTime? _lastScanAt;
  String? _lastValue;
  String? _statusMessage;
  Color _statusColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _ensurePermission();
  }

  Future<void> _ensurePermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (!mounted) return;
      setState(() {
        _hasPermission = true;
        _checkingPermission = false;
        _permanentlyDenied = false;
      });
      return;
    }

    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      setState(() {
        _hasPermission = false;
        _checkingPermission = false;
        _permanentlyDenied = true;
      });
      return;
    }

    final request = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _hasPermission = request.isGranted;
      _checkingPermission = false;
      _permanentlyDenied = request.isPermanentlyDenied;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    String? value;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        value = raw.trim();
        break;
      }
    }
    if (value == null || value.trim().isEmpty) return;

    final now = DateTime.now();
    final recent = _lastScanAt != null &&
        now.difference(_lastScanAt!).inMilliseconds < 800;
    if (recent && value == _lastValue) return;
    _lastScanAt = now;
    _lastValue = value;

    final feedback = widget.onScan(value);
    if (feedback == null) return;

    ScanSound.play();
    if (feedback.success) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    setState(() {
      _statusMessage = feedback.message;
      _statusColor = feedback.success ? Colors.green : Colors.red;
    });
  }

  int get _totalItems =>
      widget.cart.fold(0, (sum, item) => sum + item.quantity);

  double get _totalAmount =>
      widget.cart.fold(0.0, (sum, item) => sum + item.total);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("POS skanerlash"),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: _hasPermission ? () => _controller.toggleTorch() : null,
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Tugatish",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _checkingPermission
          ? const Center(child: AppLoader())
          : !_hasPermission
              ? _permissionView()
              : Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error, child) {
                        return const Center(
                          child: Text("Kamerani ishga tushirib bo'lmadi"),
                        );
                      },
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 260,
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.8),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    DraggableScrollableSheet(
                      initialChildSize: 0.28,
                      minChildSize: 0.18,
                      maxChildSize: 0.6,
                      builder: (context, controller) {
                        return Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 16,
                                offset: Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Savat: $_totalItems ta",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${_totalAmount.toStringAsFixed(0)} UZS",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: widget.onCheckout == null
                                        ? null
                                        : () {
                                            Navigator.pop(context);
                                            widget.onCheckout?.call();
                                          },
                                    child: const Text("To'lov"),
                                  ),
                                ],
                              ),
                              if (_statusMessage != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _statusMessage!,
                                    style: TextStyle(
                                      color: _statusColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Expanded(
                                child: widget.cart.isEmpty
                                    ? const Center(
                                        child: Text(
                                          "Savat bo'sh. Skanerlashni boshlang.",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      )
                                    : ListView.separated(
                                        controller: controller,
                                        itemCount: widget.cart.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 12),
                                        itemBuilder: (context, index) {
                                          final item = widget.cart[index];
                                          return Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.product.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "${item.quantity} x ${item.product.price.toStringAsFixed(0)}",
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                item.total.toStringAsFixed(0),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
    );
  }

  Widget _permissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              "Kameraga ruxsat kerak",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              "Shtrix-kodlarni skanerlash uchun kameraga ruxsat bering.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final permanentlyDenied =
                      await Permission.camera.isPermanentlyDenied;
                  if (permanentlyDenied) {
                    await openAppSettings();
                    await _ensurePermission();
                  } else {
                    setState(() => _checkingPermission = true);
                    await _ensurePermission();
                  }
                },
                child: Text(
                  _permanentlyDenied ? "Sozlamalarni ochish" : "Ruxsat berish",
                ),
              ),
            ),
          ],
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
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 16,
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
                      "Xaridor tanlash",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AppLoader();
                    }

                    if (snapshot.hasError) {
                      return const Center(child: Text("Nimadir noto'g'ri ketdi"));
                    }

                    final list = _filter(snapshot.data ?? []);

                    if (list.isEmpty) {
                      return const Center(child: Text("Xaridor topilmadi"));
                    }

                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = list[index];
                        final name =
                            "${customer.firstName} ${customer.lastName ?? ""}".trim();

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
