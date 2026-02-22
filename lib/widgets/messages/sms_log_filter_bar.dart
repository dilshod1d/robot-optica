import 'package:flutter/material.dart';
import '../../models/sms_log_time_filter.dart';

class SmsLogFilterBar extends StatelessWidget {
  final SmsLogTimeFilter currentFilter;
  final void Function(SmsLogTimeFilter) onFilterChanged;

  const SmsLogFilterBar({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: SmsLogTimeFilter.values.map((filter) {
          final selected = filter == currentFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_label(filter)),
              selected: selected,
              onSelected: (_) => onFilterChanged(filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(SmsLogTimeFilter filter) {
    switch (filter) {
      case SmsLogTimeFilter.today:
        return "Bugun";
      case SmsLogTimeFilter.thisWeek:
        return "Shu Hafta";
      case SmsLogTimeFilter.thisMonth:
        return "Shu Oy";
      case SmsLogTimeFilter.all:
        return "Hammasi";
    }
  }
}
