import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/billing_model.dart';
import '../models/sms_config_model.dart';
import '../models/visit_model.dart';
import '../services/billing_service.dart';
import '../services/customer_service.dart';
import '../services/optica_service.dart';
import '../services/prescription_service.dart';
import '../services/sms_rule_engine.dart';
import '../services/visit_service.dart';
import '../utils/device_info_utils.dart';
import '../utils/sms_delay_jitter.dart';
import '../utils/sms_sanitizer.dart';
import '../utils/sms_template_engine.dart';
import '../utils/sms_types.dart';

class SchedulerService {
  /// 🔑 REQUIRED: Optica context
  final String opticaId;

  SchedulerService({required this.opticaId});

  final CustomerService _customerService = CustomerService();
  final VisitService _visitService = VisitService();
  final BillingFirebaseService _billingService = BillingFirebaseService();
  final PrescriptionService _prescriptionService = PrescriptionService();
  final OpticaService _opticaService = OpticaService();
  final SmsRuleEngine _smsRuleEngine = SmsRuleEngine();

  final DateFormat _formatter = DateFormat('dd/MM/yy');

  Future<bool> hasRunToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRun = prefs.getString('lastRunDate');
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return lastRun == todayStr;
  }

  Future<void> markRunToday() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString('lastRunDate', todayStr);
  }

  Future<void> runDailySmsJob() async {
    if (await hasRunToday()) {
      debugPrint('Scheduler: Job already run today, skipping.');
      return;
    }

    try {
      final config = await _opticaService.getSmsConfig(opticaId);
      if (!await _isActiveDevice(config)) {
        debugPrint('Scheduler: inactive device or SMS disabled.');
        return;
      }

      final today = DateTime.now();

      if (config.visitSendOnCreate && config.smsForVisits) {
        await _processPendingVisitSms(config);
      } else {
        await _clearPendingVisitSms();
      }

      if (config.smsForPrescriptions) {
        await _processPendingPrescriptionSms(config);
      } else {
        await _clearPendingPrescriptionSms();
      }

      if (config.debtSendOnCreate && config.smsForPayments) {
        await _processPendingDebtSms(config);
      } else {
        await _clearPendingDebtSms();
      }

      if (config.smsForPayments) {
        await _processPendingDebtPaidSms(config);
      } else {
        await _clearPendingDebtPaidSms();
      }

      if (config.smsForPayments) {
        await _runDebtRules(today, config);
      }

      if (config.smsForVisits) {
        await _runVisitRules(today, config);
      }

      await markRunToday();
    } catch (e) {
      debugPrint('Scheduler error: $e');
    }
  }

  Future<void> runQueueJob() async {
    try {
      final config = await _opticaService.getSmsConfig(opticaId);
      if (!await _isActiveDevice(config)) {
        debugPrint('Scheduler: inactive device or SMS disabled.');
        return;
      }

      if (config.visitSendOnCreate && config.smsForVisits) {
        await _processPendingVisitSms(config);
      } else {
        await _clearPendingVisitSms();
      }

      if (config.smsForPrescriptions) {
        await _processPendingPrescriptionSms(config);
      } else {
        await _clearPendingPrescriptionSms();
      }

      if (config.debtSendOnCreate && config.smsForPayments) {
        await _processPendingDebtSms(config);
      } else {
        await _clearPendingDebtSms();
      }

      if (config.smsForPayments) {
        await _processPendingDebtPaidSms(config);
      } else {
        await _clearPendingDebtPaidSms();
      }

      final now = DateTime.now();
      final scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        config.dailyHour,
        config.dailyMinute,
      );

      // Only run date-based rules after the configured daily time
      if (!now.isBefore(scheduled)) {
        if (config.smsForPayments) {
          await _runDebtRules(now, config);
        }
        if (config.smsForVisits) {
          await _runVisitRules(now, config);
        }
      }
    } catch (e) {
      debugPrint('Scheduler queue error: $e');
    }
  }

  Future<bool> _isActiveDevice(SmsConfigModel config) async {
    if (!config.isSmsEnabled) return false;
    if (config.smsEnabledDeviceId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final cachedDeviceId = prefs.getString('smsLocalDeviceId');
    final localDeviceId = cachedDeviceId ?? await getDeviceId();
    if (localDeviceId == null) return false;

    return localDeviceId == config.smsEnabledDeviceId;
  }

  Future<void> _runVisitRules(DateTime today, SmsConfigModel config) async {
    if (config.visitMaxCount <= 0) return;

    if (config.visitSendBefore && config.visitDaysBefore > 0) {
      final target = today.add(Duration(days: config.visitDaysBefore));
      await _sendVisitStageForDate(
        targetDay: target,
        type: SmsLogTypes.visitBefore,
        config: config,
      );
    }

    if (config.visitSendOnDate) {
      await _sendVisitStageForDate(
        targetDay: today,
        type: SmsLogTypes.visitOnDate,
        config: config,
      );
    }
  }

  Future<void> _processPendingVisitSms(SmsConfigModel config) async {
    final visits = await _visitService.fetchPendingVisitSms(opticaId: opticaId);

    for (final visit in visits) {
      if (!visit.isPending) {
        await _visitService.clearVisitSmsPending(opticaId, visit.id);
        continue;
      }

      final customer = await _customerService.getCustomer(
        opticaId: opticaId,
        customerId: visit.customerId,
      );

      if (customer == null ||
          !customer.visitsSmsEnabled ||
          customer.phone.trim().isEmpty) {
        await _visitService.clearVisitSmsPending(opticaId, visit.id);
        continue;
      }

      final msg = _buildVisitMessage(
        customer.firstName,
        customer.lastName,
        visit,
        config,
        SmsLogTypes.visitCreated,
      );
      final sent = await _smsRuleEngine.sendVisitSms(
        opticaId: opticaId,
        visit: visit,
        customer: customer,
        type: SmsLogTypes.visitCreated,
        message: msg,
        config: config,
      );

      if (sent) {
        await _visitService.clearVisitSmsPending(opticaId, visit.id);
      }

      await Future.delayed(smsDelayWithJitter());
    }
  }

  Future<void> _clearPendingVisitSms() async {
    final visits = await _visitService.fetchPendingVisitSms(opticaId: opticaId);
    for (final visit in visits) {
      await _visitService.clearVisitSmsPending(opticaId, visit.id);
    }
  }

  Future<void> _processPendingPrescriptionSms(SmsConfigModel config) async {
    final plans =
        await _prescriptionService.fetchPendingPrescriptions(opticaId: opticaId);

    for (final plan in plans) {
      final customer = await _customerService.getCustomer(
        opticaId: opticaId,
        customerId: plan.customerId,
      );

      if (customer == null ||
          !customer.visitsSmsEnabled ||
          customer.phone.trim().isEmpty) {
        await _prescriptionService.clearPrescriptionSmsPending(opticaId, plan.id);
        continue;
      }

      final msg = _prescriptionService.buildPrescriptionMessage(
        customerFirstName: customer.firstName,
        customerLastName: customer.lastName,
        plan: plan,
        config: config,
      );

      final sent = await _smsRuleEngine.sendPrescriptionSms(
        opticaId: opticaId,
        plan: plan,
        customer: customer,
        message: msg,
        config: config,
      );

      if (sent) {
        await _prescriptionService.clearPrescriptionSmsPending(opticaId, plan.id);
      }

      await Future.delayed(smsDelayWithJitter());
    }
  }

  Future<void> _clearPendingPrescriptionSms() async {
    final plans =
        await _prescriptionService.fetchPendingPrescriptions(opticaId: opticaId);
    for (final plan in plans) {
      await _prescriptionService.clearPrescriptionSmsPending(opticaId, plan.id);
    }
  }

  Future<void> _runDebtRules(DateTime today, SmsConfigModel config) async {
    if (config.debtMaxCount <= 0) return;

    if (config.debtSendBefore && config.debtDaysBefore > 0) {
      final target = today.add(Duration(days: config.debtDaysBefore));
      await _sendDebtStageForDate(
        targetDay: target,
        type: SmsLogTypes.debtBefore,
        config: config,
      );
    }

    if (config.debtSendOnDueDate) {
      await _sendDebtStageForDate(
        targetDay: today,
        type: SmsLogTypes.debtDue,
        config: config,
      );
    }

    if (config.debtRepeatEnabled && config.debtRepeatDays > 0) {
      await _sendDebtRepeatSms(today, config);
    }
  }

  Future<void> _processPendingDebtSms(SmsConfigModel config) async {
    final debts =
        await _billingService.fetchPendingDebtSms(opticaId: opticaId);

    for (final debt in debts) {
      final latest = await _billingService.getBilling(
        opticaId: opticaId,
        billingId: debt.id,
      );
      if (latest == null || latest.remaining <= 0) {
        await _billingService.clearDebtSmsPending(opticaId, debt.id);
        continue;
      }

      final customer = await _customerService.getCustomer(
        opticaId: opticaId,
        customerId: latest.customerId,
      );

      if (customer == null ||
          !customer.debtsSmsEnabled ||
          customer.phone.trim().isEmpty) {
        await _billingService.clearDebtSmsPending(opticaId, debt.id);
        continue;
      }

      final msg = _buildDebtMessage(
        customer.firstName,
        customer.lastName,
        latest,
        config,
        SmsLogTypes.debtCreated,
      );

      final sent = await _smsRuleEngine.sendDebtSms(
        opticaId: opticaId,
        billing: latest,
        customer: customer,
        type: SmsLogTypes.debtCreated,
        message: msg,
        config: config,
      );

      if (sent) {
        await _billingService.clearDebtSmsPending(opticaId, debt.id);
      }

      await Future.delayed(smsDelayWithJitter());
    }
  }

  Future<void> _clearPendingDebtSms() async {
    final debts =
        await _billingService.fetchPendingDebtSms(opticaId: opticaId);
    for (final debt in debts) {
      await _billingService.clearDebtSmsPending(opticaId, debt.id);
    }
  }

  Future<void> _processPendingDebtPaidSms(SmsConfigModel config) async {
    final debts =
        await _billingService.fetchPendingDebtPaidSms(opticaId: opticaId);

    for (final debt in debts) {
      final latest = await _billingService.getBilling(
        opticaId: opticaId,
        billingId: debt.id,
      );
      if (latest == null || latest.remaining > 0) {
        await _billingService.clearDebtPaidSmsPending(opticaId, debt.id);
        continue;
      }

      final customer = await _customerService.getCustomer(
        opticaId: opticaId,
        customerId: latest.customerId,
      );

      if (customer == null ||
          !customer.debtsSmsEnabled ||
          customer.phone.trim().isEmpty) {
        await _billingService.clearDebtPaidSmsPending(opticaId, debt.id);
        continue;
      }

      final msg = _buildDebtMessage(
        customer.firstName,
        customer.lastName,
        latest,
        config,
        SmsLogTypes.debtPaid,
      );

      final sent = await _smsRuleEngine.sendDebtPaidSms(
        opticaId: opticaId,
        billing: latest,
        customer: customer,
        message: msg,
        config: config,
      );

      if (sent) {
        await _billingService.clearDebtPaidSmsPending(opticaId, debt.id);
      }

      await Future.delayed(smsDelayWithJitter());
    }
  }

  Future<void> _clearPendingDebtPaidSms() async {
    final debts =
        await _billingService.fetchPendingDebtPaidSms(opticaId: opticaId);
    for (final debt in debts) {
      await _billingService.clearDebtPaidSmsPending(opticaId, debt.id);
    }
  }

  Future<void> _sendDebtRepeatSms(DateTime today, SmsConfigModel config) async {
    final overdue = await _billingService.getOverdueBillings(opticaId);
    final todayStart = _startOfDay(today);

    for (final debt in overdue) {
      final latest = await _billingService.getBilling(
        opticaId: opticaId,
        billingId: debt.id,
      );
      if (latest == null || latest.remaining <= 0) continue;

      final dueStart = _startOfDay(latest.dueDate.toDate());
      final daysOverdue = todayStart.difference(dueStart).inDays;
      if (daysOverdue <= 0) continue;
      if (daysOverdue % config.debtRepeatDays != 0) continue;

      final customer = await _customerService.getCustomer(
        opticaId: opticaId,
        customerId: latest.customerId,
      );

      if (customer == null ||
          !customer.debtsSmsEnabled ||
          customer.phone.trim().isEmpty) {
        continue;
      }

      final msg = _buildDebtMessage(
        customer.firstName,
        customer.lastName,
        latest,
        config,
        SmsLogTypes.debtRepeat,
      );

      await _smsRuleEngine.sendDebtSms(
        opticaId: opticaId,
        billing: latest,
        customer: customer,
        type: SmsLogTypes.debtRepeat,
        message: msg,
        config: config,
        allowRepeat: true,
        minDaysBetween: config.debtRepeatDays,
      );

      await Future.delayed(smsDelayWithJitter());
    }
  }

  Future<void> _sendVisitStageForDate({
    required DateTime targetDay,
    required String type,
    required SmsConfigModel config,
  }) async {
    final start = _startOfDay(targetDay);
    final end = start.add(const Duration(days: 1));

    final visits = await _visitService.fetchVisitsByDateRange(
      opticaId: opticaId,
      start: start,
      end: end,
    );

    for (final visit in visits) {
      if (!visit.isPending) continue;

      final customer = await _customerService.getCustomer(
        opticaId: opticaId,
        customerId: visit.customerId,
      );

      if (customer == null ||
          !customer.visitsSmsEnabled ||
          customer.phone.trim().isEmpty) {
        continue;
      }

      final msg = _buildVisitMessage(
        customer.firstName,
        customer.lastName,
        visit,
        config,
        type,
      );

      await _smsRuleEngine.sendVisitSms(
        opticaId: opticaId,
        visit: visit,
        customer: customer,
        type: type,
        message: msg,
        config: config,
      );

      await Future.delayed(smsDelayWithJitter());
    }
  }

  Future<void> _sendDebtStageForDate({
    required DateTime targetDay,
    required String type,
    required SmsConfigModel config,
  }) async {
    final start = _startOfDay(targetDay);
    final end = start.add(const Duration(days: 1));

    final debts = await _billingService.fetchBillingsByDueDateRange(
      opticaId: opticaId,
      start: start,
      end: end,
    );

    for (final debt in debts) {
      final latest = await _billingService.getBilling(
        opticaId: opticaId,
        billingId: debt.id,
      );
      if (latest == null || latest.remaining <= 0) continue;

      final customer = await _customerService.getCustomer(
        opticaId: opticaId,
        customerId: latest.customerId,
      );

      if (customer == null ||
          !customer.debtsSmsEnabled ||
          customer.phone.trim().isEmpty) {
        continue;
      }

      final msg = _buildDebtMessage(
        customer.firstName,
        customer.lastName,
        latest,
        config,
        type,
      );

      await _smsRuleEngine.sendDebtSms(
        opticaId: opticaId,
        billing: latest,
        customer: customer,
        type: type,
        message: msg,
        config: config,
      );

      await Future.delayed(smsDelayWithJitter());
    }
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


  String _buildVisitMessage(
    String firstName,
    String? lastName,
    VisitModel visit,
    SmsConfigModel config,
    String type,
  ) {
    final isCyrillic = config.isSmsCyrillic;
    final date = _formatDate(visit.visitDate, isCyrillic: isCyrillic);
    final opticaPhone =
        config.opticaPhone.trim().isEmpty ? '933400034' : config.opticaPhone;
    final safeLastName = (lastName ?? '').trim();

    final template = SmsTemplateEngine.resolveTemplate(
      config: config,
      type: type,
    );

    final message = SmsTemplateEngine.render(
      template: template,
      variables: {
        'firstName': firstName,
        'lastName': safeLastName,
        'visitDate': date,
        'visitReason': visit.reason,
        'opticaName': config.opticaName,
        'opticaPhone': opticaPhone,
      },
    );

    return smsSanitize(message, allowUnicode: isCyrillic);
  }

  String _buildDebtMessage(
    String firstName,
    String? lastName,
    BillingModel debt,
    SmsConfigModel config,
    String type,
  ) {
    final isCyrillic = config.isSmsCyrillic;
    final dueDate = debt.dueDate.toDate();
    final dueStr = _formatDate(dueDate, isCyrillic: isCyrillic);
    final amount = debt.remaining.toStringAsFixed(0);
    final paidAmount = debt.amountPaid.toStringAsFixed(0);
    final opticaPhone =
        config.opticaPhone.trim().isEmpty ? '933400034' : config.opticaPhone;
    final safeLastName = (lastName ?? '').trim();

    final template = SmsTemplateEngine.resolveTemplate(
      config: config,
      type: type,
    );

    final message = SmsTemplateEngine.render(
      template: template,
      variables: {
        'firstName': firstName,
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

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
