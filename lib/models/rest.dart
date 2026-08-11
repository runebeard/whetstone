import 'character.dart';
import 'character_resource.dart';
import 'character_state.dart';

enum RestType {
  shortRest('Short Rest'),
  longRest('Long Rest');

  final String label;

  const RestType(this.label);
}

class RestPlan {
  final RestType type;
  final CharacterState updatedState;
  final List<String> changes;

  const RestPlan({
    required this.type,
    required this.updatedState,
    required this.changes,
  });

  bool get hasChanges => changes.isNotEmpty;

  factory RestPlan.forCharacter({
    required RestType type,
    required Character character,
    required CharacterState currentState,
  }) {
    final changes = <String>[];
    final resourceValues = {...currentState.resourceValues};

    for (final resource in character.resources) {
      if (!_recovers(resource.rechargePeriod, type)) {
        continue;
      }

      final currentValue = resourceValues[resource.id] ?? resource.initialValue;
      if (currentValue < resource.maximum) {
        changes.add('${resource.name}: $currentValue → ${resource.maximum}');
        resourceValues[resource.id] = resource.maximum;
      }
    }

    var currentHp = currentState.currentHp;
    var temporaryHp = currentState.temporaryHp;
    var deathSaveSuccesses = currentState.deathSaveSuccesses;
    var deathSaveFailures = currentState.deathSaveFailures;

    if (type == RestType.longRest) {
      if (currentHp < currentState.maxHp) {
        changes.add('Hit points: $currentHp → ${currentState.maxHp}');
        currentHp = currentState.maxHp;
      }
      if (temporaryHp > 0) {
        changes.add('Temporary hit points: $temporaryHp → 0');
        temporaryHp = 0;
      }
      if (deathSaveSuccesses > 0 || deathSaveFailures > 0) {
        changes.add('Death saves cleared');
        deathSaveSuccesses = 0;
        deathSaveFailures = 0;
      }
    }

    return RestPlan(
      type: type,
      updatedState: currentState.copyWith(
        currentHp: currentHp,
        temporaryHp: temporaryHp,
        deathSaveSuccesses: deathSaveSuccesses,
        deathSaveFailures: deathSaveFailures,
        resourceValues: resourceValues,
      ),
      changes: changes,
    );
  }

  static bool _recovers(RechargePeriod rechargePeriod, RestType restType) {
    return switch ((rechargePeriod, restType)) {
      (RechargePeriod.shortRest, _) => true,
      (RechargePeriod.longRest, RestType.longRest) => true,
      _ => false,
    };
  }
}
