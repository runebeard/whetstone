import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  for (final (combat, level, die) in [(true, 1, 6), (false, 10, 10)]) {
    testWidgets(
      'Grant Inspiration level $level combat=$combat persists costs',
      (tester) async {
        final bard = seedCharacters.first.copyWith(
          characterClass: 'Bard',
          level: level,
          weapons: [],
          resources: BuiltInClass.bard.classResources(
            level,
            charismaModifier: 3,
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            bard,
          ).copyWith(resourceValues: {bardicInspirationResourceId: 2}),
          inventory: [],
          archivedInventory: [],
          isInCombat: combat,
          usedCombatActions: combat
              ? {CombatActionCost.action, CombatActionCost.reaction}
              : {},
        );
        final dice = SequenceDiceRoller([4]);
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(
              session
                  .characterState
                  .resourceValues[bardicInspirationResourceId],
            ),
            character: bard,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (value) => session = value,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        final button = find.widgetWithText(
          OutlinedButton,
          combat
              ? 'Bardic Inspiration · Bonus Action'
              : 'Grant Bardic Inspiration',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.textContaining('does not already have'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          session.characterState.resourceValues[bardicInspirationResourceId],
          2,
        );
        expect(
          session.usedCombatActions.contains(CombatActionCost.bonusAction),
          false,
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Grant die'));
        await tester.pumpAndSettle();
        expect(
          session.characterState.resourceValues[bardicInspirationResourceId],
          1,
        );
        expect(
          session.usedCombatActions,
          combat ? CombatActionCost.values.toSet() : isEmpty,
        );
        expect(session.characterState.currentHp, 34);
        expect(dice.index, 0);
        expect(
          session.timeline.first.title,
          'Bardic Inspiration granted · d$die',
        );
        expect(session.timeline.first.detail, contains('1 hour'));
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          tester.widget<OutlinedButton>(button).onPressed,
          combat ? isNull : isNotNull,
        );
        if (combat) {
          final next = find.text('Next Turn');
          await tester.ensureVisible(next);
          await tester.tap(next);
          await tester.pumpAndSettle();
          expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
          expect(
            session.characterState.resourceValues[bardicInspirationResourceId],
            1,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Inspiration cannot bypass empty pool, spent Bonus Action or incapacitation',
    (tester) async {
      for (final (points, spent, incapacitated) in [
        (0, false, false),
        (1, true, false),
        (1, false, true),
      ]) {
        final bard = seedCharacters.first.copyWith(
          characterClass: 'Bard',
          level: 1,
          weapons: [],
          resources: BuiltInClass.bard.classResources(1, charismaModifier: 3),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey('$points-$spent-$incapacitated'),
              character: bard,
              initialSession: CharacterSession(
                characterState: CharacterState.fromCharacter(bard).copyWith(
                  resourceValues: {bardicInspirationResourceId: points},
                  activeConditions: incapacitated ? {'Incapacitated'} : {},
                ),
                inventory: [],
                archivedInventory: [],
                isInCombat: true,
                usedCombatActions: spent ? {CombatActionCost.bonusAction} : {},
              ),
              onCharacterChanged: (_) {},
              onSessionChanged: (_) {},
            ),
          ),
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(
                  OutlinedButton,
                  'Bardic Inspiration · Bonus Action',
                ),
              )
              .onPressed,
          isNull,
        );
      }
    },
  );
}
