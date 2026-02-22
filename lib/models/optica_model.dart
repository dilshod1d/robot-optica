import 'package:cloud_firestore/cloud_firestore.dart';

class OpticaModel {
  final String id;
  final String name;
  final String ownerId;
  final String phone;
  final Timestamp createdAt;
  final String? smsEnabledDeviceId;
  final String? smsEnabledPlatform;
  final Timestamp? smsEnabledAt;

  OpticaModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.phone,
    required this.createdAt,
    this.smsEnabledDeviceId,
    this.smsEnabledPlatform,
    this.smsEnabledAt,
  });

  factory OpticaModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return OpticaModel(
      id: doc.id,
      name: data['name'],
      ownerId: data['ownerId'],
      phone: data['phone'],
      createdAt: data['createdAt'],
      smsEnabledDeviceId: data['smsEnabledDeviceId'],
      smsEnabledPlatform: data['smsEnabledPlatform'],
      smsEnabledAt: data['smsEnabledAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'phone': phone,
      'createdAt': createdAt,
      if (smsEnabledDeviceId != null)
        'smsEnabledDeviceId': smsEnabledDeviceId,
      if (smsEnabledPlatform != null)
        'smsEnabledPlatform': smsEnabledPlatform,
      if (smsEnabledAt != null)
        'smsEnabledAt': smsEnabledAt,
    };
  }
}
