import '../models/character_resource.dart';
import '../models/character_state.dart';
import '../models/session_event.dart';

class SessionEventRecorder {
  int _nextId = 0;

  SessionEvent create(SessionEventType type, String title, {String? detail}) {
    final occurredAt = DateTime.now();
    return SessionEvent(
      id: '${occurredAt.microsecondsSinceEpoch}-${_nextId++}',
      occurredAt: occurredAt,
      type: type,
      title: title,
      detail: detail,
    );
  }

  List<SessionEvent> stateChanges({
    required CharacterState previous,
    required CharacterState updated,
    required Iterable<CharacterResource> resources,
  }) {
    final events = <SessionEvent>[];
    if (updated.divineInterventionRestsRemaining !=
        previous.divineInterventionRestsRemaining) {
      events.add(
        create(
          SessionEventType.resource,
          updated.divineInterventionRestsRemaining > 0
              ? 'Divine Intervention: ${updated.divineInterventionRestsRemaining} Long Rests remaining'
              : 'Divine Intervention cooldown ended',
          detail:
              '${previous.divineInterventionRestsRemaining} → ${updated.divineInterventionRestsRemaining} Long Rests remaining',
        ),
      );
    }
    if (updated.exhaustionLevel != previous.exhaustionLevel) {
      events.add(
        create(
          SessionEventType.condition,
          'Exhaustion: ${previous.exhaustionLevel} → ${updated.exhaustionLevel}',
          detail: updated.exhaustionLevel == 6
              ? 'Six Exhaustion levels cause death. Resolve revival at the table.'
              : updated.exhaustionLevel == 0
              ? 'Exhaustion cleared. Its D20 Test penalty and Speed reduction have ended.'
              : 'D20 Tests −${updated.exhaustionPenalty}. Reduce Speed by ${updated.exhaustionSpeedReduction} feet at the table.',
        ),
      );
    }
    if (updated.currentHp != previous.currentHp) {
      final difference = updated.currentHp - previous.currentHp;
      events.add(
        create(
          SessionEventType.health,
          difference > 0
              ? 'Recovered $difference HP'
              : 'Took ${difference.abs()} damage',
          detail: '${previous.currentHp} -> ${updated.currentHp} HP',
        ),
      );
    }
    if (updated.temporaryHp != previous.temporaryHp) {
      final difference = updated.temporaryHp - previous.temporaryHp;
      events.add(
        create(
          SessionEventType.health,
          difference > 0
              ? 'Gained $difference temporary HP'
              : 'Lost ${difference.abs()} temporary HP',
          detail:
              '${previous.temporaryHp} -> ${updated.temporaryHp} temporary HP',
        ),
      );
    }
    if (updated.concentrationSpellId != previous.concentrationSpellId) {
      events.add(
        create(
          SessionEventType.condition,
          updated.concentrationSpellId == null
              ? 'Concentration ended'
              : previous.concentrationSpellId == null
              ? 'Concentration started'
              : 'Concentration switched',
        ),
      );
    }
    if (updated.deathSaveSuccesses != previous.deathSaveSuccesses) {
      events.add(
        create(
          SessionEventType.health,
          updated.deathSaveSuccesses > previous.deathSaveSuccesses
              ? 'Death save success recorded'
              : 'Death save successes updated',
          detail: '${updated.deathSaveSuccesses} of 3 successes',
        ),
      );
    }
    if (updated.deathSaveFailures != previous.deathSaveFailures) {
      events.add(
        create(
          SessionEventType.health,
          updated.deathSaveFailures > previous.deathSaveFailures
              ? 'Death save failure recorded'
              : 'Death save failures updated',
          detail: '${updated.deathSaveFailures} of 3 failures',
        ),
      );
    }

    for (final condition in updated.activeConditions.difference(
      previous.activeConditions,
    )) {
      events.add(create(SessionEventType.condition, '$condition applied'));
    }
    for (final condition in previous.activeConditions.difference(
      updated.activeConditions,
    )) {
      events.add(create(SessionEventType.condition, '$condition removed'));
    }

    final resourcesById = {
      for (final resource in resources) resource.id: resource,
    };
    final resourceIds = {
      ...previous.resourceValues.keys,
      ...updated.resourceValues.keys,
    };
    for (final id in resourceIds) {
      final before = previous.resourceValues[id];
      final after = updated.resourceValues[id];
      if (before == null || after == null || before == after) continue;
      final name = resourcesById[id]?.name ?? id;
      events.add(
        create(
          SessionEventType.resource,
          after < before ? '$name spent' : '$name restored',
          detail: '$before -> $after remaining',
        ),
      );
    }
    return events;
  }
}
