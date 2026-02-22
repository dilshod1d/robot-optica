import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/billing_model.dart';
import '../models/care_plan_model.dart';
import '../models/customer_model.dart';
import '../models/sms_config_model.dart';
import '../models/sms_log_model.dart';
import '../models/visit_model.dart';
import '../services/optica_service.dart';
import '../services/sms_log_service.dart';
import '../services/sms_service.dart';
import '../utils/sms_types.dart';

class SmsRuleEngine {
  final SmsService _smsService = SmsService();
  final SmsLogService _smsLogService = SmsLogService();
  final OpticaService _opticaService = OpticaService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  Future<SmsConfigModel> _loadConfig(String opticaId) async {
    return _opticaService.getSmsConfig(opticaId);
  }

  Future<bool> sendVisitSms({
    required String opticaId,
    required VisitModel visit,
    required CustomerModel customer,
    required String type,
    required String message,
    SmsConfigModel? config,
  }) async {
    final cfg = config ?? await _loadConfig(opticaId);

    if (!cfg.isSmsEnabled || !cfg.smsForVisits) return false;
    if (!visit.isPending) return false;
    if (!customer.visitsSmsEnabled) return false;
    if (!customer.visitsSmsEnabled) return false;
    final phone = customer.phone.trim();
    if (phone.isEmpty) return false;
    if (cfg.visitMaxCount <= 0) return false;

    final count = await _smsLogService.getVisitSmsCount(
      opticaId: opticaId,
      visitId: visit.id,
      after: visit.smsResetAt,
    );
    if (count >= cfg.visitMaxCount) return false;

    final alreadySent = await _smsLogService.hasVisitSmsStage(
      opticaId: opticaId,
      visitId: visit.id,
      type: type,
      after: visit.smsResetAt,
    );
    if (alreadySent) return false;

    try {
      final success = await _smsService.sendSms(
        phone: phone,
        message: message,
        onStatus: (status) {
          // ignore: avoid_print
          print("Scheduler SMS (Visit): $status");
        },
      );

      if (!success) return false;

      final log = SmsLogModel(
        id: _uuid.v4(),
        customerId: customer.id,
        phone: phone,
        debtId: null,
        visitId: visit.id,
        message: message,
        type: type,
        sentAt: DateTime.now(),
      );

      await _smsLogService.logSms(opticaId: opticaId, log: log);
      await _incrementVisitReminder(opticaId: opticaId, visitId: visit.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendDebtSms({
    required String opticaId,
    required BillingModel billing,
    required CustomerModel customer,
    required String type,
    required String message,
    SmsConfigModel? config,
    bool allowRepeat = false,
    int? minDaysBetween,
  }) async {
    final cfg = config ?? await _loadConfig(opticaId);
    final resetAt = billing.debtSmsResetAt;

    if (!cfg.isSmsEnabled || !cfg.smsForPayments) return false;
    if (billing.remaining <= 0) return false;
    if (!customer.debtsSmsEnabled) return false;
    final phone = customer.phone.trim();
    if (phone.isEmpty) return false;
    if (cfg.debtMaxCount <= 0) return false;

    final count = await _smsLogService.getDebtSmsCount(
      opticaId: opticaId,
      debtId: billing.id,
      after: resetAt,
    );
    if (count >= cfg.debtMaxCount) return false;

    if (!allowRepeat) {
      final alreadySent = await _smsLogService.hasDebtSmsStage(
        opticaId: opticaId,
        debtId: billing.id,
        type: type,
        after: resetAt,
      );
      if (alreadySent) return false;
    } else if (minDaysBetween != null && minDaysBetween > 0) {
      final lastSentAt = await _smsLogService.getLastDebtSmsSentAt(
        opticaId: opticaId,
        debtId: billing.id,
        type: type,
        after: resetAt,
      );
      if (lastSentAt != null) {
        final diffDays = DateTime.now().difference(lastSentAt).inDays;
        if (diffDays < minDaysBetween) return false;
      }
    }

    try {
      final success = await _smsService.sendSms(
        phone: phone,
        message: message,
        onStatus: (status) {
          // ignore: avoid_print
          print("Scheduler SMS (Debt): $status");
        },
      );

      if (!success) return false;

      final log = SmsLogModel(
        id: _uuid.v4(),
        customerId: customer.id,
        phone: phone,
        debtId: billing.id,
        visitId: null,
        message: message,
        type: type,
        sentAt: DateTime.now(),
      );

      await _smsLogService.logSms(opticaId: opticaId, log: log);
      await _incrementDebtReminder(opticaId: opticaId, billingId: billing.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendDebtPaidSms({
    required String opticaId,
    required BillingModel billing,
    required CustomerModel customer,
    required String message,
    SmsConfigModel? config,
  }) async {
    final cfg = config ?? await _loadConfig(opticaId);

    if (!cfg.isSmsEnabled || !cfg.smsForPayments) return false;
    if (billing.remaining > 0) return false;
    if (!customer.debtsSmsEnabled) return false;
    final phone = customer.phone.trim();
    if (phone.isEmpty) return false;

    final alreadySent = await _smsLogService.hasDebtSmsStage(
      opticaId: opticaId,
      debtId: billing.id,
      type: SmsLogTypes.debtPaid,
    );
    if (alreadySent) return false;

    try {
      final success = await _smsService.sendSms(
        phone: phone,
        message: message,
        onStatus: (status) {
          // ignore: avoid_print
          print("Scheduler SMS (Debt Paid): $status");
        },
      );

      if (!success) return false;

      final log = SmsLogModel(
        id: _uuid.v4(),
        customerId: customer.id,
        phone: phone,
        debtId: billing.id,
        visitId: null,
        message: message,
        type: SmsLogTypes.debtPaid,
        sentAt: DateTime.now(),
      );

      await _smsLogService.logSms(opticaId: opticaId, log: log);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendPrescriptionSms({
    required String opticaId,
    required CarePlanModel plan,
    required CustomerModel customer,
    required String message,
    SmsConfigModel? config,
  }) async {
    final cfg = config ?? await _loadConfig(opticaId);

    if (!cfg.isSmsEnabled || !cfg.smsForPrescriptions) return false;
    if (!customer.visitsSmsEnabled) return false;
    final phone = customer.phone.trim();
    if (phone.isEmpty) return false;

    final alreadySent = await _smsLogService.hasPrescriptionSmsStage(
      opticaId: opticaId,
      prescriptionId: plan.id,
      type: SmsLogTypes.prescriptionCreated,
    );
    if (alreadySent) return false;

    try {
      final success = await _smsService.sendSms(
        phone: phone,
        message: message,
        onStatus: (status) {
          // ignore: avoid_print
          print("Scheduler SMS (Prescription): $status");
        },
      );

      if (!success) return false;

      final log = SmsLogModel(
        id: _uuid.v4(),
        customerId: customer.id,
        phone: phone,
        debtId: null,
        visitId: plan.visitId,
        prescriptionId: plan.id,
        message: message,
        type: SmsLogTypes.prescriptionCreated,
        sentAt: DateTime.now(),
      );

      await _smsLogService.logSms(opticaId: opticaId, log: log);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _incrementVisitReminder({
    required String opticaId,
    required String visitId,
  }) async {
    await _db
        .collection('opticas')
        .doc(opticaId)
        .collection('visits')
        .doc(visitId)
        .update({
      'remindersSent': FieldValue.increment(1),
    });
  }

  Future<void> _incrementDebtReminder({
    required String opticaId,
    required String billingId,
  }) async {
    await _db
        .collection('opticas')
        .doc(opticaId)
        .collection('billings')
        .doc(billingId)
        .update({
      'reminderSentCount': FieldValue.increment(1),
    });
  }
}
