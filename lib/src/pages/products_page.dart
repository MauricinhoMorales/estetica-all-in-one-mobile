import 'package:flutter/material.dart';
import '../components/barcode_scan_dialog.dart';
import '../components/product_card.dart';
import '../models/product.dart';
import '../utilities/database_helper.dart';
import 'product_form_page.dart';

class ProductsPage extends StatefulWidget {
  final VoidCallback toggleTheme;

  const ProductsPage({super.key, required this.toggleTheme});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();

  List<Product> _all = [];
  List<Product> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await _db.getProducts();
    if (!mounted) return;
    setState(() {
      _all = products;
      _filter();
    });
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_all)
          : _all.where((p) {
              return p.name.toLowerCase().contains(q) ||
                  (p.brand?.toLowerCase().contains(q) ?? false) ||
                  p.barcode.contains(q);
            }).toList();
    });
  }

  Future<void> _openForm({Product? product, String? barcode}) async {
    final result = await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormPage(
          existingProduct: product,
          initialBarcode: barcode,
        ),
      ),
    );
    if (result != null) _loadProducts();
  }

  Future<void> _scanAndAdd() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScanDialog(),
        fullscreenDialog: true,
      ),
    );
    if (scanned == null || !mounted) return;

    final existing = await _db.getProductByBarcode(scanned);
    if (!mounted) return;

    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${existing.name}" is already in the catalog.'),
          action: SnackBarAction(
            label: 'Edit',
            onPressed: () => _openForm(product: existing),
          ),
        ),
      );
    } else {
      await _openForm(barcode: scanned);
    }
  }

  Future<void> _confirmDelete(Product product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Remove "${product.name}" from the catalog? '
            'This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteProduct(product.barcode);
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: widget.toggleTheme,
            tooltip: 'Toggle theme',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, brand, or barcode…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filter();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _all.isEmpty ? 'No products yet.\nTap + to add one.' : 'No results.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadProducts,
                    child: ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => ProductCard(
                        key: ValueKey(_filtered[i].barcode),
                        product: _filtered[i],
                        onEdit: () => _openForm(product: _filtered[i]),
                        onDelete: () => _confirmDelete(_filtered[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanAndAdd,
        tooltip: 'Scan to add product',
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }
}
