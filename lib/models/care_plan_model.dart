import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robot_optica/models/prescription_item.dart';

class CarePlanModel {
  final String id;
  final String? visitId;
  final String customerId;
  final List<PrescriptionItem> items;
  final String? generalAdvice;
  final DateTime createdAt;

  CarePlanModel({
    required this.id,
    this.visitId,
    required this.customerId,
    required this.items,
    this.generalAdvice,
    required this.createdAt,
  });

  factory CarePlanModel.fromFirestore(
      Map<String, dynamic> data,
      String id,
      ) {
    return CarePlanModel(
      id: id,
      visitId: data['visitId'],
      customerId: data['customerId'],
      items: (data['items'] as List)
          .map((e) => PrescriptionItem.fromMap(e))
          .toList(),
      generalAdvice: data['generalAdvice'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'visitId': visitId,
    'customerId': customerId,
    'items': items.map((e) => e.toMap()).toList(),
    'generalAdvice': generalAdvice,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
