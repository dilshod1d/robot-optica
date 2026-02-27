import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
import 'package:intl/intl.dart';

class CustomerListItem extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onTap;
  final EdgeInsetsGeometry margin;

  const CustomerListItem({
    super.key,
    required this.customer,
    required this.onTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
  });

  // Premium optica palette
  static const Color primaryBlue = Color(0xFF66C2E3); // your chosen color
  static const Color softBlue = Color(0xFFEFF9FD);
  static const Color borderBlue = Color(0xFFBFE9F5);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final fullName =
    "${customer.firstName} ${customer.lastName ?? ""}".trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: margin,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderBlue,
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(fullName),
            const SizedBox(width: 14),
            Expanded(child: _info(fullName)),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: primaryBlue,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String name) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : "?";

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            softBlue,
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: borderBlue,
          width: 1.4,
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: primaryBlue,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _info(String fullName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16.5,
                  color: textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: _dateTag(customer.createdAt.toDate())),
          ],
        ),
        const SizedBox(height: 6),

        Row(
          children: [
            Icon(
              Icons.phone_outlined,
              size: 14,
              color: textSecondary.withOpacity(0.9),
            ),
            const SizedBox(width: 5),
            Text(
              customer.phone,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 13.5,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            _smsPill(
              label: "Tashrif SMS",
              enabled: customer.visitsSmsEnabled,
            ),
            const SizedBox(width: 8),
            _smsPill(
              label: "To'lov SMS",
              enabled: customer.debtsSmsEnabled,
            ),
          ],
        ),
      ],
    );
  }

  Widget _smsPill({
    required String label,
    required bool enabled,
  }) {
    final Color color = enabled ? primaryBlue : textSecondary;
    final Color bgColor = enabled ? softBlue : const Color(0xFFF6F7F9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled ? borderBlue : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sms_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? primaryBlue : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateTag(DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderBlue),
      ),
      child: Text(
        _formatDate(date),
        style: const TextStyle(
          fontSize: 11,
          color: textSecondary,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat("dd MMM yyyy").format(date);
  }
}
