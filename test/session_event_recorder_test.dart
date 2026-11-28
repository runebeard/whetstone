import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/session_event.dart';
import 'package:whetstone/services/session_event_recorder.dart';

void main() {
  const initial = CharacterState(
    currentHp: 20,
    maxHp: 20,
    temporaryHp: 0,
    armourClass: 14,
    initiativeModifier: 2,
    deathSaveSuccesses: 0,
    deathSaveFailures: 0,
    activeConditions: {},
    pinnedActionKeys: {},
    resourceValues: {'focus': 2},
  );

  test('describes meaningful state changes without UI dependencies', () {
    final recorder = SessionEventRecorder();
    final events = recorder.stateChanges(
      previous: initial,
      updated: initial.copyWith(
        currentHp: 15,
        temporaryHp: 3,
        activeConditions: {'Poisoned'},
        resourceValues: {'focus': 1},
      ),
      resources: const [
        CharacterResource(
          id: 'focus',
          name: 'Focus',
          maximum: 2,
          initialValue: 2,
          rechargePeriod: RechargePeriod.shortRest,
        ),
      ],
    );

    expect(events.map((event) => event.type), [
      SessionEventType.health,
      SessionEventType.health,
      SessionEventType.condition,
      SessionEventType.resource,
    ]);
    expect(events.map((event) => event.title), [
      'Took 5 damage',
      'Gained 3 temporary HP',
      'Poisoned applied',
      'Focus spent',
    ]);
  });

  test('creates unique event identities', () {
    final recorder = SessionEventRecorder();
    final first = recorder.create(SessionEventType.combat, 'Combat began');
    final second = recorder.create(SessionEventType.combat, 'Combat ended');

    expect(first.id, isNot(second.id));
  });
  for (final (before, after) in [(0, 2), (5, 6), (3, 0), (3, 2), (2, 2)]) {
    test(
      'Exhaustion history $before to $after records only an actual change',
      () {
        final recorder = SessionEventRecorder();
        final events = recorder.stateChanges(
          previous: initial.copyWith(exhaustionLevel: before),
          updated: initial.copyWith(exhaustionLevel: after),
          resources: [],
        );
        if (before == after) {
          expect(events, isEmpty);
          return;
        }
        final event = events.single;
        expect(event.type, SessionEventType.condition);
        expect(event.title, 'Exhaustion: $before → $after');
        expect(
          event.detail,
          contains(
            after == 6
                ? 'death'
                : after == 0
                ? 'cleared'
                : 'D20 Tests −${2 * after}',
          ),
        );
        final restored = SessionEvent.fromJson(event.toJson());
        expect(restored.title, event.title);
        expect(restored.detail, event.detail);
      },
    );
  }
}
