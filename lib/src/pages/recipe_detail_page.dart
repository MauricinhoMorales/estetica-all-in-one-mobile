import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../components/inventory_card.dart' show kUnits;
import '../models/product.dart';
import '../models/recipe.dart';
import '../utilities/database_helper.dart';
import '../utilities/image_helper.dart';
import 'recipe_cook_page.dart';

class RecipeDetailPage extends StatefulWidget {
  final int? recipeId;

  const RecipeDetailPage({super.key, this.recipeId});

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  final _db = DatabaseHelper();
  final _nameCtrl = TextEditingController();

  List<RecipeIngredient> _ingredients = [];
  List<RecipeStep> _steps = [];
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.recipeId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isEdit) {
      final recipe = await _db.getRecipeById(widget.recipeId!);
      final ingredients = await _db.getRecipeIngredients(widget.recipeId!);
      final steps = await _db.getRecipeSteps(widget.recipeId!);
      for (final step in steps) {
        step.photos = await _db.getStepPhotos(step.id!);
      }
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = recipe?.name ?? '';
        _ingredients = ingredients;
        _steps = steps;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe name is required.')),
      );
      return;
    }
    setState(() => _saving = true);

    int recipeId;
    if (_isEdit) {
      await _db.updateRecipe(Recipe(id: widget.recipeId, name: name));
      recipeId = widget.recipeId!;
    } else {
      recipeId = await _db.insertRecipe(Recipe(name: name));
    }

    // Save ingredients
    for (final ing in _ingredients) {
      await _db.upsertRecipeIngredient(
          RecipeIngredient(
            recipeId: recipeId,
            barcode: ing.barcode,
            productName: ing.productName,
            brand: ing.brand,
            quantity: ing.quantity,
            unit: ing.unit,
          ));
    }

    // Save steps
    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      final s = RecipeStep(
        id: step.id,
        recipeId: recipeId,
        stepOrder: i + 1,
        description: step.description,
        waitTimeSecs: step.waitTimeSecs,
        resultNote: step.resultNote,
      );
      int stepId;
      if (step.id != null) {
        await _db.updateRecipeStep(s);
        stepId = step.id!;
      } else {
        stepId = await _db.insertRecipeStep(s);
      }
      for (final photo in step.photos) {
        if (photo.id == null) {
          await _db.insertStepPhoto(StepPhoto(stepId: stepId, photoPath: photo.photoPath));
        }
      }
    }

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true);
    }
  }

  // ── Ingredients ───────────────────────────────────────────────────────────

  Future<void> _addIngredient() async {
    final products = await _db.getProducts();
    if (!mounted) return;
    final existing = _ingredients.map((i) => i.barcode).toSet();
    final available = products.where((p) => !existing.contains(p.barcode)).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IngredientPickerSheet(
        products: available,
        onSelected: (product, qty, unit) {
          setState(() {
            _ingredients.add(RecipeIngredient(
              recipeId: widget.recipeId ?? 0,
              barcode: product.barcode,
              productName: product.name,
              brand: product.brand,
              quantity: qty,
              unit: unit,
            ));
          });
        },
      ),
    );
  }

  void _removeIngredient(int index) async {
    final ing = _ingredients[index];
    if (_isEdit) {
      await _db.deleteRecipeIngredient(widget.recipeId!, ing.barcode);
    }
    setState(() => _ingredients.removeAt(index));
  }

  // ── Steps ─────────────────────────────────────────────────────────────────

  void _addStep() {
    setState(() {
      _steps.add(RecipeStep(
        recipeId: widget.recipeId ?? 0,
        stepOrder: _steps.length + 1,
        description: '',
      ));
    });
  }

  Future<void> _removeStep(int index) async {
    final step = _steps[index];
    if (step.id != null) {
      await _db.deleteRecipeStep(step.id!);
    }
    setState(() => _steps.removeAt(index));
  }

  Future<void> _addStepPhoto(int stepIndex) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file == null) return;
    final path = await ImageHelper.saveImage(file);
    setState(() {
      _steps[stepIndex].photos = [
        ..._steps[stepIndex].photos,
        StepPhoto(stepId: _steps[stepIndex].id ?? 0, photoPath: path),
      ];
    });
  }

  Future<void> _removeStepPhoto(int stepIndex, int photoIndex) async {
    final photo = _steps[stepIndex].photos[photoIndex];
    if (photo.id != null) {
      await _db.deleteStepPhoto(photo.id!, photo.photoPath);
    } else {
      await ImageHelper.deleteImage(photo.photoPath);
    }
    setState(() {
      final photos = List<StepPhoto>.from(_steps[stepIndex].photos);
      photos.removeAt(photoIndex);
      _steps[stepIndex].photos = photos;
    });
  }

  // ── Inventory check ───────────────────────────────────────────────────────

  Future<void> _checkFeasibility() async {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ingredients to check.')),
      );
      return;
    }
    final invMap = await _db.getInventoryMap();
    final missing = _ingredients.where((ing) {
      return (invMap[ing.barcode] ?? 0.0) < ing.quantity;
    }).toList();

    if (!mounted) return;

    if (missing.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ready to cook!'),
          content: const Text('You have all the ingredients in stock.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }

    // Show missing ingredients + option to add to shopping list
    await showDialog(
      context: context,
      builder: (_) => _MissingIngredientsDialog(
        missing: missing,
        invMap: invMap,
        onAddToList: () => _addMissingToShoppingList(missing, invMap),
      ),
    );
  }

  Future<void> _addMissingToShoppingList(
      List<RecipeIngredient> missing, Map<String, double> invMap) async {
    final sessionId = await _db.getOrCreateActiveSession();
    final existingItems = await _db.getShoppingListItems(sessionId);
    final existingBarcodes = existingItems.map((i) => i.barcode).toSet();

    int added = 0;
    for (final ing in missing) {
      if (!existingBarcodes.contains(ing.barcode)) {
        final deficit = ing.quantity - (invMap[ing.barcode] ?? 0.0);
        final price = await _db.getLatestPrice(ing.barcode);
        await _db.addItemToList(sessionId, ing.barcode, deficit, price);
        added++;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'All missing items are already in the shopping list.'
                : '$added item(s) added to shopping list.',
          ),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              tooltip: 'Cook mode',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RecipeCookPage(
                        recipeId: widget.recipeId!,
                        recipeName: _nameCtrl.text,
                        ingredients: _ingredients)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name field
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Recipe name *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),

          // Ingredients section
          _sectionHeader('Ingredients', Icons.egg_outlined,
              trailing: TextButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              )),
          if (_ingredients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No ingredients yet.', style: TextStyle(color: Colors.grey)),
            )
          else
            ..._ingredients.asMap().entries.map((e) {
              final i = e.key;
              final ing = e.value;
              return _IngredientRow(
                ingredient: ing,
                onDelete: () => _removeIngredient(i),
                onChanged: (qty, unit) {
                  setState(() {
                    _ingredients[i].quantity = qty;
                    _ingredients[i].unit = unit;
                  });
                },
              );
            }),

          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _checkFeasibility,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Can I make this?'),
          ),
          const SizedBox(height: 20),

          // Steps section
          _sectionHeader('Steps', Icons.format_list_numbered_outlined,
              trailing: TextButton.icon(
                onPressed: _addStep,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add step'),
              )),
          if (_steps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No steps yet.', style: TextStyle(color: Colors.grey)),
            )
          else
            ..._steps.asMap().entries.map((e) {
              final i = e.key;
              final step = e.value;
              return _StepCard(
                stepNumber: i + 1,
                step: step,
                onDelete: () => _removeStep(i),
                onAddPhoto: () => _addStepPhoto(i),
                onRemovePhoto: (pi) => _removeStepPhoto(i, pi),
                onDescriptionChanged: (v) => setState(() => step.description = v),
                onWaitTimeChanged: (v) => setState(() => step.waitTimeSecs = v),
                onResultNoteChanged: (v) => setState(() => step.resultNote = v),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }
}

// ── Ingredient row ────────────────────────────────────────────────────────

class _IngredientRow extends StatefulWidget {
  final RecipeIngredient ingredient;
  final VoidCallback onDelete;
  final void Function(double qty, String unit) onChanged;

  const _IngredientRow({
    required this.ingredient,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<_IngredientRow> {
  late TextEditingController _qtyCtrl;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
        text: widget.ingredient.quantity == widget.ingredient.quantity.truncateToDouble()
            ? widget.ingredient.quantity.toInt().toString()
            : widget.ingredient.quantity.toStringAsFixed(2));
    _unit = kUnits.contains(widget.ingredient.unit) ? widget.ingredient.unit : 'units';
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              widget.ingredient.productName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 56,
            child: TextField(
              controller: _qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              onChanged: (v) {
                final qty = double.tryParse(v) ?? widget.ingredient.quantity;
                widget.onChanged(qty, _unit);
              },
            ),
          ),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: _unit,
            isDense: true,
            underline: const SizedBox(),
            items: kUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _unit = v);
              final qty = double.tryParse(_qtyCtrl.text) ?? widget.ingredient.quantity;
              widget.onChanged(qty, v);
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Step card ─────────────────────────────────────────────────────────────

class _StepCard extends StatefulWidget {
  final int stepNumber;
  final RecipeStep step;
  final VoidCallback onDelete;
  final VoidCallback onAddPhoto;
  final void Function(int) onRemovePhoto;
  final void Function(String) onDescriptionChanged;
  final void Function(int?) onWaitTimeChanged;
  final void Function(String?) onResultNoteChanged;

  const _StepCard({
    required this.stepNumber,
    required this.step,
    required this.onDelete,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.onDescriptionChanged,
    required this.onWaitTimeChanged,
    required this.onResultNoteChanged,
  });

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _waitCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.step.description);
    _waitCtrl = TextEditingController(
      text: widget.step.waitTimeSecs != null
          ? (widget.step.waitTimeSecs! ~/ 60).toString()
          : '',
    );
    _noteCtrl = TextEditingController(text: widget.step.resultNote ?? '');
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _waitCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  child: Text('${widget.stepNumber}', style: const TextStyle(fontSize: 12)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Step description…',
                border: OutlineInputBorder(),
              ),
              onChanged: widget.onDescriptionChanged,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _waitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Wait (min)',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) {
                      final mins = int.tryParse(v);
                      widget.onWaitTimeChanged(mins != null ? mins * 60 : null);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Expected result…',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) => widget.onResultNoteChanged(v.isEmpty ? null : v),
                  ),
                ),
              ],
            ),
            // Photos
            if (widget.step.photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.step.photos.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == widget.step.photos.length) {
                      return GestureDetector(
                        onTap: widget.onAddPhoto,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(widget.step.photos[i].photoPath),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image)),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => widget.onRemovePhoto(i),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: widget.onAddPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Add photo'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Ingredient picker sheet ───────────────────────────────────────────────

