import 'package:flutter/material.dart';
import '../models/character.dart';
import '../widgets/combat_summary.dart';
import '../models/inventory_item.dart';
import '../widgets/inventory_section.dart';
import '../widgets/dialogue_action_button.dart';
import '../models/character_mode.dart';

class CharacterOverview extends StatefulWidget {
  final Character character;

  const CharacterOverview({super.key, required this.character});

  @override
  State<CharacterOverview> createState() => _CharacterOverviewState();
}

class _CharacterOverviewState extends State<CharacterOverview> {
  final List<InventoryItem> inventory = [
    const InventoryItem(
      name: 'Potion of Healing',
      quantity: 3,
      weightPerItem: 0.5,
      category: ItemCategory.consumable,
    ),
    const InventoryItem(
      name: 'Rope',
      quantity: 1,
      weightPerItem: 10,
      category: ItemCategory.equipment,
    ),

    const InventoryItem(
      name: 'Torch',
      quantity: 5,
      weightPerItem: 1,
      category: ItemCategory.consumable,
    ),

    const InventoryItem(
      name: 'Antivenom',
      quantity: 2,
      weightPerItem: 1,
      category: ItemCategory.consumable,
    ),
  ];
  final List<InventoryItem> archivedInventory = [];
  void consumeItem(int index) {
    final item = inventory[index];

    if (item.category != ItemCategory.consumable || item.quantity <= 0) {
      return;
    }

    setState(() {
      inventory[index] = item.copyWith(quantity: item.quantity - 1);
    });
  }

  void restockItem(int index) {
    final item = inventory[index];

    setState(() {
      inventory[index] = item.copyWith(quantity: item.quantity + 1);
    });
  }

  Future<void> addItem() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DialogueActionButton(
                icon: Icons.inventory_2_outlined,
                label: 'Restock Item',
                onTap: () {
                  Navigator.pop(context, 'restock');
                },
              ),

              const SizedBox(height: 10),

              DialogueActionButton(
                icon: Icons.add_circle_outline,
                label: 'New Item',
                onTap: () {
                  Navigator.pop(context, 'new');
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

    if (choice == 'restock') {
      showRestockItems();
    }

    if (choice == 'new') {
      showNewItemForm();
    }
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
                    Navigator.pop(
                      context,
                      {
                        'source': 'active',
                        'index': index,
                      },
                    );
                  },
                );
              }),

              if (archivedInventory.isNotEmpty) ...[
                const Divider(),

                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Archived',
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
                    subtitle: const Text('Archived'),
                    onTap: () {
                      Navigator.pop(
                        context,
                        {
                          'source': 'archived',
                          'index': index,
                        },
                      );
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

  setState(() {
    archivedInventory.removeAt(index);

    inventory.add(item);
  });

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

    setState(() {
      inventory.add(newItem);
    });
  }

  int get uniqueItemCount => inventory.length;
  int get totalItemCount =>
      inventory.fold(0, (sum, item) => sum + item.quantity);
  double get totalCarryWeight =>
      inventory.fold(0, (sum, item) => sum + item.totalWeight);
  List<InventoryItem> get consumableItems => inventory
      .where((item) => item.category == ItemCategory.consumable)
      .toList();

  List<InventoryItem> get equipmentItems => inventory
      .where((item) => item.category == ItemCategory.equipment)
      .toList();

  List<InventoryItem> get toolItems =>
      inventory.where((item) => item.category == ItemCategory.tool).toList();

  List<InventoryItem> get questItems =>
      inventory.where((item) => item.category == ItemCategory.quest).toList();

  List<InventoryItem> get generalItems =>
      inventory.where((item) => item.category == ItemCategory.general).toList();

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

  setState(() {
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
        print('Delete ${inventory[index].name}');
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

    setState(() {
      inventory[index] = updatedItem;
    });

   
  }

void beginCombat() {
  setState(() {
    currentMode = CharacterMode.combat;
  });
}
 CharacterMode currentMode = CharacterMode.overview;
 
void endCombat() {
  setState(() {
    currentMode = CharacterMode.exploration;
  });
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Character Overview')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.character.name, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Level ${widget.character.level} ${widget.character.characterClass}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CombatSummary(character: widget.character),
            const SizedBox(height: 20),

            const Text(
              'Inventory',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text('$uniqueItemCount unique items'),

            Text('$totalItemCount items carried'),

            Text('${totalCarryWeight.toStringAsFixed(1)} lb total'),

            const SizedBox(height: 8),
            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),

            const SizedBox(height: 8),

            InventorySection(
              icon: Icons.description_outlined,
              title: 'Quest Items',
              items: questItems,
              onConsume: consumeItem,
              fullInventory: inventory,
              onEdit: editItem,
            ),

            InventorySection(
              icon: Icons.local_drink_outlined,
              title: 'Consumables',
              items: consumableItems,
              onConsume: consumeItem,
              fullInventory: inventory,
              onEdit: editItem,
            ),

            InventorySection(
              icon: Icons.shield_outlined,
              title: 'Equipment',
              items: equipmentItems,
              onConsume: consumeItem,
              fullInventory: inventory,
              onEdit: editItem,
            ),

            InventorySection(
              icon: Icons.handyman_outlined,
              title: 'Tools',
              items: toolItems,
              onConsume: consumeItem,
              fullInventory: inventory,
              onEdit: editItem,
            ),

            InventorySection(
              icon: Icons.backpack_outlined,
              title: 'General',
              items: generalItems,
              onConsume: consumeItem,
              fullInventory: inventory,
              onEdit: editItem,
            ),
          ],
        ),
      ),
    );
  }
}
