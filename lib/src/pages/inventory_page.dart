import 'package:flutter/material.dart';
import '../components/inventory_card.dart';
import '../models/inventory_item.dart';
import '../utilities/database_helper.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();

  List<InventoryItem> _all = [];
  List<InventoryItem> _filtered = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    final items = await _db.getInventory();
    if (!mounted) return;
    setState(() {
      _all = items;
      _filter();
    });
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_all)
          : _all.where((i) {
              return i.productName.toLowerCase().contains(q) ||
                  (i.brand?.toLowerCase().contains(q) ?? false);
            }).toList();
    });
  }

  Future<void> _updateQuantity(InventoryItem item, double qty, String unit) async {
    await _db.setInventoryQuantity(item.barcode, qty, unit);
    // Update in-memory to avoid a full reload flash
    setState(() {
      item.quantity = qty;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final outOfStock = _filtered.where((i) => i.quantity <= 0).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          if (outOfStock > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text('$outOfStock out of stock'),
                backgroundColor: Colors.red[100],
                labelStyle: const TextStyle(color: Colors.red, fontSize: 12),
              ),
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
                hintText: 'Search products…',
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
                        const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _all.isEmpty
                              ? 'No products in catalog yet.\nAdd products first.'
                              : 'No results.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadInventory,
                    child: ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => InventoryCard(
                        key: ValueKey(_filtered[i].barcode),
                        item: _filtered[i],
                        onChanged: (qty, unit) =>
                            _updateQuantity(_filtered[i], qty, unit),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
