import 'package:robot_optica/services/visit_service.dart';
import 'package:robot_optica/services/sms_log_service.dart';
import 'package:robot_optica/services/prescription_service.dart';
import 'package:robot_optica/services/eye_scan_service.dart';
import '../models/customer_stats_model.dart';
import 'billing_service.dart';


class CustomerStatsService {
  final VisitService _visits = VisitService();
  final SmsLogService _sms = SmsLogService();
  final PrescriptionService _prescriptions = PrescriptionService();
  final EyeScanService _analysis = EyeScanService();
  final BillingFirebaseService _billing = BillingFirebaseService();

  Future<CustomerStatsModel> load({
    required String opticaId,
    required String customerId,
  }) async {
    final results = await Future.wait([
      _sms.getCustomerSmsCount(opticaId: opticaId, customerId: customerId),
      _visits.getCustomerVisitsCount(opticaId, customerId),
      _analysis.getCustomerAnalysisCount(opticaId: opticaId, customerId: customerId),
      _prescriptions.getCustomerPrescriptionCount(opticaId: opticaId, customerId: customerId),
      _billing.getCustomerTotalDebtAmount(
        opticaId: opticaId,
        customerId: customerId,
      ),
      _billing.getCustomerTotalBilledAmount(
        opticaId: opticaId,
        customerId: customerId,
      ),
    ]);

    return CustomerStatsModel(
      smsCount: results[0] as int? ?? 0,
      visitCount: results[1] as int? ?? 0,
      analysisCount: results[2] as int? ?? 0,
      prescriptionCount: results[3] as int? ?? 0,
      totalDebt: results[4] as double,
      totalSales: results[5] as double,
    );
  }
}
