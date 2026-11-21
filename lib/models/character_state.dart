import 'character.dart';

const ragingCondition = 'Raging';
const dodgingCondition = 'Dodging';
const dashingCondition = 'Dashing';
const disengagingCondition = 'Disengaging';
const naturesSanctuaryCondition = 'Nature’s Sanctuary';
const freedomOfMovementCondition = 'Freedom of Movement';
const divineSenseCondition = 'Divine Sense';

enum IncomingDamageType {
  other('Other or unspecified'),
  bludgeoning('Bludgeoning'),
  piercing('Piercing'),
  slashing('Slashing'),
  fire('Fire'),
  cold('Cold'),
  lightning('Lightning'),
  poison('Poison');

  const IncomingDamageType(this.label);
  final String label;
}

enum DruidLand {
  arid('Arid', IncomingDamageType.fire),
  polar('Polar', IncomingDamageType.cold),
  temperate('Temperate', IncomingDamageType.lightning),
  tropical('Tropical', IncomingDamageType.poison);

  const DruidLand(this.label, this.resistance);
  final String label;
  final IncomingDamageType resistance;

  List<String> spellsAt(int level) {
    final names = switch (this) {
      arid => [
        'Blur',
        'Burning Hands',
        'Fire Bolt',
        'Fireball',
        'Blight',
        'Wall of Stone',
      ],
      polar => [
        'Fog Cloud',
        'Hold Person',
        'Ray of Frost',
        'Sleet Storm',
        'Ice Storm',
        'Cone of Cold',
      ],
      temperate => [
        'Misty Step',
        'Shocking Grasp',
        'Sleep',
        'Lightning Bolt',
        'Freedom of Movement',
        'Tree Stride',
      ],
      tropical => [
        'Acid Splash',
        'Ray of Sickness',
        'Web',
        'Stinking Cloud',
        'Polymorph',
        'Insect Plague',
      ],
    };
    return level < 3
        ? const []
        : names.take(3 + ((level - 3) ~/ 2).clamp(0, 3)).toList();
  }
}

class CharacterState {
  final int currentHp;
  final int maxHp;
  final int temporaryHp;
  final String? wildShapeForm;
  final int? wildShapeTurnsRemaining;
  final String? wildCompanion;
  final bool naturalRecoveryUsed;
  final bool naturalRecoveryCastUsed;
  final DruidLand? druidLand;
  final int armourClass;
  final int initiativeModifier;
  final int legacyHitDiceSpent;
  final Map<int, int> hitDiceSpentBySize;

