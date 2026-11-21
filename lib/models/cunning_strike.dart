import 'ability.dart';

enum CunningStrike {
  poison(
    'Poison',
    1,
    5,
    Ability.constitution,
    'Target Poisoned for 1 minute. It repeats the save at each turn’s end, ending the effect on success. Requires a Poisoner’s Kit.',
  ),
  trip(
    'Trip',
    1,
    5,
    Ability.dexterity,
    'A Large or smaller target falls Prone on a failed save.',
  ),
  withdraw(
    'Withdraw',
    1,
    5,
    null,
    'Immediately move up to half your Speed without provoking opportunity attacks.',
  ),
  daze(
    'Daze',
    2,
    14,
    Ability.constitution,
    'On its next turn, the target can only move, take an action, or take a Bonus Action.',
  ),
  knockOut(
    'Knock Out',
    6,
    14,
    Ability.constitution,
    'Target Unconscious for 1 minute or until damaged. It repeats the save at each turn’s end, ending the effect on success.',
  ),
  obscure(
    'Obscure',
    3,
    14,
    Ability.dexterity,
    'Target Blinded until the end of its next turn.',
  );

  const CunningStrike(
    this.label,
    this.diceCost,
    this.minimumLevel,
    this.save,
    this.effect,
  );
  final String label;
  final int diceCost;
  final int minimumLevel;
  final Ability? save;
  final String effect;
}

class SneakAttackSelection {
  final Set<CunningStrike> effects;
  SneakAttackSelection(Iterable<CunningStrike> effects)
    : effects = Set.unmodifiable(effects);

  int get diceCost => effects.fold(0, (sum, effect) => sum + effect.diceCost);

  bool isValid({
    required int rogueLevel,
    required int sneakDice,
    required bool hasPoisonersKit,
  }) =>
      effects.length <= (rogueLevel >= 11 ? 2 : 1) &&
      diceCost <= sneakDice &&
      effects.every(
        (effect) =>
            rogueLevel >= effect.minimumLevel &&
            (effect != CunningStrike.poison || hasPoisonersKit),
      );
}
