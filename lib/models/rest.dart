import 'ability.dart';
import 'character.dart';
import 'check_roll.dart';
import 'character_resource.dart';
import 'character_state.dart';

enum RestType {
  shortRest('Short Rest'),
  longRest('Long Rest');

  final String label;

  const RestType(this.label);
}

class RestPlan {
  final RestType type;
  final CharacterState updatedState;
  final List<String> changes;

  const RestPlan({
    required this.type,
    required this.updatedState,
    required this.changes,
  });

  bool get hasChanges => changes.isNotEmpty;

  static int hitDieFor(Character character) =>
      switch (character.characterClass.trim().toLowerCase()) {
        'barbarian' => 12,
        'fighter' || 'paladin' || 'ranger' => 10,
        'sorcerer' || 'wizard' => 6,
        _ => 8,
      };

  static int availableHitDice(Character character, CharacterState state) =>
      (character.level - state.hitDiceSpent).clamp(0, character.level).toInt();

  RestPlan spendHitDice({
    required Character character,
    required int count,
    required DiceRoller roller,
  }) {
    if (type != RestType.shortRest ||
        updatedState.currentHp <= 0 ||
        updatedState.currentHp >= updatedState.maxHp) {
      return this;
    }
    final constitution = ((character.scoreFor(Ability.constitution) - 10) / 2)
        .floor();
    final sides = hitDieFor(character);
    var hp = updatedState.currentHp;
    final limit = count.clamp(0, availableHitDice(character, updatedState));
    final rolls = <int>[];
    while (rolls.length < limit && hp < updatedState.maxHp) {
      final roll = roller.rollDie(sides);
      rolls.add(roll);
      final healing = (roll + constitution)
          .clamp(0, updatedState.maxHp - hp)
          .toInt();
      hp += healing;
    }
    if (rolls.isEmpty) return this;
    return RestPlan(
      type: type,
      updatedState: updatedState.copyWith(
        currentHp: hp,
        hitDiceSpent: updatedState.hitDiceSpent + rolls.length,
      ),
      changes: [
        ...changes,
        'Hit points: ${updatedState.currentHp} → $hp '
            '(${rolls.length}d$sides rolled: ${rolls.join(', ')})',
      ],
    );
  }

  factory RestPlan.forCharacter({
    required RestType type,
    required Character character,
    required CharacterState currentState,
  }) {
    final changes = <String>[];
    final resourceValues = {...currentState.resourceValues};

    for (final resource in character.resources) {
      if (!_recovers(resource.rechargePeriod, type)) {
        continue;
      }

      final currentValue = resourceValues[resource.id] ?? resource.initialValue;
      if (currentValue < resource.maximum) {
        changes.add('${resource.name}: $currentValue → ${resource.maximum}');
        resourceValues[resource.id] = resource.maximum;
      }
    }

    var currentHp = currentState.currentHp;
    var temporaryHp = currentState.temporaryHp;
    var deathSaveSuccesses = currentState.deathSaveSuccesses;
    var deathSaveFailures = currentState.deathSaveFailures;

    var hitDiceSpent = currentState.hitDiceSpent;
    if (type == RestType.longRest) {
      if (hitDiceSpent > 0) {
        changes.add('Recovered $hitDiceSpent Hit Dice');
        hitDiceSpent = 0;
      }
      if (currentHp < currentState.maxHp) {
        changes.add('Hit points: $currentHp → ${currentState.maxHp}');
        currentHp = currentState.maxHp;
      }
      if (temporaryHp > 0) {
        changes.add('Temporary hit points: $temporaryHp → 0');
        temporaryHp = 0;
      }
      if (deathSaveSuccesses > 0 || deathSaveFailures > 0) {
        changes.add('Death saves cleared');
        deathSaveSuccesses = 0;
        deathSaveFailures = 0;
      }
    }

    return RestPlan(
      type: type,
      updatedState: currentState.copyWith(
        currentHp: currentHp,
        hitDiceSpent: hitDiceSpent,
        temporaryHp: temporaryHp,
        deathSaveSuccesses: deathSaveSuccesses,
        deathSaveFailures: deathSaveFailures,
        resourceValues: resourceValues,
      ),
      changes: changes,
    );
  }

  static bool _recovers(RechargePeriod rechargePeriod, RestType restType) {
    return switch ((rechargePeriod, restType)) {
      (RechargePeriod.shortRest, _) => true,
      (RechargePeriod.longRest, RestType.longRest) => true,
      _ => false,
    };
  }
}
