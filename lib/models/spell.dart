import 'ability.dart';
import 'character_action.dart';

class Spell extends CharacterAction {
  static const circleGrantPrefix = 'whetstone:circle-spell:';
  bool get isCircleGrant => id.startsWith(circleGrantPrefix);
  static const draconicGrantPrefix = 'whetstone:draconic-spell:';
  bool get isDraconicGrant => id.startsWith(draconicGrantPrefix);
  bool get isClassGrant => isCircleGrant || isDraconicGrant;
  static String normalizedName(String name) =>
      name.trim().toLowerCase().replaceAll('’', "'");
  static const draconicGrants = {
    'alter self': (3, 2),
    'chromatic orb': (3, 1),
    'command': (3, 1),
    "dragon's breath": (3, 2),
    'fear': (5, 3),
    'fly': (5, 3),
    'arcane eye': (7, 4),
    'charm monster': (7, 4),
    'legend lore': (9, 5),
    'summon dragon': (9, 5),
  };

  bool get hasCostlyOrConsumedMaterial {
    final description = components;
    if (description == null) return false;
    final material = description.replaceAll(
      RegExp(
        r'\b(?:(?:is|are|do|does)\s+)?not\s+(?:consume|consumed)\b'
        r'|\b(?:doesn.t|isn.t|aren.t|don.t)\s+(?:consume|consumed)\b',
        caseSensitive: false,
      ),
      '',
    );
    return RegExp(
      r'\b\d[\d,]*(?:\.\d+)?\s*(?:[csegp]p|(?:copper|silver|electrum|gold|platinum) pieces?)\b'
      r'|\b(?:consumes?|consumed|consuming)\b',
      caseSensitive: false,
    ).hasMatch(material);
  }

  @override
  final String id;

  @override
  final String name;

  final int level;
  final bool prepared;
  final bool concentration;
  final bool repeatableEffect;
  final bool rollEffectOnCast;
  final bool ritual;
  final Ability? castingAbility;
  final bool deriveAttackModifier;
  final bool scaleCantripDamage;
  final int additionalDicePerSlotLevel;
  final bool addCastingModifierToDamage;
  final Ability? savingThrowAbility;
  final bool halfDamageOnSave;
  final String? castingTime;
  final String? range;
  final String? duration;
  final String? components;

  @override
  final int? rollModifier;

  @override
  final String? damageFormula;

  @override
  final String? damageType;

  @override
  final String summary;

  const Spell({
    required this.id,
    required this.name,
    required this.level,
    required this.prepared,
    this.concentration = false,
    this.repeatableEffect = false,
    this.rollEffectOnCast = false,
    this.ritual = false,
    this.castingAbility,
    this.deriveAttackModifier = false,
    this.scaleCantripDamage = false,
    this.additionalDicePerSlotLevel = 0,
    this.addCastingModifierToDamage = false,
    this.savingThrowAbility,
    this.halfDamageOnSave = false,
    this.castingTime,
    this.range,
    this.duration,
    this.components,
    required this.summary,
    this.rollModifier,
    this.damageFormula,
    this.damageType,
  });

  bool get canMoveConcentrationTarget =>
      concentration &&
      switch (name.trim().toLowerCase().replaceAll('’', "'")) {
        'hex' || "hunter's mark" => true,
        _ => false,
      };

  bool get isCantrip => level == 0;
  Spell withPrepared(bool value) => Spell(
    id: id,
    name: name,
    level: level,
    prepared: value,
    summary: summary,
    concentration: concentration,
    repeatableEffect: repeatableEffect,
    rollEffectOnCast: rollEffectOnCast,
    ritual: ritual,
    castingAbility: castingAbility,
    deriveAttackModifier: deriveAttackModifier,
    scaleCantripDamage: scaleCantripDamage,
    additionalDicePerSlotLevel: additionalDicePerSlotLevel,
    addCastingModifierToDamage: addCastingModifierToDamage,
    savingThrowAbility: savingThrowAbility,
    halfDamageOnSave: halfDamageOnSave,
    castingTime: castingTime,
    range: range,
    duration: duration,
    components: components,
    rollModifier: rollModifier,
    damageFormula: damageFormula,
    damageType: damageType,
  );
  bool get isAvailableInCombat => isCantrip || prepared;

  String get levelLabel => isCantrip ? 'Cantrip' : 'Level $level';

  int get scrollSaveDc => switch (level) {
    <= 2 => 13,
    <= 4 => 15,
    <= 6 => 17,
    <= 8 => 18,
    _ => 19,
  };

  int get scrollAttackBonus => scrollSaveDc - 8;

  @override
  CharacterActionType get type => CharacterActionType.spell;
}
