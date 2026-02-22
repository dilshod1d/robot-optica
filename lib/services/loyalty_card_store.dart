import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/loyalty_card_model.dart';

class LoyaltyCardStore {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> _cardsRef(String opticaId) {
    return _db.collection('opticas').doc(opticaId).collection('loyalty_cards');
  }

  Future<LoyaltyCardModel> createCard({
    required String opticaId,
    String? customerId,
    String? cardId,
  }) async {
    final id = cardId ?? _uuid.v4();
    final now = Timestamp.now();
    final data = <String, dynamic>{
      'createdAt': now,
      if (customerId != null && customerId.trim().isNotEmpty)
        'customerId': customerId.trim(),
      if (customerId != null && customerId.trim().isNotEmpty)
        'linkedAt': now,
    };
    await _cardsRef(opticaId).doc(id).set(data);
    return LoyaltyCardModel(
      id: id,
      opticaId: opticaId,
      customerId: customerId,
      createdAt: now,
      linkedAt: customerId == null ? null : now,
    );
  }

  Future<LoyaltyCardModel?> getCard({
    required String opticaId,
    required String cardId,
  }) async {
    final doc = await _cardsRef(opticaId).doc(cardId).get();
    if (!doc.exists) return null;
    return LoyaltyCardModel.fromFirestore(doc, opticaId);
  }

  Future<void> linkCard({
    required String opticaId,
    required String cardId,
    required String customerId,
  }) async {
    await _cardsRef(opticaId).doc(cardId).update({
      'customerId': customerId,
      'linkedAt': Timestamp.now(),
    });
  }
}
