import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robot_optica/utils/billing_utils.dart';
import '../models/customer_model.dart';
import '../models/billing_model.dart';
import '../models/billing_status.dart';
import '../models/payment_model.dart';
import '../models/sms_config_model.dart';
import 'billing_stats_service.dart';
import 'customer_service.dart';
import 'optica_service.dart';
import 'sms_log_service.dart';
import 'sms_rule_engine.dart';
import '../utils/device_info_utils.dart';
import '../utils/sms_sanitizer.dart';
import '../utils/sms_template_engine.dart';
import '../utils/sms_types.dart';

class BillingFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final BillingStatsService _statsService = BillingStatsService();
  final CustomerService _customerService = CustomerService();
  final OpticaService _opticaService = OpticaService();
  final SmsRuleEngine _smsRuleEngine = SmsRuleEngine();
  final SmsLogService _smsLogService = SmsLogService();

  CollectionReference<Map<String, dynamic>> _billingRef(String opticaId) {
    return _db.collection('opticas').doc(opticaId).collection('billings');
  }

  // ========================
  // REALTIME DEBT SMS LISTENER
  // ========================
  void listenForNewDebts(String opticaId) {
    _billingRef(opticaId)
        .where('debtSmsPending', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added &&
            change.type != DocumentChangeType.modified) {
          continue;
        }

        final billing = BillingModel.fromFirestore(change.doc, opticaId);

        if (billing.remaining <= 0) {
          await _clearDebtSmsPending(opticaId, billing.id);
          continue;
        }

        final CustomerModel? customer = await _customerService.getCustomer(
          opticaId: opticaId,
          customerId: billing.customerId,
        );

        if (customer == null ||
            customer.phone.isEmpty ||
            !customer.debtsSmsEnabled) {
          await _clearDebtSmsPending(opticaId, billing.id);
          continue;
        }

        final SmsConfigModel config = await _opticaService.getSmsConfig(opticaId);
        if (!config.isSmsEnabled ||
            !config.smsForPayments ||
            !config.debtSendOnCreate) {
          await _clearDebtSmsPending(opticaId, billing.id);
          continue;
        }

        final localDeviceId = await getDeviceId();
        if (config.smsEnabledDeviceId == null || localDeviceId == null) continue;
        if (config.smsEnabledDeviceId != localDeviceId) continue;

        final message = _buildDebtMessage(
          customerFirstName: customer.firstName,
          customerLastName: customer.lastName,
          billing: billing,
          config: config,
          type: SmsLogTypes.debtCreated,
        );

        final sent = await _smsRuleEngine.sendDebtSms(
          opticaId: opticaId,
          billing: billing,
          customer: customer,
          type: SmsLogTypes.debtCreated,
          message: message,
          config: config,
        );

        if (sent) {
          await _clearDebtSmsPending(opticaId, billing.id);
        }
      }
    });
  }

  void listenForPaidDebts(String opticaId) {
    _billingRef(opticaId)
        .where('debtPaidSmsPending', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added &&
            change.type != DocumentChangeType.modified) {
          continue;
        }

        final billing = BillingModel.fromFirestore(change.doc, opticaId);

        if (billing.remaining > 0) {
          await _clearDebtPaidSmsPending(opticaId, billing.id);
          continue;
        }

        final CustomerModel? customer = await _customerService.getCustomer(
          opticaId: opticaId,
          customerId: billing.customerId,
        );

        if (customer == null ||
            customer.phone.isEmpty ||
            !customer.debtsSmsEnabled) {
          await _clearDebtPaidSmsPending(opticaId, billing.id);
          continue;
        }

        final SmsConfigModel config = await _opticaService.getSmsConfig(opticaId);
        if (!config.isSmsEnabled || !config.smsForPayments) {
          await _clearDebtPaidSmsPending(opticaId, billing.id);
          continue;
        }

        final localDeviceId = await getDeviceId();
        if (config.smsEnabledDeviceId == null || localDeviceId == null) continue;
        if (config.smsEnabledDeviceId != localDeviceId) continue;

        final alreadySent = await _smsLogService.hasDebtSmsStage(
          opticaId: opticaId,
          debtId: billing.id,
          type: SmsLogTypes.debtPaid,
        );
        if (alreadySent) {
          await _clearDebtPaidSmsPending(opticaId, billing.id);
          continue;
        }

        final message = _buildDebtMessage(
          customerFirstName: customer.firstName,
          customerLastName: customer.lastName,
          billing: billing,
          config: config,
          type: SmsLogTypes.debtPaid,
        );

        final sent = await _smsRuleEngine.sendDebtPaidSms(
          opticaId: opticaId,
          billing: billing,
          customer: customer,
          message: message,
          config: config,
        );

        if (sent) {
          await _clearDebtPaidSmsPending(opticaId, billing.id);
        }
      }
    });
  }

  Future<List<BillingModel>> fetchPendingDebtSms({
    required String opticaId,
    int limit = 50,
  }) async {
    final snapshot = await _billingRef(opticaId)
        .where('debtSmsPending', isEqualTo: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => BillingModel.fromFirestore(doc, opticaId))
        .toList();
  }

  Future<List<BillingModel>> fetchPendingDebtPaidSms({
    required String opticaId,
    int limit = 50,
  }) async {
    final snapshot = await _billingRef(opticaId)
        .where('debtPaidSmsPending', isEqualTo: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => BillingModel.fromFirestore(doc, opticaId))
        .toList();
  }

  Future<void> clearDebtSmsPending(String opticaId, String billingId) async {
    await _clearDebtSmsPending(opticaId, billingId);
  }

  Future<void> clearDebtPaidSmsPending(String opticaId, String billingId) async {
    await _clearDebtPaidSmsPending(opticaId, billingId);
  }

  Future<void> _clearDebtSmsPending(String opticaId, String billingId) async {
    await _billingRef(opticaId).doc(billingId).update({
      'debtSmsPending': false,
    });
  }

  Future<void> _clearDebtPaidSmsPending(String opticaId, String billingId) async {
    await _billingRef(opticaId).doc(billingId).update({
      'debtPaidSmsPending': false,
    });
  }

  String _formatDate(DateTime date, {required bool isCyrillic}) {
    const monthsLatin = [
      'yanvar',
      'fevral',
      'mart',
      'aprel',
      'may',
      'iyun',
      'iyul',
      'avgust',
      'sentyabr',
      'oktyabr',
      'noyabr',
      'dekabr',
    ];
    const monthsCyrillic = [
      'январь',
      'февраль',
      'март',
      'апрель',
      'май',
      'июнь',
      'июль',
      'август',
      'сентябрь',
      'октябрь',
      'ноябрь',
      'декабрь',
    ];

    final monthName =
        (isCyrillic ? monthsCyrillic : monthsLatin)[date.month - 1];
    return "${date.day} $monthName";
  }

  String _buildDebtMessage({
    required String customerFirstName,
    String? customerLastName,
    required BillingModel billing,
    required SmsConfigModel config,
    required String type,
  }) {
    final isCyrillic = config.isSmsCyrillic;
    final dueDate = billing.dueDate.toDate();
    final dueStr = _formatDate(dueDate, isCyrillic: isCyrillic);
    final amount = billing.remaining.toStringAsFixed(0);
    final paidAmount = billing.amountPaid.toStringAsFixed(0);
    final opticaPhone =
        config.opticaPhone.trim().isEmpty ? '933400034' : config.opticaPhone;
    final safeLastName = (customerLastName ?? '').trim();

    final template = SmsTemplateEngine.resolveTemplate(
      config: config,
      type: type,
    );

    final message = SmsTemplateEngine.render(
      template: template,
      variables: {
        'firstName': customerFirstName,
        'lastName': safeLastName,
        'dueDate': dueStr,
        'amount': amount,
        'paidAmount': paidAmount,
        'opticaName': config.opticaName,
        'opticaPhone': opticaPhone,
      },
    );

    return smsSanitize(message, allowUnicode: isCyrillic);
  }

  // ========================
  // CREATE BILLING
  // ========================
  Future<void> createBilling({
    required String opticaId,
    required BillingModel billing,
    double? initialPaidAmount,
  }) async {
    final docRef = _billingRef(opticaId).doc(billing.id);

    final batch = _db.batch();
    final data = billing.toMap();
    final paid = initialPaidAmount ?? billing.amountPaid;
    if (paid <= 0 &&
        await _shouldQueueDebtSmsOnCreate(
      opticaId: opticaId,
      billing: billing,
      initialPaidAmount: initialPaidAmount,
    )) {
      data['debtSmsPending'] = true;
    }
    batch.set(docRef, data);

    await batch.commit();

    // Update cached stats
    await _statsService.onCreate(
      opticaId: opticaId,
      billing: billing,
    );

  }

  Future<void> queueDebtSmsOnCreate({
    required String opticaId,
    required BillingModel billing,
  }) async {
    if (await _shouldQueueDebtSmsOnCreate(
      opticaId: opticaId,
      billing: billing,
    )) {
      await _billingRef(opticaId).doc(billing.id).update({
        'debtSmsPending': true,
      });
    }
  }

  Future<bool> _shouldQueueDebtSmsOnCreate({
    required String opticaId,
    required BillingModel billing,
    double? initialPaidAmount,
  }) async {
    final paid = initialPaidAmount ?? billing.amountPaid;
    if (billing.amountDue - paid <= 0) return false;

    try {
      final config = await _opticaService.getSmsConfig(opticaId);
      if (!config.isSmsEnabled ||
          !config.smsForPayments ||
          !config.debtSendOnCreate) {
        return false;
      }

      final customer = await _customerService.getCustomer(
        opticaId: opticaId,
        customerId: billing.customerId,
      );

      if (customer == null ||
          !customer.debtsSmsEnabled ||
          customer.phone.trim().isEmpty) {
        return false;
      }

      return true;
    } catch (_) {
      // Fail safe: don't queue if config/customer lookup fails
      return false;
    }
  }

  Future<bool> _shouldQueueDebtPaidSms({
    required String opticaId,
    required BillingModel billing,
  }) async {
    if (billing.remaining > 0) return false;

    try {
      final config = await _opticaService.getSmsConfig(opticaId);
      if (!config.isSmsEnabled || !config.smsForPayments) {
        return false;
      }

      final customer = await _customerService.getCustomer(
        opticaId: opticaId,
        customerId: billing.customerId,
      );

      if (customer == null ||
          !customer.debtsSmsEnabled ||
          customer.phone.trim().isEmpty) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // ========================
  // DELETE BILLING
  // ========================
  Future<void> deleteBilling({
    required String opticaId,
    required BillingModel billing,
  }) async {
    final ref = _billingRef(opticaId).doc(billing.id);

    final batch = _db.batch();
    batch.delete(ref);
    await batch.commit();
    await _statsService.onDelete(
      opticaId: opticaId,
      billing: billing,
    );


  }


  // ========================
  // STREAM ALL
  // ========================
  Stream<List<BillingModel>> watchBillings(String opticaId) {
    return _billingRef(opticaId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BillingModel.fromFirestore(doc, opticaId);
      }).toList();
    });
  }

  // ========================
  // STREAM BY CUSTOMER
  // ========================
  Stream<List<BillingModel>> watchByCustomer({
    required String opticaId,
    required String customerId,
  }) {
    return _billingRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BillingModel.fromFirestore(doc, opticaId);
      }).toList();
    });
  }

  // ========================
  // APPLY PAYMENT (PARTIAL / FULL)
  // ========================
  Future<void> applyPayment({
    required String opticaId,
    required BillingModel billing,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) {
      throw Exception("Payment amount must be greater than 0");
    }

    final now = Timestamp.now();
    final hadRemaining = billing.remaining > 0;
    final newPaid = billing.amountPaid + amount;

    if (newPaid > billing.amountDue) {
      throw Exception("Payment exceeds amount due");
    }

    final updatedBilling = billing.copyWith(
      amountPaid: newPaid,
      updatedAt: now,
    );

    final billingDoc = _billingRef(opticaId).doc(billing.id);
    final paymentDoc = billingDoc.collection('payments').doc();

    final batch = _db.batch();

    batch.update(billingDoc, updatedBilling.toMap());

    batch.set(paymentDoc, {
      'amount': amount,
      'note': note,
      'paidAt': now,
    });

    await batch.commit();
    // Update cached money totals
    await _statsService.onPayment(
      opticaId: opticaId,
      amountDelta: amount,
    );

    // Update count buckets if status changed
    if (billing.liveStatus != updatedBilling.liveStatus) {
      await _statsService.onStatusChange(
        opticaId: opticaId,
        oldBilling: billing,
        newBilling: updatedBilling,
      );
    }

    if (hadRemaining && updatedBilling.remaining <= 0) {
      if (await _shouldQueueDebtPaidSms(
        opticaId: opticaId,
        billing: updatedBilling,
      )) {
        await _billingRef(opticaId).doc(billing.id).update({
          'debtPaidSmsPending': true,
        });
      }
    }
  }

  // ========================
  // PAYMENT HISTORY
  // ========================
  Stream<List<PaymentModel>> watchPayments({
    required String opticaId,
    required String billingId,
  }) {
    return _billingRef(opticaId)
        .doc(billingId)
        .collection('payments')
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PaymentModel.fromFirestore(doc);
      }).toList();
    });
  }

  // ========================
  // UPDATE DUE DATE
  // ========================
  Future<void> updateDueDate({
    required String opticaId,
    required BillingModel oldBilling,
    required Timestamp newDueDate,
  }) async {
    final ref = _billingRef(opticaId).doc(oldBilling.id);

    final updatedBilling = oldBilling.copyWith(
      dueDate: newDueDate,
      updatedAt: Timestamp.now(),
    );

    await ref.update(updatedBilling.toMap());

    if (oldBilling.liveStatus != updatedBilling.liveStatus) {
      await _statsService.onStatusChange(
        opticaId: opticaId,
        oldBilling: oldBilling,
        newBilling: updatedBilling,
      );
    }
  }

  // ========================
  // RESCHEDULE DEBT (OPTIONAL SMS RESET)
  // ========================
  Future<void> rescheduleDebt({
    required String opticaId,
    required BillingModel billing,
    required DateTime newDate,
    required bool resetSms,
  }) async {
    final ref = _billingRef(opticaId).doc(billing.id);

    final updatedBilling = billing.copyWith(
      dueDate: Timestamp.fromDate(newDate),
      updatedAt: Timestamp.now(),
      reminderSentCount: resetSms ? 0 : billing.reminderSentCount,
      debtSmsResetAt: resetSms ? DateTime.now() : billing.debtSmsResetAt,
    );

    await ref.update(updatedBilling.toMap());

    if (billing.liveStatus != updatedBilling.liveStatus) {
      await _statsService.onStatusChange(
        opticaId: opticaId,
        oldBilling: billing,
        newBilling: updatedBilling,
      );
    }
  }


  // ========================
  // UPDATE AMOUNT DUE
  // ========================
  Future<void> updateAmountDue({
    required String opticaId,
    required String billingId,
    required double newAmountDue,
  }) async {
    if (newAmountDue <= 0) {
      throw Exception("Amount due must be greater than 0");
    }

    await _billingRef(opticaId).doc(billingId).update({
      'amountDue': newAmountDue,
      'updatedAt': Timestamp.now(),
    });
  }

  // ========================
  // GET SINGLE BILLING (ONE-TIME READ)
  // ========================
  Future<BillingModel?> getBilling({
    required String opticaId,
    required String billingId,
  }) async {
    final doc = await _billingRef(opticaId).doc(billingId).get();
    if (!doc.exists) return null;
    return BillingModel.fromFirestore(doc, opticaId);
  }

  // ========================
