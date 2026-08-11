import 'character.dart';

class CharacterState {
  final int currentHp;
  final int maxHp;
  final int temporaryHp;
  final int armourClass;
  final int initiativeModifier;
  final int deathSaveSuccesses;
  final int deathSaveFailures;
  final Set<String> activeConditions;
  final Set<String> pinnedActionKeys;
  final Map<String, int> resourceValues;

  const CharacterState({
    required this.currentHp,
    required this.maxHp,
    required this.temporaryHp,
    required this.armourClass,
    required this.initiativeModifier,
    required this.deathSaveSuccesses,
    required this.deathSaveFailures,
    required this.activeConditions,
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
      'deathSaveSuccesses': deathSaveSuccesses,
      'deathSaveFailures': deathSaveFailures,
      'activeConditions': activeConditions.toList()..sort(),
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
      deathSaveSuccesses: json['deathSaveSuccesses'] as int,
      deathSaveFailures: json['deathSaveFailures'] as int,
      activeConditions: stringSet('activeConditions'),
      pinnedActionKeys: stringSet('pinnedActionKeys'),
      resourceValues: (json['resourceValues'] as Map<String, Object?>).map(
        (key, value) => MapEntry(key, value as int),
      ),
    );
  }

  CharacterState copyWith({
    int? currentHp,
    int? maxHp,
    int? temporaryHp,
    int? armourClass,
    int? initiativeModifier,
    int? deathSaveSuccesses,
    int? deathSaveFailures,
    Set<String>? activeConditions,
    Set<String>? pinnedActionKeys,
    Map<String, int>? resourceValues,
  }) {
    return CharacterState(
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      temporaryHp: temporaryHp ?? this.temporaryHp,
      armourClass: armourClass ?? this.armourClass,
      initiativeModifier: initiativeModifier ?? this.initiativeModifier,
      deathSaveSuccesses: deathSaveSuccesses ?? this.deathSaveSuccesses,
      deathSaveFailures: deathSaveFailures ?? this.deathSaveFailures,
      activeConditions: activeConditions ?? this.activeConditions,
      pinnedActionKeys: pinnedActionKeys ?? this.pinnedActionKeys,
      resourceValues: resourceValues ?? this.resourceValues,
    );
  }
}
