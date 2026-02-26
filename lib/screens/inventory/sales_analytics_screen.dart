import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../services/inventory_service.dart';
import '../../services/sales_service.dart';
import '../../utils/inventory_categories.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/empty_state.dart';

class SalesAnalyticsScreen extends StatefulWidget {
  final String opticaId;

  const SalesAnalyticsScreen({super.key, required this.opticaId});

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen> {
  final _salesService = SalesService();
  final _inventoryService = InventoryService();
  final _currency = NumberFormat('#,##0', 'en_US');
  final _monthFormat = DateFormat('MMM yy', 'en_US');

  String _rangePreset = '30d'; // all | 7d | 30d | 90d | custom
  DateTimeRange? _range;
  int _targetDays = 14;

  @override
  void initState() {
    super.initState();
    _setPresetRange(_rangePreset);
  }

  void _setPresetRange(String preset) {
    final now = DateTime.now();
    if (preset == 'all') {
      setState(() {
        _rangePreset = preset;
        _range = null;
      });
      return;
    }

    DateTime start;
    if (preset == '7d') {
      start = now.subtract(const Duration(days: 6));
    } else if (preset == '90d') {
      start = now.subtract(const Duration(days: 89));
    } else {
      start = now.subtract(const Duration(days: 29));
    }

    setState(() {
      _rangePreset = preset;
      _range = DateTimeRange(start: start, end: now);
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _range ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 29)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );

    if (picked != null) {
      setState(() {
        _rangePreset = 'custom';
        _range = picked;
      });
    }
  }

  List<SaleModel> _filterByRange(List<SaleModel> sales) {
    if (_range == null) return sales;
    final start = DateTime(
      _range!.start.year,
      _range!.start.month,
      _range!.start.day,
    );
    final end = DateTime(
      _range!.end.year,
      _range!.end.month,
      _range!.end.day,
      23,
      59,
      59,
      999,
    );
    return sales
        .where((sale) {
          final date = sale.createdAt.toDate();
          return !date.isBefore(start) && !date.isAfter(end);
        })
        .toList();
  }

  int _rangeDays(List<SaleModel> allSales) {
    if (_range != null) {
      return max(1, _range!.duration.inDays + 1);
    }
    if (allSales.isEmpty) return 30;
    final dates = allSales.map((s) => s.createdAt.toDate()).toList();
    dates.sort();
    final diff = DateTime.now().difference(dates.first).inDays;
    return max(1, diff + 1);
  }

  _AnalyticsResult _computeAnalytics({
    required List<SaleModel> allSales,
    required List<SaleModel> filteredSales,
    required List<ProductModel> products,
  }) {
    final productStats = <String, _ProductAggregate>{};

    double revenue = 0;
    double cost = 0;
    double discount = 0;
    double grossProfit = 0;
    double paid = 0;
    double due = 0;
    double negativeMargin = 0;

    for (final sale in filteredSales) {
      revenue += sale.total;
      discount += sale.discount;
      paid += sale.paidAmount;
      due += sale.dueAmount;

      for (final item in sale.items) {
        final stats = productStats.putIfAbsent(
          item.productId,
          () => _ProductAggregate(id: item.productId),
        );
        final itemRevenue = item.price * item.quantity;
        final itemCost = item.cost * item.quantity;
        stats.qty += item.quantity;
        stats.revenue += itemRevenue;
        stats.cost += itemCost;
        stats.profit += (itemRevenue - itemCost);
        if (itemCost > itemRevenue) {
          negativeMargin += (itemCost - itemRevenue);
        }
      }
    }

    for (final stats in productStats.values) {
      cost += stats.cost;
      grossProfit += stats.profit;
    }

    final netProfit = grossProfit - discount;
    final margin = revenue <= 0 ? 0.0 : (netProfit / revenue) * 100;
    final days = _rangeDays(allSales);
    final avgDailyRevenue = revenue / days;

    final insights = products.map((product) {
      final stats = productStats[product.id];
      return _ProductInsight(
        product: product,
        qty: stats?.qty ?? 0,
        revenue: stats?.revenue ?? 0,
        profit: stats?.profit ?? 0,
      );
    }).toList();

    final fastMoving = insights
        .where((i) => i.qty > 0)
        .toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
    final slowMoving = insights.toList()
      ..sort((a, b) => a.qty.compareTo(b.qty));

    final reorderSuggestions = _buildReorderSuggestions(
      insights: insights,
      rangeDays: days,
    );

    final seasonal = _buildSeasonalTrend(allSales);

    return _AnalyticsResult(
      revenue: revenue,
      cost: cost,
      discount: discount,
      grossProfit: grossProfit,
      netProfit: netProfit,
      negativeMargin: negativeMargin,
      paid: paid,
      due: due,
      marginPercent: margin,
      avgDailyRevenue: avgDailyRevenue,
      fastMoving: fastMoving.take(5).toList(),
      slowMoving: slowMoving.take(5).toList(),
      reorderSuggestions: reorderSuggestions,
      seasonalTrend: seasonal,
    );
  }

  List<_ReorderSuggestion> _buildReorderSuggestions({
    required List<_ProductInsight> insights,
    required int rangeDays,
  }) {
    final suggestions = <_ReorderSuggestion>[];
    for (final insight in insights) {
      final product = insight.product;
      final dailyVelocity = rangeDays <= 0 ? 0.0 : insight.qty / rangeDays;
      final targetQty = (dailyVelocity * _targetDays).ceil();
      final byVelocity = max(0, targetQty - product.stockQty);
      final byMinStock = max(0, product.minStock - product.stockQty);
      final recommended = max(byVelocity, byMinStock);
      if (recommended <= 0) continue;

      suggestions.add(
        _ReorderSuggestion(
          product: product,
          dailyVelocity: dailyVelocity,
          recommendedQty: recommended,
        ),
      );
    }

    suggestions.sort(
      (a, b) => b.recommendedQty.compareTo(a.recommendedQty),
    );
    return suggestions.take(10).toList();
  }

  List<_MonthlyTrend> _buildSeasonalTrend(List<SaleModel> allSales) {
    final now = DateTime.now();
    final months = <DateTime>[];
    for (var i = 11; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i, 1));
    }

