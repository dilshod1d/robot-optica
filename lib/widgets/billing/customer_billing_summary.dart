import 'package:flutter/material.dart';
import '../../models/billing_model.dart';

class CustomerBillingSummary extends StatelessWidget {
  final List<BillingModel> bills;

  const CustomerBillingSummary({super.key, required this.bills});

  @override
  Widget build(BuildContext context) {
    final totalDue = bills.fold<double>(0, (s, b) => s + b.amountDue);
    final totalPaid = bills.fold<double>(0, (s, b) => s + b.amountPaid);
    final totalRemaining = bills.fold<double>(0, (s, b) => s + b.remaining);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black.withOpacity(0.05),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item("Jami", totalDue),
          _item("To'langan", totalPaid, color: Colors.green),
          _item("Qolgan", totalRemaining, color: Colors.red),
        ],
      ),
    );
  }

  Widget _item(String label, double value, {Color? color}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          "${value.toStringAsFixed(0)} so'm",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