// STREAM: RECENT BILLS
// ========================
  Stream<List<BillingModel>> watchRecentBillings(
      String opticaId, {
        int limit = 10,
      }) {
    return _billingRef(opticaId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BillingModel.fromFirestore(doc, opticaId);
      }).toList();
    });
  }



  // ========================
// STREAM: ALL UNPAID (CLINIC DEBT)
// ========================
  Stream<List<BillingModel>> watchClinicDebt(String opticaId) {
    return watchBillings(opticaId).map(
          (list) => list.where((b) => b.remaining > 0).toList(),
    );
  }

// ========================
// STREAM: OVERDUE
// ========================
  Stream<List<BillingModel>> watchOverdue(String opticaId) {
    return watchBillings(opticaId).map(
          (list) => list.where((b) => b.liveStatus == BillingStatus.overdue).toList(),
    );
  }

// ========================
// STREAM: LATE PAID
// ========================
  Stream<List<BillingModel>> watchLatePaid(String opticaId) {
    return watchBillings(opticaId).map(
          (list) => list.where((b) => b.liveStatus == BillingStatus.latePaid).toList(),
    );
  }

// ========================
// STREAM: PARTIALLY PAID
// ========================
  Stream<List<BillingModel>> watchPartiallyPaid(String opticaId) {
    return watchBillings(opticaId).map(
          (list) => list.where((b) => b.liveStatus == BillingStatus.partiallyPaid).toList(),
    );
  }

