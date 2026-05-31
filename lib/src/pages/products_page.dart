import 'package:flutter/material.dart';
import '../components/barcode_scan_dialog.dart';
import '../components/product_card.dart';
import '../models/inventory_item.dart';
import '../models/product.dart';
import '../utilities/database_helper.dart';
import 'product_form_page.dart';

class ProductsPage extends StatefulWidget {
  final VoidCallback toggleTheme;

  const ProductsPage({super.key, required this.toggleTheme});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage>
    with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();

  List<Product> _all = [];
  List<Product> _filtered = [];
  Map<String, InventoryItem> _inventory = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final products = await _db.getProducts();
    final inventoryItems = await _db.getInventory();
    if (!mounted) return;
    setState(() {
      _all = products;
      _inventory = {for (final i in inventoryItems) i.barcode: i};
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
    final inv = product != null ? _inventory[product.barcode] : null;
    final result = await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormPage(
          existingProduct: product,
          initialBarcode: barcode,
          initialQuantity: inv?.quantity,
          initialUnit: inv?.unit,
        ),
      ),
    );
    if (result != null) _load();
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

  Future<bool> _confirmDelete(Product product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
            'Remove "${product.name}" from the catalog? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                        const Icon(Icons.storefront_outlined,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _all.isEmpty
                              ? 'No products yet.\nTap + to add one.'
                              : 'No results.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        final inv = _inventory[p.barcode];
                        return Dismissible(
                          key: ValueKey(p.barcode),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(p),
                          onDismissed: (_) async {
                            await _db.deleteProduct(p.barcode);
                            setState(() {
                              _all.removeWhere((x) => x.barcode == p.barcode);
                              _filtered.removeAt(i);
                              _inventory.remove(p.barcode);
                            });
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white),
                          ),
                          child: ProductCard(
                            key: ValueKey(p.barcode),
                            product: p,
                            quantity: inv?.quantity,
                            unit: inv?.unit,
                            onEdit: () => _openForm(product: p),
                          ),
                        );
                      },
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
