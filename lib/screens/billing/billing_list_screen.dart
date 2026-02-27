import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/billing_filter.dart';
import '../../models/billing_model.dart';
import '../../models/billing_status.dart';
import '../../providers/auth_provider.dart';
import '../../services/billing_service.dart';
import '../../widgets/billing/billing_filter_chips.dart';
import '../../widgets/billing/billing_item_card.dart';
import '../../widgets/billing/pay_bottom_sheet.dart';
import '../../widgets/billing/reschedule_debt_sheet.dart';
import '../../widgets/common/app_loader.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/responsive_frame.dart';
import 'billing_detail_screen.dart';


class BillingListScreen extends StatefulWidget {
  final bool dueTodayOnly;
  final String? title;

  const BillingListScreen({
    super.key,
    this.dueTodayOnly = false,
    this.title,
  });

  @override
  State<BillingListScreen> createState() => _BillingListScreenState();
}

class _BillingListScreenState extends State<BillingListScreen> {
  BillingFilter _selectedFilter = BillingFilter.all;

  int _columnsForWidth(double width) {
    const minWidth = 360.0;
    const maxColumns = 3;
    if (width <= 0) return 1;
    final count = (width / minWidth).floor();
    return count.clamp(1, maxColumns);
  }

  @override
  Widget build(BuildContext context) {
    final service = BillingFirebaseService();
    final opticaId = context.watch<AuthProvider>().opticaId;
    final fallbackTitle =
        widget.dueTodayOnly ? "Bugungi qarzlar" : "Barcha Xisob-kitoblar";

    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? fallbackTitle)),
      body: StreamBuilder<List<BillingModel>>(
        stream: service.watchBillings(opticaId!),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AppLoader();
          }

          final list = snapshot.data!;
          final filtered = _applyFilters(list);

          return ResponsiveFrame(
            child: Column(
              children: [
                BillingFilterChips(
                  selected: _selectedFilter,
                  onChanged: (f) => setState(() => _selectedFilter = f),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          title: widget.dueTodayOnly
                              ? "Bugun to'lanishi kerak qarzlar yo'q"
                              : "Hisob-kitoblar yo'q",
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns =
                                _columnsForWidth(constraints.maxWidth);
                            const spacing = 12.0;

                            if (columns <= 1) {
                              return ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final bill = filtered[i];

                                  return BillingItemCard(
                                    bill: bill,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BillingDetailScreen(
                                            opticaId: opticaId,
                                            billing: bill,
                                            service: service,
                                          ),
                                        ),
                                      );
                                    },
                                    onEdit: bill.remaining > 0
                                        ? () => _reschedule(
                                              context,
                                              bill,
                                              service,
                                              opticaId,
                                            )
                                        : null,
                                    onPay: bill.remaining > 0
                                        ? () => _pay(
                                              context,
                                              bill,
                                              service,
                                              opticaId,
                                            )
                                        : null,
                                  );
                                },
                              );
                            }

                            final availableWidth =
                                constraints.maxWidth - (12 * 2);
                            final itemWidth = (availableWidth -
                                    (spacing * (columns - 1))) /
                                columns;

                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                children: filtered.map((bill) {
                                  return SizedBox(
                                    width: itemWidth,
                                    child: BillingItemCard(
                                      bill: bill,
                                      margin: EdgeInsets.zero,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                BillingDetailScreen(
                                              opticaId: opticaId,
                                              billing: bill,
                                              service: service,
                                            ),
                                          ),
                                        );
                                      },
                                      onEdit: bill.remaining > 0
                                          ? () => _reschedule(
                                                context,
                                                bill,
                                                service,
                                                opticaId,
                                              )
                                          : null,
                                      onPay: bill.remaining > 0
                                          ? () => _pay(
                                                context,
                                                bill,
                                                service,
                                                opticaId,
                                              )
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<BillingModel> _applyFilters(List<BillingModel> list) {
    Iterable<BillingModel> result = list;

    if (widget.dueTodayOnly) {
      result = result.where(_isDueTodayAndUnpaid);
    }

    switch (_selectedFilter) {
      case BillingFilter.overdue:
        result = result.where((b) => b.liveStatus == BillingStatus.overdue);
        break;
      case BillingFilter.partiallyPaid:
        result =
            result.where((b) => b.liveStatus == BillingStatus.partiallyPaid);
        break;
      case BillingFilter.paid:
        result = result.where((b) => b.liveStatus == BillingStatus.paid);
        break;
      case BillingFilter.latePaid:
        result = result.where((b) => b.liveStatus == BillingStatus.latePaid);
        break;
      case BillingFilter.today:
        result = result.where((b) => _isInRange(b, _rangeToday()));
        break;
      case BillingFilter.last7Days:
        result = result.where((b) => _isInRange(b, _rangeLastDays(7)));
        break;
      case BillingFilter.last30Days:
        result = result.where((b) => _isInRange(b, _rangeLastDays(30)));
        break;
      case BillingFilter.all:
        break;
    }

    return result.toList();
  }

  bool _isDueTodayAndUnpaid(BillingModel bill) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    if (bill.remaining <= 0) return false;
    final due = bill.dueDate.toDate();
    return !due.isBefore(start) && due.isBefore(end);
  }

  _Range _rangeToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return _Range(start, start.add(const Duration(days: 1)));
  }

  _Range _rangeLastDays(int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return _Range(start, end);
  }

  bool _isInRange(BillingModel bill, _Range range) {
    final created = bill.createdAt.toDate();
    return !created.isBefore(range.start) && created.isBefore(range.end);
  }

  void _pay(
      BuildContext context,
      BillingModel bill,
      BillingFirebaseService service,
      String opticaId,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PayBottomSheet(
        maxAmount: bill.remaining,
        onConfirm: (amount, note) async {
          await service.applyPayment(
            opticaId: opticaId,
            billing: bill,
            amount: amount,
            note: note,
          );
        },
      ),
    );
  }

  Future<void> _reschedule(
    BuildContext context,
    BillingModel bill,
    BillingFirebaseService service,
    String opticaId,
  ) async {
    final result = await RescheduleDebtSheet.show(
      context: context,
      initialDate: bill.dueDate.toDate(),
    );
    if (result == null) return;
    await service.rescheduleDebt(
      opticaId: opticaId,
      billing: bill,
      newDate: result.date,
      resetSms: result.resetSms,
    );
  }

}

class _Range {
  final DateTime start;
  final DateTime end;
  const _Range(this.start, this.end);
}
