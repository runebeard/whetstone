import 'character_resource.dart';
import 'feature.dart';
import 'inventory_item.dart';
import 'spell.dart';
import 'weapon.dart';

class ContentPack {
  final String id;
  final String name;
  final String gameSystem;
  final String version;
  final String author;
  final String description;
  final List<Weapon> weapons;
  final List<Spell> spells;
  final List<CharacterResource> resources;
  final List<Feature> features;
  final List<InventoryItem> items;

  const ContentPack({
    required this.id,
    required this.name,
    required this.gameSystem,
    required this.version,
    required this.author,
    required this.description,
    this.weapons = const [],
    this.spells = const [],
    this.resources = const [],
    this.features = const [],
    this.items = const [],
  });

  int get entryCount =>
      weapons.length +
      spells.length +
      resources.length +
      features.length +
      items.length;

  Map<String, Object> toJson() {
    return {
      'id': id,
      'name': name,
      'gameSystem': gameSystem,
      'version': version,
      'author': author,
      'description': description,
      'weapons': weapons
          .map(
            (weapon) => {
              'id': weapon.id,
              'name': weapon.name,
              'attackModifier': weapon.attackModifier,
              'damage': weapon.damage,
              'damageFormula': weapon.damageFormula,
              'damageType': weapon.damageType,
              'range': weapon.range,
            },
          )
          .toList(),
      'spells': spells
          .map(
            (spell) => {
              'id': spell.id,
              'name': spell.name,
              'level': spell.level,
              'prepared': spell.prepared,
              'summary': spell.summary,
              'rollModifier': spell.rollModifier,
              'damageFormula': spell.damageFormula,
              'damageType': spell.damageType,
            },
          )
          .toList(),
      'resources': resources
          .map(
            (resource) => {
              'id': resource.id,
              'name': resource.name,
              'maximum': resource.maximum,
              'initialValue': resource.initialValue,
              'rechargePeriod': resource.rechargePeriod.name,
            },
          )
          .toList(),
      'features': features
          .map(
            (feature) => {
              'id': feature.id,
              'name': feature.name,
              'summary': feature.summary,
              'rollModifier': feature.rollModifier,
            },
          )
          .toList(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory ContentPack.fromJson(Map<String, Object?> json) {
    return ContentPack(
      id: json['id'] as String,
      name: json['name'] as String,
      gameSystem: json['gameSystem'] as String,
      version: json['version'] as String,
      author: json['author'] as String,
      description: json['description'] as String,
      weapons: (json['weapons'] as List<Object?>? ?? const []).map((value) {
        final weapon = value as Map<String, Object?>;
        return Weapon(
          id: weapon['id'] as String,
          name: weapon['name'] as String,
          attackModifier: weapon['attackModifier'] as int,
          damage: weapon['damage'] as String,
          damageFormula: weapon['damageFormula'] as String?,
          damageType: weapon['damageType'] as String?,
          range: weapon['range'] as String?,
        );
      }).toList(),
      spells: (json['spells'] as List<Object?>? ?? const []).map((value) {
        final spell = value as Map<String, Object?>;
        return Spell(
          id: spell['id'] as String,
          name: spell['name'] as String,
          level: spell['level'] as int,
          prepared: spell['prepared'] as bool? ?? false,
          summary: spell['summary'] as String,
          rollModifier: spell['rollModifier'] as int?,
          damageFormula: spell['damageFormula'] as String?,
          damageType: spell['damageType'] as String?,
        );
      }).toList(),
      resources: (json['resources'] as List<Object?>? ?? const []).map((value) {
        final resource = value as Map<String, Object?>;
        return CharacterResource(
          id: resource['id'] as String,
          name: resource['name'] as String,
          maximum: resource['maximum'] as int,
          initialValue: resource['initialValue'] as int,
          rechargePeriod: RechargePeriod.values.byName(
            resource['rechargePeriod'] as String,
          ),
        );
      }).toList(),
      features: (json['features'] as List<Object?>? ?? const []).map((value) {
        final feature = value as Map<String, Object?>;
        return Feature(
          id: feature['id'] as String,
          name: feature['name'] as String,
          summary: feature['summary'] as String,
          rollModifier: feature['rollModifier'] as int?,
        );
      }).toList(),
      items: (json['items'] as List<Object?>? ?? const [])
          .map((value) => InventoryItem.fromJson(value as Map<String, Object?>))
          .toList(),
    );
  }
}
