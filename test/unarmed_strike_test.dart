import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';

import 'support/sequence_dice_roller.dart';

void main() {
  for (final (strength, raging, damage) in [(16, true, 6), (6, false, 0)]) {
    testWidgets(
      'basic unarmed damage with Strength $strength and Rage=$raging',
      (tester) async {
        final barbarian = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: 5,
          weapons: const [],
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.strength: strength,
          },
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(barbarian).copyWith(
            activeConditions: raging ? {ragingCondition} : {},
            conditionTurns: raging ? {ragingCondition: 1} : {},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([20]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: barbarian,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
              diceRoller: dice,
            ),
          ),
        );
        final unarmed = find.widgetWithText(OutlinedButton, 'Unarmed Strike');
        await tester.ensureVisible(unarmed);
        await tester.tap(unarmed);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Damage').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hit · Apply unarmed damage'));
        await tester.pumpAndSettle();
        expect(session.timeline.first.title, 'Unarmed Strike Damage: $damage');
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(session.attackActionAttacksRemaining, 1);
        expect(dice.index, 1);
        if (raging) {
          expect(session.characterState.conditionTurns[ragingCondition], 2);
        }
      },
    );
  }

  for (final (choice, outcome, effect) in [
    ('Grapple', 'Save failed', 'Target Grappled (escape DC 14).'),
    ('Shove · Prone', 'Save failed', 'Target falls Prone.'),
    ('Shove · Push', 'Save failed', 'Push the target 5 feet away.'),
    ('Grapple', 'Save succeeded', 'The target avoids the effect.'),
    (
      'Grapple',
      'Resolve later',
      'Target chooses a DC 14 Strength or Dexterity save.',
    ),
  ]) {
    testWidgets(
      '$choice shares Extra Attack with weapons and records $outcome',
      (tester) async {
        final barbarian = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: 5,
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.strength: 16,
          },
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(barbarian).copyWith(
            activeConditions: {ragingCondition},
            conditionTurns: {ragingCondition: 1},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([10]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: barbarian,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
              diceRoller: dice,
            ),
          ),
        );
        final unarmed = find.widgetWithText(OutlinedButton, 'Unarmed Strike');
        await tester.ensureVisible(unarmed);
        await tester.tap(unarmed);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.usedCombatActions, isEmpty);
        await tester.tap(unarmed);
        await tester.pumpAndSettle();
        await tester.tap(find.text(choice));
        await tester.pumpAndSettle();
        await tester.tap(find.text(outcome));
        await tester.pumpAndSettle();
        expect(session.timeline.first.detail, contains(effect));
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(session.attackActionAttacksRemaining, 1);
        expect(session.characterState.conditionTurns[ragingCondition], 2);
        expect(dice.index, 0);
        expect(session.characterState.activeConditions, {ragingCondition});
        final attack = find.byKey(
          const ValueKey('attack-attacks-weapon:quarterstaff'),
        );
        await tester.ensureVisible(attack);
        await tester.tap(attack);
        await tester.pumpAndSettle();
        expect(session.attackActionAttacksRemaining, 0);
        expect(dice.index, 1);
        await tester.ensureVisible(unarmed);
        await tester.tap(unarmed);
        await tester.pumpAndSettle();
        expect(
          find.text('No Attack action attacks remaining.'),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsNothing);
      },
    );
  }
}
