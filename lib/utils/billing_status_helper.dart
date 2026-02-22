import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/billing_status.dart';

BillingStatus calculateBillingStatus({
  required double amountDue,
  required double amountPaid,
  required Timestamp dueDate,
  required Timestamp updatedAt,
}) {
  final remaining = amountDue - amountPaid;
  final now = DateTime.now();
  final due = dueDate.toDate();
  final lastUpdate = updatedAt.toDate();

  const gracePeriod = Duration(minutes: 5);

  // Fully paid
  if (remaining <= 0) {
    // Paid after due + grace = latePaid
    if (lastUpdate.isAfter(due.add(gracePeriod))) {
      return BillingStatus.latePaid;
    }
    return BillingStatus.paid;
  }

  // Not fully paid and past due + grace
  if (now.isAfter(due.add(gracePeriod))) {
    return BillingStatus.overdue;
  }

  // Partially paid
  if (amountPaid > 0) {
    return BillingStatus.partiallyPaid;
  }

  return BillingStatus.unpaid;
}
