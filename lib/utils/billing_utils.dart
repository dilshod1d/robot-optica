import '../models/billing_model.dart';

double sumInRange(
    List<BillingModel> bills,
    DateTime from,
    DateTime to,
    ) {
  return bills
      .where((b) {
    final date = b.createdAt.toDate();
    return date.isAfter(from) && date.isBefore(to);
  })
      .fold(0.0, (sum, b) => sum + b.amountDue);
}
