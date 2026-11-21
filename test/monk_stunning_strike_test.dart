import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  for (final outcome in ['Save failed', 'Save succeeded', 'Resolve later']) {
    testWidgets(
      'Stunning Strike $outcome spends once and preserves actions across reload',
      (tester) async {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: 5,
          weapons: [],
          resources: BuiltInClass.monk.classResources(5, charismaModifier: 0),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(monk),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: {
            CombatActionCost.action,
            CombatActionCost.bonusAction,
          },
          attackActionAttacksRemaining: 1,
        );
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(session.stunningStrikeUsedThisTurn),
            character: monk,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        );
        await tester.pumpWidget(app());
        final button = find.text('Stunning Strike · Confirm eligible hit');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.stunningStrikeUsedThisTurn, isFalse);
        expect(session.characterState.resourceValues[focusResourceId], 5);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eligible hit · Spend 1 Focus'));
        await tester.pumpAndSettle();
        expect(find.textContaining('DC 12 Constitution save.'), findsOneWidget);
        await tester.tap(find.text(outcome));
        await tester.pumpAndSettle();
        expect(session.characterState.resourceValues[focusResourceId], 4);
        expect(session.stunningStrikeUsedThisTurn, isTrue);
        expect(session.usedCombatActions, {
          CombatActionCost.action,
          CombatActionCost.bonusAction,
        });
        expect(session.attackActionAttacksRemaining, 1);
        expect(session.characterState.activeConditions, isEmpty);
        expect(
          session.timeline.first.detail,
          contains(
            outcome == 'Save failed'
                ? 'Target Stunned'
                : outcome == 'Save succeeded'
                ? 'Target Speed halved'
                : 'DC 12 Constitution save',
          ),
        );
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(
                  OutlinedButton,
                  'Stunning Strike · used this turn',
                ),
              )
              .onPressed,
          isNull,
        );
        final boundary = find.text('Track another creature’s turn');
        await tester.ensureVisible(boundary);
        await tester.tap(boundary);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.stunningStrikeUsedThisTurn, isTrue);
        await tester.tap(boundary);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Different turn confirmed'));
        await tester.pumpAndSettle();
        expect(session.stunningStrikeUsedThisTurn, isFalse);
        expect(session.usedCombatActions, {
          CombatActionCost.action,
          CombatActionCost.bonusAction,
        });
        expect(session.characterState.resourceValues[focusResourceId], 4);
        final again = find.text('Stunning Strike · Confirm eligible hit');
        await tester.ensureVisible(again);
        await tester.tap(again);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eligible hit · Spend 1 Focus'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Resolve later'));
        await tester.pumpAndSettle();
        final next = find.text('Next Turn');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(session.stunningStrikeUsedThisTurn, isFalse);
        expect(session.characterState.resourceValues[focusResourceId], 3);
        expect(session.usedCombatActions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Stunning Strike requires Monk five and Focus and is blocked by incapacitation',
    (tester) async {
      for (final (level, points, incapacitated) in [
        (4, 4, false),
        (5, 0, false),
        (5, 5, true),
      ]) {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: level,
          weapons: [],
          resources: BuiltInClass.monk.classResources(
            level,
            charismaModifier: 0,
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(monk).copyWith(
            resourceValues: {focusResourceId: points},
            activeConditions: incapacitated ? {'Incapacitated'} : {},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey('$level-$points-$incapacitated'),
              character: monk,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
            ),
          ),
        );
        final button = find.widgetWithText(
          OutlinedButton,
          'Stunning Strike · Confirm eligible hit',
        );
        if (level == 4) {
          expect(button, findsNothing);
        } else if (incapacitated) {
          expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        } else {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.text('Eligible hit · Spend 1 Focus'), findsNothing);
        }
        expect(session.stunningStrikeUsedThisTurn, isFalse);
        expect(session.characterState.resourceValues[focusResourceId], points);
      }
    },
  );
}
