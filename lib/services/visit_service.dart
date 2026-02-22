import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:robot_optica/models/customer_model.dart';
import 'package:robot_optica/services/customer_service.dart';
import 'package:robot_optica/services/optica_service.dart';
import '../models/visit_model.dart';
import '../models/sms_config_model.dart';
import '../services/sms_rule_engine.dart';
import '../utils/sms_sanitizer.dart';
import '../utils/sms_template_engine.dart';
import '../utils/sms_types.dart';
import '../utils/device_info_utils.dart';

class VisitService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CustomerService _customerService = CustomerService();
  final OpticaService _opticaService = OpticaService();
  final SmsRuleEngine _smsRuleEngine = SmsRuleEngine();

  CollectionReference _visitRef(String opticaId) {
    return _db
        .collection('opticas')
        .doc(opticaId)
        .collection('visits');
  }



  // ============================
  // TYPE SAFE REALTIME LISTENER
  // ============================

  void listenForNewVisits(String opticaId) {
    _visitRef(opticaId)
        .where('visitSmsPending', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added &&
            change.type != DocumentChangeType.modified) {
          continue;
        }

        // Type-safe conversion
        final visit = VisitModel.fromFirestore(change.doc);

        // Fetch customer safely
        final CustomerModel? customer = await _customerService.getCustomer(
          opticaId: opticaId,
          customerId: visit.customerId,
        );

        if (customer == null ||
            !customer.visitsSmsEnabled ||
            customer.phone.isEmpty) {
          await _clearVisitSmsPending(opticaId, visit.id);
          continue;
        }

        final SmsConfigModel config = await _opticaService.getSmsConfig(opticaId);
        if (!config.visitSendOnCreate || !config.isSmsEnabled || !config.smsForVisits) {
          await _clearVisitSmsPending(opticaId, visit.id);
          continue;
        }

        final localDeviceId = await getDeviceId();
        if (config.smsEnabledDeviceId == null || localDeviceId == null) continue;
        if (config.smsEnabledDeviceId != localDeviceId) continue;

        final sent = await _smsRuleEngine.sendVisitSms(
          opticaId: opticaId,
          visit: visit,
          customer: customer,
          type: SmsLogTypes.visitCreated,
          message: _buildVisitMessage(
            visit,
            customer.firstName,
            customer.lastName,
            config,
          ),
          config: config,
        );

        if (sent) {
          await _clearVisitSmsPending(opticaId, visit.id);
        }
      }
    });
  }



  Future<void> _clearVisitSmsPending(String opticaId, String visitId) async {
    await _visitRef(opticaId).doc(visitId).update({
      'visitSmsPending': false,
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


  // ============================
  // MESSAGE FORMAT (TYPE SAFE)
  // ============================

  String _buildVisitMessage(
    VisitModel visit,
    String firstName,
    String? lastName,
    SmsConfigModel config,
  ) {
    final isCyrillic = config.isSmsCyrillic;
    final date = _formatDate(visit.visitDate, isCyrillic: isCyrillic);
    final opticaPhone =
        config.opticaPhone.trim().isEmpty ? '933400034' : config.opticaPhone;
    final safeLastName = (lastName ?? '').trim();

    final template = SmsTemplateEngine.resolveTemplate(
      config: config,
      type: SmsLogTypes.visitCreated,
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

  Future<List<VisitModel>> fetchVisitsByCustomer(
      String opticaId,
      String customerId,
      ) async {
    final snapshot = await _visitRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .orderBy('visitDate')
        .get();

    return snapshot.docs
        .map((doc) => VisitModel.fromFirestore(doc))
        .toList();
  }

  Future<List<VisitModel>> fetchAllVisits({
    required String opticaId,
    DocumentSnapshot? startAfterDoc,
    int limit = 20,
  }) async {
    Query query = _visitRef(opticaId)
        .orderBy('visitDate')
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => VisitModel.fromFirestore(doc))
        .toList();
  }

  Future<List<VisitModel>> fetchPendingVisitSms({
    required String opticaId,
    int limit = 50,
  }) async {
    final snapshot = await _visitRef(opticaId)
        .where('visitSmsPending', isEqualTo: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => VisitModel.fromFirestore(doc))
        .toList();
  }

  Future<void> clearVisitSmsPending(String opticaId, String visitId) async {
    await _clearVisitSmsPending(opticaId, visitId);
  }

  Future<List<VisitModel>> fetchVisitsByDateRange({
    required String opticaId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _visitRef(opticaId)
        .where('visitDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('visitDate', isLessThan: Timestamp.fromDate(end))
        .orderBy('visitDate')
        .get();

    return snapshot.docs
        .map((doc) => VisitModel.fromFirestore(doc))
        .toList();
  }

  /// Filters:
  /// pending | visited | lateVisited | notVisited | today | week | month | year
  Future<List<VisitModel>> fetchFilteredVisits(
      String opticaId,
      String filter, {
        DocumentSnapshot? startAfterDoc,
        int limit = 20,
      }) async {
    Query query = _visitRef(opticaId);
    final now = DateTime.now();

    if (filter == 'pending' ||
        filter == 'visited' ||
        filter == 'lateVisited' ||
        filter == 'notVisited') {
      query = query.where('status', isEqualTo: filter);
    }

    if (filter == 'today') {
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      query = query
          .where('visitDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('visitDate', isLessThan: Timestamp.fromDate(end));
    } else if (filter == 'week') {
      final start = now.subtract(Duration(days: now.weekday - 1));
      final end = start.add(const Duration(days: 7));
      query = query
          .where('visitDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('visitDate', isLessThan: Timestamp.fromDate(end));
    } else if (filter == 'month') {
      final start = DateTime(now.year, now.month);
      final end = DateTime(now.year, now.month + 1);
      query = query
          .where('visitDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('visitDate', isLessThan: Timestamp.fromDate(end));
    } else if (filter == 'year') {
      final start = DateTime(now.year);
      final end = DateTime(now.year + 1);
      query = query
          .where('visitDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('visitDate', isLessThan: Timestamp.fromDate(end));
    }

    query = query.orderBy('visitDate').limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => VisitModel.fromFirestore(doc))
        .toList();
  }



  Future<String> addVisit(String opticaId, VisitModel visit) async {
    final docRef = _visitRef(opticaId).doc(); // auto ID

    final visitWithId = visit.copyWith(id: docRef.id);

    final data = visitWithId.toMap();

    try {
      final config = await _opticaService.getSmsConfig(opticaId);
      if (config.isSmsEnabled && config.smsForVisits && config.visitSendOnCreate) {
        final customer = await _customerService.getCustomer(
          opticaId: opticaId,
          customerId: visit.customerId,
        );

        if (customer != null &&
            customer.visitsSmsEnabled &&
            customer.phone.trim().isNotEmpty) {
          data['visitSmsPending'] = true;
        }
      }
    } catch (_) {
      // If config fetch fails (offline), mark pending and let active device decide.
      data['visitSmsPending'] = true;
    }

    await docRef.set(data);

    return docRef.id; // ✅ return real visit id
  }


  Future<void> updateVisit(String opticaId, VisitModel visit) async {
    await _visitRef(opticaId).doc(visit.id).update(visit.toMap());
  }

  Future<void> rescheduleVisit({
    required String opticaId,
    required VisitModel visit,
    required DateTime newDate,
    required bool resetSms,
  }) async {
    final data = <String, dynamic>{
      'visitDate': Timestamp.fromDate(newDate),
      'status': VisitStatus.pending.name,
      'visitedDate': null,
    };

    if (resetSms) {
      data['remindersSent'] = 0;
      data['smsResetAt'] = Timestamp.now();
    }

    await _visitRef(opticaId).doc(visit.id).update(data);
  }

  /// Marks as visited or lateVisited depending on date
  Future<void> markVisited(String opticaId, VisitModel visit) async {
    final now = DateTime.now();

    final VisitStatus newStatus =
    now.isAfter(visit.visitDate)
        ? VisitStatus.lateVisited
        : VisitStatus.visited;

    await _visitRef(opticaId).doc(visit.id).update({
      'status': newStatus.name,
      'visitedDate': Timestamp.fromDate(now),
    });
  }

  Future<void> markNotVisited(String opticaId, String visitId) async {
    await _visitRef(opticaId).doc(visitId).update({
      'status': VisitStatus.notVisited.name,
      'visitedDate': null,
    });
  }

  Future<void> deleteVisit(String opticaId, String visitId) async {
    await _visitRef(opticaId).doc(visitId).delete();
  }

  Future<int?> getTotalVisits(String opticaId) async {
    final snapshot = await _visitRef(opticaId).count().get();
    return snapshot.count;
  }

  Future<int?> getVisitsToday(String opticaId) async {
    final start = _startOfToday();
    final end = start.add(const Duration(days: 1));

    final snapshot = await _visitRef(opticaId)
        .where('visitDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('visitDate', isLessThan: Timestamp.fromDate(end))
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getVisitsLast7Days(String opticaId) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));

    final snapshot = await _visitRef(opticaId)
        .where('visitDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('visitDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getVisitsLast30Days(String opticaId) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));

    final snapshot = await _visitRef(opticaId)
        .where('visitDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('visitDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getVisitsThisYear(String opticaId) async {
    final start = _startOfYear();
    final now = DateTime.now();

    final snapshot = await _visitRef(opticaId)
        .where('visitDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('visitDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .count()
        .get();

    return snapshot.count;
  }
  Future<int?> getCompletedVisits(String opticaId) async {
    final snapshot = await _visitRef(opticaId)
        .where('status', isEqualTo: VisitStatus.visited.name)
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getLateVisits(String opticaId) async {
    final snapshot = await _visitRef(opticaId)
        .where('status', isEqualTo: VisitStatus.lateVisited.name)
        .count()
        .get();

    return snapshot.count;
  }
  Future<int?> getMissedVisits(String opticaId) async {
    final snapshot = await _visitRef(opticaId)
        .where('status', isEqualTo: VisitStatus.notVisited.name)
        .count()
        .get();

    return snapshot.count;
  }
  Future<int?> getPendingVisits(String opticaId) async {
    final snapshot = await _visitRef(opticaId)
        .where('status', isEqualTo: VisitStatus.pending.name)
        .count()
        .get();

    return snapshot.count;
  }

  Future<List<VisitModel>> fetchRecentVisits(
      String opticaId, {
        int limit = 5,
      }) async {
    final snapshot = await _visitRef(opticaId)
        .orderBy('visitDate', descending: true) // most recent first
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => VisitModel.fromFirestore(doc))
        .toList();
  }

  Future<int?> getCustomerVisitsCount(
      String opticaId,
      String customerId,
      ) async {
    final snapshot = await _visitRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getVisitsTodayCount(String opticaId) async {
    final start = _startOfToday();
    final end = start.add(const Duration(days: 1));

    final snapshot = await _visitRef(opticaId)
        .where('visitDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('visitDate', isLessThan: Timestamp.fromDate(end))
        .count()
        .get();

    return snapshot.count;
  }


}



DateTime _startOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _startOfWeek() {
  final now = DateTime.now();
  return now.subtract(Duration(days: now.weekday - 1));
}

DateTime _startOfMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}

DateTime _startOfYear() {
  final now = DateTime.now();
  return DateTime(now.year);
}
