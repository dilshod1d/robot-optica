import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';

class CustomerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _customerRef(String opticaId) {
    return _db.collection('opticas').doc(opticaId).collection('customers');
  }

  // ========================
  // CREATE CUSTOMER
  // ========================
  Future<void> createCustomer({
    required String opticaId,
    required CustomerModel customer,
  }) async {
    await _customerRef(opticaId).doc(customer.id).set(customer.toMap());
  }

  // ========================
  // DELETE CUSTOMER
  // ========================
  Future<void> deleteCustomer({
    required String opticaId,
    required String customerId,
  }) async {
    await _customerRef(opticaId).doc(customerId).delete();
  }

  // ========================
  // CASCADE DELETE CUSTOMER
  // ========================
  Future<void> deleteCustomerCascade({
    required String opticaId,
    required String customerId,
  }) async {
    final opticaRef = _db.collection('opticas').doc(opticaId);

    await _deleteByQuery(
      opticaRef.collection('visits').where('customerId', isEqualTo: customerId),
    );

    await _deleteByQuery(
      opticaRef
          .collection('eye_analyses')
          .where('customerId', isEqualTo: customerId),
    );

    await _deleteByQuery(
      opticaRef
          .collection('care_plans')
          .where('customerId', isEqualTo: customerId),
    );

    await _deleteBillingsAndPayments(
      opticaId: opticaId,
      customerId: customerId,
    );

    await _deleteByQuery(
      opticaRef
          .collection('sms_logs')
          .where('customerId', isEqualTo: customerId),
    );

    await _customerRef(opticaId).doc(customerId).delete();
  }

  Future<void> _deleteBillingsAndPayments({
    required String opticaId,
    required String customerId,
  }) async {
    const batchSize = 300;
    final billingsRef =
        _db.collection('opticas').doc(opticaId).collection('billings');

    while (true) {
      final snapshot = await billingsRef
          .where('customerId', isEqualTo: customerId)
          .limit(batchSize)
          .get();

      if (snapshot.docs.isEmpty) break;

      for (final doc in snapshot.docs) {
        await _deleteCollection(doc.reference.collection('payments'));
      }

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteByQuery(Query<Map<String, dynamic>> query) async {
    const batchSize = 300;
    while (true) {
      final snapshot = await query.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    const batchSize = 300;
    while (true) {
      final snapshot = await ref.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // ========================
  // GET SINGLE CUSTOMER
  // ========================
  Future<CustomerModel?> getCustomer({
    required String opticaId,
    required String customerId,
  }) async {
    final doc = await _customerRef(opticaId).doc(customerId).get();
    if (!doc.exists) return null;
    return CustomerModel.fromFirestore(doc);
  }

  // ========================
  // STREAM ALL CUSTOMERS
  // ========================
  Stream<List<CustomerModel>> watchCustomers(String opticaId) {
    return _customerRef(opticaId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CustomerModel.fromFirestore(doc);
      }).toList();
    });
  }

  // ========================
  // FETCH ALL CUSTOMERS (ONE-TIME)
  // ========================
  Future<List<CustomerModel>> fetchAllCustomers({
    required String opticaId,
  }) async {
    final snapshot = await _customerRef(opticaId).get();
    return snapshot.docs.map((doc) {
      return CustomerModel.fromFirestore(doc);
    }).toList();
  }

  // ========================
  // UPDATE CUSTOMER INFO
  // ========================
  Future<void> updateCustomerInfo({
    required String opticaId,
    required String customerId,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final data = <String, dynamic>{};

    if (firstName != null) data['firstName'] = firstName;
    if (lastName != null) data['lastName'] = lastName;
    if (phone != null) data['phone'] = phone;

    if (data.isEmpty) return;

    if (firstName != null || lastName != null) {
      final nameKey = _normalizeNameKey(
        firstName ?? '',
        lastName,
      );
      if (nameKey.isNotEmpty) {
        data['fullNameLower'] = nameKey;
      }
    }

    await _customerRef(opticaId).doc(customerId).update(data);
  }

  // ========================
  // TOGGLE VISITS SMS
  // ========================
  Future<void> setVisitsSmsEnabled({
    required String opticaId,
    required String customerId,
    required bool enabled,
  }) async {
    await _customerRef(opticaId).doc(customerId).update({
      'visitsSmsEnabled': enabled,
    });
  }

  // ========================
  // TOGGLE DEBTS SMS
  // ========================
  Future<void> setDebtsSmsEnabled({
    required String opticaId,
    required String customerId,
    required bool enabled,
  }) async {
    await _customerRef(opticaId).doc(customerId).update({
      'debtsSmsEnabled': enabled,
    });
  }

  // ========================
  // TOGGLE LOYALTY
  // ========================
  Future<void> setLoyaltyEnabled({
    required String opticaId,
    required String customerId,
    required bool enabled,
  }) async {
    await _customerRef(opticaId).doc(customerId).update({
      'loyaltyEnabled': enabled,
    });
  }

  // ========================
  // SEARCH CUSTOMERS (CLIENT SIDE)
  // ========================
  Stream<List<CustomerModel>> searchCustomers({
    required String opticaId,
    required String query,
  }) {
    return watchCustomers(opticaId).map((list) {
      if (query.trim().isEmpty) return list;

      final q = query.toLowerCase();

      return list.where((c) {
        final fullName =
        '${c.firstName} ${c.lastName ?? ""}'.toLowerCase();
        return fullName.contains(q) ||
            c.phone.toLowerCase().contains(q);
      }).toList();
    });
  }

  // ========================
  // STREAM: TOTAL CUSTOMERS COUNT
  // ========================
  Stream<int> watchTotalCustomers(String opticaId) {
    return _customerRef(opticaId).snapshots().map(
          (snapshot) => snapshot.docs.length,
    );
  }

  // ========================
  // DUPLICATE CHECK
  // ========================
  Future<CustomerDuplicateCheck> checkDuplicate({
    required String opticaId,
    required String phone,
    required String firstName,
    String? lastName,
    String? excludeCustomerId,
  }) async {
    bool phoneExists = false;
    bool nameExists = false;

    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone.isNotEmpty) {
      final phoneSnapshot = await _customerRef(opticaId)
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get();

      if (phoneSnapshot.docs.isNotEmpty) {
        final docId = phoneSnapshot.docs.first.id;
        if (excludeCustomerId == null || docId != excludeCustomerId) {
          phoneExists = true;
        }
      }
    }

    final nameKey = _normalizeNameKey(firstName, lastName);
    if (nameKey.isNotEmpty) {
      final nameSnapshot = await _customerRef(opticaId)
          .where('fullNameLower', isEqualTo: nameKey)
          .limit(1)
          .get();

      if (nameSnapshot.docs.isNotEmpty) {
        final docId = nameSnapshot.docs.first.id;
        if (excludeCustomerId == null || docId != excludeCustomerId) {
          nameExists = true;
        }
      } else {
        final fallbackSnapshot = await _customerRef(opticaId)
            .where('firstName', isEqualTo: firstName.trim())
            .limit(5)
            .get();

        for (final doc in fallbackSnapshot.docs) {
          if (excludeCustomerId != null && doc.id == excludeCustomerId) {
            continue;
          }
          final data = doc.data();
          final existingLast = (data['lastName'] ?? '').toString();
          final existingKey =
              _normalizeNameKey(firstName.trim(), existingLast);
          if (existingKey == nameKey) {
            nameExists = true;
            break;
          }
        }
      }
    }

    if (!phoneExists && normalizedPhone.isNotEmpty) {
      final fallbackAll = await _customerRef(opticaId).get();
      for (final doc in fallbackAll.docs) {
        if (excludeCustomerId != null && doc.id == excludeCustomerId) {
          continue;
        }
        final data = doc.data();
        final existingPhone = _normalizePhone((data['phone'] ?? '').toString());
        if (existingPhone.isNotEmpty && existingPhone == normalizedPhone) {
          phoneExists = true;
          break;
        }
      }
    }

    if (!nameExists && nameKey.isNotEmpty) {
      final fallbackAll = await _customerRef(opticaId).get();
      for (final doc in fallbackAll.docs) {
        if (excludeCustomerId != null && doc.id == excludeCustomerId) {
          continue;
        }
        final data = doc.data();
        final existingFirst = (data['firstName'] ?? '').toString();
        final existingLast = (data['lastName'] ?? '').toString();
        final existingKey = _normalizeNameKey(existingFirst, existingLast);
        if (existingKey == nameKey) {
          nameExists = true;
          break;
        }
      }
    }

    return CustomerDuplicateCheck(
      phoneExists: phoneExists,
      nameExists: nameExists,
    );
  }

  String _normalizeNameKey(String firstName, String? lastName) {
    final full =
        "${firstName.trim()} ${lastName?.trim() ?? ""}".trim().toLowerCase();
    return full;
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\\D'), '');
  }

}

class CustomerDuplicateCheck {
  final bool phoneExists;
  final bool nameExists;

  const CustomerDuplicateCheck({
    required this.phoneExists,
    required this.nameExists,
  });
}
