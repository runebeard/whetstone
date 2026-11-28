import 'ability.dart';
import 'built_in_class.dart';
import 'character.dart';
import 'check_roll.dart';
import 'character_resource.dart';
import 'character_state.dart';
import 'spell_slots.dart';

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

  int sorcerousRestorationAmount(Character character) {
    final level = character.levelInClass('Sorcerer');
    if (type != RestType.shortRest || level < 5) return 0;
    final points = character.resources
        .where((r) => r.id == sorceryPointsResourceId)
        .firstOrNull;
    final use = character.resources
        .where((r) => r.id == sorcerousRestorationResourceId)
        .firstOrNull;
    if (points == null ||
        use == null ||
        (updatedState.resourceValues[use.id] ?? use.initialValue) < 1) {
      return 0;
    }
    final current =
        updatedState.resourceValues[points.id] ?? points.initialValue;
    return (points.maximum - current).clamp(0, level ~/ 2);
  }

  RestPlan recoverSorceryPoints(Character character) {
    final amount = sorcerousRestorationAmount(character);
    if (amount == 0) return this;
    final points = character.resources.singleWhere(
      (r) => r.id == sorceryPointsResourceId,
    );
    final use = character.resources.singleWhere(
      (r) => r.id == sorcerousRestorationResourceId,
    );
    final current =
        updatedState.resourceValues[points.id] ?? points.initialValue;
    return RestPlan(
      type: type,
      updatedState: updatedState.copyWith(
        resourceValues: {
          ...updatedState.resourceValues,
          points.id: current + amount,
          use.id: (updatedState.resourceValues[use.id] ?? use.initialValue) - 1,
        },
      ),
      changes: [
        ...changes,
        'Sorcerous Restoration: $current → ${current + amount} Sorcery Points · One use spent',
      ],
    );
  }

  static int hitDieFor(Character character) =>
      BuiltInClass.named(character.characterClass)?.hitDie ?? 8;

  static int availableHitDice(Character character, CharacterState state) =>
      availableHitDiceBySize(character, state).values.fold(0, (a, b) => a + b);

  static Map<int, int> availableHitDiceBySize(
    Character character,
    CharacterState state,
  ) {
    final primaryDie = hitDieFor(character);
    final totals = <int, int>{primaryDie: character.level};
    for (final entry in character.additionalClassLevels.entries) {
      final extra = BuiltInClass.named(entry.key);
      if (extra == null || entry.value <= 0) continue;
      totals.update(primaryDie, (count) => count - entry.value);
      totals.update(
        extra.hitDie,
        (count) => count + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    return {
      for (final entry in totals.entries)
        entry.key:
            (entry.value -
                    (state.hitDiceSpentBySize[entry.key] ?? 0) -
                    (entry.key == primaryDie ? state.legacyHitDiceSpent : 0))
                .clamp(0, entry.value < 0 ? 0 : entry.value),
    };
  }

  RestPlan spendHitDice({
    required Character character,
    int count = 0,
    Map<int, int>? countsBySize,
    required DiceRoller roller,
  }) {
    if (type != RestType.shortRest ||
        updatedState.currentHp <= 0 ||
        updatedState.currentHp >= updatedState.maxHp) {
      return this;
    }
    final constitution = character.abilityModifierFor(Ability.constitution);
    final primaryDie = hitDieFor(character);
    final requested = countsBySize ?? {primaryDie: count};
    final available = availableHitDiceBySize(character, updatedState);
    final spent = {...updatedState.hitDiceSpentBySize};
    var hp = updatedState.currentHp;
    final descriptions = <String>[];
    for (final entry in requested.entries) {
      final sides = entry.key;
      final limit = entry.value.clamp(0, available[sides] ?? 0);
      final rolls = <int>[];
      while (rolls.length < limit && hp < updatedState.maxHp) {
        final roll = roller.rollDie(sides);
        rolls.add(roll);
        hp += (roll + constitution).clamp(0, updatedState.maxHp - hp);
      }
      if (rolls.isEmpty) continue;
      spent.update(
        sides,
        (count) => count + rolls.length,
        ifAbsent: () => rolls.length,
      );
      descriptions.add('${rolls.length}d$sides rolled: ${rolls.join(', ')}');
    }
    if (descriptions.isEmpty) return this;
    if (updatedState.legacyHitDiceSpent > 0) {
      final legacy = updatedState.legacyHitDiceSpent;
      spent.update(
        primaryDie,
        (count) => count + legacy,
        ifAbsent: () => legacy,
      );
    }
    return RestPlan(
      type: type,
      updatedState: updatedState.copyWith(
        currentHp: hp,
        hitDiceSpent: 0,
        hitDiceSpentBySize: spent,
      ),
      changes: [
        ...changes,
        'Hit points: ${updatedState.currentHp} → $hp '
            '(${descriptions.join(' · ')})',
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
    final restConditions = {...currentState.activeConditions}
      ..removeAll({
        divineSenseCondition,
        ragingCondition,
        recklessAttackCondition,
        steadyAimCondition,
        superiorDefenseCondition,
        innateSorceryCondition,
        dragonWingsCondition,
        dragonCompanionCondition,
      });
    final wardTurns = currentState.conditionTurns[deathWardCondition];
    final wardRemaining = wardTurns == null
        ? null
        : wardTurns - (type == RestType.shortRest ? 600 : 4800);
    if ((wardRemaining != null && wardRemaining <= 0) ||
        (wardTurns == null && type == RestType.longRest)) {
      restConditions.remove(deathWardCondition);
    }
    final ended = currentState.activeConditions.difference(restConditions);
    if (ended.isNotEmpty) changes.add('Ended ${ended.join(', ')}');

    for (final resource in character.resources) {
      final currentValue = resourceValues[resource.id] ?? resource.initialValue;
      final int recovered;
      if (_recovers(resource.rechargePeriod, type)) {
        recovered = resource.maximum;
      } else if (type == RestType.shortRest &&
          (resource.id == rageResourceId ||
              resource.id == wildShapeResourceId ||
              resource.id == secondWindResourceId ||
              resource.id == clericChannelDivinityId ||
              resource.id == paladinChannelDivinityId)) {
        recovered = (currentValue + 1).clamp(0, resource.maximum);
      } else {
        continue;
      }
      if (currentValue < recovered) {
        changes.add('${resource.name}: $currentValue → $recovered');
        resourceValues[resource.id] = recovered;
      }
    }

    var currentHp = currentState.currentHp;
    var temporaryHp = currentState.temporaryHp;
    var deathSaveSuccesses = currentState.deathSaveSuccesses;
    var deathSaveFailures = currentState.deathSaveFailures;

    final hitDiceSpent = currentState.hitDiceSpent;
    if (currentState.relentlessRageAttempts > 0) {
      changes.add('Relentless Rage save DC reset to 10');
    }
    if (type == RestType.longRest) {
      for (var level = 1; level <= 5; level++) {
        final removed = resourceValues.remove(fontOfMagicSlotId(level));
        if (removed != null && removed > 0) {
          changes.add(
            'Font of Magic: $removed created level $level slots expired',
          );
        }
      }
      if (currentState.naturalRecoveryUsed) {
        changes.add('Natural Recovery restored');
      }
      if (currentState.naturalRecoveryCastUsed) {
        changes.add('Natural Recovery free cast restored');
      }
      if (resourceValues.remove(wildResurgenceSlot.id) != null) {
        changes.add('Wild Resurgence slot creation restored');
      }
      for (final slot in natureMagicianSlots) {
        if (resourceValues.remove(slot.id) != null) {
          changes.add('Nature Magician restored');
        }
      }
      if (currentState.wildShapeForm != null) changes.add('Wild Shape ended');
      if (currentState.wildCompanion != null) {
        changes.add('Wild Companion dismissed');
      }
      if (currentState.persistentRageRecoveryUsed) {
        changes.add('Persistent Rage recovery restored');
      }
      if (hitDiceSpent > 0) {
        changes.add('Recovered $hitDiceSpent Hit Dice');
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

    if (type == RestType.shortRest && character.levelInClass('Wizard') >= 5) {
      changes.add('Memorize Spell available');
    }
    if (character.hasFiendishResilience) {
      changes.add('Fiendish Resilience choice available');
    }
    return RestPlan(
      type: type,
      updatedState: currentState.endDragonCompanion().copyWith(
        fiendishResilienceAvailable: character.hasFiendishResilience,
        clearFiendishResistance: !character.hasFiendishResilience,
        memorizeSpellAvailable:
            type == RestType.shortRest && character.levelInClass('Wizard') >= 5,
        activeConditions: restConditions,
        conditionTurns: {
          ...currentState.conditionTurns,
          if (wardRemaining != null && wardRemaining > 0)
            deathWardCondition: wardRemaining,
        },
        currentHp: currentHp,
        hitDiceSpent: type == RestType.longRest
            ? 0
            : currentState.legacyHitDiceSpent,
        hitDiceSpentBySize: type == RestType.longRest
            ? const {}
            : currentState.hitDiceSpentBySize,
        relentlessRageAttempts: 0,
        persistentRageRecoveryUsed:
            type == RestType.shortRest &&
            currentState.persistentRageRecoveryUsed,
        temporaryHp: temporaryHp,
        clearWildShape: type == RestType.longRest,
        clearWildCompanion: type == RestType.longRest,
        naturalRecoveryUsed:
            type == RestType.shortRest && currentState.naturalRecoveryUsed,
        naturalRecoveryCastUsed:
            type == RestType.shortRest && currentState.naturalRecoveryCastUsed,
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
