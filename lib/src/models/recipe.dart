class Recipe {
  final int? id;
  final String name;

  const Recipe({this.id, required this.name});

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] as int?,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{'name': name};
    if (id != null) m['id'] = id;
    return m;
  }
}

class RecipeIngredient {
  final int recipeId;
  final String barcode;
  final String productName;
  final String? brand;
  double quantity;
  String unit;

  RecipeIngredient({
    required this.recipeId,
    required this.barcode,
    required this.productName,
    this.brand,
    required this.quantity,
    required this.unit,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      recipeId: map['recipe_id'] as int,
      barcode: map['barcode'] as String,
      productName: map['name'] as String,
      brand: map['brand'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String? ?? 'units',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipe_id': recipeId,
      'barcode': barcode,
      'quantity': quantity,
      'unit': unit,
    };
  }
}

class RecipeStep {
  final int? id;
  final int recipeId;
  final int stepOrder;
  String description;
  int? waitTimeSecs;
  String? resultNote;
  List<StepPhoto> photos;

  RecipeStep({
    this.id,
    required this.recipeId,
    required this.stepOrder,
    required this.description,
    this.waitTimeSecs,
    this.resultNote,
    this.photos = const [],
  });

  factory RecipeStep.fromMap(Map<String, dynamic> map) {
    return RecipeStep(
      id: map['id'] as int?,
      recipeId: map['recipe_id'] as int,
      stepOrder: map['step_order'] as int,
      description: map['description'] as String,
      waitTimeSecs: map['wait_time_secs'] as int?,
      resultNote: map['result_note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'recipe_id': recipeId,
      'step_order': stepOrder,
      'description': description,
      'wait_time_secs': waitTimeSecs,
      'result_note': resultNote,
    };
    if (id != null) m['id'] = id;
    return m;
  }
}

class StepPhoto {
  final int? id;
  final int stepId;
  final String photoPath;

  const StepPhoto({this.id, required this.stepId, required this.photoPath});

  factory StepPhoto.fromMap(Map<String, dynamic> map) {
    return StepPhoto(
      id: map['id'] as int?,
      stepId: map['step_id'] as int,
      photoPath: map['photo_path'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'step_id': stepId,
      'photo_path': photoPath,
    };
    if (id != null) m['id'] = id;
    return m;
  }
}
