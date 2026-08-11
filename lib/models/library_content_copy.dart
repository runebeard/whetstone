import 'character_resource.dart';
import 'feature.dart';
import 'inventory_item.dart';
import 'spell.dart';
import 'weapon.dart';

class LibraryContentCopy {
  static String uniqueId(String sourceId, Iterable<String> existingIds) {
    final used = existingIds.toSet();
    if (!used.contains(sourceId)) return sourceId;
    var suffix = DateTime.now().microsecondsSinceEpoch;
    var candidate = '$sourceId-$suffix';
    while (used.contains(candidate)) {
      suffix += 1;
      candidate = '$sourceId-$suffix';
    }
    return candidate;
  }

  static Weapon weapon(Weapon source, Iterable<Weapon> existing) {
    return Weapon(
      id: uniqueId(source.id, existing.map((entry) => entry.id)),
      name: source.name,
      attackModifier: source.attackModifier,
      damage: source.damage,
      damageFormula: source.damageFormula,
      damageType: source.damageType,
      range: source.range,
    );
  }

  static Spell spell(Spell source, Iterable<Spell> existing) {
    return Spell(
      id: uniqueId(source.id, existing.map((entry) => entry.id)),
      name: source.name,
      level: source.level,
      prepared: source.prepared,
      summary: source.summary,
      rollModifier: source.rollModifier,
      damageFormula: source.damageFormula,
      damageType: source.damageType,
    );
  }

  static CharacterResource resource(
    CharacterResource source,
    Iterable<CharacterResource> existing,
  ) {
    return CharacterResource(
      id: uniqueId(source.id, existing.map((entry) => entry.id)),
      name: source.name,
      maximum: source.maximum,
      initialValue: source.initialValue,
      rechargePeriod: source.rechargePeriod,
    );
  }

  static Feature feature(Feature source, Iterable<Feature> existing) {
    return Feature(
      id: uniqueId(source.id, existing.map((entry) => entry.id)),
      name: source.name,
      summary: source.summary,
      rollModifier: source.rollModifier,
    );
  }

  static InventoryItem item(InventoryItem source) {
    return InventoryItem(
      name: source.name,
      quantity: source.quantity,
      weightPerItem: source.weightPerItem,
      category: source.category,
    );
  }
}
