import 'character.dart';

class CharacterState {
  final int currentHp;
  final int maxHp;
  final int temporaryHp;
  final int armourClass;
  final int initiativeModifier;
  final int hitDiceSpent;
  final String? concentrationSpellId;
  final int? concentrationSlotLevel;
  final int? concentrationTurnsRemaining;
  final int deathSaveSuccesses;
  final int deathSaveFailures;
  final Set<String> activeConditions;
  final Map<String, int> conditionTurns;
  final Set<String> pinnedActionKeys;
  final Map<String, int> resourceValues;

  const CharacterState({
    required this.currentHp,
    required this.maxHp,
    required this.temporaryHp,
    required this.armourClass,
    required this.initiativeModifier,
    this.hitDiceSpent = 0,
    this.concentrationSpellId,
    this.concentrationSlotLevel,
    this.concentrationTurnsRemaining,
    required this.deathSaveSuccesses,
    required this.deathSaveFailures,
    required this.activeConditions,
    this.conditionTurns = const {},
    required this.pinnedActionKeys,
    required this.resourceValues,
  });

  factory CharacterState.fromCharacter(Character character) {
    return CharacterState(
      currentHp: character.currentHp,
      maxHp: character.maxHp,
      temporaryHp: 0,
      armourClass: character.armourClass,
      initiativeModifier: character.initiativeModifier,
      deathSaveSuccesses: 0,
      deathSaveFailures: 0,
      activeConditions: const {},
      pinnedActionKeys: {...character.initiallyPinnedActionKeys},
      resourceValues: {
        for (final resource in character.resources)
          resource.id: resource.initialValue,
      },
    );
  }

  Map<String, Object> toJson() {
    return {
      'currentHp': currentHp,
      'maxHp': maxHp,
      'temporaryHp': temporaryHp,
      'armourClass': armourClass,
      'initiativeModifier': initiativeModifier,
      if (hitDiceSpent > 0) 'hitDiceSpent': hitDiceSpent,
      'concentrationSpellId': ?concentrationSpellId,
      'concentrationSlotLevel': ?concentrationSlotLevel,
      'concentrationTurnsRemaining': ?concentrationTurnsRemaining,
      'deathSaveSuccesses': deathSaveSuccesses,
      'deathSaveFailures': deathSaveFailures,
      'activeConditions': activeConditions.toList()..sort(),
      if (conditionTurns.isNotEmpty) 'conditionTurns': conditionTurns,
      'pinnedActionKeys': pinnedActionKeys.toList()..sort(),
      'resourceValues': resourceValues,
    };
  }

  factory CharacterState.fromJson(Map<String, Object?> json) {
    Set<String> stringSet(String key) {
      return (json[key] as List<Object?>).cast<String>().toSet();
    }

    return CharacterState(
      currentHp: json['currentHp'] as int,
      maxHp: json['maxHp'] as int,
      temporaryHp: json['temporaryHp'] as int,
      armourClass: json['armourClass'] as int,
      initiativeModifier: json['initiativeModifier'] as int,
      hitDiceSpent: json['hitDiceSpent'] as int? ?? 0,
      concentrationSpellId: json['concentrationSpellId'] as String?,
      concentrationSlotLevel: json['concentrationSlotLevel'] as int?,
      concentrationTurnsRemaining: json['concentrationTurnsRemaining'] as int?,
      deathSaveSuccesses: json['deathSaveSuccesses'] as int,
      deathSaveFailures: json['deathSaveFailures'] as int,
      activeConditions: stringSet('activeConditions'),
      conditionTurns:
          ((json['conditionTurns'] as Map<String, Object?>?) ??
                  const <String, Object?>{})
              .cast<String, int>(),
      pinnedActionKeys: stringSet('pinnedActionKeys'),
      resourceValues: (json['resourceValues'] as Map<String, Object?>).map(
        (key, value) => MapEntry(key, value as int),
      ),
    );
  }

