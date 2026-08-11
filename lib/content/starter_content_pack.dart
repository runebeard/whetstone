import '../models/character_resource.dart';
import '../models/content_pack.dart';
import '../models/feature.dart';
import '../models/inventory_item.dart';
import '../models/spell.dart';
import '../models/weapon.dart';

const starterContentPack = ContentPack(
  id: 'whetstone-generic-d20-starter',
  name: 'Whetstone d20 Starter',
  gameSystem: 'Generic d20 Fantasy',
  version: '1.0.0',
  author: 'Whetstone',
  description:
      'A small fictional starter library demonstrating reusable character '
      'content without requiring a particular published game system.',
  weapons: [
    Weapon(
      id: 'training_sword',
      name: 'Training Sword',
      attackModifier: 4,
      damage: '1d8 + 2 slashing',
      damageFormula: '1d8 + 2',
      damageType: 'slashing',
      range: 'Melee',
    ),
  ],
  spells: [
    Spell(
      id: 'ember_bolt',
      name: 'Ember Bolt',
      level: 0,
      prepared: false,
      summary: '+5 to hit • 1d10 fire • 60 ft',
      rollModifier: 5,
      damageFormula: '1d10',
      damageType: 'fire',
    ),
  ],
  resources: [
    CharacterResource(
      id: 'heroic_effort',
      name: 'Heroic Effort',
      maximum: 2,
      initialValue: 2,
      rechargePeriod: RechargePeriod.shortRest,
    ),
  ],
  features: [
    Feature(
      id: 'rally',
      name: 'Rally',
      summary: 'Bonus action • Encourage a nearby ally',
    ),
  ],
  items: [
    InventoryItem(
      name: 'Healing Draught',
      quantity: 1,
      weightPerItem: 0.5,
      category: ItemCategory.consumable,
    ),
  ],
);
