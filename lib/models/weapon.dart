import 'character_action.dart';

enum WeaponCategory {
  simpleMelee('Simple melee'),
  simpleRanged('Simple ranged'),
  martialMelee('Martial melee'),
  martialRanged('Martial ranged');

  const WeaponCategory(this.label);
  final String label;
}

enum WeaponMastery {
  cleave('Cleave'),
  graze('Graze'),
  nick('Nick'),
  push('Push'),
  sap('Sap'),
  slow('Slow'),
  topple('Topple'),
  vex('Vex');

  static String weaponType(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static WeaponMastery? forWeapon(String name) => switch (weaponType(name)) {
    'greataxe' || 'halberd' => cleave,
    'glaive' || 'greatsword' => graze,
    'dagger' || 'light hammer' || 'sickle' || 'scimitar' => nick,
    'greatclub' || 'pike' || 'warhammer' || 'heavy crossbow' => push,
    'mace' ||
    'spear' ||
    'flail' ||
    'longsword' ||
    'morningstar' ||
    'war pick' => sap,
    'club' ||
    'javelin' ||
    'light crossbow' ||
    'sling' ||
    'whip' ||
    'longbow' ||
    'musket' => slow,
    'quarterstaff' || 'battleaxe' || 'lance' || 'maul' || 'trident' => topple,
    'handaxe' ||
    'dart' ||
    'shortbow' ||
    'rapier' ||
    'shortsword' ||
    'blowgun' ||
    'hand crossbow' ||
    'pistol' => vex,
    _ => null,
  };

  static bool hasRoom({
    required int limit,
    required String name,
    required Iterable<Weapon> weapons,
    Weapon? editing,
  }) {
    final type = weaponType(name);
    final selected = {
      for (final weapon in weapons)
        if (!identical(weapon, editing) && weapon.mastery != null)
          weaponType(weapon.name),
    };
    return limit > 0 && (selected.contains(type) || selected.length < limit);
  }

  const WeaponMastery(this.label);
  final String label;
}

class Weapon extends CharacterAction {
  @override
  final String id;

  @override
  final String name;

  final int attackModifier;

  @override
  int get rollModifier => attackModifier;
  final String damage;

  @override
  final String? damageFormula;

  @override
  final String? damageType;

  final String? range;
  final String? versatileDamageFormula;
  final bool usesStrength;
  final String? ammunitionName;
  final WeaponCategory? category;
  final WeaponMastery? mastery;
  final List<String> properties;
  bool get isLight =>
      properties.any((value) => value.trim().toLowerCase() == 'light') ||
      const {
        'dagger',
        'handaxe',
        'light hammer',
        'sickle',
        'scimitar',
        'shortsword',
        'hand crossbow',
      }.contains(WeaponMastery.weaponType(name));
  final int? normalRange;
  final int? longRange;

  bool get sneakAttackEligible =>
      properties.any((value) => value.trim().toLowerCase() == 'finesse') ||
      const {
        'dagger',
        'dart',
        'rapier',
        'scimitar',
        'shortsword',
        'whip',
      }.contains(WeaponMastery.weaponType(name)) ||
      category == WeaponCategory.simpleRanged ||
      category == WeaponCategory.martialRanged ||
      (category == null &&
          const {
            'dart',
            'light crossbow',
            'shortbow',
            'sling',
            'blowgun',
            'hand crossbow',
            'heavy crossbow',
            'longbow',
            'pistol',
            'musket',
          }.contains(WeaponMastery.weaponType(name)));

  bool get isMelee => switch (category) {
    WeaponCategory.simpleMelee || WeaponCategory.martialMelee => true,
    WeaponCategory.simpleRanged || WeaponCategory.martialRanged => false,
    null => const {
      'club',
      'dagger',
      'greatclub',
      'handaxe',
      'javelin',
      'light hammer',
      'mace',
      'quarterstaff',
      'sickle',
      'spear',
      'battleaxe',
      'flail',
      'glaive',
      'greataxe',
      'greatsword',
      'halberd',
      'lance',
      'longsword',
      'maul',
      'morningstar',
      'pike',
      'rapier',
      'scimitar',
      'shortsword',
      'trident',
      'war pick',
      'warhammer',
      'whip',
    }.contains(WeaponMastery.weaponType(name)),
  };

  const Weapon({
    required this.id,
    required this.name,
    required this.attackModifier,
    required this.damage,
    this.damageFormula,
    this.damageType,
    this.range,
    this.versatileDamageFormula,
    this.usesStrength = false,
    this.ammunitionName,
    this.category,
    this.mastery,
    this.properties = const [],
    this.normalRange,
    this.longRange,
  });

  Weapon withMastery(WeaponMastery? value) => Weapon(
    id: id,
    name: name,
    attackModifier: attackModifier,
    damage: damage,
    damageFormula: damageFormula,
    damageType: damageType,
    range: range,
    versatileDamageFormula: versatileDamageFormula,
    usesStrength: usesStrength,
    ammunitionName: ammunitionName,
    category: category,
    mastery: value,
    properties: properties,
    normalRange: normalRange,
    longRange: longRange,
  );

  @override
  CharacterActionType get type => CharacterActionType.weapon;

  @override
  String get summary {
    final displayModifier = attackModifier > 0
        ? '+$attackModifier'
        : '$attackModifier';
    return [
      '$displayModifier to hit',
      damage,
      if (normalRange case final distance?)
        longRange == null ? '$distance ft' : '$distance/$longRange ft'
      else
        ?range,
      ?category?.label,
      ...properties,
      if (mastery case final value?) 'Mastery: ${value.label}',
    ].join(' • ');
  }
}
