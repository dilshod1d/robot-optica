import 'package:flutter/material.dart';
import '../../models/billing_model.dart';
import '../../models/billing_status.dart';

class BillingItemCard extends StatelessWidget {
  final BillingModel bill;
  final bool showCustomerName;
  final VoidCallback? onPay;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const BillingItemCard({
    super.key,
    required this.bill,
    this.showCustomerName = false,
    this.onPay,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(bill.liveStatus);
    final statusText = _statusLabel(bill.liveStatus);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(Icons.receipt_long, color: statusColor, size: 18),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showCustomerName) ...[
                        Text(
                          bill.customerName ?? "",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],

                      Text(
                        _formatDate(bill.createdAt.toDate()),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Qolgan: ${bill.remaining.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Eslatma yuborilgan: ${bill.reminderSentCount}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (onEdit != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: onEdit,
                        tooltip: "Tahrirlash",
                        icon: const Icon(Icons.edit, size: 18),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            if (bill.remaining > 0 && onPay != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  onPressed: onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text("To'lash"),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.year}";
  }

  Color _statusColor(BillingStatus status) {
    switch (status) {
      case BillingStatus.paid:
        return Colors.green;
      case BillingStatus.partiallyPaid:
        return Colors.blue;
      case BillingStatus.overdue:
        return Colors.red;
      case BillingStatus.latePaid:
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(BillingStatus status) {
    switch (status) {
      case BillingStatus.paid:
        return "To'langan";
      case BillingStatus.partiallyPaid:
        return "Qisman to'langan";
      case BillingStatus.overdue:
        return "O'tib ketgan";
      case BillingStatus.latePaid:
        return "Kech to'langan";
      default:
        return "To'lanmangan";
    }
  }
}