    final totals = <String, double>{};
    for (final sale in allSales) {
      final date = sale.createdAt.toDate();
      final key = _monthKey(date);
      totals.update(key, (v) => v + sale.total, ifAbsent: () => sale.total);
    }

    return months.map((month) {
      final key = _monthKey(month);
      return _MonthlyTrend(
        month: month,
        revenue: totals[key] ?? 0,
      );
    }).toList();
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SaleModel>>(
      stream: _salesService.watchSales(widget.opticaId, limit: 500),
      builder: (context, salesSnapshot) {
        if (salesSnapshot.connectionState == ConnectionState.waiting) {
          return const AppLoader();
        }
        if (salesSnapshot.hasError) {
          return const Center(child: Text("Nimadir noto'g'ri ketdi"));
        }
        final allSales = salesSnapshot.data ?? [];
        final filteredSales = _filterByRange(allSales);

        return StreamBuilder<List<ProductModel>>(
          stream: _inventoryService.watchProducts(widget.opticaId),
          builder: (context, productSnapshot) {
            if (productSnapshot.connectionState == ConnectionState.waiting) {
              return const AppLoader();
            }
            if (productSnapshot.hasError) {
              return const Center(child: Text("Nimadir noto'g'ri ketdi"));
            }

            final products = productSnapshot.data ?? [];
            if (allSales.isEmpty) {
              return const EmptyState(
                title: "Hisobot uchun sotuvlar yo'q",
                subtitle: "Analitika ko'rish uchun sotuvlar kerak",
              );
            }

            final analytics = _computeAnalytics(
              allSales: allSales,
              filteredSales: filteredSales,
              products: products,
            );

            return Column(
              children: [
                _filters(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _sectionTitle("Savdo va foyda"),
                      _metricGrid(analytics),
                      const SizedBox(height: 16),
                      _sectionTitle("Tez aylanadigan mahsulotlar"),
                      _productListCard(analytics.fastMoving, emptyLabel: "Ma'lumot yo'q"),
                      const SizedBox(height: 16),
                      _sectionTitle("Sekin aylanadigan mahsulotlar"),
                      _productListCard(analytics.slowMoving, emptyLabel: "Ma'lumot yo'q"),
                      const SizedBox(height: 16),
                      _sectionTitle("Qayta buyurtma tavsiyasi"),
                      _reorderCard(analytics.reorderSuggestions),
                      const SizedBox(height: 16),
                      _sectionTitle("Mavsumiy trend (12 oy)"),
                      _seasonalCard(analytics.seasonalTrend),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _rangeChip('all', 'Barcha'),
                const SizedBox(width: 8),
                _rangeChip('7d', '7 kun'),
                const SizedBox(width: 8),
                _rangeChip('30d', '30 kun'),
                const SizedBox(width: 8),
                _rangeChip('90d', '90 kun'),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _pickCustomRange,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _rangePreset == 'custom'
                          ? Colors.black
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Text(
                      _rangePreset == 'custom' && _range != null
                          ? "${DateFormat('yyyy-MM-dd').format(_range!.start)} - ${DateFormat('yyyy-MM-dd').format(_range!.end)}"
                          : "Oraliq",
                      style: TextStyle(
                        color: _rangePreset == 'custom'
                            ? Colors.white
                            : Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                "Reorder (kun):",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              _targetChip(7),
              const SizedBox(width: 8),
              _targetChip(14),
              const SizedBox(width: 8),
              _targetChip(30),
            ],
          ),
        ],
      ),
    );
  }

  Widget _targetChip(int value) {
    final isActive = _targetDays == value;
    return InkWell(
      onTap: () => setState(() => _targetDays = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black),
        ),
        child: Text(
          "$value",
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _rangeChip(String value, String label) {
    final isActive = _rangePreset == value;
    return InkWell(
      onTap: () => _setPresetRange(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _metricGrid(_AnalyticsResult analytics) {
    final netPositive = analytics.netProfit >= 0;
    final netLabel = netPositive ? "Sof foyda" : "Sof zarar";
    final netColor = netPositive ? Colors.green : Colors.red;
    final marginLabel = analytics.revenue <= 0
        ? ''
        : "Marja ${analytics.marginPercent.toStringAsFixed(1)}%";

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                title: "Savdo",
                value: "${_currency.format(analytics.revenue)} UZS",
                icon: Icons.shopping_bag,
                subtitle:
                    "O'rtacha: ${_currency.format(analytics.avgDailyRevenue)} / kun",
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                title: "Tannarx",
                value: "${_currency.format(analytics.cost)} UZS",
                icon: Icons.inventory_2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                title: "Chegirma",
                value: "${_currency.format(analytics.discount)} UZS",
                icon: Icons.percent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                title: netLabel,
                value: "${_currency.format(analytics.netProfit)} UZS",
                icon: Icons.trending_up,
                valueColor: netColor,
                subtitle: marginLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                title: "To'langan",
                value: "${_currency.format(analytics.paid)} UZS",
                icon: Icons.payments,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                title: "Qarz",
                value: "${_currency.format(analytics.due)} UZS",
                icon: Icons.credit_score,
                valueColor:
                    analytics.due > 0 ? Colors.orange : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        if (analytics.negativeMargin > 0) ...[
          const SizedBox(height: 12),
          _metricCard(
            title: "Salbiy marja (zarar)",
            value: "${_currency.format(analytics.negativeMargin)} UZS",
            icon: Icons.warning_amber_rounded,
            valueColor: Colors.red,
          ),
        ],
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    String? subtitle,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? Colors.black,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productListCard(List<_ProductInsight> items,
      {required String emptyLabel}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                emptyLabel,
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: items.map((item) {
                final label = inventoryCategoryLabel(item.product.category);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${item.qty} dona",
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "${_currency.format(item.revenue)} UZS",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _reorderCard(List<_ReorderSuggestion> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "Hozircha qayta buyurtma kerak emas",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Sotuv tezligi: ${item.dailyVelocity.toStringAsFixed(2)} / kun",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Stok: ${item.product.stockQty}",
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            "Tavsiya: ${item.recommendedQty}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _seasonalCard(List<_MonthlyTrend> items) {
    final maxValue =
        items.isEmpty ? 0 : items.map((e) => e.revenue).reduce(max);
    final peak = items.isEmpty
        ? null
        : items.reduce((a, b) => a.revenue >= b.revenue ? a : b);
    final low = items.isEmpty
        ? null
        : items.reduce((a, b) => a.revenue <= b.revenue ? a : b);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (peak != null && low != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Eng yuqori: ${_monthFormat.format(peak.month)}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Eng past: ${_monthFormat.format(low.month)}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Column(
            children: items.map((item) {
              final ratio = maxValue == 0 ? 0.0 : item.revenue / maxValue;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        _monthFormat.format(item.month),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: ratio,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text(
                        _currency.format(item.revenue),
                        textAlign: TextAlign.end,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsResult {
  final double revenue;
  final double cost;
  final double discount;
  final double grossProfit;
  final double netProfit;
  final double negativeMargin;
  final double paid;
  final double due;
  final double marginPercent;
  final double avgDailyRevenue;
  final List<_ProductInsight> fastMoving;
  final List<_ProductInsight> slowMoving;
  final List<_ReorderSuggestion> reorderSuggestions;
  final List<_MonthlyTrend> seasonalTrend;

  _AnalyticsResult({
    required this.revenue,
    required this.cost,
    required this.discount,
    required this.grossProfit,
    required this.netProfit,
    required this.negativeMargin,
    required this.paid,
    required this.due,
    required this.marginPercent,
    required this.avgDailyRevenue,
    required this.fastMoving,
    required this.slowMoving,
    required this.reorderSuggestions,
    required this.seasonalTrend,
  });
}

class _ProductAggregate {
  final String id;
  int qty = 0;
  double revenue = 0;
  double cost = 0;
  double profit = 0;

  _ProductAggregate({required this.id});
}

class _ProductInsight {
  final ProductModel product;
  final int qty;
  final double revenue;
  final double profit;

  _ProductInsight({
    required this.product,
    required this.qty,
    required this.revenue,
    required this.profit,
  });
}

class _ReorderSuggestion {
  final ProductModel product;
  final double dailyVelocity;
  final int recommendedQty;

  _ReorderSuggestion({
    required this.product,
    required this.dailyVelocity,
    required this.recommendedQty,
  });
}

class _MonthlyTrend {
  final DateTime month;
  final double revenue;

  _MonthlyTrend({required this.month, required this.revenue});
}