  CharacterState takeDamage(int damage, {bool critical = false}) {
    if (damage <= 0) return this;
    final absorbed = damage.clamp(0, temporaryHp).toInt();
    final remaining = damage - absorbed;
    final failedSave = currentHp == 0 && remaining > 0 && deathSaveFailures < 3;
    return copyWith(
      temporaryHp: temporaryHp - absorbed,
      clearConcentration: currentHp <= remaining,
      currentHp: (currentHp - remaining).clamp(0, maxHp).toInt(),
      deathSaveSuccesses: failedSave && deathSaveSuccesses == 3
          ? 0
          : deathSaveSuccesses,
      deathSaveFailures: failedSave
          ? (deathSaveFailures + (critical ? 2 : 1)).clamp(0, 3).toInt()
          : deathSaveFailures,
    );
  }

  bool get canConcentrate =>
      currentHp > 0 &&
      !activeConditions.any(
        const {
          'Incapacitated',
          'Paralyzed',
          'Petrified',
          'Stunned',
          'Unconscious',
        }.contains,
      );

  bool get canRollDeathSave =>
      currentHp == 0 && deathSaveSuccesses < 3 && deathSaveFailures < 3;

  CharacterState applyDeathSave(int roll) {
    if (!canRollDeathSave || roll < 1 || roll > 20) return this;
    return switch (roll) {
      20 => copyWith(currentHp: 1, deathSaveSuccesses: 0, deathSaveFailures: 0),
      >= 10 => copyWith(deathSaveSuccesses: deathSaveSuccesses + 1),
      1 => copyWith(
        deathSaveFailures: (deathSaveFailures + 2).clamp(0, 3).toInt(),
      ),
      _ => copyWith(deathSaveFailures: deathSaveFailures + 1),
    };
  }

  CharacterState advanceConditionTurn() {
    if (conditionTurns.isEmpty) return this;
    return copyWith(
      activeConditions: {
        for (final condition in activeConditions)
          if (conditionTurns[condition] != 1) condition,
      },
      conditionTurns: {
        for (final entry in conditionTurns.entries)
          if (entry.value > 1) entry.key: entry.value - 1,
      },
    );
  }

  CharacterState advanceConcentrationTurn() {
    final remaining = concentrationTurnsRemaining;
    if (concentrationSpellId == null || remaining == null) return this;
    return remaining <= 1
        ? copyWith(clearConcentration: true)
        : copyWith(concentrationTurnsRemaining: remaining - 1);
  }

  CharacterState copyWith({
    int? currentHp,
    int? maxHp,
    int? temporaryHp,
    int? armourClass,
    int? initiativeModifier,
    int? hitDiceSpent,
    String? concentrationSpellId,
    int? concentrationSlotLevel,
    int? concentrationTurnsRemaining,
    bool clearConcentration = false,
    int? deathSaveSuccesses,
    int? deathSaveFailures,
    Set<String>? activeConditions,
    Map<String, int>? conditionTurns,
    Set<String>? pinnedActionKeys,
    Map<String, int>? resourceValues,
  }) {
    return CharacterState(
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      temporaryHp: temporaryHp ?? this.temporaryHp,
      armourClass: armourClass ?? this.armourClass,
      initiativeModifier: initiativeModifier ?? this.initiativeModifier,
      hitDiceSpent: hitDiceSpent ?? this.hitDiceSpent,
      concentrationSpellId: clearConcentration
          ? null
          : concentrationSpellId ?? this.concentrationSpellId,
      concentrationTurnsRemaining:
          clearConcentration || concentrationTurnsRemaining == 0
          ? null
          : concentrationTurnsRemaining ??
                (concentrationSpellId == null ||
                        concentrationSpellId == this.concentrationSpellId
                    ? this.concentrationTurnsRemaining
                    : null),
      concentrationSlotLevel: clearConcentration
          ? null
          : concentrationSlotLevel ??
                (concentrationSpellId == null ||
                        concentrationSpellId == this.concentrationSpellId
                    ? this.concentrationSlotLevel
                    : null),
      deathSaveSuccesses: deathSaveSuccesses ?? this.deathSaveSuccesses,
      deathSaveFailures: deathSaveFailures ?? this.deathSaveFailures,
      activeConditions: activeConditions ?? this.activeConditions,
      conditionTurns: {
        for (final entry in (conditionTurns ?? this.conditionTurns).entries)
          if ((activeConditions ?? this.activeConditions).contains(entry.key) &&
              entry.value > 0)
            entry.key: entry.value,
      },
      pinnedActionKeys: pinnedActionKeys ?? this.pinnedActionKeys,
      resourceValues: resourceValues ?? this.resourceValues,
    );
  }
}
