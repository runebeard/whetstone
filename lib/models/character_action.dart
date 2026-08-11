enum CharacterActionType { weapon, spell, feature, item }

abstract class CharacterAction {
  const CharacterAction();

  String get id;
  String get name;
  String get summary;
  CharacterActionType get type;
  int? get rollModifier => null;
  String? get damageFormula => null;
  String? get damageType => null;

  String get actionKey => '${type.name}:$id';
}
