import '../models/weapon.dart';
import '../models/ability.dart';

class WildShapeForm {
  final String name;
  final int armourClass;
  final String speed;
  final int strength;
  final int dexterity;
  final int constitution;
  final String attack;
  final String? trait;
  final Weapon combatAttack;
  final Map<String, int> skillModifiers;
  final Map<Ability, int> saveModifiers;
  final bool flies;
  final int? fixedDamage;
  final String senses;

  const WildShapeForm({
    required this.name,
    required this.armourClass,
    required this.speed,
    required this.strength,
    required this.dexterity,
    required this.constitution,
    required this.attack,
    this.trait,
    required this.combatAttack,
    this.skillModifiers = const {},
    this.saveModifiers = const {},
    this.flies = false,
    this.fixedDamage,
    this.senses = '',
  });
}

const suggestedWildShapeForms = [
  WildShapeForm(
    name: 'Owl',
    armourClass: 11,
    speed: '5 ft., fly 60 ft.',
    strength: 3,
    dexterity: 13,
    constitution: 8,
    skillModifiers: {'perception': 5, 'stealth': 5},
    flies: true,
    fixedDamage: 1,
    senses: 'Darkvision 120 feet',
    attack: 'Talons +3, reach 5 ft., 1 slashing',
    trait:
        'Flyby. Flying out of an enemy’s reach does not provoke an opportunity attack.',
    combatAttack: Weapon(
      id: 'wild-shape-owl',
      name: 'Owl Talons',
      attackModifier: 3,
      damage: '1 slashing',
      damageFormula: '1d1',
      damageType: 'slashing',
      range: '5 feet',
    ),
  ),
  WildShapeForm(
    name: 'Raven',
    armourClass: 12,
    speed: '10 ft., fly 50 ft.',
    strength: 2,
    dexterity: 14,
    constitution: 10,
    skillModifiers: {'perception': 3},
    flies: true,
    fixedDamage: 1,
    attack: 'Beak +4, reach 5 ft., 1 piercing',
    trait:
        'Mimicry. Copy simple sounds. A listener can identify the imitation with a DC 10 Wisdom (Insight) check.',
    combatAttack: Weapon(
      id: 'wild-shape-raven',
      name: 'Raven Beak',
      attackModifier: 4,
      damage: '1 piercing',
      damageFormula: '1d1',
      damageType: 'piercing',
      range: '5 feet',
    ),
  ),
  WildShapeForm(
    name: 'Cat',
    saveModifiers: {Ability.dexterity: 4},
    armourClass: 12,
    speed: '40 ft., climb 40 ft.',
    strength: 3,
    dexterity: 15,
    constitution: 10,
    skillModifiers: {'perception': 3, 'stealth': 4},
    fixedDamage: 1,
    attack: 'Scratch +4, reach 5 ft., 1 slashing',
    trait: 'Jumper. Use Dexterity to determine jump distance.',
    combatAttack: Weapon(
      id: 'wild-shape-cat',
      name: 'Cat Scratch',
      attackModifier: 4,
      damage: '1 slashing',
      damageFormula: '1d1',
      damageType: 'slashing',
      range: '5 feet',
    ),
  ),
  WildShapeForm(
    name: 'Eagle',
    armourClass: 12,
    speed: '10 ft., fly 60 ft.',
    strength: 6,
    dexterity: 15,
    constitution: 12,
    skillModifiers: {'perception': 6},
    flies: true,
    attack: 'Talons +4, reach 5 ft., 1d4 + 2 slashing',
    combatAttack: Weapon(
      id: 'wild-shape-eagle',
      name: 'Eagle Talons',
      attackModifier: 4,
      damage: '1d4 + 2 slashing',
      damageFormula: '1d4 + 2',
      damageType: 'slashing',
      range: '5 feet',
    ),
  ),
  WildShapeForm(
    name: 'Rat',
    senses: 'Darkvision 30 feet',
    fixedDamage: 1,
    skillModifiers: {'perception': 2},
    combatAttack: Weapon(
      id: 'wild-shape-rat',
      name: 'Rat Bite',
      attackModifier: 2,
      damage: '1 piercing',
      damageFormula: '1d1',
      damageType: 'piercing',
      range: '5 feet',
    ),
    armourClass: 10,
    speed: '20 ft., climb 20 ft.',
    strength: 2,
    dexterity: 11,
    constitution: 9,
    attack: 'Bite +2, reach 5 ft., 1 piercing',
    trait:
        'Agile. Leaving an enemy’s reach does not provoke an opportunity attack.',
  ),
  WildShapeForm(
    name: 'Riding Horse',
    combatAttack: Weapon(
      id: 'wild-shape-horse',
      name: 'Horse Hooves',
      attackModifier: 5,
      damage: '1d8 + 3 bludgeoning',
      damageFormula: '1d8 + 3',
      damageType: 'bludgeoning',
      range: '5 feet',
    ),
    armourClass: 11,
    speed: '60 ft.',
    strength: 16,
    dexterity: 13,
    constitution: 12,
    attack: 'Hooves +5, reach 5 ft., 1d8 + 3 bludgeoning',
  ),
  WildShapeForm(
    name: 'Spider',
    senses: 'Darkvision 30 feet',
    skillModifiers: {'stealth': 4},
    combatAttack: Weapon(
      id: 'wild-shape-spider',
      name: 'Spider Bite',
      attackModifier: 4,
      damage: '1 piercing plus 1d4 poison',
      damageFormula: '1d4 + 1',
      damageType: 'mixed piercing and poison',
      range: '5 feet',
    ),
    armourClass: 12,
    speed: '20 ft., climb 20 ft.',
    strength: 2,
    dexterity: 14,
    constitution: 8,
    attack: 'Bite +4, reach 5 ft., 1 piercing plus 1d4 poison',
    trait:
        'Spider Climb. Climb difficult surfaces and ceilings without a check.',
  ),
  WildShapeForm(
    name: 'Wolf',
    senses: 'Darkvision 60 feet',
    skillModifiers: {'perception': 5, 'stealth': 4},
    combatAttack: Weapon(
      id: 'wild-shape-wolf',
      name: 'Wolf Bite',
      attackModifier: 4,
      damage: '1d6 + 2 piercing',
      damageFormula: '1d6 + 2',
      damageType: 'piercing',
      range: '5 feet',
      properties: [
        'Medium or smaller targets fall Prone on a hit',
        'Pack Tactics',
      ],
    ),
    armourClass: 12,
    speed: '40 ft.',
    strength: 14,
    dexterity: 15,
    constitution: 12,
    attack:
        'Bite +4, reach 5 ft., 1d6 + 2 piercing. Medium or smaller targets fall Prone.',
    trait:
        'Pack Tactics. Attack with advantage if a non-incapacitated ally is within 5 ft. of the target.',
  ),
  WildShapeForm(
    name: 'Crab',
    armourClass: 11,
    speed: '20 ft., swim 20 ft.',
    strength: 6,
    dexterity: 11,
    constitution: 12,
    skillModifiers: {'stealth': 2},
    fixedDamage: 1,
    senses: 'Blindsight 30 feet',
    attack: 'Claw +2, reach 5 ft., 1 bludgeoning',
    trait: 'Amphibious. Breathe both underwater and on land.',
    combatAttack: Weapon(
      id: 'wild-shape-crab',
      name: 'Crab Claw',
      attackModifier: 2,
      damage: '1 bludgeoning',
      damageFormula: '1d1',
      damageType: 'bludgeoning',
      range: '5 feet',
    ),
  ),
  WildShapeForm(
    name: 'Lizard',
    armourClass: 10,
    speed: '20 ft., climb 20 ft.',
    strength: 2,
    dexterity: 11,
    constitution: 10,
    fixedDamage: 1,
    senses: 'Darkvision 30 feet',
    attack: 'Bite +2, reach 5 ft., 1 piercing',
    trait:
        'Spider Climb. Traverse difficult climbing surfaces and ceilings without a check.',
    combatAttack: Weapon(
      id: 'wild-shape-lizard',
      name: 'Lizard Bite',
      attackModifier: 2,
      damage: '1 piercing',
      damageFormula: '1d1',
      damageType: 'piercing',
      range: '5 feet',
    ),
  ),
  WildShapeForm(
    name: 'Bat',
    armourClass: 12,
    speed: '5 ft., fly 30 ft.',
    strength: 2,
    dexterity: 15,
    constitution: 8,
    flies: true,
    fixedDamage: 1,
    senses: 'Blindsight 60 feet',
    attack: 'Bite +4, reach 5 ft., 1 piercing',
    combatAttack: Weapon(
      id: 'wild-shape-bat',
      name: 'Bat Bite',
      attackModifier: 4,
      damage: '1 piercing',
      damageFormula: '1d1',
      damageType: 'piercing',
      range: '5 feet',
    ),
  ),
];

WildShapeForm? wildShapeFormNamed(String name) => suggestedWildShapeForms
    .where((form) => form.name.toLowerCase() == name.trim().toLowerCase())
    .firstOrNull;
