import 'package:flutter/material.dart';
import '../../models/billing_sort.dart';

class BillingSearchSortBar extends StatelessWidget {
  final String query;
  final BillingSort sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<BillingSort> onSortChanged;

  const BillingSearchSortBar({
    super.key,
    required this.query,
    required this.sort,
    required this.onQueryChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Izlash...",
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: onQueryChanged,
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<BillingSort>(
            icon: const Icon(Icons.sort),
            onSelected: onSortChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: BillingSort.newest,
                child: Text("Eng yangisi"),
              ),
              PopupMenuItem(
                value: BillingSort.oldest,
                child: Text("Eng eskisi"),
              ),
              PopupMenuItem(
                value: BillingSort.amountHigh,
                child: Text("Miqdor ↓"),
              ),
              PopupMenuItem(
                value: BillingSort.amountLow,
                child: Text("Miqdor ↑"),
              ),
              PopupMenuItem(
                value: BillingSort.remainingHigh,
                child: Text("Qolgan ↓"),
              ),
              PopupMenuItem(
                value: BillingSort.remainingLow,
                child: Text("Qolgan ↑"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
