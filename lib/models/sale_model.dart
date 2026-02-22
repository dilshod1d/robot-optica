import 'package:cloud_firestore/cloud_firestore.dart';
import 'sale_item.dart';

class SaleModel {
  final String id;
  final String opticaId;
  final String? customerId;
  final String? customerName;
  final String? billingId;
  final List<SaleItem> items;
  final double subtotal;
  final double discount;
  final String? discountType;
  final double? discountValue;
  final double total;
  final double paidAmount;
  final double dueAmount;
  final String paymentMethod;
  final String? note;
  final Timestamp createdAt;

  SaleModel({
    required this.id,
    required this.opticaId,
    this.customerId,
    this.customerName,
    this.billingId,
    required this.items,
    required this.subtotal,
    required this.discount,
    this.discountType,
    this.discountValue,
    required this.total,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentMethod,
    this.note,
    required this.createdAt,
  });

  factory SaleModel.fromFirestore(DocumentSnapshot doc, String opticaId) {
    final data = doc.data() as Map<String, dynamic>;
    final itemsRaw = (data['items'] ?? []) as List<dynamic>;
    final total = (data['total'] ?? 0) is num
        ? (data['total'] as num).toDouble()
        : 0;
    final paid = (data['paidAmount'] ?? total) is num
        ? (data['paidAmount'] as num).toDouble()
        : total;
    final due = (data['dueAmount'] ?? (total - paid)) is num
        ? (data['dueAmount'] as num).toDouble()
        : (total - paid);

    return SaleModel(
      id: doc.id,
      opticaId: opticaId,
      customerId: data['customerId'],
      customerName: data['customerName'],
      billingId: data['billingId'],
      items: itemsRaw.map((e) => SaleItem.fromMap(e as Map<String, dynamic>)).toList(),
      subtotal: (data['subtotal'] ?? 0) is num
          ? (data['subtotal'] as num).toDouble()
          : 0,
      discount: (data['discount'] ?? 0) is num
          ? (data['discount'] as num).toDouble()
          : 0,
      discountType: data['discountType'],
      discountValue: data['discountValue'] is num
          ? (data['discountValue'] as num).toDouble()
          : null,
      total: total.toDouble(),
      paidAmount: paid.toDouble(),
      dueAmount: due.toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'Naqd',
      note: data['note'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'billingId': billingId,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      if (discountType != null) 'discountType': discountType,
      if (discountValue != null) 'discountValue': discountValue,
      'total': total,
      'paidAmount': paidAmount,
      'dueAmount': dueAmount,
      'paymentMethod': paymentMethod,
      'note': note,
      'createdAt': createdAt,
    };
  }
}
