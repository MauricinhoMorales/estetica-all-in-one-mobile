class Preset {
  final int id;
  final String name;

  const Preset({required this.id, required this.name});

  factory Preset.fromMap(Map<String, dynamic> map) {
    return Preset(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }
}

class PresetItem {
  final int presetId;
  final String barcode;
  final String? productName;
  final double quantity;
  final String unit;

  const PresetItem({
    this.presetId = 0,
    required this.barcode,
    this.productName,
    required this.quantity,
    this.unit = 'units',
  });

  factory PresetItem.fromMap(Map<String, dynamic> map) {
    return PresetItem(
      presetId: map['preset_id'] as int,
      barcode: map['barcode'] as String,
      productName: map['name'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String? ?? 'units',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'preset_id': presetId,
      'barcode': barcode,
      'quantity': quantity,
      'unit': unit,
    };
  }
}
