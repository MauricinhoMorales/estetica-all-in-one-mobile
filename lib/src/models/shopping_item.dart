class ShoppingItem {
  final int sessionId;
  final String barcode;
  final String productName;
  final String? brand;
  double price;
  double quantity;
  bool checked;

  ShoppingItem({
    required this.sessionId,
    required this.barcode,
    required this.productName,
    this.brand,
    required this.price,
    required this.quantity,
    required this.checked,
  });

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    return ShoppingItem(
      sessionId: map['session_id'] as int,
      barcode: map['barcode'] as String,
      productName: map['name'] as String,
      brand: map['brand'] as String?,
      price: (map['price'] as num? ?? 0).toDouble(),
      quantity: (map['quantity'] as num? ?? 1).toDouble(),
      checked: (map['checked'] as int? ?? 0) == 1,
    );
  }

  double get lineTotal => price * quantity;
}
