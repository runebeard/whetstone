import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  for (final (self, disadvantage, inspiration) in [
    (true, false, 1),
    (true, true, 1),
    (false, false, 0),
  ]) {
    testWidgets(
      'Countercharm self=$self disadvantage=$disadvantage Inspiration=$inspiration shares Reaction',
      (tester) async {
        final bard = seedCharacters.first.copyWith(
          characterClass: 'Bard',
          level: 7,
          weapons: [],
          savingThrowProficiencies: {},
          subclasses: {'Bard': 'College of Lore'},
          resources: BuiltInClass.bard.classResources(7, charismaModifier: 3),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(bard).copyWith(
            activeConditions: {'Charmed'},
            resourceValues: {bardicInspirationResourceId: inspiration},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([3, 17]);
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(session.usedCombatActions.length),
            character: bard,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        final button = find.text('Countercharm · Reaction');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.usedCombatActions, isEmpty);
        expect(dice.index, 0);
        await tester.tap(button);
        await tester.pumpAndSettle();
        if (disadvantage) {
          await tester.tap(find.text('Your save also has Disadvantage'));
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.text(self ? 'Reroll your failed save' : 'Help another creature'),
        );
        await tester.pumpAndSettle();
        expect(session.usedCombatActions, {CombatActionCost.reaction});
        expect(
          session.characterState.resourceValues[bardicInspirationResourceId],
          inspiration,
        );
        expect(session.characterState.activeConditions, {'Charmed'});
        expect(session.characterState.currentHp, 34);
        if (self) {
          expect(
            session.timeline.first.title,
            'Wisdom Save · Countercharm: ${disadvantage ? 4 : 18}',
          );
          expect(dice.index, disadvantage ? 1 : 2);
        } else {
          expect(
            session.timeline.first.detail,
            contains('Another creature within 30 feet'),
          );
          expect(dice.index, 0);
        }
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Countercharm · Reaction'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Cutting Words · Reaction'),
              )
              .onPressed,
          isNull,
        );
        final next = find.text('Next Turn');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Countercharm · Reaction'),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          session.characterState.resourceValues[bardicInspirationResourceId],
          inspiration,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Countercharm requires Bard seven and an available conscious Reaction',
    (tester) async {
      for (final (level, incapacitated, spent) in [
        (6, false, false),
        (7, true, false),
        (7, false, true),
      ]) {
        final bard = seedCharacters.first.copyWith(
          characterClass: 'Bard',
          level: level,
          weapons: [],
        );
        final session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            bard,
          ).copyWith(activeConditions: incapacitated ? {'Incapacitated'} : {}),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: spent ? {CombatActionCost.reaction} : {},
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey('$level-$incapacitated-$spent'),
              character: bard,
              initialSession: session,
              onCharacterChanged: (_) {},
              onSessionChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.widgetWithText(
          OutlinedButton,
          'Countercharm · Reaction',
        );
        if (level < 7) {
          expect(button, findsNothing);
        } else {
          expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        }
      }
    },
  );
}
