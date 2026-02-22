import 'package:flutter/material.dart';
import '../../models/billing_status.dart';

class BillingStatusChip extends StatelessWidget {
  final BillingStatus status;

  const BillingStatusChip({super.key, required this.status});

  Color get _color {
    switch (status) {
      case BillingStatus.paid:
        return Colors.green;
      case BillingStatus.partiallyPaid:
        return Colors.orange;
      case BillingStatus.overdue:
        return Colors.red;
      case BillingStatus.latePaid:
        return Colors.deepOrange;
      case BillingStatus.unpaid:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
