import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/billing_model.dart';
import '../models/sale_model.dart';
import 'billing_stats_service.dart';
import 'billing_service.dart';

class SalesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final BillingStatsService _statsService = BillingStatsService();
  final BillingFirebaseService _billingService = BillingFirebaseService();

  CollectionReference<Map<String, dynamic>> _salesRef(String opticaId) {
    return _db.collection('opticas').doc(opticaId).collection('sales');
  }

  CollectionReference<Map<String, dynamic>> _productsRef(String opticaId) {
    return _db.collection('opticas').doc(opticaId).collection('products');
  }

  CollectionReference<Map<String, dynamic>> _customersRef(String opticaId) {
    return _db.collection('opticas').doc(opticaId).collection('customers');
  }

  Stream<List<SaleModel>> watchSales(String opticaId, {int limit = 50}) {
    return _salesRef(opticaId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SaleModel.fromFirestore(doc, opticaId))
          .toList();
    });
  }

  Future<void> createSale({
    required String opticaId,
    required SaleModel sale,
    BillingModel? billing,
  }) async {
    final saleRef = _salesRef(opticaId).doc(sale.id);
    final billingRef = billing == null
        ? null
        : _db
            .collection('opticas')
            .doc(opticaId)
            .collection('billings')
            .doc(billing.id);
    final hasInitialPayment = billing != null && billing.amountPaid > 0;
    final billingForCreate = billing == null
        ? null
        : (hasInitialPayment
            ? billing.copyWith(
                amountPaid: 0,
                updatedAt: Timestamp.now(),
              )
            : billing);

    await _db.runTransaction((transaction) async {
      final qtyByProduct = <String, int>{};
      for (final item in sale.items) {
        qtyByProduct.update(
          item.productId,
          (value) => value + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }

      final productSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in qtyByProduct.entries) {
        final productRef = _productsRef(opticaId).doc(entry.key);
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) {
          throw Exception('${entry.key} topilmadi');
        }
        productSnapshots[entry.key] = snapshot;
      }

      DocumentSnapshot<Map<String, dynamic>>? customerSnapshot;
      if (sale.customerId != null) {
        final customerRef = _customersRef(opticaId).doc(sale.customerId);
        customerSnapshot = await transaction.get(customerRef);
      }

      for (final entry in qtyByProduct.entries) {
        final productRef = _productsRef(opticaId).doc(entry.key);
        final snapshot = productSnapshots[entry.key]!;
        final data = snapshot.data() as Map<String, dynamic>;
        final currentStock = (data['stockQty'] ?? 0) is num
            ? (data['stockQty'] as num).toInt()
            : 0;

        if (currentStock < entry.value) {
          final name = data['name'] ?? entry.key;
          throw Exception('$name uchun yetarli stok yo\'q');
        }

        transaction.update(productRef, {
          'stockQty': FieldValue.increment(-entry.value),
          'updatedAt': Timestamp.now(),
        });
      }

      transaction.set(saleRef, sale.toMap());

      if (sale.customerId != null &&
          customerSnapshot != null &&
          customerSnapshot.exists) {
        final customerRef = _customersRef(opticaId).doc(sale.customerId);
        transaction.update(customerRef, {
          'loyaltyPurchaseCount': FieldValue.increment(1),
        });
      }

      if (billingRef != null) {
        transaction.set(billingRef, billingForCreate?.toMap());
      }
    });

    if (billing != null) {
      await _statsService.onCreate(
        opticaId: opticaId,
        billing: billingForCreate ?? billing,
      );

      if (hasInitialPayment && billingForCreate != null) {
        final note = sale.note ?? "POS (${sale.paymentMethod})";
        await _billingService.applyPayment(
          opticaId: opticaId,
          billing: billingForCreate,
          amount: billing.amountPaid,
          note: note,
        );

        final updatedBilling = billingForCreate.copyWith(
          amountPaid: billing.amountPaid,
          updatedAt: Timestamp.now(),
        );

        if (updatedBilling.remaining > 0) {
          await _billingService.queueDebtSmsOnCreate(
            opticaId: opticaId,
            billing: updatedBilling,
          );
        }
      } else {
        await _billingService.queueDebtSmsOnCreate(
          opticaId: opticaId,
          billing: billing,
        );
      }
    }
  }
}
