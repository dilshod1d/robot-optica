import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/billing_model.dart';

class BillingStatsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String opticaId) {
    return _db
        .collection('opticas')
        .doc(opticaId)
        .collection('billing_stats')
        .doc('main');
  }
  // ---------------- INIT ----------------

  Future<void> initIfMissing(String opticaId) async {
    final ref = _ref(opticaId);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set({
        'totalBilled': 0.0,
        'totalCollected': 0.0,
        'totalUnpaid': 0.0,

        'paidCount': 0,
        'partialCount': 0,
        'overdueCount': 0,
        'pendingDueCount': 0,

        'updatedAt': Timestamp.now(),
      });
    }
  }

  // ---------------- CREATE ----------------

  Future<void> onCreate({
    required String opticaId,
    required BillingModel billing,
  }) async {
    await initIfMissing(opticaId);

    final ref = _ref(opticaId);

    final data = <String, dynamic>{
      'totalBilled': FieldValue.increment(billing.amountDue),
      'totalCollected': FieldValue.increment(billing.amountPaid),
      'totalUnpaid': FieldValue.increment(billing.remaining),
      'updatedAt': Timestamp.now(),
    };

    _applyCountIncrement(billing, data);

    await ref.update(data);
  }

  // ---------------- PAYMENT ----------------

  /// Pass only the delta paid amount
  Future<void> onPayment({
    required String opticaId,
    required double amountDelta,
  }) async {
    final ref = _ref(opticaId);

    await ref.update({
      'totalCollected': FieldValue.increment(amountDelta),
      'totalUnpaid': FieldValue.increment(-amountDelta),
      'updatedAt': Timestamp.now(),
    });
  }

  // ---------------- STATUS CHANGE ----------------

  Future<void> onStatusChange({
    required String opticaId,
    required BillingModel oldBilling,
    required BillingModel newBilling,
  }) async {
    final ref = _ref(opticaId);
    final data = <String, dynamic>{};

    _applyCountDecrement(oldBilling, data);
    _applyCountIncrement(newBilling, data);

    data['updatedAt'] = Timestamp.now();
    await ref.update(data);
  }

  // ---------------- DELETE ----------------

  Future<void> onDelete({
    required String opticaId,
    required BillingModel billing,
  }) async {
    final ref = _ref(opticaId);

    final data = <String, dynamic>{
      'totalBilled': FieldValue.increment(-billing.amountDue),
      'totalCollected': FieldValue.increment(-billing.amountPaid),
      'totalUnpaid': FieldValue.increment(-billing.remaining),
      'updatedAt': Timestamp.now(),
    };

    _applyCountDecrement(billing, data);

    await ref.update(data);
  }

  // ---------------- HELPERS ----------------

  void _applyCountIncrement(BillingModel b, Map<String, dynamic> data) {
    if (b.remaining == 0) {
      data['paidCount'] = FieldValue.increment(1);
    } else if (b.amountPaid > 0) {
      data['partialCount'] = FieldValue.increment(1);
    } else if (b.isOverdue) {
      data['overdueCount'] = FieldValue.increment(1);
    } else {
      data['pendingDueCount'] = FieldValue.increment(1);
    }
  }

  void _applyCountDecrement(BillingModel b, Map<String, dynamic> data) {
    if (b.remaining == 0) {
      data['paidCount'] = FieldValue.increment(-1);
    } else if (b.amountPaid > 0) {
      data['partialCount'] = FieldValue.increment(-1);
    } else if (b.isOverdue) {
      data['overdueCount'] = FieldValue.increment(-1);
    } else {
      data['pendingDueCount'] = FieldValue.increment(-1);
    }
  }

  // ---------------- READ ----------------

  Future<Map<String, dynamic>> getStats(String opticaId) async {
    final doc = await _ref(opticaId).get();
    return doc.data()!;
  }

  Stream<Map<String, dynamic>> watchStats(String opticaId) async* {
    await initIfMissing(opticaId);

    yield* _ref(opticaId).snapshots().map((d) {
      return d.data() ?? {
        'totalBilled': 0.0,
        'totalCollected': 0.0,
        'totalUnpaid': 0.0,
        'paidCount': 0,
        'partialCount': 0,
        'overdueCount': 0,
        'pendingDueCount': 0,
      };
    });
  }

}
