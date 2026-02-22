class BillingStatsModel {
  final double todayTotal; // Amount dues no matter paid or not
  final double last7DaysTotal; // Amount dues no matter paid or not
  final double last30DaysTotal; // Amount dues no matter paid or not
  final double yearTotal; // Amount dues no matter paid or not

  final double totalBilled;     // sum(amountDue)
  final double totalCollected;  // sum(amountPaid)
  final double totalUnpaid;     // sum(remaining)

  final int paidCount; // without any debt
  final int partialCount; // debt but partially paid
  final int overdueCount; // any debt not paid on time
  final int pendingDueCount;  // debt but not overdue

  final DateTime updatedAt;

  BillingStatsModel({
    required this.todayTotal,
    required this.last7DaysTotal,
    required this.last30DaysTotal,
    required this.yearTotal,
    required this.totalBilled,
    required this.totalCollected,
    required this.totalUnpaid,
    required this.paidCount,
    required this.partialCount,
    required this.overdueCount,
    required this.pendingDueCount,
    required this.updatedAt,
  });

  factory BillingStatsModel.empty() {
    return BillingStatsModel(
      todayTotal: 0,
      last7DaysTotal: 0,
      last30DaysTotal: 0,
      yearTotal: 0,
      totalBilled: 0,
      totalCollected: 0,
      totalUnpaid: 0,
      paidCount: 0,
      partialCount: 0,
      overdueCount: 0,
      pendingDueCount: 0,
      updatedAt: DateTime.now(),
    );
  }
}
