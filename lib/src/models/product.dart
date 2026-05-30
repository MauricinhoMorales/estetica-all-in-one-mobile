class Product {
  final String barcode;
  final String name;
  final String? brand;
  final String? store;
  final String? photoPath;
  final double price;

  const Product({
    required this.barcode,
    required this.name,
    this.brand,
    this.store,
    this.photoPath,
    required this.price,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String?,
      store: map['store'] as String?,
      photoPath: map['photo_path'] as String?,
      price: (map['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'store': store,
      'photo_path': photoPath,
      'price': price,
    };
  }

  Product copyWith({
    String? barcode,
    String? name,
    String? brand,
    String? store,
    String? photoPath,
    double? price,
  }) {
    return Product(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      store: store ?? this.store,
      photoPath: photoPath ?? this.photoPath,
      price: price ?? this.price,
    );
  }
}
