enum BillingStatus {
  paid,
  partiallyPaid,
  overdue,
  latePaid,
  unpaid,
}

extension BillingStatusX on BillingStatus {
  String get label {
    switch (this) {
      case BillingStatus.paid:
        return "Paid";
      case BillingStatus.partiallyPaid:
        return "Partially Paid";
      case BillingStatus.overdue:
        return "Overdue";
      case BillingStatus.latePaid:
        return "Late Paid";
      case BillingStatus.unpaid:
        return "Not Paid";
    }
  }
}
