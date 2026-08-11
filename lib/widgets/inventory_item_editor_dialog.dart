import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/inventory_item.dart';

class InventoryItemEditorDialog extends StatefulWidget {
  final InventoryItem? item;

  const InventoryItemEditorDialog({super.key, this.item});

  @override
  State<InventoryItemEditorDialog> createState() =>
      _InventoryItemEditorDialogState();
}

class _InventoryItemEditorDialogState extends State<InventoryItemEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController quantityController;
  late final TextEditingController weightController;
  late ItemCategory category;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.item?.name ?? '');
    quantityController = TextEditingController(
      text: '${widget.item?.quantity ?? 1}',
    );
    weightController = TextEditingController(
      text: '${widget.item?.weightPerItem ?? 0}',
    );
    category = widget.item?.category ?? ItemCategory.general;
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    weightController.dispose();
    super.dispose();
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      InventoryItem(
        name: nameController.text.trim(),
        quantity: int.parse(quantityController.text),
        weightPerItem: double.parse(weightController.text),
        category: category,
      ),
    );
  }

  String categoryLabel(ItemCategory value) {
    return switch (value) {
      ItemCategory.consumable => 'Consumable',
      ItemCategory.equipment => 'Equipment',
      ItemCategory.tool => 'Tool',
      ItemCategory.quest => 'Quest Item',
      ItemCategory.general => 'General',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('inventory-name'),
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Item name'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ItemCategory>(
                key: const ValueKey('inventory-category'),
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final value in ItemCategory.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(categoryLabel(value)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) category = value;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('inventory-quantity'),
                controller: quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: (value) {
                  final quantity = int.tryParse(value ?? '');
                  return quantity == null || quantity < 0 || quantity > 999
                      ? '0–999'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('inventory-weight'),
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Weight per item',
                  suffixText: 'lb',
                ),
                validator: (value) {
                  final weight = double.tryParse(value ?? '');
                  return weight == null || weight < 0 || weight > 999
                      ? '0–999'
                      : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-inventory-item'),
          onPressed: save,
          child: Text(widget.item == null ? 'Add Item' : 'Save Item'),
        ),
      ],
    );
  }
}