// ========================
// STREAM: PAID
// ========================
  Stream<List<BillingModel>> watchPaid(String opticaId) {
    return watchBillings(opticaId).map(
          (list) => list.where((b) => b.liveStatus == BillingStatus.paid).toList(),
    );
  }


  // ========================
// TODAY TOTAL
// ========================
  Stream<double> watchTodayTotal(String opticaId) {
    return watchBillings(opticaId).map((list) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));

      return sumInRange(list, start, end);
    });
  }

// ========================
// LAST 7 DAYS
// ========================
  Stream<double> watchLast7DaysTotal(String opticaId) {
    return watchBillings(opticaId).map((list) {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      return sumInRange(list, start, now);
    });
  }

// ========================
// LAST 30 DAYS
// ========================
  Stream<double> watchLast30DaysTotal(String opticaId) {
    return watchBillings(opticaId).map((list) {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));
      return sumInRange(list, start, now);
    });
  }

// ========================
// THIS YEAR
// ========================
  Stream<double> watchYearTotal(String opticaId) {
    return watchBillings(opticaId).map((list) {
      final now = DateTime.now();
      final start = DateTime(now.year, 1, 1);
      return sumInRange(list, start, now);
    });
  }

  Stream<double> watchTotalDebt(String opticaId) {
    return watchBillings(opticaId).map((list) {
      return list.fold(0.0, (sum, b) => sum + b.remaining);
    });
  }

  Future<double> getCustomerTotalBilledAmount({
    required String opticaId,
    required String customerId,
  }) async {
    final snapshot = await _billingRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .get();

    double total = 0;

    for (final doc in snapshot.docs) {
      final billing = BillingModel.fromFirestore(doc, opticaId);
      total += billing.amountDue;
    }

    return total;
  }

  Future<double> getCustomerTotalPaidAmount({
    required String opticaId,
    required String customerId,
  }) async {
    final snapshot = await _billingRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .get();

    double totalPaid = 0;

    for (final doc in snapshot.docs) {
      final billing = BillingModel.fromFirestore(doc, opticaId);
      totalPaid += billing.amountPaid;
    }

    return totalPaid;
  }

  Future<double> getCustomerTotalDebtAmount({
    required String opticaId,
    required String customerId,
  }) async {
    final snapshot = await _billingRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .get();

    double totalDebt = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final due = (data['amountDue'] ?? 0).toDouble();
      final paid = (data['amountPaid'] ?? 0).toDouble();

      final remaining = due - paid;
      if (remaining > 0) {
        totalDebt += remaining;
      }
    }

    return totalDebt;
  }

  Future<int> getBillsToCollectTodayCount(String opticaId) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    final snapshot = await _billingRef(opticaId)
        .where(
      'dueDate',
      isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
    )
        .where(
      'dueDate',
      isLessThan: Timestamp.fromDate(endOfToday),
    )
        .get();

    int count = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final due = (data['amountDue'] ?? 0).toDouble();
      final paid = (data['amountPaid'] ?? 0).toDouble();

      if (due - paid > 0) {
        count++;
      }
    }

    return count;
  }

  Future<List<BillingModel>> fetchBillingsByDueDateRange({
    required String opticaId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _billingRef(opticaId)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dueDate', isLessThan: Timestamp.fromDate(end))
        .get();

    final List<BillingModel> result = [];

    for (final doc in snapshot.docs) {
      final billing = BillingModel.fromFirestore(doc, opticaId);
      final remaining = billing.amountDue - billing.amountPaid;
      if (remaining > 0) {
        result.add(billing);
      }
    }

    return result;
  }

  Future<List<BillingModel>> getOverdueBillings(String opticaId) async {
    final now = DateTime.now();

    final snapshot = await _billingRef(opticaId)
        .where('dueDate', isLessThan: Timestamp.fromDate(now))
        .get();

    final List<BillingModel> result = [];

    for (final doc in snapshot.docs) {
      final billing = BillingModel.fromFirestore(doc, opticaId);
      final remaining = billing.amountDue - billing.amountPaid;

      if (remaining > 0) {
        result.add(billing);
      }
    }

    return result;
  }







}
