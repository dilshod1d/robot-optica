import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loyalty_config_model.dart';
import '../models/optica_model.dart';
import '../models/sms_config_model.dart';

class OpticaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get optica by owner
  Future<OpticaModel?> getUserOptica(String ownerId) async {
    final snapshot = await _db
        .collection('opticas')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return OpticaModel.fromFirestore(snapshot.docs.first);
  }

  /// Get optica by ID
  Future<OpticaModel?> getOpticaById(String opticaId) async {
    final doc = await _db.collection('opticas').doc(opticaId).get();

    if (!doc.exists) return null;

    return OpticaModel.fromFirestore(doc);
  }


  Future<void> enableSmsForDevice({
    required String opticaId,
    required String deviceId,
  }) async {
    await _db.collection('opticas').doc(opticaId).update({
      'smsEnabled': true,
      'smsEnabledDeviceId': deviceId,
      'smsEnabledPlatform': 'android',
      'smsEnabledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> disableSms(String opticaId) async {
    await _db.collection('opticas').doc(opticaId).update({
      'smsEnabled': false,
      'smsEnabledDeviceId': FieldValue.delete(),
      'smsEnabledPlatform': FieldValue.delete(),
      'smsEnabledAt': FieldValue.delete(),
    });
  }

  /// Update SMS feature settings
  Future<void> updateSmsSettings({
    required String opticaId,
    bool? visits,
    bool? payments,
  }) async {
    final data = <String, dynamic>{};

    if (visits != null) data['smsForVisits'] = visits;
    if (payments != null) data['smsForPayments'] = payments;

    if (data.isNotEmpty) {
      data['smsSettingsUpdatedAt'] = FieldValue.serverTimestamp();
      await _db.collection('opticas').doc(opticaId).update(data);
    }
  }

  Future<SmsConfigModel> getSmsConfig(String opticaId) async {
    final data = await getOptica(opticaId);
    return SmsConfigModel.fromMap(data);
  }

  Future<LoyaltyConfigModel> getLoyaltyConfig(String opticaId) async {
    final data = await getOptica(opticaId);
    return LoyaltyConfigModel.fromMap(data);
  }

  Future<void> updateSmsConfigFields({
    required String opticaId,
    required Map<String, dynamic> data,
  }) async {
    if (data.isEmpty) return;
    data['smsSettingsUpdatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('opticas').doc(opticaId).update(data);
  }

  Future<void> updateLoyaltyConfigFields({
    required String opticaId,
    required Map<String, dynamic> data,
  }) async {
    if (data.isEmpty) return;
    data['loyaltySettingsUpdatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('opticas').doc(opticaId).update(data);
  }


  /// Create optica
  Future<OpticaModel> createOptica({
    required String name,
    required String ownerId,
    required String phone,
  }) async {
    final ref = _db.collection('opticas').doc();

    final optica = OpticaModel(
      id: ref.id,
      name: name,
      ownerId: ownerId,
      phone: phone,
      createdAt: Timestamp.now(),
    );

    await ref.set(optica.toMap());

    // Link optica to user
    await _db.collection('users').doc(ownerId).update({
      'activeOpticaId': ref.id,
    });

    return optica;
  }

  Future<Map<String, dynamic>> getOptica(String opticaId) async {
    final doc = await _db.collection('opticas').doc(opticaId).get();
    return doc.data()!;
  }

  Future<void> updateOptica({
    required String opticaId,
    required String name,
    required String phone,
  }) async {
    await _db.collection('opticas').doc(opticaId).update({
      'name': name,
      'phone': phone,
    });
  }
}
