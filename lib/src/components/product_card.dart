import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _buildPhoto(),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.brand != null) Text(product.brand!),
            Text(
              '\$${product.price.toStringAsFixed(2)}${product.store != null ? ' · ${product.store}' : ''}',
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
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    if (product.photoPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(product.photoPath!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
    );
  }
}
