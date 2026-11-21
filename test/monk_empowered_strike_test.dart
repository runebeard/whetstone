import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  testWidgets(
    'Empowered Strike offers Force at Monk six and keeps the attack cost',
    (tester) async {
      final monk = seedCharacters.first.copyWith(
        characterClass: 'Monk',
        level: 6,
        weapons: [],
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.dexterity: 18,
        },
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(monk),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([10, 6]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: monk,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: dice,
          ),
        ),
      );
      final strike = find.widgetWithText(OutlinedButton, 'Unarmed Strike');
      await tester.ensureVisible(strike);
      await tester.tap(strike);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eligible · Use Martial Arts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Damage').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hit · Empowered Strike (Force)'));
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Unarmed Strike Damage: 10');
      expect(session.timeline.first.detail, endsWith(' | force'));
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(session.attackActionAttacksRemaining, 1);
      expect(dice.index, 2);
    },
  );
}
