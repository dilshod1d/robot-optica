import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../models/sms_log_model.dart';
import '../utils/sms_types.dart';

class SmsLogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _smsLogRef(String opticaId) {
    return _db
        .collection('opticas')
        .doc(opticaId)
        .collection('sms_logs');
  }

  Future<List<SmsLogModel>> fetchLogsByCustomer({
    required String opticaId,
    required String customerId,
    DateTime? after,
    DocumentSnapshot? startAfterDoc,
    int limit = 20,
  }) async {
    Query query = _smsLogRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .orderBy('sentAt', descending: true);

    if (after != null) {
      query = query.where(
        'sentAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(after),
      );
    }

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs.map((doc) => SmsLogModel.fromFirestore(doc)).toList();
  }

  Future<List<SmsLogModel>> fetchAllLogs({
    required String opticaId,
    DateTime? after,
    DocumentSnapshot? startAfterDoc,
    int limit = 20,
  }) async {
    Query query = _smsLogRef(opticaId)
        .orderBy('sentAt', descending: true);

    if (after != null) {
      query = query.where(
        'sentAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(after),
      );
    }

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs.map((doc) => SmsLogModel.fromFirestore(doc)).toList();
  }

  Future<void> logSms({
    required String opticaId,
    required SmsLogModel log,
  }) async {
    try {
      final ref = _smsLogRef(opticaId).doc(log.id);

      await ref.set({
        ...log.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ SMS log saved: ${ref.id}');
    } catch (e, s) {
      debugPrint('❌ Failed to save SMS log: $e');
      debugPrintStack(stackTrace: s);
      rethrow; // so UI can react if needed
    }
  }


  // Future<void> logSms({
  //   required String opticaId,
  //   required SmsLogModel log,
  // }) async {
  //   await _smsLogRef(opticaId).doc(log.id).set(log.toMap());
  // }

  Future<int?> getTotalVisitSms(String opticaId) async {
    final snapshot = await _smsLogRef(opticaId)
        .where('type', whereIn: SmsLogTypes.visitTypes)
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getVisitSmsToday(String opticaId) async {
    final start = _startOfToday();
    final end = start.add(const Duration(days: 1));

    final snapshot = await _smsLogRef(opticaId)
        .where('type', whereIn: SmsLogTypes.visitTypes)
        .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('sentAt', isLessThan: Timestamp.fromDate(end))
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getVisitSmsLast7Days(String opticaId) async {
    final start = _startOfLast7Days();
    final now = DateTime.now();

    final snapshot = await _smsLogRef(opticaId)
        .where('type', whereIn: SmsLogTypes.visitTypes)
        .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getVisitSmsLast30Days(String opticaId) async {
    final start = _startOfLast30Days();
    final now = DateTime.now();

    final snapshot = await _smsLogRef(opticaId)
        .where('type', whereIn: SmsLogTypes.visitTypes)
        .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getTotalDebtSms(String opticaId) async {
    final snapshot = await _smsLogRef(opticaId)
        .where('type', whereIn: SmsLogTypes.debtTypes)
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getDebtSmsToday(String opticaId) async {
    final start = _startOfToday();
    final end = start.add(const Duration(days: 1));

    final snapshot = await _smsLogRef(opticaId)
        .where('type', whereIn: SmsLogTypes.debtTypes)
        .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('sentAt', isLessThan: Timestamp.fromDate(end))
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getDebtSmsLast7Days(String opticaId) async {
    final start = _startOfLast7Days();
    final now = DateTime.now();

    final snapshot = await _smsLogRef(opticaId)
        .where('type', whereIn: SmsLogTypes.debtTypes)
        .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getDebtSmsLast30Days(String opticaId) async {
    final start = _startOfLast30Days();
    final now = DateTime.now();

    final snapshot = await _smsLogRef(opticaId)
        .where('type', whereIn: SmsLogTypes.debtTypes)
        .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .count()
        .get();

    return snapshot.count;
  }

  Future<int?> getCustomerSmsCount({
    required String opticaId,
    required String customerId,
  }) async {
    final snapshot = await _smsLogRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .count()
        .get();

    return snapshot.count;
  }

  Future<int> getVisitSmsCount({
    required String opticaId,
    required String visitId,
    DateTime? after,
  }) async {
    Query<Map<String, dynamic>> query =
        _smsLogRef(opticaId).where('visitId', isEqualTo: visitId);
    if (after != null) {
      query = query.where(
        'sentAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(after),
      );
    }

    final snapshot = await query.count().get();

    return snapshot.count ?? 0;
  }

  Future<int> getDebtSmsCount({
    required String opticaId,
    required String debtId,
    DateTime? after,
  }) async {
    Query<Map<String, dynamic>> query =
        _smsLogRef(opticaId).where('debtId', isEqualTo: debtId);
    if (after != null) {
      query = query.where(
        'sentAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(after),
      );
    }

    final snapshot = await query.count().get();

    return snapshot.count ?? 0;
  }

  Future<DateTime?> getLastDebtSmsSentAt({
    required String opticaId,
    required String debtId,
    String? type,
    DateTime? after,
  }) async {
    Query<Map<String, dynamic>> query = _smsLogRef(opticaId)
        .where('debtId', isEqualTo: debtId)
        .orderBy('sentAt', descending: true);

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    if (after != null) {
      query = query.where(
        'sentAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(after),
      );
    }

    query = query.limit(1);

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return null;
    final data = snapshot.docs.first.data();
    if (data == null) return null;
    final sentAt = data['sentAt'];
    if (sentAt is Timestamp) {
      return sentAt.toDate();
    }
    if (sentAt is DateTime) {
      return sentAt;
    }
    return null;
  }

  Future<bool> hasVisitSmsStage({
    required String opticaId,
    required String visitId,
    required String type,
    DateTime? after,
  }) async {
    Query<Map<String, dynamic>> query = _smsLogRef(opticaId)
        .where('visitId', isEqualTo: visitId)
        .where('type', isEqualTo: type);
    if (after != null) {
      query = query.where(
        'sentAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(after),
      );
    }

    final snapshot = await query.limit(1).get();

    return snapshot.docs.isNotEmpty;
  }

  Future<bool> hasDebtSmsStage({
    required String opticaId,
    required String debtId,
    required String type,
    DateTime? after,
  }) async {
    Query<Map<String, dynamic>> query = _smsLogRef(opticaId)
        .where('debtId', isEqualTo: debtId)
        .where('type', isEqualTo: type);
    if (after != null) {
      query = query.where(
        'sentAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(after),
      );
    }

    final snapshot = await query.limit(1).get();

    return snapshot.docs.isNotEmpty;
  }

  Future<int> getPrescriptionSmsCount({
    required String opticaId,
    required String prescriptionId,
  }) async {
    final snapshot = await _smsLogRef(opticaId)
        .where('prescriptionId', isEqualTo: prescriptionId)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  Future<bool> hasPrescriptionSmsStage({
    required String opticaId,
    required String prescriptionId,
    required String type,
  }) async {
    final snapshot = await _smsLogRef(opticaId)
        .where('prescriptionId', isEqualTo: prescriptionId)
        .where('type', isEqualTo: type)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<void> deleteVisitSmsLogs({
    required String opticaId,
    required String visitId,
  }) async {
    const batchLimit = 200;

    while (true) {
      final snapshot = await _smsLogRef(opticaId)
          .where('visitId', isEqualTo: visitId)
          .limit(batchLimit)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < batchLimit) return;
    }
  }

}

DateTime _startOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _startOfLast7Days() {
  return DateTime.now().subtract(const Duration(days: 7));
}

DateTime _startOfLast30Days() {
  return DateTime.now().subtract(const Duration(days: 30));
}
