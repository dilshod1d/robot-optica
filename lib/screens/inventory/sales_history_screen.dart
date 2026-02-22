import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sale_model.dart';
import '../../services/sales_service.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/stat_card.dart';

class SalesHistoryScreen extends StatefulWidget {
  final String opticaId;

  const SalesHistoryScreen({super.key, required this.opticaId});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _service = SalesService();
  final _currency = NumberFormat('#,##0', 'en_US');
  final _dateFormat = DateFormat('yyyy-MM-dd');

  String _query = '';
  String _filter = 'all'; // all | paid | partial
  String _rangePreset = 'all'; // all | today | 7d | 30d | custom
  DateTimeRange? _range;

  List<SaleModel> _filterSales(List<SaleModel> list) {
    final q = _query.trim().toLowerCase();
    final filtered = list.where((sale) {
      if (_range != null) {
        final date = sale.createdAt.toDate();
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
        if (date.isBefore(start) || date.isAfter(end)) {
          return false;
        }
      }

      if (_filter == 'paid' && sale.dueAmount > 0) return false;
      if (_filter == 'partial' && sale.dueAmount <= 0) return false;

      if (q.isEmpty) return true;
      final name = (sale.customerName ?? '').toLowerCase();
      return name.contains(q) || sale.id.toLowerCase().contains(q);
    }).toList();

    return filtered;
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

    if (preset == 'today') {
      final start = DateTime(now.year, now.month, now.day);
      setState(() {
        _rangePreset = preset;
        _range = DateTimeRange(start: start, end: start);
      });
      return;
    }

    if (preset == '7d') {
      final start = now.subtract(const Duration(days: 6));
      setState(() {
        _rangePreset = preset;
        _range = DateTimeRange(start: start, end: now);
      });
      return;
    }

    if (preset == '30d') {
      final start = now.subtract(const Duration(days: 29));
      setState(() {
        _rangePreset = preset;
        _range = DateTimeRange(start: start, end: now);
      });
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _range ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
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

  Map<String, double> _computeTotals(List<SaleModel> list) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(const Duration(days: 6));

    double todayTotal = 0;
    double weekTotal = 0;

    for (final sale in list) {
      final date = sale.createdAt.toDate();
      if (!date.isBefore(todayStart)) {
        todayTotal += sale.total;
      }
      if (!date.isBefore(weekStart)) {
        weekTotal += sale.total;
      }
    }

    return {
      'today': todayTotal,
      'week': weekTotal,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: "Xaridor yoki chek raqami",
              prefixIcon: Icon(Icons.search),
              suffixIcon: Icon(Icons.receipt_long),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', "Hammasi"),
                const SizedBox(width: 8),
                _filterChip('paid', "To'langan"),
                const SizedBox(width: 8),
                _filterChip('partial', "Qarz"),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _rangeChip('all', "Barcha"),
                const SizedBox(width: 8),
                _rangeChip('today', "Bugun"),
                const SizedBox(width: 8),
                _rangeChip('7d', "7 kun"),
                const SizedBox(width: 8),
                _rangeChip('30d', "30 kun"),
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
                          ? "${_dateFormat.format(_range!.start)} - ${_dateFormat.format(_range!.end)}"
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
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<SaleModel>>(
            stream: _service.watchSales(widget.opticaId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoader();
              }

              if (snapshot.hasError) {
                return const Center(child: Text("Nimadir noto'g'ri ketdi"));
              }

              final allSales = snapshot.data ?? [];
              final totals = _computeTotals(allSales);
              final list = _filterSales(allSales);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: "Bugun",
                            value:
                                "${_currency.format(totals['today'] ?? 0)} UZS",
                            icon: Icons.today,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: "7 kun",
                            value:
                                "${_currency.format(totals['week'] ?? 0)} UZS",
                            icon: Icons.date_range,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: list.isEmpty
                        ? EmptyState(
                            title: "Sotuvlar yo'q",
                            subtitle: "Hozircha sotuvlar tarixi bo'sh",
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(
                              left: 12,
                              right: 12,
                              bottom: 80,
                            ),
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final sale = list[index];
                              final isPartial = sale.dueAmount > 0;
                              final total = _currency.format(sale.total);
                              final paid = _currency.format(sale.paidAmount);
                              final due = _currency.format(sale.dueAmount);
                              final date = sale.createdAt.toDate();

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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            sale.customerName?.isNotEmpty ==
                                                    true
                                                ? sale.customerName!
                                                : "Noma'lum xaridor",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isPartial
                                                ? Colors.orange
                                                    .withOpacity(0.12)
                                                : Colors.green
                                                    .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            isPartial ? "Qarz" : "To'langan",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isPartial
                                                  ? Colors.orange
                                                  : Colors.green,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _dateFormat.format(date),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _metric("Jami", total),
                                        const SizedBox(width: 16),
                                        _metric("To'langan", paid),
                                        const SizedBox(width: 16),
                                        if (isPartial)
                                          _metric("Qolgan", due,
                                              color: Colors.red),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children:
                                          sale.items.take(3).map((item) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            "${item.name} x${item.quantity}",
                                            style:
                                                const TextStyle(fontSize: 11),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final isActive = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
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

  Widget _metric(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color ?? Colors.black,
          ),
        ),
      ],
    );
  }
}
