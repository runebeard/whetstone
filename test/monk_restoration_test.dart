import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  for (final condition in ['Charmed', 'Frightened', 'Poisoned']) {
    testWidgets(
      'Self-Restoration removes only $condition and saves the turn limit',
      (tester) async {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: 10,
          weapons: [],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(monk).copyWith(
            activeConditions: {'Charmed', 'Frightened', 'Poisoned', 'Prone'},
            conditionTurns: {'Charmed': 3, 'Frightened': 3, 'Poisoned': 3},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: {
            CombatActionCost.action,
            CombatActionCost.bonusAction,
            CombatActionCost.reaction,
          },
        );
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(session.selfRestorationUsedThisTurn),
            character: monk,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        final button = find.text('Self-Restoration · End of turn');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.selfRestorationUsedThisTurn, isFalse);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('End turn · Remove $condition'));
        await tester.pumpAndSettle();
        expect(
          session.characterState.activeConditions,
          {'Charmed', 'Frightened', 'Poisoned', 'Prone'}..remove(condition),
        );
        expect(
          session.characterState.conditionTurns.containsKey(condition),
          isFalse,
        );
        expect(session.usedCombatActions, CombatActionCost.values.toSet());
        expect(session.selfRestorationUsedThisTurn, isTrue);
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.text('Self-Restoration · End of turn'), findsNothing);
        final next = find.text('Next Turn');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(session.selfRestorationUsedThisTurn, isFalse);
        expect(find.text('Self-Restoration · End of turn'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Self-Restoration excludes unrelated conditions and is absent below Monk ten',
    (tester) async {
      for (final level in [9, 10]) {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: level,
          weapons: [],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            monk,
          ).copyWith(activeConditions: {'Prone'}),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey(level),
              character: monk,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
            ),
          ),
        );
        final button = find.text('Self-Restoration · End of turn');
        if (level == 9) {
          expect(button, findsNothing);
        } else {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.text('No eligible condition to remove.'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(session.characterState.activeConditions, {'Prone'});
          expect(session.selfRestorationUsedThisTurn, isFalse);
        }
      }
    },
  );
}
