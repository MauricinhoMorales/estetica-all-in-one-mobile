import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../utilities/database_helper.dart';
import '../utilities/image_helper.dart';

class ProductFormPage extends StatefulWidget {
  final Product? existingProduct;
  final String? initialBarcode;
  final bool forShoppingList;

  const ProductFormPage({
    super.key,
    this.existingProduct,
    this.initialBarcode,
    this.forShoppingList = false,
  });

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();

  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _storeCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;

  String? _photoPath;
  bool _saving = false;

  bool get _isEdit => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _brandCtrl = TextEditingController(text: p?.brand ?? '');
    _storeCtrl = TextEditingController(text: p?.store ?? '');
    _priceCtrl = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _qtyCtrl = TextEditingController(text: '1');
    _photoPath = p?.photoPath;
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _storeCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return;
    final saved = await ImageHelper.saveImage(file);
    if (widget.existingProduct?.photoPath != null &&
        widget.existingProduct!.photoPath != saved) {
      await ImageHelper.deleteImage(widget.existingProduct!.photoPath);
    }
    setState(() => _photoPath = saved);
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final barcode = _barcodeCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;

    final product = Product(
      barcode: barcode,
      name: _nameCtrl.text.trim(),
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      store: _storeCtrl.text.trim().isEmpty ? null : _storeCtrl.text.trim(),
      photoPath: _photoPath,
      price: price,
    );

    try {
      if (_isEdit) {
        await _db.updateProduct(product);
      } else {
        final existing = await _db.getProductByBarcode(barcode);
        if (existing != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A product with this barcode already exists.')),
          );
          setState(() => _saving = false);
          return;
        }
        await _db.insertProduct(product);
      }

      if (!mounted) return;

      if (widget.forShoppingList) {
        final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1.0;
        Navigator.pop(context, {'product': product, 'quantity': qty});
      } else {
        Navigator.pop(context, product);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving product: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Product' : 'New Product'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Save',
              onPressed: _save,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photo
            GestureDetector(
              onTap: _showPhotoOptions,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  image: _photoPath != null
                      ? DecorationImage(
                          image: FileImage(File(_photoPath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _photoPath == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 40),
                          SizedBox(height: 8),
                          Text('Add photo'),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                              onPressed: _showPhotoOptions,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Barcode
            TextFormField(
              controller: _barcodeCtrl,
              enabled: !_isEdit,
              decoration: const InputDecoration(
                labelText: 'Barcode *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Brand
            TextFormField(
              controller: _brandCtrl,
              decoration: const InputDecoration(
                labelText: 'Brand',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            // Store
            TextFormField(
              controller: _storeCtrl,
              decoration: const InputDecoration(
                labelText: 'Store',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            // Price
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Price *',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                return null;
              },
            ),

            // Quantity (only when adding from shopping list)
            if (widget.forShoppingList) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Quantity to buy *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
