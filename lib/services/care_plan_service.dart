import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/care_plan_model.dart';

class CarePlanService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(
      String opticaId,
      String visitId,
      ) {
    return _db
        .collection('opticas')
        .doc(opticaId)
        .collection('visits')
        .doc(visitId)
        .collection('care_plans');
  }

  /// Fetch latest care plan for a visit
  Future<CarePlanModel?> fetchLatestCarePlan(
      String opticaId,
      String visitId,
      ) async {
    final snapshot = await _ref(opticaId, visitId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return CarePlanModel.fromFirestore(doc.data(), doc.id);
  }

  /// Add new care plan
  Future<void> addCarePlan(
      String opticaId,
      String visitId,
      CarePlanModel model,
      ) async {
    await _ref(opticaId, visitId)
        .doc(model.id)
        .set(model.toMap());
  }

  /// Optional: update existing care plan
  Future<void> updateCarePlan(
      String opticaId,
      String visitId,
      CarePlanModel model,
      ) async {
    await _ref(opticaId, visitId)
        .doc(model.id)
        .update(model.toMap());
  }
}
