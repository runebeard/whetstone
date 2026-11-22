import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/screens/character_overview.dart';

const restore = 'Dragon Wings · Restore use';
Future<void> tap(WidgetTester tester, String text) async {
  final finder = text == 'Dragon Wings'
      ? find.widgetWithText(OutlinedButton, text)
      : find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Dragon Wings requires Draconic fourteen, lasts 600 turns and only Long Rest restores the use',
    () {
      for (final (level, subclass, expected) in [
        (13, 'Draconic Sorcery', false),
        (14, 'Draconic Sorcery', true),
        (20, 'Other', false),
      ]) {
        expect(
          BuiltInClass.sorcerer
              .classResources(level, charismaModifier: 3, subclass: subclass)
              .any((r) => r.id == dragonWingsResourceId),
          expected,
        );
      }
      final character = seedCharacters.first.copyWith(
        characterClass: 'Sorcerer',
        level: 14,
        subclasses: {'Sorcerer': 'Draconic Sorcery'},
        resources: BuiltInClass.sorcerer.classResources(
          14,
          charismaModifier: 3,
          subclass: 'Draconic Sorcery',
        ),
      );
      var state = CharacterState.fromCharacter(character).copyWith(
        activeConditions: {dragonWingsCondition},
        conditionTurns: {dragonWingsCondition: 600},
        resourceValues: {dragonWingsResourceId: 0},
      );
      for (var turn = 0; turn < 599; turn++) {
        state = state.advanceConditionTurn();
      }
      expect(state.activeConditions, contains(dragonWingsCondition));
      expect(
        state.advanceConditionTurn().activeConditions,
        isNot(contains(dragonWingsCondition)),
      );
      for (final type in RestType.values) {
        final rested = RestPlan.forCharacter(
          type: type,
          character: character,
          currentState: state,
        ).updatedState;
        expect(rested.activeConditions, isNot(contains(dragonWingsCondition)));
        expect(
          rested.resourceValues[dragonWingsResourceId],
          type == RestType.longRest ? 1 : 0,
        );
      }
    },
  );
  for (final combat in [false, true]) {
    testWidgets(
      'Dragon Wings activation, recharge, reload and dismissal combat=$combat',
      (tester) async {
        var character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: 14,
          subclasses: {'Sorcerer': 'Draconic Sorcery'},
          resources: [],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 22,
            resourceValues: {
              dragonWingsResourceId: 1,
              sorceryPointsResourceId: 6,
            },
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: combat,
          usedCombatActions: combat
              ? {CombatActionCost.action, CombatActionCost.reaction}
              : {},
        );
        var generation = 0;
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          character.resources.any((r) => r.id == dragonWingsResourceId),
          isTrue,
        );
        await tap(tester, 'Dragon Wings');
        await tap(tester, 'Cancel');
        expect(session.characterState.resourceValues[dragonWingsResourceId], 1);
        await tap(tester, 'Dragon Wings');
        await tap(tester, 'Activate wings');
        expect(session.characterState.resourceValues[dragonWingsResourceId], 0);
        expect(
          session.characterState.conditionTurns[dragonWingsCondition],
          600,
        );
        expect(
          session.characterState.activeConditions,
          contains(dragonWingsCondition),
        );
        expect(
          session.usedCombatActions,
          combat ? CombatActionCost.values.toSet() : isEmpty,
        );
        expect(find.textContaining('Fly Speed 60 feet'), findsOneWidget);
        await tap(tester, restore);
        await tap(tester, 'Cancel');
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          6,
        );
        await tap(tester, restore);
        await tap(tester, 'Spend 3 points · Restore use');
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          3,
        );
        expect(session.characterState.resourceValues[dragonWingsResourceId], 1);
        expect(
          session.characterState.conditionTurns[dragonWingsCondition],
          600,
        );
        expect(
          session.usedCombatActions,
          combat ? CombatActionCost.values.toSet() : isEmpty,
        );
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        if (combat) {
          await tap(tester, 'Next Turn');
          expect(
            session.characterState.conditionTurns[dragonWingsCondition],
            599,
          );
        }
        final actions = {...session.usedCombatActions};
        await tap(tester, 'Dismiss Dragon Wings');
        await tap(tester, 'Dismiss wings');
        expect(
          session.characterState.activeConditions,
          isNot(contains(dragonWingsCondition)),
        );
        expect(
          session.characterState.conditionTurns.containsKey(
            dragonWingsCondition,
          ),
          isFalse,
        );
        expect(session.characterState.resourceValues[dragonWingsResourceId], 1);
        expect(session.usedCombatActions, actions);
        expect(session.characterState.currentHp, 22);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final points in [2, 3]) {
    testWidgets(
      'Dragon Wings restoration needs three points and no action: $points',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: 14,
          subclasses: {'Sorcerer': 'Draconic Sorcery'},
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            resourceValues: {
              dragonWingsResourceId: 0,
              sorceryPointsResourceId: points,
            },
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: CombatActionCost.values.toSet(),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              onCharacterChanged: (_) {},
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (points == 2) {
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, restore),
                )
                .onPressed,
            isNull,
          );
        } else {
          await tap(tester, restore);
          await tap(tester, 'Spend 3 points · Restore use');
          expect(
            session.characterState.resourceValues[dragonWingsResourceId],
            1,
          );
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId],
            0,
          );
          expect(
            session.characterState.activeConditions,
            isNot(contains(dragonWingsCondition)),
          );
        }
        expect(session.usedCombatActions, CombatActionCost.values.toSet());
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final scenario in ['level', 'subclass', 'stunned', 'bonus']) {
    testWidgets('Dragon Wings rejects $scenario', (tester) async {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Sorcerer',
        level: 14,
        additionalClassLevels: scenario == 'level' ? {'Fighter': 1} : {},
        subclasses: {
          'Sorcerer': scenario == 'subclass' ? 'Other' : 'Draconic Sorcery',
        },
      );
      final session = CharacterSession(
        characterState: CharacterState.fromCharacter(character).copyWith(
          activeConditions: scenario == 'stunned' ? {'Stunned'} : {},
          resourceValues: {dragonWingsResourceId: 1},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        usedCombatActions: scenario == 'bonus'
            ? {CombatActionCost.bonusAction}
            : {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(OutlinedButton, 'Dragon Wings');
      if (scenario == 'level' || scenario == 'subclass') {
        expect(button, findsNothing);
      } else {
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
