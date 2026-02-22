import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String id;
  final String opticaId;
  final String firstName;
  final String? lastName;
  final String phone;
  final Timestamp createdAt;
  final bool visitsSmsEnabled;
  final bool debtsSmsEnabled;
  final bool loyaltyEnabled;
  final int loyaltyPurchaseCount;

  CustomerModel({
    required this.id,
    required this.opticaId,
    required this.firstName,
    this.lastName,
    required this.phone,
    required this.createdAt,
    this.visitsSmsEnabled = true,
    this.debtsSmsEnabled = true,
    this.loyaltyEnabled = false,
    this.loyaltyPurchaseCount = 0,
  });

  String get fullName {
    return "${firstName.trim()} ${lastName?.trim() ?? ""}".trim();
  }

  String get fullNameLower {
    return fullName.toLowerCase();
  }

  // ✅ ADD THIS
  factory CustomerModel.create({
    required String opticaId,
    required String firstName,
    String? lastName,
    required String phone,
  }) {
    final id = FirebaseFirestore.instance.collection('tmp').doc().id;

    return CustomerModel(
      id: id,
      opticaId: opticaId,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      createdAt: Timestamp.now(),
      visitsSmsEnabled: true,
      debtsSmsEnabled: true,
      loyaltyEnabled: false,
      loyaltyPurchaseCount: 0,
    );
  }

  factory CustomerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CustomerModel(
      id: doc.id,
      opticaId: data['opticaId'],
      firstName: data['firstName'],
      lastName: data['lastName'],
      phone: data['phone'],
      createdAt: data['createdAt'],
      visitsSmsEnabled: data['visitsSmsEnabled'] ?? true,
      debtsSmsEnabled: data['debtsSmsEnabled'] ?? true,
      loyaltyEnabled: data['loyaltyEnabled'] ?? false,
      loyaltyPurchaseCount: data['loyaltyPurchaseCount'] is num
          ? (data['loyaltyPurchaseCount'] as num).toInt()
          : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'opticaId': opticaId,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'createdAt': createdAt,
      'fullNameLower': fullNameLower,
      'visitsSmsEnabled': visitsSmsEnabled,
      'debtsSmsEnabled': debtsSmsEnabled,
      'loyaltyEnabled': loyaltyEnabled,
      'loyaltyPurchaseCount': loyaltyPurchaseCount,
    };
  }

  CustomerModel copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    bool? visitsSmsEnabled,
    bool? debtsSmsEnabled,
    bool? loyaltyEnabled,
    int? loyaltyPurchaseCount,
  }) {
    return CustomerModel(
      id: id,
      opticaId: opticaId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      createdAt: createdAt,
      visitsSmsEnabled: visitsSmsEnabled ?? this.visitsSmsEnabled,
      debtsSmsEnabled: debtsSmsEnabled ?? this.debtsSmsEnabled,
      loyaltyEnabled: loyaltyEnabled ?? this.loyaltyEnabled,
      loyaltyPurchaseCount: loyaltyPurchaseCount ?? this.loyaltyPurchaseCount,
    );
  }
}
