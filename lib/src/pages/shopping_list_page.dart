import 'package:flutter/material.dart';
import '../components/barcode_scan_dialog.dart';
import '../components/preset_picker_dialog.dart';
import '../components/shopping_list_item.dart';
import '../models/preset.dart' show Preset, PresetItem;
import '../models/product.dart';
import '../models/shopping_item.dart';
import '../utilities/database_helper.dart';
import 'product_form_page.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper();

  int? _sessionId;
  List<ShoppingItem> _items = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await _db.getOrCreateActiveSession();
    if (!mounted) return;
    setState(() => _sessionId = id);
    await _loadItems();
  }

  Future<void> _loadItems() async {
    if (_sessionId == null) return;
    final items = await _db.getShoppingListItems(_sessionId!);
    // Sort: unchecked first, then checked; within each group sort by name
    items.sort((a, b) {
      if (a.checked != b.checked) return a.checked ? 1 : -1;
      return a.productName.compareTo(b.productName);
    });
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  // ── Totals ──────────────────────────────────────────────────────────────

  double get _expectedTotal =>
      _items.fold(0, (sum, i) => sum + i.lineTotal);

  double get _actualTotal =>
      _items.where((i) => i.checked).fold(0, (sum, i) => sum + i.lineTotal);

  // ── Item actions ─────────────────────────────────────────────────────────

  Future<void> _toggleCheck(ShoppingItem item, bool checked) async {
    await _db.setItemChecked(_sessionId!, item.barcode, checked);
    setState(() {
      item.checked = checked;
      _items.sort((a, b) {
        if (a.checked != b.checked) return a.checked ? 1 : -1;
        return a.productName.compareTo(b.productName);
      });
    });
  }

  Future<void> _updateQty(ShoppingItem item, double qty) async {
    await _db.updateItemInList(_sessionId!, item.barcode, qty: qty);
    setState(() => item.quantity = qty);
  }

  Future<void> _updatePrice(ShoppingItem item, double price) async {
    await _db.updateItemInList(_sessionId!, item.barcode, price: price);
    await _db.recordPrice(item.barcode, price);
    setState(() => item.price = price);
  }

  Future<void> _removeItem(ShoppingItem item) async {
    await _db.removeItemFromList(_sessionId!, item.barcode);
    setState(() => _items.remove(item));
  }

  // ── Barcode scanner ───────────────────────────────────────────────────────

  Future<void> _scanBarcode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScanDialog(), fullscreenDialog: true),
    );
    if (scanned == null || !mounted) return;

    // Check if already in the list
    if (_items.any((i) => i.barcode == scanned)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product is already in the list.')),
      );
      return;
    }

    final product = await _db.getProductByBarcode(scanned);
    if (!mounted) return;

    if (product != null) {
      // Known product — confirm quantity & price
      await _showConfirmAddDialog(product);
    } else {
      // Unknown product — open full form
      await _openNewProductForm(barcode: scanned);
    }
  }

  Future<void> _showConfirmAddDialog(Product product) async {
    final lastPrice = await _db.getLatestPrice(product.barcode);
    if (!mounted) return;

    final priceCtrl = TextEditingController(
        text: lastPrice > 0 ? lastPrice.toStringAsFixed(2) : product.price.toStringAsFixed(2));
    final qtyCtrl = TextEditingController(text: '1');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.brand != null)
              Text(product.brand!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Price',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (confirmed == true) {
      final price = double.tryParse(priceCtrl.text.trim()) ?? product.price;
      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
      await _db.addItemToList(_sessionId!, product.barcode, qty, price);
      await _db.recordPrice(product.barcode, price);
      await _loadItems();
    }
  }

  // ── Add item (manual product search) ─────────────────────────────────────

  Future<void> _showAddProductDialog() async {
    final products = await _db.getProducts();
    if (!mounted) return;

    final existing = _items.map((i) => i.barcode).toSet();
    final available = products.where((p) => !existing.contains(p.barcode)).toList();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductPickerSheet(
        products: available,
        onSelected: (product, qty) => _addProduct(product, qty),
        onAddNew: () => _openNewProductForm(),
      ),
    );
  }

  Future<void> _addProduct(Product product, double qty) async {
    final price = await _db.getLatestPrice(product.barcode);
    await _db.addItemToList(_sessionId!, product.barcode, qty, price);
    await _loadItems();
  }

  Future<void> _openNewProductForm({String? barcode}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormPage(
          initialBarcode: barcode,
          forShoppingList: true,
        ),
      ),
    );
    if (result != null) {
      final product = result['product'] as Product;
      final qty = result['quantity'] as double;
      final price = await _db.getLatestPrice(product.barcode);
      await _db.addItemToList(_sessionId!, product.barcode, qty, price);
      await _loadItems();
    }
  }

  // ── Load preset ───────────────────────────────────────────────────────────

  void _showPresetPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PresetPickerDialog(
        onSelected: (preset) => _loadPreset(preset),
      ),
    );
  }

  Future<void> _loadPreset(Preset preset) async {
    await _db.loadPresetIntoSession(preset.id, _sessionId!);
    await _loadItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded preset "${preset.name}"')),
      );
    }
  }

  // ── Save current list as preset ───────────────────────────────────────────

  Future<void> _saveAsPreset() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shopping list is empty.')),
      );
      return;
    }
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save as preset'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            hintText: 'Preset name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, nameCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final presetItems = _items
        .map((i) => PresetItem(barcode: i.barcode, quantity: i.quantity))
        .toList();
    await _db.createPreset(name, presetItems);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preset "$name" saved.')),
      );
    }
  }

  // ── Complete session ──────────────────────────────────────────────────────

  Future<void> _completeSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Complete shopping?'),
        content: const Text(
            'This will mark the session as done and update your inventory '
            'with all checked items.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _db.completeSession(_sessionId!);
    await _init();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Load preset',
            onPressed: _showPresetPicker,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'save_preset') _saveAsPreset();
              if (v == 'complete') _completeSession();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'save_preset',
                  child: ListTile(leading: Icon(Icons.bookmark_outline), title: Text('Save as preset'), dense: true)),
              const PopupMenuItem(value: 'complete',
                  child: ListTile(leading: Icon(Icons.check_circle_outline), title: Text('Complete session'), dense: true)),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _TotalRow(expected: _expectedTotal, actual: _actualTotal),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart_outlined,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Empty list.\nTap + to add items.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final item = _items[i];
                            return ShoppingListItemCard(
                              key: ValueKey(item.barcode),
                              item: item,
                              onToggleCheck: (c) => _toggleCheck(item, c),
                              onQtyChanged: (q) => _updateQty(item, q),
                              onPriceChanged: (p) => _updatePrice(item, p),
                              onDelete: () => _removeItem(item),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_scan',
            onPressed: _scanBarcode,
            tooltip: 'Scan barcode',
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'fab_add',
            onPressed: _showAddProductDialog,
            tooltip: 'Add item',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

// ── Helper: total display row ─────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  final double expected;
  final double actual;

  const _TotalRow({required this.expected, required this.actual});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Expected', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('\$${expected.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('In cart (checked)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('\$${actual.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper: product picker sheet ──────────────────────────────────────────

class _ProductPickerSheet extends StatefulWidget {
  final List<Product> products;
  final void Function(Product, double) onSelected;
  final VoidCallback onAddNew;

  const _ProductPickerSheet({
    required this.products,
    required this.onSelected,
    required this.onAddNew,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
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
            : widget.products.where((p) =>
                p.name.toLowerCase().contains(q) ||
                (p.brand?.toLowerCase().contains(q) ?? false)).toList();
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
    final qty = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add ${product.name}'),
        content: TextField(
          controller: qtyCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, double.tryParse(v) ?? 1.0),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(qtyCtrl.text) ?? 1.0),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (!mounted || qty == null) return;
    Navigator.pop(context);
    widget.onSelected(product, qty);
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
            child: Text('Add Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            child: ListView(
              controller: controller,
              children: [
                ..._filtered.map((p) => ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                          '${p.brand ?? ''}${p.brand != null ? ' · ' : ''}\$${p.price.toStringAsFixed(2)}'),
                      onTap: () => _pick(p),
                    )),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Add new product'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onAddNew();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

