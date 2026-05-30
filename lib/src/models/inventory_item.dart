class InventoryItem {
  final String barcode;
  final String productName;
  final String? brand;
  final String? photoPath;
  double quantity;
  final String unit;

  InventoryItem({
    required this.barcode,
    required this.productName,
    this.brand,
    this.photoPath,
    required this.quantity,
    required this.unit,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      barcode: map['barcode'] as String,
      productName: map['name'] as String,
      brand: map['brand'] as String?,
      photoPath: map['photo_path'] as String?,
      quantity: (map['quantity'] as num? ?? 0).toDouble(),
      unit: map['unit'] as String? ?? 'units',
    );
  }
}
