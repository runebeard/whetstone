import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  test(
    'Rage extensions preserve its elapsed time and stop after 100 rounds',
    () {
      var state = CharacterState.fromCharacter(seedCharacters.first).copyWith(
        activeConditions: {ragingCondition},
        conditionTurns: {ragingCondition: 2},
      );
      for (var round = 1; round <= 100; round++) {
        state = state
            .copyWith(conditionTurns: {ragingCondition: 2})
            .advanceConditionTurn();
        if (round < 100) {
          expect(state.isRaging, isTrue);
          expect(state.rageTurnsElapsed, round);
        }
        if (round == 50) state = CharacterState.fromJson(state.toJson());
      }
      expect(state.isRaging, isFalse);
      expect(state.rageTurnsElapsed, 0);
      expect(state.conditionTurns, isNot(contains(ragingCondition)));
    },
  );

  test('ending Rage clears elapsed time without removing other conditions', () {
    final state = CharacterState.fromCharacter(seedCharacters.first).copyWith(
      activeConditions: {ragingCondition, 'Poisoned'},
      rageTurnsElapsed: 72,
      conditionTurns: {ragingCondition: 2, 'Poisoned': 4},
    );
    final ended = state.endRage();
    expect(ended.rageTurnsElapsed, 0);
    expect(ended.activeConditions, {'Poisoned'});
    expect(ended.conditionTurns, {'Poisoned': 4});
    expect(ended.toJson().containsKey('rageTurnsElapsed'), isFalse);
  });

  testWidgets(
    'confirmed enemy save extends Rage without spending a Bonus Action',
    (tester) async {
      final barbarian = seedCharacters.first.copyWith(
        characterClass: 'Barbarian',
        level: 5,
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(barbarian).copyWith(
          activeConditions: {ragingCondition},
          conditionTurns: {ragingCondition: 1},
          rageTurnsElapsed: 98,
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        usedCombatActions: {CombatActionCost.bonusAction},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: barbarian,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        ),
      );
      final record = find.text('Record enemy save');
      await tester.ensureVisible(record);
      await tester.tap(record);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.characterState.conditionTurns[ragingCondition], 1);
      await tester.ensureVisible(record);
      await tester.tap(record);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enemy forced to save'));
      await tester.pumpAndSettle();
      expect(session.characterState.conditionTurns[ragingCondition], 2);
      expect(session.characterState.rageTurnsElapsed, 98);
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(session.timeline.first.title, 'Rage extended by enemy save');
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.text('Next Turn'));
        await tester.tap(find.text('Next Turn'));
        await tester.pumpAndSettle();
      }
      expect(session.characterState.isRaging, isFalse);
      expect(find.text('Record enemy save'), findsNothing);
    },
  );
}
