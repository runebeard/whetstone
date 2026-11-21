import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/inventory_item.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/screens/character_overview.dart';

import 'support/sequence_dice_roller.dart';

void main() {
  for (final choice in [
    'Pick a pocket',
    'Pick a lock / disarm trap',
    'Utilize',
    'Magic Item',
  ]) {
    testWidgets('Fast Hands $choice uses only a Bonus Action', (tester) async {
      final rogue = seedCharacters.first.copyWith(
        characterClass: 'Rogue',
        level: 7,
        subclasses: {'Rogue': 'Thief'},
        skillProficiencies: {'sleight_of_hand': SkillProficiency.proficient},
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(rogue),
        inventory: const [
          InventoryItem(
            name: 'Thieves’ Tools',
            quantity: 1,
            weightPerItem: 1,
            category: ItemCategory.tool,
          ),
          InventoryItem(
            name: 'Wand',
            quantity: 1,
            weightPerItem: 1,
            category: ItemCategory.equipment,
          ),
        ],
        archivedInventory: [],
        isInCombat: true,
        actionSurge: ActionSurgeState.available,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: rogue,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: SequenceDiceRoller([1]),
          ),
        ),
      );
      final button = find.widgetWithText(OutlinedButton, 'Fast Hands');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Dash'), findsNothing);
      expect(find.text('Ready'), findsNothing);
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();
      if (choice == 'Utilize' || choice == 'Magic Item') {
        await tester.tap(find.text('Wand'));
        await tester.pumpAndSettle();
        expect(session.timeline.first.title, 'Fast Hands · $choice');
        expect(session.timeline.first.detail, 'Wand');
      } else {
        expect(
          session.timeline.first.title,
          'Fast Hands · $choice · Sleight of Hand: 15',
        );
        expect(session.timeline.first.detail, contains('Reliable Talent'));
      }
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(session.actionSurge, ActionSurgeState.available);
      expect(session.inventory.every((item) => item.quantity == 1), isTrue);
      await tester.ensureVisible(button);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    });
  }

  testWidgets(
    'Fast Hands requires Thieves Tools for locks and preserves cancellation',
    (tester) async {
      final rogue = seedCharacters.first.copyWith(
        characterClass: 'Rogue',
        level: 3,
        subclasses: {'Rogue': 'Thief'},
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(rogue),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: rogue,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        ),
      );
      final button = find.widgetWithText(OutlinedButton, 'Fast Hands');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final lock = find.ancestor(
        of: find.text('Pick a lock / disarm trap'),
        matching: find.byType(SimpleDialogOption),
      );
      expect(tester.widget<SimpleDialogOption>(lock).onPressed, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, isEmpty);
    },
  );

  for (final (level, subclass) in [(2, 'Thief'), (7, 'Other')]) {
    testWidgets('Fast Hands absent at level $level with subclass $subclass', (
      tester,
    ) async {
      final rogue = seedCharacters.first.copyWith(
        characterClass: 'Rogue',
        level: level,
        subclasses: {'Rogue': subclass},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: rogue,
            initialSession: CharacterSession(
              characterState: CharacterState.fromCharacter(rogue),
              inventory: [],
              archivedInventory: [],
              isInCombat: true,
            ),
            onSessionChanged: (_) {},
            onCharacterChanged: (_) {},
          ),
        ),
      );
      expect(find.widgetWithText(OutlinedButton, 'Fast Hands'), findsNothing);
    });
  }
}
