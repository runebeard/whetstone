import 'package:flutter/material.dart';

import '../models/inventory_item.dart';

class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final bool isDepleted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const InventoryItemCard({
    super.key,
    required this.item,
    required this.isDepleted,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDepleted ? 0.4 : 1.0,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.weightPerItem} lb each • '
                        '${item.totalWeight.toStringAsFixed(1)} lb total',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '× ${item.quantity}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