  int get hitDiceSpent => hitDiceSpentBySize.values.fold(
    legacyHitDiceSpent,
    (total, count) => total + count,
  );
  final bool persistentRageRecoveryUsed;
  final int relentlessRageAttempts;
  final int rageTurnsElapsed;
  final String? concentrationSpellId;
  final Map<String, String> spellSummons;
  final int? concentrationSlotLevel;
  final String? concentrationTarget;
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
    this.wildShapeForm,
    this.wildShapeTurnsRemaining,
    this.wildCompanion,
    this.naturalRecoveryUsed = false,
    this.naturalRecoveryCastUsed = false,
    this.druidLand,
    required this.armourClass,
    required this.initiativeModifier,
    int hitDiceSpent = 0,
    this.hitDiceSpentBySize = const {},
    this.persistentRageRecoveryUsed = false,
    this.relentlessRageAttempts = 0,
    this.rageTurnsElapsed = 0,
    this.concentrationSpellId,
    this.spellSummons = const {},
    this.concentrationSlotLevel,
    this.concentrationTarget,
    this.concentrationTurnsRemaining,
    required this.deathSaveSuccesses,
    required this.deathSaveFailures,
    required this.activeConditions,
    this.conditionTurns = const {},
    required this.pinnedActionKeys,
    required this.resourceValues,
  }) : legacyHitDiceSpent = hitDiceSpent;

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
      'wildShapeForm': ?wildShapeForm,
      'wildShapeTurnsRemaining': ?wildShapeTurnsRemaining,
      'wildCompanion': ?wildCompanion,
      if (naturalRecoveryUsed) 'naturalRecoveryUsed': true,
      if (naturalRecoveryCastUsed) 'naturalRecoveryCastUsed': true,
      'druidLand': ?druidLand?.name,
      'armourClass': armourClass,
      'initiativeModifier': initiativeModifier,
      if (legacyHitDiceSpent > 0) 'hitDiceSpent': legacyHitDiceSpent,
      if (hitDiceSpentBySize.isNotEmpty)
        'hitDiceSpentBySize': hitDiceSpentBySize.map(
          (size, count) => MapEntry('$size', count),
        ),
      if (persistentRageRecoveryUsed) 'persistentRageRecoveryUsed': true,
      if (isRaging && rageTurnsElapsed > 0)
        'rageTurnsElapsed': rageTurnsElapsed,
      if (relentlessRageAttempts > 0)
        'relentlessRageAttempts': relentlessRageAttempts,
      'concentrationSpellId': ?concentrationSpellId,
      if (spellSummons.isNotEmpty) 'spellSummons': spellSummons,
      'concentrationSlotLevel': ?concentrationSlotLevel,
      'concentrationTarget': ?concentrationTarget,
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
      wildShapeForm: json['wildShapeForm'] as String?,
      wildShapeTurnsRemaining: json['wildShapeTurnsRemaining'] as int?,
      wildCompanion: json['wildCompanion'] as String?,
      naturalRecoveryUsed: json['naturalRecoveryUsed'] as bool? ?? false,
      naturalRecoveryCastUsed:
          json['naturalRecoveryCastUsed'] as bool? ?? false,
      druidLand: DruidLand.values
          .where((land) => land.name == json['druidLand'])
          .firstOrNull,
      armourClass: json['armourClass'] as int,
      initiativeModifier: json['initiativeModifier'] as int,
      hitDiceSpent: json['hitDiceSpent'] as int? ?? 0,
      hitDiceSpentBySize:
          (json['hitDiceSpentBySize'] as Map<String, Object?>?)?.map(
            (size, count) => MapEntry(int.parse(size), count as int),
          ) ??
          const {},
      persistentRageRecoveryUsed:
          json['persistentRageRecoveryUsed'] as bool? ?? false,
      relentlessRageAttempts: json['relentlessRageAttempts'] as int? ?? 0,
      rageTurnsElapsed: ((json['rageTurnsElapsed'] as int?) ?? 0).clamp(0, 100),
      concentrationSpellId: json['concentrationSpellId'] as String?,
      spellSummons:
          (json['spellSummons'] as Map<String, Object?>?)
              ?.cast<String, String>() ??
          const {},
      concentrationSlotLevel: json['concentrationSlotLevel'] as int?,
      concentrationTarget: json['concentrationTarget'] as String?,
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

  IncomingDamageType? landResistanceFor(Character character) =>
      character.subclasses['Druid'] == 'Circle of the Land' &&
          character.levelInClass('Druid') >= 10
      ? druidLand?.resistance
      : null;

  int damageAfterResistance(
    int amount,
    IncomingDamageType type, {
    IncomingDamageType? additionalResistance,
  }) =>
      type == additionalResistance ||
          (isRaging &&
              const {
                IncomingDamageType.bludgeoning,
                IncomingDamageType.piercing,
                IncomingDamageType.slashing,
              }.contains(type))
      ? amount ~/ 2
      : amount;

  bool get isRaging => activeConditions.contains(ragingCondition);

  CharacterState endRage() => !isRaging
      ? this
      : copyWith(
          activeConditions: {...activeConditions}..remove(ragingCondition),
        );

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
    if (conditionTurns.isEmpty && !isRaging) return this;
    final updated = copyWith(
      rageTurnsElapsed: isRaging ? rageTurnsElapsed + 1 : 0,
      activeConditions: {
        for (final condition in activeConditions)
          if (conditionTurns[condition] != 1) condition,
      },
      conditionTurns: {
        for (final entry in conditionTurns.entries)
          if (entry.value > 1) entry.key: entry.value - 1,
      },
    );
    return updated.isRaging && updated.rageTurnsElapsed >= 100
        ? updated.endRage()
        : updated;
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
    String? wildShapeForm,
    int? wildShapeTurnsRemaining,
    bool clearWildShape = false,
    String? wildCompanion,
    bool clearWildCompanion = false,
    bool? naturalRecoveryUsed,
    bool? naturalRecoveryCastUsed,
    DruidLand? druidLand,
    int? armourClass,
    int? initiativeModifier,
    int? hitDiceSpent,
    Map<int, int>? hitDiceSpentBySize,
    bool? persistentRageRecoveryUsed,
    int? relentlessRageAttempts,
    int? rageTurnsElapsed,
    String? concentrationSpellId,
    Map<String, String>? spellSummons,
    int? concentrationSlotLevel,
    String? concentrationTarget,
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
      wildShapeForm: clearWildShape
          ? null
          : wildShapeForm ?? this.wildShapeForm,
      wildShapeTurnsRemaining: clearWildShape
          ? null
          : wildShapeTurnsRemaining ?? this.wildShapeTurnsRemaining,
      wildCompanion: clearWildCompanion
          ? null
          : wildCompanion ?? this.wildCompanion,
      naturalRecoveryUsed: naturalRecoveryUsed ?? this.naturalRecoveryUsed,
      naturalRecoveryCastUsed:
          naturalRecoveryCastUsed ?? this.naturalRecoveryCastUsed,
      druidLand: druidLand ?? this.druidLand,
      armourClass: armourClass ?? this.armourClass,
      initiativeModifier: initiativeModifier ?? this.initiativeModifier,
      hitDiceSpent: hitDiceSpent ?? legacyHitDiceSpent,
      hitDiceSpentBySize: hitDiceSpentBySize ?? this.hitDiceSpentBySize,
      persistentRageRecoveryUsed:
          persistentRageRecoveryUsed ?? this.persistentRageRecoveryUsed,
      relentlessRageAttempts:
          relentlessRageAttempts ?? this.relentlessRageAttempts,
      rageTurnsElapsed:
          (activeConditions ?? this.activeConditions).contains(ragingCondition)
          ? (rageTurnsElapsed ?? this.rageTurnsElapsed)
          : 0,
      concentrationSpellId: clearConcentration
          ? null
          : concentrationSpellId ?? this.concentrationSpellId,
      spellSummons: {
        for (final entry in (spellSummons ?? this.spellSummons).entries)
          if (entry.key != this.concentrationSpellId ||
              (!clearConcentration &&
                  (concentrationSpellId == null ||
                      concentrationSpellId == this.concentrationSpellId)))
            entry.key: entry.value,
      },
      concentrationTurnsRemaining:
          clearConcentration || concentrationTurnsRemaining == 0
          ? null
          : concentrationTurnsRemaining ??
                (concentrationSpellId == null ||
                        concentrationSpellId == this.concentrationSpellId
                    ? this.concentrationTurnsRemaining
                    : null),
      concentrationTarget: clearConcentration || concentrationTarget == ''
          ? null
          : concentrationTarget ??
                (concentrationSpellId == null ||
                        concentrationSpellId == this.concentrationSpellId
                    ? this.concentrationTarget
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
