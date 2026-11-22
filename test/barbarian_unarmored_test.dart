import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  for (final (combat, shield) in [(true, false), (true, true), (false, true)]) {
    testWidgets(
      'Barbarian defense combat=$combat shield=$shield replaces AC and preserves live state',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: 5,
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.dexterity: 14,
            Ability.constitution: 16,
          },
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(armourClass: 18, resourceValues: {'custom': 0}),
          inventory: [],
          archivedInventory: [],
          isInCombat: combat,
          usedCombatActions: combat ? CombatActionCost.values.toSet() : {},
        );
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(session.characterState.armourClass),
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
          ),
        );
        await tester.pumpWidget(app());
        final button = find.widgetWithText(
          OutlinedButton,
          'Barbarian · Unarmored Defense',
        );
        Future<void> open() async {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
        }

        await open();
        expect(find.textContaining('does not stack'), findsOneWidget);
        expect(find.textContaining('Fast Movement'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.characterState.armourClass, 18);
        await open();
        if (shield) {
          await tester.tap(find.text('Wielding a Shield · +2 AC'));
          await tester.pumpAndSettle();
        }
        final ac = shield ? 17 : 15;
        await tester.tap(find.text('Unarmored · Apply AC $ac'));
        await tester.pumpAndSettle();
        expect(session.characterState.armourClass, ac);
        expect(session.characterState.currentHp, character.currentHp);
        expect(session.characterState.resourceValues['custom'], 0);
        expect(
          session.usedCombatActions,
          combat ? CombatActionCost.values.toSet() : isEmpty,
        );
        expect(session.timeline.first.title, 'Barbarian Unarmored Defense');
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(session.characterState.armourClass, ac);
        // Reapplying the base formula replaces the previous total instead of stacking.
        await open();
        await tester.tap(find.text('Unarmored · Apply AC 15'));
        await tester.pumpAndSettle();
        expect(session.characterState.armourClass, 15);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Barbarian defense is unavailable without a Barbarian class level',
    (tester) async {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Monk',
        level: 5,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: CharacterSession.fromCharacter(character),
            onCharacterChanged: (_) {},
            onSessionChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Barbarian · Unarmored Defense'), findsNothing);
    },
  );
}
