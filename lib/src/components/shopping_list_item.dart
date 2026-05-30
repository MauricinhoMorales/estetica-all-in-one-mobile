import 'package:flutter/material.dart';
import '../models/shopping_item.dart';

class ShoppingListItemCard extends StatelessWidget {
  final ShoppingItem item;
  final void Function(bool checked) onToggleCheck;
  final void Function(double qty) onQtyChanged;
  final void Function(double price) onPriceChanged;
  final VoidCallback onDelete;

  const ShoppingListItemCard({
    super.key,
    required this.item,
    required this.onToggleCheck,
    required this.onQtyChanged,
    required this.onPriceChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final checked = item.checked;
    final textStyle = TextStyle(
      decoration: checked ? TextDecoration.lineThrough : null,
      color: checked ? Colors.grey : null,
    );

    return Dismissible(
      key: ValueKey('shop-${item.barcode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        color: checked
            ? Theme.of(context).colorScheme.surfaceContainerLowest
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: (v) => onToggleCheck(v ?? false),
                activeColor: Colors.green,
              ),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: textStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (item.brand != null)
                      Text(
                        item.brand!,
                        style: textStyle.copyWith(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Price (tappable)
              _EditableNumber(
                value: item.price,
                prefix: '\$',
                style: textStyle,
                onChanged: onPriceChanged,
              ),
              const SizedBox(width: 6),
              const Text('×', style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 6),
              // Quantity (tappable)
              _EditableNumber(
                value: item.quantity,
                style: textStyle,
                onChanged: onQtyChanged,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: Text(
                  '\$${item.lineTotal.toStringAsFixed(2)}',
                  textAlign: TextAlign.end,
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableNumber extends StatefulWidget {
  final double value;
  final String prefix;
  final TextStyle? style;
  final void Function(double) onChanged;

  const _EditableNumber({
    required this.value,
    this.prefix = '',
    this.style,
    required this.onChanged,
  });

  @override
  State<_EditableNumber> createState() => _EditableNumberState();
}

class _EditableNumberState extends State<_EditableNumber> {
  bool _editing = false;
  late TextEditingController _ctrl;

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.value));
  }

  @override
  void didUpdateWidget(_EditableNumber old) {
    super.didUpdateWidget(old);
    if (!_editing && old.value != widget.value) {
      _ctrl.text = _fmt(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commit() {
    final v = double.tryParse(_ctrl.text.trim());
    if (v != null && v >= 0) widget.onChanged(v);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return SizedBox(
        width: 56,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          ),
          onSubmitted: (_) => _commit(),
          onTapOutside: (_) => _commit(),
        ),
      );
    }
    return GestureDetector(
      onTap: () => setState(() {
        _editing = true;
        _ctrl.text = _fmt(widget.value);
      }),
      child: Text(
        '${widget.prefix}${_fmt(widget.value)}',
        style: widget.style ??
            const TextStyle(fontWeight: FontWeight.w500, color: Colors.blue),
      ),
    );
  }
}
