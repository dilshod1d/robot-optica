class SaleItem {
  final String productId;
  final String name;
  final String category;
  final int quantity;
  final double price;
  final double cost;

  const SaleItem({
    required this.productId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    required this.cost,
  });

  double get total => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'category': category,
      'quantity': quantity,
      'price': price,
      'cost': cost,
      'total': total,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? 'other',
      quantity: (map['quantity'] ?? 0) is num
          ? (map['quantity'] as num).toInt()
          : 0,
      price: (map['price'] ?? 0) is num
          ? (map['price'] as num).toDouble()
          : 0,
      cost: (map['cost'] ?? 0) is num
          ? (map['cost'] as num).toDouble()
          : 0,
    );
  }
}
