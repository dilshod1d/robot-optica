import 'package:cloud_firestore/cloud_firestore.dart';

class LoyaltyCardModel {
  final String id;
  final String opticaId;
  final String? customerId;
  final Timestamp createdAt;
  final Timestamp? linkedAt;

  LoyaltyCardModel({
    required this.id,
    required this.opticaId,
    this.customerId,
    required this.createdAt,
    this.linkedAt,
  });

  bool get isLinked => customerId != null && customerId!.trim().isNotEmpty;

  factory LoyaltyCardModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String opticaId,
  ) {
    final data = doc.data() ?? {};
    return LoyaltyCardModel(
      id: doc.id,
      opticaId: opticaId,
      customerId: data['customerId'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      linkedAt: data['linkedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'createdAt': createdAt,
      if (linkedAt != null) 'linkedAt': linkedAt,
    };
  }
}
