import 'package:flutter/material.dart';
import '../../models/billing_filter.dart';

class BillingFilterChips extends StatelessWidget {
  final BillingFilter selected;
  final void Function(BillingFilter) onChanged;

  const BillingFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: BillingFilter.values.map((f) {
          final isSelected = f == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_label(f)),
              selected: isSelected,
              onSelected: (_) => onChanged(f),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(BillingFilter f) {
    switch (f) {
      case BillingFilter.all:
        return "Hammasi";
      case BillingFilter.overdue:
        return "O'tib ketgan";
      case BillingFilter.partiallyPaid:
        return "Qisman to'langan";
      case BillingFilter.paid:
        return "To'langan";
      case BillingFilter.latePaid:
        return "Kech to'langan";
      case BillingFilter.today:
        return "Bugun";
      case BillingFilter.last7Days:
        return "Oxirgi 7 kun";
      case BillingFilter.last30Days:
        return "Oxirgi 30 kun";
    }
  }
}
