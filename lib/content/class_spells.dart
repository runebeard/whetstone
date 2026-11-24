import '../models/ability.dart';
import '../models/character.dart';
import '../models/character_state.dart';
import '../models/spell.dart';
import 'circle_spells.dart';

List<Spell> withClassSpells(Character character, DruidLand? land) =>
    withDraconicSpells(
      character.copyWith(spells: withCircleSpells(character, land)),
    );

List<Spell> withDraconicSpells(Character character) {
  final owned = character.spells
      .where((spell) => !spell.isDraconicGrant)
      .toList();
  final level = character.levelInClass('Sorcerer');
  if (character.subclasses['Sorcerer'] != 'Draconic Sorcery' || level < 3) {
    return owned;
  }
  final names = owned
      .where(character.isDraconicClassSpell)
      .map((spell) => Spell.normalizedName(spell.name))
      .toSet();
  return [
    for (final spell in owned)
      character.isDraconicClassSpell(spell) ? spell.withPrepared(true) : spell,
    for (final entry in Spell.draconicGrants.entries)
      if (level >= entry.value.$1 && !names.contains(entry.key))
        _draconicSpell(entry.key, entry.value.$2),
  ];
}

Character withDraconicSpellGrants(Character character) {
  final spells = withDraconicSpells(character);
  final removed = {
    for (final spell in character.spells)
      if (spell.isDraconicGrant &&
          !spells.any((remaining) => remaining.id == spell.id))
        spell.actionKey,
  };
  return character.copyWith(
    spells: spells,
    initiallyPinnedActionKeys: character.initiallyPinnedActionKeys.difference(
      removed,
    ),
  );
}

Spell _draconicSpell(String key, int level) {
  final (
    name,
    range,
    duration,
    concentration,
    components,
    summary,
  ) = switch (key) {
    'alter self' => (
      'Alter Self',
      'Self',
      'Concentration, up to 1 hour',
      true,
      'V, S',
      'Choose an aquatic adaptation, changed appearance, or natural weapons. Resolve the form and its statistics at the table.',
    ),
    'chromatic orb' => (
      'Chromatic Orb',
      '90 feet',
      'Instantaneous',
      false,
      'V, S, M (diamond worth at least 50 GP)',
      'Make a ranged spell attack. Choose Acid, Cold, Fire, Lightning, Poison or Thunder damage; roll 3d8, plus 1d8 per slot level above 1. Resolve attacks, damage type and orb leaps at the table.',
    ),
    'command' => (
      'Command',
      '60 feet',
      'Instantaneous',
      false,
      'V',
      'Give a one-word command. A target failing its Wisdom save follows it on its next turn. Resolve eligibility, the command and additional upcast targets at the table.',
    ),
    "dragon's breath" => (
      "Dragon's Breath",
      'Touch',
      'Concentration, up to 1 minute',
      true,
      'V, S, M (hot pepper)',
      'Touch a willing creature and choose Acid, Cold, Fire, Lightning or Poison. Its Magic action can produce a 15-foot cone: Dexterity save for half of 3d6 damage, plus 1d6 per slot level above 2. Resolve breath actions and targets at the table.',
    ),
    'fear' => (
      'Fear',
      'Self (30-foot cone)',
      'Concentration, up to 1 minute',
      true,
      'V, S, M (white feather)',
      'Resolve Wisdom saves, Frightened targets, dropped items, movement and later saves at the table.',
    ),
    'fly' => (
      'Fly',
      'Touch',
      'Concentration, up to 10 minutes',
      true,
      'V, S, M (feather)',
      'Grant a willing creature a Fly Speed of 60 feet with hovering. Resolve flight, additional upcast targets and positioning at the table.',
    ),
    'arcane eye' => (
      'Arcane Eye',
      '30 feet',
      'Concentration, up to 1 hour',
      true,
      'V, S, M (bat fur)',
      'Create an invisible scouting eye. Move it with a Bonus Action; resolve what it can see and where it can travel at the table.',
    ),
    'charm monster' => (
      'Charm Monster',
      '30 feet',
      '1 hour',
      false,
      'V, S',
      'Resolve a Wisdom save, with Advantage while fighting you or your allies. A failed save charms the target; damage by your side can end the effect. Resolve extra upcast targets at the table.',
    ),
    'legend lore' => (
      'Legend Lore',
      'Self',
      'Instantaneous',
      false,
      'V, S, M (incense worth at least 250 GP, consumed; four ivory strips worth at least 50 GP each)',
      'Spend 10 minutes seeking lore about a legendary subject. Confirm and consume the required incense at the table; information comes from the DM.',
    ),
    'summon dragon' => (
      'Summon Dragon',
      '90 feet',
      'Concentration, up to 1 hour',
      true,
      'V, S, M (engraved dragon object worth at least 500 GP)',
      'Summon a Draconic Spirit. Resolve its chosen type, statistics, commands, movement and attacks at the table; optionally record it with Track Summon.',
    ),
    _ => throw ArgumentError.value(key),
  };
  return Spell(
    id: '${Spell.draconicGrantPrefix}${key.replaceAll(RegExp('[^a-z0-9]+'), '-')}',
    name: name,
    level: level,
    prepared: true,
    concentration: concentration,
    castingAbility: Ability.charisma,
    deriveAttackModifier: key == 'chromatic orb',
    castingTime: key == "dragon's breath"
        ? 'Bonus Action'
        : key == 'legend lore'
        ? '10 minutes'
        : 'Action',
    range: range,
    duration: duration,
    components: components,
    savingThrowAbility: {'command', 'fear', 'charm monster'}.contains(key)
        ? Ability.wisdom
        : key == "dragon's breath"
        ? Ability.dexterity
        : null,
    summary: 'Draconic Spells · $summary',
  );
}
