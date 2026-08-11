import 'character_action.dart';

class Weapon extends CharacterAction {
  @override
  final String id;

  @override
  final String name;

  final int attackModifier;

  @override
  int get rollModifier => attackModifier;
  final String damage;

  @override
  final String? damageFormula;

  @override
  final String? damageType;

  final String? range;

  const Weapon({
    required this.id,
    required this.name,
    required this.attackModifier,
    required this.damage,
    this.damageFormula,
    this.damageType,
    this.range,
  });

  @override
  CharacterActionType get type => CharacterActionType.weapon;

  @override
  String get summary {
    final displayModifier = attackModifier > 0
        ? '+$attackModifier'
        : '$attackModifier';
    final displayRange = range == null ? '' : ' • $range';
    return '$displayModifier to hit • $damage$displayRange';
  }
}