class _IngredientPickerSheet extends StatefulWidget {
  final List<Product> products;
  final void Function(Product, double, String) onSelected;

  const _IngredientPickerSheet({required this.products, required this.onSelected});

  @override
  State<_IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<_IngredientPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Product> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.of(widget.products);
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? List.of(widget.products)
            : widget.products.where((p) => p.name.toLowerCase().contains(q)).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(Product product) async {
    final qtyCtrl = TextEditingController(text: '1');
    String selectedUnit = 'units';

    final result = await showDialog<(double, String)?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(product.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Quantity', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedUnit,
                decoration: const InputDecoration(
                    labelText: 'Unit', border: OutlineInputBorder()),
                items: kUnits
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setLocal(() => selectedUnit = v ?? selectedUnit),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(qtyCtrl.text) ?? 1.0;
                Navigator.pop(ctx, (qty, selectedUnit));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || result == null) return;
    Navigator.pop(context);
    widget.onSelected(product, result.$1, result.$2);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Add Ingredient',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search products…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('No products found.'))
                : ListView.builder(
                    controller: controller,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(_filtered[i].name),
                      subtitle: _filtered[i].brand != null
                          ? Text(_filtered[i].brand!)
                          : null,
                      onTap: () => _pick(_filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Missing ingredients dialog ────────────────────────────────────────────

class _MissingIngredientsDialog extends StatelessWidget {
  final List<RecipeIngredient> missing;
  final Map<String, double> invMap;
  final VoidCallback onAddToList;

  const _MissingIngredientsDialog({
    required this.missing,
    required this.invMap,
    required this.onAddToList,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Missing ingredients'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: missing.map((ing) {
            final have = invMap[ing.barcode] ?? 0.0;
            final need = ing.quantity - have;
            return ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber_outlined, color: Colors.orange),
              title: Text(ing.productName),
              subtitle: Text(
                  'Have ${_fmt(have)} ${ing.unit} — need ${_fmt(need)} more'),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ElevatedButton.icon(
          onPressed: onAddToList,
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Add to shopping list'),
        ),
      ],
    );
  }

  static String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
