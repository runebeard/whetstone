enum ItemCategory {
  consumable,
  equipment,
  tool,
  quest,
  general,
}

class InventoryItem {
  final String name;
  final int quantity;
  final double weightPerItem;
  final ItemCategory category;

  const InventoryItem({
    required this.name,
    required this.quantity,
    required this.weightPerItem,
    required this.category,
  });

  InventoryItem copyWith({
    String? name,
    int? quantity,
    double? weightPerItem,
    ItemCategory? category,
    
  }) 
  
  {
    return InventoryItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      weightPerItem: weightPerItem ?? this.weightPerItem,
      category: category ?? this.category,
    );
  }
  double get totalWeight => weightPerItem * quantity;
  bool get isDepleted => quantity == 0;
}