import 'ability.dart';
import 'character_resource.dart';
import 'spell_slots.dart';
import 'weapon.dart';

const rageResourceId = 'whetstone:class:rage';
const secondWindResourceId = 'whetstone:class:second-wind';
const indomitableResourceId = 'whetstone:class:indomitable';
const actionSurgeResourceId = 'whetstone:class:action-surge';
const focusResourceId = 'whetstone:class:focus';
const uncannyMetabolismResourceId = 'whetstone:class:uncanny-metabolism';
const wholenessOfBodyResourceId = 'whetstone:subclass:wholeness-of-body';
const arcaneRecoveryResourceId = 'whetstone:class:arcane-recovery';
const wildShapeResourceId = 'whetstone:class:wild-shape';
const bardicInspirationResourceId = 'whetstone:class:bardic-inspiration';
const layOnHandsResourceId = 'whetstone:class:lay-on-hands';
const clericChannelDivinityId = 'whetstone:class:cleric-channel-divinity';
const paladinChannelDivinityId = 'whetstone:class:paladin-channel-divinity';

const progressingClassResourceIds = {
  rageResourceId,
  secondWindResourceId,
  indomitableResourceId,
  actionSurgeResourceId,
  focusResourceId,
  uncannyMetabolismResourceId,
  wholenessOfBodyResourceId,
  arcaneRecoveryResourceId,
  wildShapeResourceId,
  bardicInspirationResourceId,
  layOnHandsResourceId,
  clericChannelDivinityId,
  paladinChannelDivinityId,
};

enum BuiltInClass {
  barbarian('Barbarian', 12, Ability.strength, Ability.constitution),
  bard('Bard', 8, Ability.dexterity, Ability.charisma),
  cleric('Cleric', 8, Ability.wisdom, Ability.charisma),
  druid('Druid', 8, Ability.intelligence, Ability.wisdom),
  fighter('Fighter', 10, Ability.strength, Ability.constitution),
  monk('Monk', 8, Ability.strength, Ability.dexterity),
  paladin('Paladin', 10, Ability.wisdom, Ability.charisma),
  ranger('Ranger', 10, Ability.strength, Ability.dexterity),
  rogue('Rogue', 8, Ability.dexterity, Ability.intelligence),
  sorcerer('Sorcerer', 6, Ability.constitution, Ability.charisma),
  warlock('Warlock', 8, Ability.wisdom, Ability.charisma),
  wizard('Wizard', 6, Ability.intelligence, Ability.wisdom);

  const BuiltInClass(this.label, this.hitDie, this.firstSave, this.secondSave);

  final String label;
  final int hitDie;
  final Ability firstSave;
  final Ability secondSave;

  Set<Ability> get saves => {firstSave, secondSave};

  String get basicRulesSubclass => switch (this) {
    barbarian => 'Path of the Berserker',
    bard => 'College of Lore',
    cleric => 'Life Domain',
    druid => 'Circle of the Land',
    fighter => 'Champion',
    monk => 'Warrior of the Open Hand',
    paladin => 'Oath of Devotion',
    ranger => 'Hunter',
    rogue => 'Thief',
    sorcerer => 'Draconic Sorcery',
    warlock => 'Fiend Patron',
    wizard => 'Evoker',
  };

  Iterable<int> get abilityImprovementLevels => [
    4,
    if (this == fighter) 6,
    8,
    if (this == rogue) 10,
    12,
    if (this == fighter) 14,
    16,
  ];

  String? unmetMulticlassRequirement(int Function(Ability) score) {
    final abilities = switch (this) {
      barbarian => [Ability.strength],
      bard || sorcerer || warlock => [Ability.charisma],
      cleric || druid => [Ability.wisdom],
      fighter => const <Ability>[],
      monk || ranger => [Ability.dexterity, Ability.wisdom],
      paladin => [Ability.strength, Ability.charisma],
      rogue => [Ability.dexterity],
      wizard => [Ability.intelligence],
    };
    if (this == fighter) {
      return score(Ability.strength) >= 13 || score(Ability.dexterity) >= 13
          ? null
          : 'Strength or Dexterity 13';
    }
    final missing = abilities.where((ability) => score(ability) < 13).toList();
    return missing.isEmpty
        ? null
        : missing.map((ability) => '${ability.label} 13').join(' and ');
  }

  bool get hasWeaponMastery => switch (this) {
    barbarian || fighter || paladin || ranger || rogue => true,
    _ => false,
  };

  bool allowsMastery(String name) {
    if (!hasWeaponMastery || WeaponMastery.forWeapon(name) == null) {
      return false;
    }
    if (this != rogue) return true;
    return const {
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
      'dart',
      'light crossbow',
      'shortbow',
      'sling',
      'rapier',
      'scimitar',
      'shortsword',
      'whip',
      'hand crossbow',
    }.contains(WeaponMastery.weaponType(name));
  }

  int weaponMasteryLimit(int level) => switch (this) {
    fighter => switch (level) {
      >= 16 => 6,
      >= 10 => 5,
      >= 4 => 4,
      _ => 3,
    },
    barbarian => switch (level) {
      >= 10 => 4,
      >= 4 => 3,
      _ => 2,
    },
    paladin || ranger || rogue => 2,
    _ => 0,
  };

  int get skillCount => switch (this) {
    bard || ranger => 3,
    rogue => 4,
    _ => 2,
  };

