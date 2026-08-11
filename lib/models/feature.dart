import 'character_action.dart';

class Feature extends CharacterAction {
  @override
  final String id;
  @override
  final String name;
  @override
  final String summary;

  @override
  final int? rollModifier;

  const Feature({
    required this.id,
    required this.name,
    required this.summary,
    this.rollModifier,
  });

  @override
  CharacterActionType get type => CharacterActionType.feature;
}
