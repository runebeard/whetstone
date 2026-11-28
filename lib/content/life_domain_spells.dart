import '../models/ability.dart';
import '../models/character.dart';
import '../models/spell.dart';

List<Spell> withLifeDomainSpells(Character character) {
  final owned = character.spells.where((s) => !s.isLifeDomainGrant).toList();
  final level = character.levelInClass('Cleric');
  if (level < 3 || character.subclasses['Cleric'] != 'Life Domain') {
    return owned;
  }
  // Keep distinct class versions; never replace an authored or Wizard spell.
  return [
    ...owned,
    for (final entry in Spell.lifeDomainGrants.entries)
      if (level >= entry.value.$1) _lifeSpell(entry.key, entry.value.$2),
  ];
}

Spell _lifeSpell(String key, int level) {
  final (name, range, duration, components, summary) = switch (key) {
    'aid' => (
      'Aid',
      '30 feet',
      '8 hours',
      'V, S, M (white cloth)',
      'Boost up to three targets’ maximum and current HP by 5, plus 5 per higher slot. Track changes and expiry at the table.',
    ),
    'bless' => (
      'Bless',
      '30 feet',
      'Concentration, up to 1 minute',
      'V, S, M (Holy Symbol worth 5+ GP)',
      'Three targets add 1d4 to attacks and saves. Higher slots add targets; apply bonuses at the table.',
    ),
    'cure wounds' => (
      'Cure Wounds',
      'Touch',
      'Instantaneous',
      'V, S',
      'Heal 2d8 + Wisdom, plus 2d8 per higher slot. Choose targets when casting; other creatures apply their HP changes at the table.',
    ),
    'lesser restoration' => (
      'Lesser Restoration',
      'Touch',
      'Instantaneous',
      'V, S',
      'End one Blinded, Deafened, Paralyzed or Poisoned condition. Choose the target when casting; other creatures apply removal at the table.',
    ),
    'mass healing word' => (
      'Mass Healing Word',
      '60 feet',
      'Instantaneous',
      'V',
      'Heal up to six visible targets for 2d4 + Wisdom, plus 1d4 per higher slot. Choose targets when casting; other creatures apply their HP changes at the table.',
    ),
    'revivify' => (
      'Revivify',
      'Touch',
      'Instantaneous',
      'V, S, M (diamond worth 300+ GP, consumed)',
      'Return an eligible target that died within the last minute to 1 HP. Confirm eligibility and material use at the table.',
    ),
    'aura of life' => (
      'Aura of Life',
      'Self',
      'Concentration, up to 10 minutes',
      'V',
      'Allies in the 30-foot aura gain Necrotic Resistance and cannot lose maximum HP; an ally starting its turn at 0 HP regains 1. Resolve effects at the table.',
    ),
    'death ward' => (
      'Death Ward',
      'Touch',
      '8 hours',
      'V, S',
      'Protect the target from one qualifying lethal event. Track the protection, trigger and expiry at the table.',
    ),
    'greater restoration' => (
      'Greater Restoration',
      'Touch',
      'Instantaneous',
      'V, S, M (diamond dust worth 100+ GP, consumed)',
      'Remove one eligible debilitating effect. Confirm the effect and material use at the table.',
    ),
    'mass cure wounds' => (
      'Mass Cure Wounds',
      '60 feet',
      'Instantaneous',
      'V, S',
      'Heal up to six targets in a 30-foot-radius area for 5d8 + Wisdom, plus 1d8 per higher slot. Choose targets when casting; other creatures apply their HP changes at the table.',
    ),
    _ => throw ArgumentError.value(key),
  };
  return Spell(
    id: '${Spell.lifeDomainGrantPrefix}${key.replaceAll(' ', '-')}',
    name: name,
    level: level,
    prepared: true,
    castingAbility: Ability.wisdom,
    castingTime: {'lesser restoration', 'mass healing word'}.contains(key)
        ? 'Bonus Action'
        : 'Action',
    concentration: {'bless', 'aura of life'}.contains(key),
    range: range,
    duration: duration,
    components: components,
    summary: 'Life Domain Spells · $summary',
  );
}
