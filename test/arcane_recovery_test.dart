import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  test(
    'Arcane Recovery is available from Wizard one and recharges only on Long Rest',
    () {
      final resources = BuiltInClass.wizard.classResources(
        1,
        charismaModifier: 0,
      );
      expect(resources.single.id, arcaneRecoveryResourceId);
      final wizard = seedCharacters.first.copyWith(resources: resources);
      final state = CharacterState.fromCharacter(
        wizard,
      ).copyWith(resourceValues: {arcaneRecoveryResourceId: 0});
      for (final type in RestType.values) {
        expect(
          RestPlan.forCharacter(
            character: wizard,
            currentState: state,
            type: type,
          ).updatedState.resourceValues[arcaneRecoveryResourceId],
          type == RestType.longRest ? 1 : 0,
        );
      }
    },
  );
  for (final (level, fighter, budget) in [(6, 0, 3), (6, 3, 2), (20, 0, 10)]) {
    testWidgets(
      'Arcane Recovery level $level Fighter $fighter budgets $budget slot levels',
      (tester) async {
        var wizard = seedCharacters.first.copyWith(
          level: level,
          additionalClassLevels: fighter == 0 ? {} : {'Fighter': fighter},
          resources: [
            ...fullCasterSlots(level),
            CharacterResource(
              id: pactSlotId(2),
              name: 'Pact Magic',
              maximum: 2,
              initialValue: 2,
              rechargePeriod: RechargePeriod.shortRest,
            ),
          ],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(wizard).copyWith(
            resourceValues: {
              for (final r in wizard.resources)
                r.id:
                    r.id == spellSlotId(1) ||
                        r.id == spellSlotId(2) ||
                        r.id == spellSlotId(6) ||
                        r.id == pactSlotId(2)
                    ? 0
                    : r.maximum,
            },
          ),
          inventory: [],
          archivedInventory: [],
        );
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(
              session.characterState.resourceValues[arcaneRecoveryResourceId],
            ),
            character: wizard,
            initialSession: session,
            onSessionChanged: (v) => session = v,
            onCharacterChanged: (v) => wizard = v,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        final button = find.text('Arcane Recovery · After Short Rest');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.characterState.resourceValues[spellSlotId(2)], 0);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Short Rest finished · Choose slots'));
        await tester.pumpAndSettle();
        expect(find.text('$budget slot levels remaining'), findsOneWidget);
        expect(find.text('Recover a level 6 slot'), findsNothing);
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(
          session.characterState.resourceValues[arcaneRecoveryResourceId] ?? 1,
          1,
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Short Rest finished · Choose slots'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recover a level 2 slot'));
        await tester.pumpAndSettle();
        if (budget == 3) {
          expect(find.text('Recover a level 2 slot'), findsNothing);
          await tester.tap(find.text('Recover a level 1 slot'));
          await tester.pumpAndSettle();
        }
        if (budget == 10) {
          await tester.tap(find.text('Finish Recovery'));
          await tester.pumpAndSettle();
        }
        expect(session.characterState.resourceValues[spellSlotId(2)], 1);
        expect(
          session.characterState.resourceValues[spellSlotId(1)],
          budget == 3 ? 1 : 0,
        );
        expect(session.characterState.resourceValues[pactSlotId(2)], 0);
        if (level == 20) {
          expect(session.characterState.resourceValues[spellSlotId(6)], 0);
        }
        expect(
          session.characterState.resourceValues[arcaneRecoveryResourceId],
          0,
        );
        expect(session.characterState.naturalRecoveryUsed, isFalse);
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        final restored = find.text('Arcane Recovery · After Short Rest');
        await tester.ensureVisible(restored);
        await tester.tap(restored);
        await tester.pumpAndSettle();
        expect(find.text('Short Rest finished · Choose slots'), findsNothing);
        expect(session.usedCombatActions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
