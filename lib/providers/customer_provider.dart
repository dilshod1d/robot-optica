import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../services/customer_service.dart';

class CustomerProvider extends ChangeNotifier {
  final CustomerService _service;
  final String opticaId;

  CustomerProvider({
    required this.opticaId,
    CustomerService? service,
  }) : _service = service ?? CustomerService();

  Stream<List<CustomerModel>> watchCustomers(String opticaId) {
    return _service.watchCustomers(opticaId);
  }

  Stream<List<CustomerModel>> searchCustomers({
    required String opticaId,
    required String query,
  }) {
    return _service.searchCustomers(opticaId: opticaId, query: query);
  }

  Future<void> createCustomer({
    required String opticaId,
    required CustomerModel customer,
  }) async {
    await _service.createCustomer(opticaId: opticaId, customer: customer);
  }

  Future<void> deleteCustomer({
    required String opticaId,
    required String customerId,
  }) async {
    await _service.deleteCustomer(opticaId: opticaId, customerId: customerId);
  }

  Future<void> updateCustomerInfo({
    required String opticaId,
    required String customerId,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    await _service.updateCustomerInfo(
      opticaId: opticaId,
      customerId: customerId,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );
  }

  Future<void> setVisitsSmsEnabled({
    required String opticaId,
    required String customerId,
    required bool enabled,
  }) async {
    await _service.setVisitsSmsEnabled(
      opticaId: opticaId,
      customerId: customerId,
      enabled: enabled,
    );
  }

  Future<void> setDebtsSmsEnabled({
    required String opticaId,
    required String customerId,
    required bool enabled,
  }) async {
    await _service.setDebtsSmsEnabled(
      opticaId: opticaId,
      customerId: customerId,
      enabled: enabled,
    );
  }

  Future<CustomerDuplicateCheck> checkDuplicate({
    required String opticaId,
    required String phone,
    required String firstName,
    String? lastName,
    String? excludeCustomerId,
  }) async {
    return _service.checkDuplicate(
      opticaId: opticaId,
      phone: phone,
      firstName: firstName,
      lastName: lastName,
      excludeCustomerId: excludeCustomerId,
    );
  }
}
