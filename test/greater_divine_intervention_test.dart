import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/services/session_event_recorder.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'divine_intervention_test.dart' as fixtures;
import 'draconic_spell_grants_test.dart' as helpers;
import 'support/sequence_dice_roller.dart';

void main() {
  final hero = fixtures.cleric(20);
  for (final count in [0, 1, 2, 8]) {
    test(
      'Wish cooldown $count recovers only after the required Long Rests',
      () {
        var state = CharacterState.fromCharacter(hero).copyWith(
          divineInterventionRestsRemaining: count,
          resourceValues: {divineInterventionResourceId: 0},
        );
        state = CharacterState.fromJson(state.toJson());
        final before = state;
        final short = RestPlan.forCharacter(
          type: RestType.shortRest,
          character: hero,
          currentState: state,
        ).updatedState;
        expect(short.divineInterventionRestsRemaining, count);
        expect(short.resourceValues[divineInterventionResourceId], 0);
        if (count > 0) {
          expect(
            state
                .copyWith(resourceValues: {divineInterventionResourceId: 1})
                .resourceValues[divineInterventionResourceId],
            0,
          );
        }
        final rests = count == 0 ? 1 : count;
        for (var n = 1; n <= rests; n++) {
          state = RestPlan.forCharacter(
            type: RestType.longRest,
            character: hero,
            currentState: state,
          ).updatedState;
          expect(
            state.divineInterventionRestsRemaining,
            (count - n).clamp(0, 8),
          );
          expect(
            state.resourceValues[divineInterventionResourceId],
            n == rests ? 1 : 0,
          );
          state = CharacterState.fromJson(state.toJson());
        }
        if (count > 0) {
          final events = SessionEventRecorder().stateChanges(
            previous: before,
            updated: state,
            resources: hero.resources,
          );
          expect(
            events.any((e) => e.title == 'Divine Intervention cooldown ended'),
            isTrue,
          );
        }
      },
    );
  }
  test(
    'Legacy and imported cooldowns are bounded and cannot carry a refilled use',
    () {
      final json = CharacterState.fromCharacter(hero).toJson();
      expect(json.containsKey('divineInterventionRestsRemaining'), isFalse);
      expect(CharacterState.fromJson(json).divineInterventionRestsRemaining, 0);
      for (final value in [-2, 3, 99]) {
        final state = CharacterState.fromJson({
          ...json,
          'divineInterventionRestsRemaining': value,
          'resourceValues': {divineInterventionResourceId: 1},
        });
        expect(state.divineInterventionRestsRemaining, value.clamp(0, 8));
        expect(
          state.resourceValues[divineInterventionResourceId],
          value > 0 ? 0 : 1,
        );
      }
    },
  );
  for (final (first, second, concentration) in [(1, 1, false), (4, 4, true)]) {
    testWidgets(
      'Wish rolls $first plus $second once and preserves its cooldown across reloads',
      (tester) async {
        final bless = hero.spells.singleWhere((s) => s.name == 'Bless').id;
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(hero).copyWith(
            currentHp: 13,
            concentrationSpellId: bless,
            concentrationTurnsRemaining: 8,
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final resources = {...session.characterState.resourceValues};
        final dice = SequenceDiceRoller([first, second]);
        Widget app(int generation) => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: hero,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app(0));
        await tester.pumpAndSettle();
        Future<void> begin() async {
          await helpers.tap(tester, find.text('Divine Intervention').first);
          await helpers.tap(
            tester,
            find.text('Wish · Greater Divine Intervention'),
          );
        }

        await begin();
        await helpers.tap(tester, find.text('Cancel'));
        expect(
          session.characterState.resourceValues[divineInterventionResourceId],
          1,
        );
        expect(session.usedCombatActions, isEmpty);
        expect(dice.index, 0);
        await begin();
        await tester.enterText(find.byType(TextField), 'Protect the village');
        tester.testTextInput.hide();
        if (concentration) {
          await helpers.tap(
            tester,
            find.text('Chosen effect requires Concentration'),
          );
        }
        await helpers.tap(tester, find.text('Cast Wish'));
        final count = first + second;
        expect(session.characterState.divineInterventionRestsRemaining, count);
        expect(session.characterState.resourceValues, {
          ...resources,
          divineInterventionResourceId: 0,
        });
        expect(session.characterState.currentHp, 13);
        expect(
          session.characterState.concentrationSpellId,
          concentration ? null : bless,
        );
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(dice.index, 2);
        expect(session.timeline.first.title, 'Divine Intervention · Wish');
        expect(
          session.timeline.first.detail,
          contains('2d4 ($first + $second)'),
        );
        expect(session.timeline.first.detail, contains('Protect the village'));
        expect(find.text('$count Long Rests remaining'), findsOneWidget);
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app(1));
        await tester.pumpAndSettle();
        expect(session.characterState.divineInterventionRestsRemaining, count);
        await helpers.tap(tester, find.text('Divine Intervention').first);
        expect(find.text('Divine Intervention · Spell'), findsNothing);
        expect(
          find.textContaining('requires $count more Long Rests'),
          findsOneWidget,
        );
        await helpers.tap(tester, find.text('End Combat'));
        await helpers.tap(tester, find.text('Profile'));
        expect(
          find.text('Greater Divine Intervention · Cooldown'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            '$count Long Rests until Divine Intervention returns',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Cleric nineteen cannot choose Wish', (tester) async {
    final s = fixtures.Scenario();
    await s.boot(tester, level: 19);
    await s.begin(tester);
    expect(find.text('Wish · Greater Divine Intervention'), findsNothing);
    await helpers.tap(tester, find.text('Cancel'));
    expect(s.session.characterState.divineInterventionRestsRemaining, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Cancelling Wish then casting ordinary Intervention does not roll a cooldown',
    (tester) async {
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(hero),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: hero,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Divine Intervention').first);
      await helpers.tap(
        tester,
        find.text('Wish · Greater Divine Intervention'),
      );
      await helpers.tap(tester, find.text('Cancel'));
      await helpers.tap(tester, find.text('Divine Intervention').first);
      await helpers.tap(tester, find.text('Cast Bless'));
      expect(session.characterState.divineInterventionRestsRemaining, 0);
      expect(
        session.characterState.resourceValues[divineInterventionResourceId],
        0,
      );
      expect(dice.index, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
