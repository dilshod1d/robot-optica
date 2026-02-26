import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _productsRef(String opticaId) {
    return _db.collection('opticas').doc(opticaId).collection('products');
  }

  Stream<List<ProductModel>> watchProducts(String opticaId) {
    return _productsRef(opticaId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ProductModel.fromFirestore(doc, opticaId);
      }).toList();
    });
  }

  Future<List<ProductModel>> fetchProducts(String opticaId) async {
    final snapshot = await _productsRef(opticaId).get();
    return snapshot.docs.map((doc) {
      return ProductModel.fromFirestore(doc, opticaId);
    }).toList();
  }

  Future<void> upsertProduct({
    required String opticaId,
    required ProductModel product,
  }) async {
    await _productsRef(opticaId).doc(product.id).set(product.toMap());
  }

  Future<void> upsertProductsBulk({
    required String opticaId,
    required List<ProductModel> products,
  }) async {
    if (products.isEmpty) return;

    const batchSize = 400;
    for (var i = 0; i < products.length; i += batchSize) {
      final end = (i + batchSize) > products.length ? products.length : i + batchSize;
      final batch = _db.batch();

      for (final product in products.sublist(i, end)) {
        final ref = _productsRef(opticaId).doc(product.id);
        batch.set(ref, product.toMap());
      }

      await batch.commit();
    }
  }

  Future<void> updateStock({
    required String opticaId,
    required String productId,
    required int delta,
  }) async {
    await _productsRef(opticaId).doc(productId).update({
      'stockQty': FieldValue.increment(delta),
      'updatedAt': Timestamp.now(),
    });
  }
}
