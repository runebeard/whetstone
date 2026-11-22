import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final scenario in [
    'boost',
    'keep',
    'empty',
    'cancel',
    'advantage',
    'monk',
  ]) {
    testWidgets('Own Luck initiative: $scenario', (tester) async {
      final advantage = scenario == 'advantage';
      final monk = scenario == 'monk';
      final uses = scenario == 'empty' ? 0 : 2;
      var character = seedCharacters.first.copyWith(
        characterClass: advantage ? 'Barbarian' : 'Warlock',
        level: advantage
            ? 13
            : monk
            ? 8
            : 6,
        additionalClassLevels: advantage
            ? {'Warlock': 6}
            : monk
            ? {'Monk': 2}
            : {},
        subclasses: {'Warlock': 'Fiend Patron'},
        initiativeModifier: 2,
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.charisma: 16,
        },
        resources: [
          ...BuiltInClass.warlock.classResources(
            6,
            charismaModifier: 3,
            subclass: 'Fiend Patron',
          ),
          if (monk) ...BuiltInClass.monk.classResources(2, charismaModifier: 3),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character).copyWith(
          currentHp: 22,
          resourceValues: {
            darkOnesOwnLuckResourceId: uses,
            if (monk) focusResourceId: 0,
            if (monk) uncannyMetabolismResourceId: 1,
          },
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        usedCombatActions: CombatActionCost.values.toSet(),
      );
      final dice = SequenceDiceRoller(advantage ? [2, 17, 4] : [3, 7]);
      var generation = 0;
      Widget app() => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(generation),
          character: character,
          initialSession: session,
          onCharacterChanged: (value) => character = value,
          onSessionChanged: (value) => session = value,
          diceRoller: dice,
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tap(tester, '⚡ Init');
      await tap(tester, 'Record Initiative');
      if (uses > 0) {
        expect(find.text('Dark One’s Own Luck · Initiative'), findsOneWidget);
        expect(session.combatInitiative, isNull);
        expect(
          session.characterState.resourceValues[darkOnesOwnLuckResourceId],
          uses,
        );
        if (monk) {
          expect(find.text('Recover Focus and HP'), findsNothing);
          expect(session.characterState.resourceValues[focusResourceId], 0);
        }
        if (scenario == 'cancel') {
          await tap(tester, 'Cancel recording');
          expect(find.text('Record Initiative'), findsOneWidget);
          expect(session.combatInitiative, isNull);
          expect(
            session.characterState.resourceValues[darkOnesOwnLuckResourceId],
            2,
          );
          expect(dice.index, 1);
          return;
        }
        await tap(
          tester,
          scenario == 'keep'
              ? 'Keep initiative'
              : 'Spend use · Boost initiative',
        );
      }
      final boosted = uses > 0 && scenario != 'keep';
      final expected = advantage
          ? 23
          : boosted
          ? 12
          : 5;
      expect(session.combatInitiative, expected);
      expect(
        session.characterState.resourceValues[darkOnesOwnLuckResourceId],
        uses - (boosted ? 1 : 0),
      );
      if (monk) {
        expect(find.text('Recover Focus and HP'), findsOneWidget);
        await tap(tester, 'Skip');
        expect(session.characterState.resourceValues[focusResourceId], 0);
        expect(
          session.characterState.resourceValues[uncannyMetabolismResourceId],
          1,
        );
      }
      expect(session.characterState.currentHp, 22);
      expect(session.usedCombatActions, CombatActionCost.values.toSet());
      expect(
        dice.index,
        advantage
            ? 3
            : boosted
            ? 2
            : 1,
      );
      session = CharacterSession.fromJson(session.toJson());
      generation++;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(session.combatInitiative, expected);
      expect(find.text('Dark One’s Own Luck · Initiative'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
