import 'package:flutter/material.dart';
import '../models/preset.dart';
import '../models/shopping_item.dart';
import '../utilities/database_helper.dart';

class RegistrySessionDetailPage extends StatefulWidget {
  final int sessionId;

  const RegistrySessionDetailPage({super.key, required this.sessionId});

  @override
  State<RegistrySessionDetailPage> createState() => _RegistrySessionDetailPageState();
}

class _RegistrySessionDetailPageState extends State<RegistrySessionDetailPage> {
  final _db = DatabaseHelper();
  List<ShoppingItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await _db.getShoppingListItems(widget.sessionId);
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  double get _total => _items.fold(0, (s, i) => s + i.lineTotal);

  Future<void> _saveAsPreset() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save as preset'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Preset name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        actions: [
          TextButton.icon(
            onPressed: _items.isEmpty ? null : _saveAsPreset,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Save preset'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('No items in this session.'))
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final item = _items[i];
                            return _SessionItemRow(item: item);
                          },
                        ),
                ),
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(
                        '\$${_total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SessionItemRow extends StatelessWidget {
  final ShoppingItem item;
  const _SessionItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        item.checked ? Icons.check_circle : Icons.radio_button_unchecked,
        color: item.checked ? Colors.green : Colors.grey,
      ),
      title: Text(item.productName,
          style: TextStyle(
            decoration: item.checked ? null : TextDecoration.none,
            color: item.checked ? null : Colors.grey,
          )),
      subtitle: item.brand != null ? Text(item.brand!) : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '\$${item.lineTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '\$${item.price.toStringAsFixed(2)} × ${_fmt(item.quantity)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
