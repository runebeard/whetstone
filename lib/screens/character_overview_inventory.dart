part of 'character_overview.dart';

mixin _InventoryActions on State<CharacterOverview> {
  List<InventoryItem> get inventory;
  List<InventoryItem> get archivedInventory;

  void updateInventory(VoidCallback update);

  void recordSessionEvent(
    SessionEventType type,
    String title, {
    String? detail,
  });

  // ------------------------------------------------------------
  // INVENTORY ACTIONS
  // ------------------------------------------------------------

  void consumeItem(int index) {
    final item = inventory[index];

    if (item.category != ItemCategory.consumable || item.isDepleted) {
      return;
    }

    updateInventory(() {
      inventory[index] = item.copyWith(quantity: item.quantity - 1);
    });
    recordSessionEvent(
      SessionEventType.inventory,
      '${item.name} used',
      detail: '${item.quantity} -> ${item.quantity - 1} carried',
    );
  }

  void restockItem(int index) {
    final item = inventory[index];

    updateInventory(() {
      inventory[index] = item.copyWith(quantity: item.quantity + 1);
    });
    recordSessionEvent(
      SessionEventType.inventory,
      '${item.name} restocked',
      detail: '${item.quantity} -> ${item.quantity + 1} carried',
    );
  }

  Future<void> showRestockItems() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restock Item'),
          content: SizedBox(
            width: 280,
            child: ListView(
              shrinkWrap: true,
              children: [
                ...inventory.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text('Current quantity: ${item.quantity}'),
                    onTap: () {
                      Navigator.pop(context, {
                        'source': 'active',
                        'index': index,
                      });
                    },
                  );
                }),

                if (archivedInventory.isNotEmpty) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Restore Archived',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...archivedInventory.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;

                    return ListTile(
                      leading: const Icon(Icons.archive_outlined),
                      title: Text(item.name),
                      subtitle: Text('Archived • quantity ${item.quantity}'),
                      onTap: () {
                        Navigator.pop(context, {
                          'source': 'archived',
                          'index': index,
                        });
                      },
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (result == null) {
      return;
    }

    final source = result['source'] as String;
    final index = result['index'] as int;

    if (source == 'active') {
      restockItem(index);
      return;
    }

    if (source == 'archived') {
      final item = archivedInventory[index];

      updateInventory(() {
        archivedInventory.removeAt(index);
        inventory.add(item);
      });
      recordSessionEvent(
        SessionEventType.inventory,
        '${item.name} restored to inventory',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} restored'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> showNewItemForm() async {
    final nameController = TextEditingController();

    final itemName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Item'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Item name',
              hintText: 'e.g. Crowbar',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();

                if (name.isEmpty) {
                  return;
                }

                Navigator.pop(context, name);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (itemName == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final category = await showDialog<ItemCategory>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DialogueActionButton(
                icon: Icons.local_drink_outlined,
                label: 'Consumable',
                onTap: () {
                  Navigator.pop(context, ItemCategory.consumable);
                },
              ),
              const SizedBox(height: 10),
              DialogueActionButton(
                icon: Icons.shield_outlined,
                label: 'Equipment',
                onTap: () {
                  Navigator.pop(context, ItemCategory.equipment);
                },
              ),
              const SizedBox(height: 10),
              DialogueActionButton(
                icon: Icons.handyman_outlined,
                label: 'Tool',
                onTap: () {
                  Navigator.pop(context, ItemCategory.tool);
                },
              ),
              const SizedBox(height: 10),
              DialogueActionButton(
                icon: Icons.description_outlined,
                label: 'Quest Item',
                onTap: () {
                  Navigator.pop(context, ItemCategory.quest);
                },
              ),
              const SizedBox(height: 10),
              DialogueActionButton(
                icon: Icons.backpack_outlined,
                label: 'General',
                onTap: () {
                  Navigator.pop(context, ItemCategory.general);
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );

    if (category == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final weightController = TextEditingController();

    final weightPerItem = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: TextField(
            controller: weightController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'Weight per item',
              suffixText: 'lb',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final weight = double.tryParse(weightController.text);

                if (weight == null || weight < 0) {
                  return;
                }

                Navigator.pop(context, weight);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (weightPerItem == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final quantityController = TextEditingController(text: '1');

    quantityController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: quantityController.text.length,
    );

    final quantity = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: TextField(
            controller: quantityController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(quantityController.text);

                if (value == null || value <= 0) {
                  return;
                }

                Navigator.pop(context, value);
              },
              child: const Text('Add Item'),
            ),
          ],
        );
      },
    );

    if (quantity == null) {
      return;
    }

    final newItem = InventoryItem(
      name: itemName,
      quantity: quantity,
      weightPerItem: weightPerItem,
      category: category,
    );

    updateInventory(() {
      inventory.add(newItem);
    });
    recordSessionEvent(
      SessionEventType.inventory,
      '${newItem.name} added',
      detail: '${newItem.quantity} carried',
    );
  }

  Future<void> editItem(int index) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Item'),
                onTap: () {
                  Navigator.pop(context, 'edit');
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Archive Item'),
                onTap: () {
                  Navigator.pop(context, 'archive');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete Item'),
                onTap: () {
                  Navigator.pop(context, 'delete');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );

    switch (action) {
      case 'edit':
        await showEditItemDialog(index);
        break;

      case 'archive':
        final itemName = inventory[index].name;

        updateInventory(() {
          archivedInventory.add(inventory[index]);
          inventory.removeAt(index);
        });

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$itemName archived'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;

      case 'delete':
        await deleteItem(index);
        break;
    }
  }

  Future<void> showEditItemDialog(int index) async {
    final item = inventory[index];

    final nameController = TextEditingController(text: item.name);

    final weightController = TextEditingController(
      text: item.weightPerItem.toString(),
    );

    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );

    ItemCategory selectedCategory = item.category;

    final updatedItem = await showDialog<InventoryItem>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Item name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ItemCategory>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(
                          value: ItemCategory.consumable,
                          child: Text('Consumable'),
                        ),
                        DropdownMenuItem(
                          value: ItemCategory.equipment,
                          child: Text('Equipment'),
                        ),
                        DropdownMenuItem(
                          value: ItemCategory.tool,
                          child: Text('Tool'),
                        ),
                        DropdownMenuItem(
                          value: ItemCategory.quest,
                          child: Text('Quest Item'),
                        ),
                        DropdownMenuItem(
                          value: ItemCategory.general,
                          child: Text('General'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Weight per item',
                        suffixText: 'lb',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();

                    final weight = double.tryParse(weightController.text);

                    final quantity = int.tryParse(quantityController.text);

                    if (name.isEmpty ||
                        weight == null ||
                        weight < 0 ||
                        quantity == null ||
                        quantity < 0) {
                      return;
                    }

                    Navigator.pop(
                      context,
                      item.copyWith(
                        name: name,
                        weightPerItem: weight,
                        quantity: quantity,
                        category: selectedCategory,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updatedItem == null) {
      return;
    }

    updateInventory(() {
      inventory[index] = updatedItem;
    });
  }

  Future<void> deleteItem(int index) async {
    final item = inventory[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Item?'),
          content: Text('Delete ${item.name} permanently?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    updateInventory(() {
      inventory.removeAt(index);
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} deleted'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
