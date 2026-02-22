import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final double amount;
  final String? note;
  final Timestamp paidAt;

  PaymentModel({
    required this.id,
    required this.amount,
    this.note,
    required this.paidAt,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return PaymentModel(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      note: data['note'],
      paidAt: data['paidAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'note': note,
      'paidAt': paidAt,
    };
  }
}
