import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  test('Bardic Inspiration die scales by Bard class levels', () {
    for (final (level, sides) in [
      (1, 6),
      (4, 6),
      (5, 8),
      (9, 8),
      (10, 10),
      (14, 10),
      (15, 12),
      (20, 12),
    ]) {
      expect(
        seedCharacters.first
            .copyWith(characterClass: 'Bard', level: level)
            .bardicInspirationDieSides,
        sides,
      );
    }
    expect(seedCharacters.first.bardicInspirationDieSides, 0);
    expect(
      seedCharacters.first
          .copyWith(
            characterClass: 'Fighter',
            level: 20,
            additionalClassLevels: {'Bard': 1},
          )
          .bardicInspirationDieSides,
      6,
    );
  });
  for (final (level, choice, die, sides) in [
    (3, 'Successful attack roll', 4, 6),
    (5, 'Successful ability check', 6, 8),
    (10, 'Damage roll', 8, 10),
    (15, 'Damage roll', 10, 12),
  ]) {
    testWidgets(
      'Cutting Words $choice at Bard $level spends one Inspiration and Reaction',
      (tester) async {
        final bard = seedCharacters.first.copyWith(
          characterClass: 'Bard',
          level: level,
          weapons: [],
          subclasses: {'Bard': 'College of Lore'},
          resources: BuiltInClass.bard.classResources(
            level,
            charismaModifier: 3,
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(bard),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: {
            CombatActionCost.action,
            CombatActionCost.bonusAction,
          },
        );
        final dice = SequenceDiceRoller([die]);
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
        final button = find.text('Cutting Words · Reaction');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('Saving throw'), findsNothing);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          session.characterState.resourceValues[bardicInspirationResourceId],
          3,
        );
        expect(dice.index, 0);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text(choice));
        await tester.pumpAndSettle();
        expect(session.timeline.first.title, 'Cutting Words: $die');
        expect(session.timeline.first.detail, contains('1d$sides'));
        expect(session.timeline.first.detail, contains(choice.toLowerCase()));
        expect(
          session.characterState.resourceValues[bardicInspirationResourceId],
          2,
        );
        expect(session.usedCombatActions, CombatActionCost.values.toSet());
        expect(session.characterState.currentHp, 34);
        expect(dice.index, 1);
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
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
        expect(session.usedCombatActions, isEmpty);
        expect(
          session.characterState.resourceValues[bardicInspirationResourceId],
          2,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Cutting Words · Reaction'),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Cutting Words gates class, subclass, Inspiration and incapacitation',
    (tester) async {
      for (final (level, subclass, points, incapacitated) in [
        (2, 'College of Lore', 1, false),
        (3, 'Other', 1, false),
        (3, 'College of Lore', 0, false),
        (3, 'College of Lore', 1, true),
      ]) {
        var bard = seedCharacters.first.copyWith(
          characterClass: 'Bard',
          level: level,
          weapons: [],
          subclasses: {'Bard': subclass},
          resources: [],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(bard).copyWith(
            resourceValues: {bardicInspirationResourceId: points},
            activeConditions: incapacitated ? {'Incapacitated'} : {},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey('$level-$subclass-$points-$incapacitated'),
              character: bard,
              initialSession: session,
              onCharacterChanged: (v) => bard = v,
              onSessionChanged: (v) => session = v,
              diceRoller: dice,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          bard.resources
              .where((r) => r.id == bardicInspirationResourceId)
              .length,
          1,
        );
        final button = find.widgetWithText(
          OutlinedButton,
          'Cutting Words · Reaction',
        );
        if (level < 3 || subclass == 'Other') {
          expect(button, findsNothing);
        } else if (incapacitated) {
          expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        } else {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.text('Cutting Words · Confirm trigger'), findsNothing);
        }
        expect(
          session.characterState.resourceValues[bardicInspirationResourceId],
          points,
        );
        expect(session.usedCombatActions, isEmpty);
        expect(dice.index, 0);
      }
    },
  );
}
