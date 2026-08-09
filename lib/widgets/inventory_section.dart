import 'package:flutter/material.dart';
import '../models/inventory_item.dart';
import 'inventory_item_card.dart';

class InventorySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<InventoryItem> items;
  final Function(int) onConsume;
  final List<InventoryItem> fullInventory;
  final Function(int) onEdit;

  const InventorySection({
    super.key,
    required this.icon,
    required this.title,
    required this.items,
    required this.onConsume,
    required this.fullInventory,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(height: 8),

        ...items.map((item) {
          final index = fullInventory.indexOf(item);

          return InventoryItemCard(
            item: item,
            isDepleted: item.isDepleted,
            onTap: item.category == ItemCategory.consumable && !item.isDepleted
                ? () => onConsume(index)
                : null,
            onLongPress: () => onEdit(index),
          );
        }),
      ],
    );
  }
}
