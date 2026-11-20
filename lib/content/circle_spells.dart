import '../models/ability.dart';
import '../models/character.dart';
import '../models/character_state.dart';
import '../models/spell.dart';

List<Spell> withCircleSpells(Character character, DruidLand? land) {
  final owned = character.spells
      .where((spell) => !spell.isCircleGrant)
      .toList();
  if (land == null || character.subclasses['Druid'] != 'Circle of the Land') {
    return owned;
  }
  final availableNames = land.spellsAt(character.levelInClass('Druid'));
  final known = {
    for (final spell in owned.where((spell) => spell.isAvailableInCombat))
      spell.name.trim().toLowerCase(),
  };
  return [
    ...owned,
    for (final name in availableNames)
      if (!known.contains(name.toLowerCase())) _circleSpell(name),
  ];
}

Spell _circleSpell(String name) {
  final (level, concentration) = switch (name) {
    'Fire Bolt' ||
    'Ray of Frost' ||
    'Shocking Grasp' ||
    'Acid Splash' => (0, false),
    'Burning Hands' || 'Ray of Sickness' => (1, false),
    'Fog Cloud' || 'Sleep' => (1, true),
    'Misty Step' => (2, false),
    'Blur' || 'Hold Person' || 'Web' => (2, true),
    'Fireball' || 'Lightning Bolt' => (3, false),
    'Sleet Storm' || 'Stinking Cloud' => (3, true),
    'Blight' || 'Ice Storm' || 'Freedom of Movement' => (4, false),
    'Polymorph' => (4, true),
    'Cone of Cold' => (5, false),
    'Wall of Stone' || 'Tree Stride' || 'Insect Plague' => (5, true),
    _ => throw ArgumentError.value(name, 'name', 'Unknown Circle spell'),
  };
  final (damage, damageType, range) = switch (name) {
    'Fire Bolt' => ('1d10', 'fire', '120 feet'),
    'Ray of Frost' => ('1d8', 'cold', '60 feet'),
    'Shocking Grasp' => ('1d8', 'lightning', 'Touch'),
    'Acid Splash' => ('1d6', 'acid', '60 feet'),
    'Burning Hands' => ('3d6', 'fire', 'Self (15-foot cone)'),
    'Ray of Sickness' => ('2d8', 'poison', '60 feet'),
    'Fireball' => ('8d6', 'fire', '150 feet'),
    'Lightning Bolt' => ('8d6', 'lightning', 'Self (100-foot line)'),
    'Blight' => ('8d8', 'necrotic', '30 feet'),
    'Cone of Cold' => ('8d8', 'cold', 'Self (60-foot cone)'),
    'Insect Plague' => ('4d10', 'piercing', '300 feet'),
    'Blur' || 'Misty Step' => (null, null, 'Self'),
    'Fog Cloud' => (null, null, '120 feet'),
    'Hold Person' || 'Web' || 'Sleep' || 'Polymorph' => (null, null, '60 feet'),
    'Sleet Storm' => (null, null, '150 feet'),
    'Ice Storm' => ('2d10', 'bludgeoning', '300 feet'),
    'Stinking Cloud' => (null, null, '90 feet'),
    'Freedom of Movement' => (null, null, 'Touch'),
    'Wall of Stone' => (null, null, '120 feet'),
    'Tree Stride' => (null, null, 'Self'),
    _ => (null, null, null),
  };
  final save = switch (name) {
    'Acid Splash' ||
    'Burning Hands' ||
    'Fireball' ||
    'Lightning Bolt' => Ability.dexterity,
    'Blight' || 'Cone of Cold' || 'Insect Plague' => Ability.constitution,
    'Hold Person' || 'Sleep' || 'Polymorph' => Ability.wisdom,
    'Web' ||
    'Sleet Storm' ||
    'Ice Storm' ||
    'Wall of Stone' => Ability.dexterity,
    'Stinking Cloud' => Ability.constitution,
    _ => null,
  };
  final summary = switch (name) {
    'Burning Hands' =>
      'Creatures in the cone save for half damage. Exposed flammable objects can ignite.',
    'Ray of Sickness' =>
      'On a hit, the target is also Poisoned until the end of your next turn.',
    'Fireball' => 'Creatures in a 20-foot-radius sphere save for half damage.',
    'Lightning Bolt' =>
      'Creatures in a 100-foot-long, 5-foot-wide line save for half damage.',
    'Blight' =>
      'A creature you can see saves for half damage. Plants automatically fail.',
    'Cone of Cold' => 'Creatures in the cone save for half damage.',
    'Insect Plague' =>
      'Creatures in the swarm save for half damage. Repeat when a creature first enters on a turn or ends its turn there, at most once per turn per creature.',
    'Blur' =>
      'Attacks against you have disadvantage unless the attacker can see through the illusion.',
    'Fog Cloud' =>
      'A 20-foot-radius sphere is heavily obscured. Add 20 feet to the radius per slot level above 1.',
    'Misty Step' => 'Teleport up to 30 feet to a visible, unoccupied space.',
    'Hold Person' =>
      'A visible Humanoid saves against Paralyzed. It repeats the Wisdom save at the end of each turn. Higher slots add one target per level above 2.',
    'Web' =>
      'Create a 20-foot cube of webs. A creature entering for the first time on a turn or starting its turn there makes a Dexterity save against Restrained. Resolve escape checks and burning webs at the table.',
    'Sleep' =>
      'Choose creatures in a 5-foot-radius sphere. A failed Wisdom save incapacitates until the end of the next turn. A second failed save then causes Unconscious. Damage or an action to shake the target ends the effect.',
    'Sleet Storm' =>
      'Create a heavily obscured cylinder with a 40-foot radius and 20-foot height. Ground is difficult terrain. A creature entering for the first time on a turn or starting its turn there makes a Dexterity save against Prone and loss of concentration.',
    'Ice Storm' =>
      'Creatures in a 20-foot-radius, 40-foot-high cylinder make a Dexterity save. Roll 2d10 bludgeoning and 4d6 cold, halving each on success. Higher slots add 1d10 bludgeoning per level above 4. Ground is difficult terrain until the end of your next turn.',
    'Stinking Cloud' =>
      'Create a 20-foot-radius sphere of heavily obscuring gas. Creatures starting their turn inside make a Constitution save against Poisoned until the end of that turn. While affected, they cannot take an action or Bonus Action.',
    'Polymorph' =>
      'A visible creature makes a Wisdom save against transformation into a Beast. The chosen Beast CR cannot exceed its CR or level. Track the replacement statistics and temporary HP at the table.',
    'Freedom of Movement' =>
      'A willing creature ignores difficult terrain. Magic cannot reduce its Speed or impose Paralyzed or Restrained. It can spend 5 feet of movement to escape nonmagical restraints.',
    'Wall of Stone' =>
      'Create ten contiguous stone panels supported by existing stone. An enclosed creature can make a Dexterity save and use its Reaction to escape on success. Concentrating for the full ten minutes makes the wall permanent.',
    'Tree Stride' =>
      'Enter a living tree of your size or larger and emerge from another of the same kind within 500 feet. Entering and exiting each cost 5 feet of movement. Use this transportation once per turn.',
    _ =>
      'Circle of the Land spell. Resolve any untracked effects at the table.',
  };
  return Spell(
    id: '${Spell.circleGrantPrefix}${name.toLowerCase().replaceAll(' ', '-')}',
    name: name,
    level: level,
    prepared: true,
    concentration: concentration,
    castingAbility: Ability.wisdom,
    castingTime: name == 'Misty Step' ? 'Bonus Action' : 'Action',
    deriveAttackModifier: damage != null && save == null,
    savingThrowAbility: save,
    halfDamageOnSave: save != null && damage != null && level > 0,
    scaleCantripDamage: level == 0,
    rollEffectOnCast: damage != null,
    additionalDicePerSlotLevel: damage != null && level > 0 ? 1 : 0,
    repeatableEffect: name == 'Insect Plague',
    damageFormula: damage,
    damageType: damageType,
    range: range,
    duration: switch (name) {
      'Blur' => 'Concentration, up to 1 minute',
      'Fog Cloud' => 'Concentration, up to 1 hour',
      'Insect Plague' => 'Concentration, up to 10 minutes',
      'Misty Step' => 'Instantaneous',
      'Hold Person' ||
      'Sleep' ||
      'Sleet Storm' ||
      'Stinking Cloud' ||
      'Tree Stride' => 'Concentration, up to 1 minute',
      'Web' || 'Polymorph' => 'Concentration, up to 1 hour',
      'Wall of Stone' => 'Concentration, up to 10 minutes',
      'Freedom of Movement' => '1 hour',
      'Ice Storm' => 'Instantaneous',
      _ => null,
    },
    summary: summary,
  );
}
