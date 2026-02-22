import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String opticaId;
  final String name;
  final String category;
  final String? sku;
  final String? barcode;
  final double cost;
  final double price;
  final int stockQty;
  final int minStock;
  final String unit;
  final bool active;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  ProductModel({
    required this.id,
    required this.opticaId,
    required this.name,
    required this.category,
    this.sku,
    this.barcode,
    required this.cost,
    required this.price,
    required this.stockQty,
    required this.minStock,
    this.unit = 'pcs',
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc, String opticaId) {
    final data = doc.data() as Map<String, dynamic>;

    return ProductModel(
      id: doc.id,
      opticaId: opticaId,
      name: data['name'] ?? '',
      category: data['category'] ?? 'other',
      sku: data['sku'],
      barcode: data['barcode'],
      cost: (data['cost'] ?? 0) is num ? (data['cost'] as num).toDouble() : 0,
      price: (data['price'] ?? 0) is num ? (data['price'] as num).toDouble() : 0,
      stockQty: (data['stockQty'] ?? 0) is num
          ? (data['stockQty'] as num).toInt()
          : 0,
      minStock: (data['minStock'] ?? 0) is num
          ? (data['minStock'] as num).toInt()
          : 0,
      unit: data['unit'] ?? 'pcs',
      active: (data['active'] ?? true) as bool,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'sku': sku,
      'barcode': barcode,
      'cost': cost,
      'price': price,
      'stockQty': stockQty,
      'minStock': minStock,
      'unit': unit,
      'active': active,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  ProductModel copyWith({
    String? name,
    String? category,
    String? sku,
    String? barcode,
    double? cost,
    double? price,
    int? stockQty,
    int? minStock,
    String? unit,
    bool? active,
    Timestamp? updatedAt,
  }) {
    return ProductModel(
      id: id,
      opticaId: opticaId,
      name: name ?? this.name,
      category: category ?? this.category,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      cost: cost ?? this.cost,
      price: price ?? this.price,
      stockQty: stockQty ?? this.stockQty,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
