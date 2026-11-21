import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  for (final ally in [false, true]) {
    testWidgets(
      'Restoring Touch combines healing and conditions for ally=$ally',
      (tester) async {
        final paladin = seedCharacters.first.copyWith(
          characterClass: 'Paladin',
          level: 14,
          resources: BuiltInClass.paladin.classResources(
            14,
            charismaModifier: 3,
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(paladin).copyWith(
            activeConditions: {'Blinded', 'Deafened', 'Poisoned'},
            conditionTurns: {'Blinded': 4, 'Deafened': 3, 'Poisoned': 6},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: paladin,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
            ),
          ),
        );
        final pool = find.byKey(ValueKey('resource-$layOnHandsResourceId-70'));
        await tester.ensureVisible(pool);
        await tester.tap(pool);
        await tester.pumpAndSettle();
        if (ally) {
          await tester.tap(find.byType(DropdownButtonFormField<bool>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('An ally').last);
          await tester.pumpAndSettle();
        }
        await tester.enterText(find.byType(TextField), '4');
        for (final name
            in ally ? ['Paralyzed', 'Stunned'] : ['Blinded', 'Deafened']) {
          final condition = find.widgetWithText(CheckboxListTile, name);
          await tester.ensureVisible(condition);
          await tester.tap(condition);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Apply Lay on Hands'));
        await tester.pumpAndSettle();
        expect(session.characterState.resourceValues[layOnHandsResourceId], 56);
        expect(session.usedCombatActions, {CombatActionCost.bonusAction});
        expect(session.characterState.currentHp, ally ? 34 : 38);
        expect(
          session.characterState.activeConditions,
          ally ? {'Blinded', 'Deafened', 'Poisoned'} : {'Poisoned'},
        );
        expect(
          session.characterState.conditionTurns,
          ally ? {'Blinded': 4, 'Deafened': 3, 'Poisoned': 6} : {'Poisoned': 6},
        );
        expect(session.timeline.first.detail, contains('Spent 14 points'));
        session = CharacterSession.fromJson(session.toJson());
        expect(session.characterState.resourceValues[layOnHandsResourceId], 56);
        final spentPool = find.byKey(
          ValueKey('resource-$layOnHandsResourceId-56'),
        );
        await tester.ensureVisible(spentPool);
        await tester.tap(spentPool);
        await tester.pumpAndSettle();
        expect(find.text('Apply Lay on Hands'), findsNothing);
      },
    );
  }

  testWidgets(
    'Restoring Touch rejects overspending and preserves cancellation',
    (tester) async {
      final paladin = seedCharacters.first.copyWith(
        characterClass: 'Paladin',
        level: 14,
        resources: BuiltInClass.paladin.classResources(14, charismaModifier: 3),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(paladin).copyWith(
          activeConditions: {'Blinded', 'Deafened'},
          resourceValues: {layOnHandsResourceId: 12},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: paladin,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        ),
      );
      final pool = find.byKey(ValueKey('resource-$layOnHandsResourceId-12'));
      await tester.ensureVisible(pool);
      await tester.tap(pool);
      await tester.pumpAndSettle();
      for (final name in ['Blinded', 'Deafened']) {
        final condition = find.widgetWithText(CheckboxListTile, name);
        await tester.ensureVisible(condition);
        await tester.tap(condition);
        await tester.pumpAndSettle();
      }
      final healing = find.byType(TextField);
      await tester.ensureVisible(healing);
      await tester.enterText(healing, '3');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Apply Lay on Hands'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(healing, '2');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Apply Lay on Hands'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.characterState.resourceValues[layOnHandsResourceId], 12);
      expect(session.usedCombatActions, isEmpty);
      expect(session.characterState.activeConditions, {'Blinded', 'Deafened'});
    },
  );
}
