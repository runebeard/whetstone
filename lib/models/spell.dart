import 'ability.dart';
import 'character_action.dart';

class Spell extends CharacterAction {
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

  bool get isCantrip => level == 0;
  bool get isAvailableInCombat => isCantrip || prepared;

  String get levelLabel => isCantrip ? 'Cantrip' : 'Level $level';

  @override
  CharacterActionType get type => CharacterActionType.spell;
}
