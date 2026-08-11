import 'character_action.dart';

class Spell extends CharacterAction {
  @override
  final String id;

  @override
  final String name;

  final int level;
  final bool prepared;

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
