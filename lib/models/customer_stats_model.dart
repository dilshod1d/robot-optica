class CustomerStatsModel {
  final int smsCount;
  final int visitCount;
  final int analysisCount;
  final int prescriptionCount;
  final double totalDebt;
  final double totalSales;

  CustomerStatsModel({
    required this.smsCount,
    required this.visitCount,
    required this.analysisCount,
    required this.prescriptionCount,
    required this.totalDebt,
    required this.totalSales,
  });
}
