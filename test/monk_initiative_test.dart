import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  test('Metabolism recovers on Long Rest only', () {
    final monk = seedCharacters.first.copyWith(
      characterClass: 'Monk',
      level: 5,
      resources: BuiltInClass.monk.classResources(5, charismaModifier: 0),
    );
    final state = CharacterState.fromCharacter(monk).copyWith(
      resourceValues: {uncannyMetabolismResourceId: 0, focusResourceId: 0},
    );
    for (final type in RestType.values) {
      final rested = RestPlan.forCharacter(
        character: monk,
        currentState: state,
        type: type,
      ).updatedState;
      expect(
        rested.resourceValues[uncannyMetabolismResourceId],
        type == RestType.longRest ? 1 : 0,
      );
      expect(rested.resourceValues[focusResourceId], 5);
    }
  });
  for (final (level, accept, available, initial, expected) in [
    (5, true, true, 1, 5),
    (5, false, true, 1, 1),
    (15, false, true, 1, 4),
    (15, false, false, 1, 4),
    (15, false, false, 8, 8),
    (15, true, true, 1, 15),
  ]) {
    testWidgets(
      'Initiative Monk $level accept=$accept available=$available focus=$initial',
      (tester) async {
        var monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: level,
          resources: BuiltInClass.monk.classResources(
            level,
            charismaModifier: 0,
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(monk).copyWith(
            currentHp: 20,
            resourceValues: {
              focusResourceId: initial,
              uncannyMetabolismResourceId: available ? 1 : 0,
            },
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([10, 4, 12]);
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(session.combatInitiative),
            character: monk,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (value) => monk = value,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        Future<void> initiative() async {
          final button = find.text('⚡ Init');
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Record Initiative'));
          await tester.pumpAndSettle();
        }

        await initiative();
        if (available) {
          await tester.tap(find.text(accept ? 'Recover Focus and HP' : 'Skip'));
          await tester.pumpAndSettle();
        } else {
          expect(find.byType(AlertDialog), findsNothing);
        }
        expect(
          session.characterState.resourceValues[focusResourceId],
          expected,
        );
        expect(
          session.characterState.resourceValues[uncannyMetabolismResourceId],
          accept
              ? 0
              : available
              ? 1
              : 0,
        );
        expect(
          session.characterState.currentHp,
          accept ? (24 + level).clamp(0, 42) : 20,
        );
        expect(session.usedCombatActions, isEmpty);
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await initiative();
        expect(find.text('Recover Focus and HP'), findsNothing);
        expect(
          session.characterState.resourceValues[focusResourceId],
          expected,
        );
        expect(dice.index, accept ? 3 : 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