  bool allowsSkill(String id) {
    final choices = switch (this) {
      barbarian =>
        'animal_handling athletics intimidation nature perception survival',
      bard => null,
      cleric => 'history insight medicine persuasion religion',
      druid =>
        'arcana animal_handling insight medicine nature perception religion survival',
      fighter =>
        'acrobatics animal_handling athletics history insight intimidation persuasion perception survival',
      monk => 'acrobatics athletics history insight religion stealth',
      paladin => 'athletics insight intimidation medicine persuasion religion',
      ranger =>
        'animal_handling athletics insight investigation nature perception stealth survival',
      rogue =>
        'acrobatics athletics deception insight intimidation investigation perception persuasion sleight_of_hand stealth',
      sorcerer => 'arcana deception insight intimidation persuasion religion',
      warlock =>
        'arcana deception history intimidation investigation nature religion',
      wizard => 'arcana history insight investigation medicine nature religion',
    };
    return choices == null || choices.split(' ').contains(id);
  }

  List<CharacterResource> startingResources({required int charismaModifier}) =>
      [
        ...spellSlotsForClass(label, 1),
        ...classResources(1, charismaModifier: charismaModifier),
      ];

  List<CharacterResource> classResources(
    int level, {
    required int charismaModifier,
    int wisdomModifier = 0,
    String? subclass,
  }) {
    if (level < 1) return [];
    final personalResource = switch (this) {
      barbarian => (
        rageResourceId,
        'Rage',
        switch (level) {
          >= 17 => 6,
          >= 12 => 5,
          >= 6 => 4,
          >= 3 => 3,
          _ => 2,
        },
      ),
      fighter => (
        secondWindResourceId,
        'Second Wind',
        switch (level) {
          >= 10 => 4,
          >= 4 => 3,
          _ => 2,
        },
      ),
      bard => (
        bardicInspirationResourceId,
        'Bardic Inspiration',
        charismaModifier.clamp(1, 10),
      ),
      paladin => (layOnHandsResourceId, 'Lay on Hands', 5 * level),
      sorcerer => ('whetstone:class:innate-sorcery', 'Innate Sorcery', 2),
      _ => null,
    };
    return [
      if (this == wizard)
        const CharacterResource(
          id: arcaneRecoveryResourceId,
          name: 'Arcane Recovery',
          maximum: 1,
          initialValue: 1,
          rechargePeriod: RechargePeriod.longRest,
        ),
      if (this == monk && level >= 6 && subclass == 'Warrior of the Open Hand')
        CharacterResource(
          id: wholenessOfBodyResourceId,
          name: 'Wholeness of Body',
          maximum: wisdomModifier.clamp(1, 10),
          initialValue: wisdomModifier.clamp(1, 10),
          rechargePeriod: RechargePeriod.longRest,
        ),
      if (this == monk && level >= 2)
        const CharacterResource(
          id: uncannyMetabolismResourceId,
          name: 'Uncanny Metabolism',
          maximum: 1,
          initialValue: 1,
          rechargePeriod: RechargePeriod.longRest,
        ),
      if (this == monk && level >= 2)
        CharacterResource(
          id: focusResourceId,
          name: 'Focus Points',
          maximum: level,
          initialValue: level,
          rechargePeriod: RechargePeriod.shortRest,
        ),
      if (personalResource case (final id, final name, final uses))
        CharacterResource(
          id: id,
          name: name,
          maximum: uses,
          initialValue: uses,
          rechargePeriod: this == bard && level >= 5
              ? RechargePeriod.shortRest
              : RechargePeriod.longRest,
        ),
      if (this == cleric && level >= 2)
        _channelDivinity(
          clericChannelDivinityId,
          level >= 18
              ? 4
              : level >= 6
              ? 3
              : 2,
        ),
      if (this == paladin && level >= 3)
        _channelDivinity(paladinChannelDivinityId, level >= 11 ? 3 : 2),
      if (this == druid && level >= 2)
        CharacterResource(
          id: wildShapeResourceId,
          name: 'Wild Shape',
          maximum: level >= 17
              ? 4
              : level >= 6
              ? 3
              : 2,
          initialValue: level >= 17
              ? 4
              : level >= 6
              ? 3
              : 2,
          rechargePeriod: RechargePeriod.longRest,
        ),
      if (this == fighter && level >= 2)
        CharacterResource(
          id: actionSurgeResourceId,
          name: 'Action Surge',
          maximum: level >= 17 ? 2 : 1,
          initialValue: level >= 17 ? 2 : 1,
          rechargePeriod: RechargePeriod.shortRest,
        ),
      if (this == fighter && level >= 9)
        CharacterResource(
          id: indomitableResourceId,
          name: 'Indomitable',
          maximum: level >= 17
              ? 3
              : level >= 13
              ? 2
              : 1,
          initialValue: level >= 17
              ? 3
              : level >= 13
              ? 2
              : 1,
          rechargePeriod: RechargePeriod.longRest,
        ),
    ];
  }

  static CharacterResource _channelDivinity(String id, int uses) =>
      CharacterResource(
        id: id,
        name: id == clericChannelDivinityId
            ? 'Cleric Channel Divinity'
            : 'Paladin Channel Divinity',
        maximum: uses,
        initialValue: uses,
        rechargePeriod: RechargePeriod.longRest,
      );

  static BuiltInClass? named(String name) {
    final normalized = name.trim().toLowerCase();
    for (final entry in values) {
      if (entry.name == normalized) return entry;
    }
    return null;
  }
}
