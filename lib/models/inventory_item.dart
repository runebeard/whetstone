enum ItemCategory { consumable, equipment, tool, quest, general }

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
  }) {
    return InventoryItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      weightPerItem: weightPerItem ?? this.weightPerItem,
      category: category ?? this.category,
    );
  }

  Map<String, Object> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'weightPerItem': weightPerItem,
      'category': category.name,
    };
  }

  factory InventoryItem.fromJson(Map<String, Object?> json) {
    return InventoryItem(
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      weightPerItem: (json['weightPerItem'] as num).toDouble(),
      category: ItemCategory.values.byName(json['category'] as String),
    );
  }

  double get totalWeight => weightPerItem * quantity;
  bool get isDepleted => quantity == 0;
}
