import 'dart:io';
import 'package:flutter/material.dart';
import '../models/inventory_item.dart';

const List<String> kUnits = ['units', 'g', 'kg', 'mL', 'L', 'tbsp', 'tsp', 'cups'];

class InventoryCard extends StatefulWidget {
  final InventoryItem item;
  final void Function(double qty, String unit) onChanged;

  const InventoryCard({super.key, required this.item, required this.onChanged});

  @override
  State<InventoryCard> createState() => _InventoryCardState();
}

class _InventoryCardState extends State<InventoryCard> {
  late TextEditingController _qtyCtrl;
  late String _unit;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: _fmt(widget.item.quantity));
    _unit = kUnits.contains(widget.item.unit) ? widget.item.unit : 'units';
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  void _save() {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? widget.item.quantity;
    setState(() => _editing = false);
    widget.onChanged(qty, _unit);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _buildPhoto(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (widget.item.brand != null)
                    Text(widget.item.brand!,
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_editing) _editRow() else _displayRow(),
          ],
        ),
      ),
    );
  }

  Widget _displayRow() {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? widget.item.quantity;
    final color = qty <= 0 ? Colors.red : Colors.green;
    return GestureDetector(
      onTap: () => setState(() => _editing = true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_fmt(qty)} $_unit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _editRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          child: TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(width: 6),
        DropdownButton<String>(
          value: _unit,
          isDense: true,
          underline: const SizedBox(),
          items: kUnits
              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
              .toList(),
          onChanged: (v) => setState(() => _unit = v ?? _unit),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _buildPhoto() {
    if (widget.item.photoPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(widget.item.photoPath!),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2_outlined, size: 22, color: Colors.grey),
      );
}
