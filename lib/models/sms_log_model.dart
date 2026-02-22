// models/sms_log_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SmsLogModel {
  final String id;
  final String customerId;
  final String phone;
  final String? debtId;
  final String? visitId;
  final String? prescriptionId;
  final String message;
  final String type; // visit/debt stages (see SmsLogTypes)
  final DateTime sentAt;

  final DocumentSnapshot? firestoreDoc;

  SmsLogModel({
    required this.id,
    required this.customerId,
    required this.phone,
    this.debtId,
    this.visitId,
    this.prescriptionId,
    required this.message,
    required this.type,
    required this.sentAt,
    this.firestoreDoc,
  });

  factory SmsLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return SmsLogModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      phone: data['phone'] ?? '',
      debtId: data['debtId'],
      visitId: data['visitId'],
      prescriptionId: data['prescriptionId'],
      message: data['message'] ?? '',
      type: data['type'] ?? 'unknown',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      firestoreDoc: doc,
    );
  }


  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'debtId': debtId,
      'phone': phone,
      'visitId': visitId,
      'prescriptionId': prescriptionId,
      'message': message,
      'type': type,
      'sentAt': Timestamp.fromDate(sentAt),
    };
  }
}
