import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final double? quantity;
  final String? unit;
  final VoidCallback onEdit;

  const ProductCard({
    super.key,
    required this.product,
    this.quantity,
    this.unit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildPhoto(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (product.brand != null)
                    Text(
                      product.brand!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}'
                    '${product.store != null ? ' · ${product.store}' : ''}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    product.barcode,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildQuantity(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantity() {
    final String label;
    final Color color;
    if (quantity == null) {
      label = '—';
      color = Colors.grey;
    } else if (quantity! <= 0) {
      label = '${_fmt(quantity!)} ${unit ?? ''}';
      color = Colors.red;
    } else {
      label = '${_fmt(quantity!)} ${unit ?? ''}';
      color = Colors.green;
    }
    return Text(
      label.trim(),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: color,
      ),
    );
  }

  Widget _buildPhoto() {
    if (product.photoPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(product.photoPath!),
          width: 52,
          height: 52,
          cacheWidth: 156,
          cacheHeight: 156,
          fit: BoxFit.scaleDown,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
    );
  }

  static String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
