import 'character.dart';
import 'built_in_class.dart';
import 'metamagic.dart';

const ragingCondition = 'Raging';
const recklessAttackCondition = 'Reckless Attack';
const dodgingCondition = 'Dodging';
const dashingCondition = 'Dashing';
const disengagingCondition = 'Disengaging';
const naturesSanctuaryCondition = 'Nature’s Sanctuary';
const freedomOfMovementCondition = 'Freedom of Movement';
const divineSenseCondition = 'Divine Sense';
const deathWardCondition = 'Death Ward';
const steadyAimCondition = 'Steady Aim';
const superiorDefenseCondition = 'Superior Defense';
const innateSorceryCondition = 'Innate Sorcery';
const dragonWingsCondition = 'Dragon Wings';
const dragonCompanionCondition = 'Dragon Companion';

enum IncomingDamageType {
  other('Other or unspecified'),
  bludgeoning('Bludgeoning'),
  piercing('Piercing'),
  slashing('Slashing'),
  fire('Fire'),
  cold('Cold'),
  lightning('Lightning'),
  poison('Poison'),
  acid('Acid'),
  force('Force'),
  necrotic('Necrotic'),
  psychic('Psychic'),
  radiant('Radiant'),
  thunder('Thunder');

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
  final int exhaustionLevel;
  final int divineInterventionRestsRemaining;
  int get exhaustionPenalty => 2 * exhaustionLevel;
  int get exhaustionSpeedReduction => 5 * exhaustionLevel;
  final String? wildShapeForm;
  final int? wildShapeTurnsRemaining;
  final String? wildCompanion;
  final bool naturalRecoveryUsed;
  final bool memorizeSpellAvailable;
  final IncomingDamageType? fiendishResistance;
  final bool fiendishResilienceAvailable;
  final String? dragonCompanionSpellId;
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
  final Map<String, String> spellDamageTypes;
  final Map<String, SpellSaveEffect> spellSaveEffects;
  final int? concentrationSlotLevel;
  final String? concentrationTarget;
  final int? concentrationTurnsRemaining;
  final bool extendedConcentration;
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
    this.exhaustionLevel = 0,
    this.divineInterventionRestsRemaining = 0,
    this.wildShapeForm,
    this.wildShapeTurnsRemaining,
    this.wildCompanion,
    this.naturalRecoveryUsed = false,
    this.memorizeSpellAvailable = false,
    this.fiendishResistance,
    this.fiendishResilienceAvailable = false,
    this.dragonCompanionSpellId,
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
    this.spellDamageTypes = const {},
    this.spellSaveEffects = const {},
    this.concentrationSlotLevel,
    this.concentrationTarget,
    this.concentrationTurnsRemaining,
    this.extendedConcentration = false,
    required this.deathSaveSuccesses,
    required this.deathSaveFailures,
    required this.activeConditions,
    this.conditionTurns = const {},
    required this.pinnedActionKeys,
    required this.resourceValues,
  }) : assert(exhaustionLevel >= 0 && exhaustionLevel <= 6),
       assert(
         divineInterventionRestsRemaining >= 0 &&
             divineInterventionRestsRemaining <= 8,
       ),
       legacyHitDiceSpent = hitDiceSpent;

  factory CharacterState.fromCharacter(Character character) {
    return CharacterState(
      currentHp: character.currentHp,
      maxHp: character.maxHp,
      temporaryHp: 0,
      fiendishResilienceAvailable: character.hasFiendishResilience,
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
      if (exhaustionLevel > 0) 'exhaustionLevel': exhaustionLevel,
      if (divineInterventionRestsRemaining > 0)
        'divineInterventionRestsRemaining': divineInterventionRestsRemaining,
      'fiendishResistance': ?fiendishResistance?.name,
      if (fiendishResilienceAvailable) 'fiendishResilienceAvailable': true,
      'dragonCompanionSpellId': ?dragonCompanionSpellId,
      'wildShapeForm': ?wildShapeForm,
      'wildShapeTurnsRemaining': ?wildShapeTurnsRemaining,
      'wildCompanion': ?wildCompanion,
      if (naturalRecoveryUsed) 'naturalRecoveryUsed': true,
      if (memorizeSpellAvailable) 'memorizeSpellAvailable': true,
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
      if (concentrationSpellId != null && extendedConcentration)
        'extendedConcentration': true,
      if (spellSummons.isNotEmpty) 'spellSummons': spellSummons,
      if (spellDamageTypes.isNotEmpty) 'spellDamageTypes': spellDamageTypes,
      if (spellSaveEffects.isNotEmpty)
        'spellSaveEffects': spellSaveEffects.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
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
      exhaustionLevel: (json['exhaustionLevel'] as int? ?? 0).clamp(0, 6),
      divineInterventionRestsRemaining:
          (json['divineInterventionRestsRemaining'] as int? ?? 0).clamp(0, 8),
      fiendishResistance: IncomingDamageType.values
          .where(
            (type) =>
                type.name == json['fiendishResistance'] &&
                type != IncomingDamageType.force &&
                type != IncomingDamageType.other,
          )
          .firstOrNull,
      fiendishResilienceAvailable:
          json['fiendishResilienceAvailable'] as bool? ?? false,
      dragonCompanionSpellId: json['dragonCompanionSpellId'] as String?,
      wildShapeForm: json['wildShapeForm'] as String?,
      wildShapeTurnsRemaining: json['wildShapeTurnsRemaining'] as int?,
      wildCompanion: json['wildCompanion'] as String?,
      naturalRecoveryUsed: json['naturalRecoveryUsed'] as bool? ?? false,
      memorizeSpellAvailable: json['memorizeSpellAvailable'] as bool? ?? false,
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
      spellSaveEffects: {
        for (final entry
            in (json['spellSaveEffects'] as Map<String, Object?>? ?? const {})
                .entries)
          entry.key: ?SpellSaveEffect.fromJson(entry.value),
      },
      spellDamageTypes: {
        for (final entry
            in (json['spellDamageTypes'] as Map<String, Object?>? ?? const {})
                .entries)
          entry.key: ?Metamagic.transmutedType(
            entry.value is String ? entry.value as String : null,
          ),
      },
      extendedConcentration:
          json['concentrationSpellId'] != null &&
          (json['extendedConcentration'] as bool? ?? false),
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
      resourceValues: {
        ...(json['resourceValues'] as Map<String, Object?>).map(
          (key, value) => MapEntry(key, value as int),
        ),
        if ((json['divineInterventionRestsRemaining'] as int? ?? 0) > 0)
          divineInterventionResourceId: 0,
      },
    );
  }

  CharacterState takeDamage(int damage, {bool critical = false}) {
    if (damage <= 0) return this;
    final absorbed = damage.clamp(0, temporaryHp).toInt();
    final remaining = damage - absorbed;
    final warded =
        currentHp > 0 &&
        remaining >= currentHp &&
        activeConditions.contains(deathWardCondition);
    final failedSave = currentHp == 0 && remaining > 0 && deathSaveFailures < 3;
    return copyWith(
      temporaryHp: temporaryHp - absorbed,
      clearConcentration: !warded && currentHp <= remaining,
      currentHp: warded ? 1 : (currentHp - remaining).clamp(0, maxHp).toInt(),
      activeConditions: warded
          ? ({...activeConditions}..remove(deathWardCondition))
          : null,
      conditionTurns: warded
          ? ({...conditionTurns}..remove(deathWardCondition))
          : null,
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

  Set<IncomingDamageType> classResistancesFor(Character character) => {
    ?landResistanceFor(character),
    if (character.hasElementalAffinity && character.elementalAffinity != null)
      IncomingDamageType.values.byName(character.elementalAffinity!.name),
  };

  int damageAfterResistance(
    int amount,
    IncomingDamageType type, {
    IncomingDamageType? additionalResistance,
    Set<IncomingDamageType> additionalResistances = const {},
  }) =>
      type == additionalResistance ||
          additionalResistances.contains(type) ||
          (fiendishResistance != null &&
              fiendishResistance != IncomingDamageType.force &&
              fiendishResistance != IncomingDamageType.other &&
              type == fiendishResistance) ||
          (canConcentrate &&
              activeConditions.contains(superiorDefenseCondition) &&
              type != IncomingDamageType.force &&
              type != IncomingDamageType.other) ||
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
      exhaustionLevel < 6 &&
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
      currentHp == 0 &&
      exhaustionLevel < 6 &&
      deathSaveSuccesses < 3 &&
      deathSaveFailures < 3;

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

  CharacterState normalizeSpellDamageTypes(Character character) =>
      spellDamageTypes.isEmpty && spellSaveEffects.isEmpty
      ? this
      : copyWith(
          spellSaveEffects: {
            for (final spell in character.spells)
              if (spell.savingThrowAbility != null)
                spell.id: ?spellSaveEffects[spell.id],
          },
          spellDamageTypes: {
            for (final spell in character.spells)
              if (Metamagic.transmutedType(spell.damageType) != null)
                spell.id: ?Metamagic.transmutedType(spellDamageTypes[spell.id]),
          },
        );

  CharacterState endDragonCompanion() => copyWith(
    clearDragonCompanion: true,
    activeConditions: {...activeConditions}..remove(dragonCompanionCondition),
    spellSummons: {...spellSummons}..remove(dragonCompanionSpellId),
  );

  CharacterState normalizeDragonCompanion(Character character) =>
      !character.hasDragonCompanion ||
          !activeConditions.contains(dragonCompanionCondition)
      ? endDragonCompanion()
      : this;

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
    IncomingDamageType? fiendishResistance,
    bool clearFiendishResistance = false,
    bool? fiendishResilienceAvailable,
    String? dragonCompanionSpellId,
    bool clearDragonCompanion = false,
    int? currentHp,
    int? maxHp,
    int? temporaryHp,
    int? exhaustionLevel,
    int? divineInterventionRestsRemaining,
    String? wildShapeForm,
    int? wildShapeTurnsRemaining,
    bool clearWildShape = false,
    String? wildCompanion,
    bool clearWildCompanion = false,
    bool? naturalRecoveryUsed,
    bool? memorizeSpellAvailable,
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
    Map<String, String>? spellDamageTypes,
    Map<String, SpellSaveEffect>? spellSaveEffects,
    int? concentrationSlotLevel,
    String? concentrationTarget,
    int? concentrationTurnsRemaining,
    bool? extendedConcentration,
    bool clearConcentration = false,
    int? deathSaveSuccesses,
    int? deathSaveFailures,
    Set<String>? activeConditions,
    Map<String, int>? conditionTurns,
    Set<String>? pinnedActionKeys,
    Map<String, int>? resourceValues,
  }) {
    final interventionRests =
        (divineInterventionRestsRemaining ??
                this.divineInterventionRestsRemaining)
            .clamp(0, 8);
    return CharacterState(
      fiendishResistance: clearFiendishResistance
          ? null
          : fiendishResistance ?? this.fiendishResistance,
      fiendishResilienceAvailable:
          fiendishResilienceAvailable ?? this.fiendishResilienceAvailable,
      dragonCompanionSpellId: clearDragonCompanion
          ? null
          : dragonCompanionSpellId ?? this.dragonCompanionSpellId,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      temporaryHp: temporaryHp ?? this.temporaryHp,
      exhaustionLevel: (exhaustionLevel ?? this.exhaustionLevel).clamp(0, 6),
      divineInterventionRestsRemaining: interventionRests,
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
      memorizeSpellAvailable:
          memorizeSpellAvailable ?? this.memorizeSpellAvailable,
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
      spellDamageTypes: spellDamageTypes ?? this.spellDamageTypes,
      spellSaveEffects: spellSaveEffects ?? this.spellSaveEffects,
      extendedConcentration:
          clearConcentration ||
              (concentrationSpellId ?? this.concentrationSpellId) == null
          ? false
          : extendedConcentration ??
                (concentrationSpellId == null ||
                        concentrationSpellId == this.concentrationSpellId
                    ? this.extendedConcentration
                    : false),
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
      resourceValues: {
        ...(resourceValues ?? this.resourceValues),
        if (interventionRests > 0) divineInterventionResourceId: 0,
      },
    );
  }
}
