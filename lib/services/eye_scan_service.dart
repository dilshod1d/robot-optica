import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:robot_optica/models/eye_scan_result.dart';

import '../models/eye_measurement.dart';
import '../models/eye_side.dart';


class EyeScanService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _col = 'eye_analyses';
  final GenerativeModel _model =
  FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash-lite');

  // ================== COLLECTION HELPER ==================

  CollectionReference<Map<String, dynamic>> _analysisRef(String opticaId) {
    return _db
        .collection('opticas')
        .doc(opticaId)
        .collection('eye_analyses');
  }

  Future<EyeScanResult> scanImage(Uint8List imageBytes) async {
    final prompt = '''
You are a medical OCR and data extraction engine.

Your task:
1. Read the image.
2. Extract eye prescription data.
3. Return ONLY valid JSON.
4. No explanations. No markdown. No comments.

If a field is missing, return null.

JSON schema (STRICT):
{
  "date": string|null,
  "pd": string|null,
  "right": {
    "readings": [
      { "sphere": string, "cylinder": string, "axis": string }
    ],
    "avg": { "sphere": string, "cylinder": string, "axis": string }|null,
    "se": string|null
  },
  "left": {
    "readings": [
      { "sphere": string, "cylinder": string, "axis": string }
    ],
    "avg": { "sphere": string, "cylinder": string, "axis": string }|null,
    "se": string|null
  }
}

Rules:
- Axis is always an integer from 1–180.
- Sphere and cylinder always have + or -.
- Do not hallucinate values.
- Do not guess.
- There can be any number of readings (1 or more). Include all rows you can see.

Return JSON only.
''';

    final response = await _model.generateContent([
      Content.multi([
        InlineDataPart('image/jpeg', imageBytes),
        TextPart(prompt),
      ]),
    ]);

    final raw = response.text?.trim();

    final jsonStr = _extractJson(raw!);
    final map = json.decode(jsonStr) as Map<String, dynamic>;

    return EyeScanResult.fromJson(map);
  }

  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw Exception('No JSON object found in response.');
    }
    return text.substring(start, end + 1);
  }

  // ================== FIRESTORE WRITE ==================

  Future<void> saveAnalysis({
    required String opticaId,
    required String customerId,
    String? visitId,
    required EyeScanResult scan,
  }) async {
    await _analysisRef(opticaId).add({
      'customerId': customerId,
      'visitId': visitId,
      'date': scan.date,
      'pd': scan.pd,
      'right': _sideToMap(scan.right),
      'left': _sideToMap(scan.left),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ================== READ ==================

  Stream<List<EyeScanResult>> streamByCustomer({
    required String opticaId,
    required String customerId,
  }) {
    return _analysisRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(_fromDoc).toList(),
    );
  }

  Future<List<EyeScanResult>> fetchByCustomer({
    required String opticaId,
    required String customerId,
  }) async {
    final snap = await _analysisRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map(_fromDoc).toList();
  }

  Future<void> deleteAnalysis({
    required String opticaId,
    required String analysisId,
  }) async {
    await _analysisRef(opticaId).doc(analysisId).delete();
  }

  Future<void> updateAnalysis({
    required String opticaId,
    required String analysisId,
    required EyeScanResult scan,
  }) async {
    await _analysisRef(opticaId).doc(analysisId).update({
      'date': scan.date,
      'pd': scan.pd,
      'right': _sideToMap(scan.right),
      'left': _sideToMap(scan.left),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ================== COUNTS ==================

  Future<int?> getCustomerAnalysisCount({
    required String opticaId,
    required String customerId,
  }) async {
    final snapshot = await _analysisRef(opticaId)
        .where('customerId', isEqualTo: customerId)
        .count()
        .get();

    return snapshot.count;
  }

  // ================== MAPPING ==================

  EyeScanResult _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    return EyeScanResult(
      id: doc.id,
      date: data['date'],
      pd: data['pd'],
      right: _sideFromMap(data['right']),
      left: _sideFromMap(data['left']),
    );
  }

  Map<String, dynamic> _sideToMap(EyeSide side) {
    return {
      'se': side.se,
      'avg': side.avg != null ? _measurementToMap(side.avg!) : null,
      'readings': side.readings.map(_measurementToMap).toList(),
    };
  }

  EyeSide _sideFromMap(Map<String, dynamic> map) {
    return EyeSide.fromJson(map);
  }

  Map<String, dynamic> _measurementToMap(EyeMeasurement m) {
    return {
      'sphere': m.sphere,
      'cylinder': m.cylinder,
      'axis': m.axis,
    };
  }

}
