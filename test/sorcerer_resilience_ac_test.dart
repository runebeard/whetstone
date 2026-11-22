import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';

const label = 'Draconic Resilience · Unarmored AC';
Future<void> tap(WidgetTester tester, String text) async {
  final finder = text == label
      ? find.widgetWithText(OutlinedButton, text)
      : find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final (shield, negative, cancel, combat) in [
    (false, false, false, false),
    (true, false, false, true),
    (false, true, false, true),
    (false, false, true, true),
  ]) {
    testWidgets(
      'Draconic AC shield=$shield negative=$negative cancel=$cancel combat=$combat',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: 3,
          subclasses: {'Sorcerer': 'Draconic Sorcery'},
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.dexterity: negative ? 8 : 14,
            Ability.charisma: negative ? 8 : 16,
          },
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(currentHp: 22, maxHp: 42, armourClass: 18),
          inventory: [],
          archivedInventory: [],
          isInCombat: combat,
          usedCombatActions: combat ? CombatActionCost.values.toSet() : {},
        );
        var generation = 0;
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (value) => session = value,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tap(tester, label);
        if (shield) {
          await tap(tester, 'Wielding a Shield · +2 AC');
        }
        final expected = negative
            ? 8
            : shield
            ? 17
            : 15;
        await tap(tester, cancel ? 'Cancel' : 'Unarmored · Apply AC $expected');
        expect(session.characterState.armourClass, cancel ? 18 : expected);
        expect(session.characterState.currentHp, 22);
        expect(session.characterState.maxHp, 42);
        expect(
          session.usedCombatActions,
          combat ? CombatActionCost.values.toSet() : isEmpty,
        );
        final resources = {...session.characterState.resourceValues};
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(session.characterState.armourClass, cancel ? 18 : expected);
        await tap(tester, label);
        await tap(tester, 'Unarmored · Apply AC ${negative ? 8 : 15}');
        expect(session.characterState.armourClass, negative ? 8 : 15);
        expect(session.characterState.resourceValues, resources);
        expect(session.characterState.currentHp, 22);
        expect(session.characterState.maxHp, 42);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final scenario in ['level', 'subclass', 'beast']) {
    testWidgets('Draconic AC rejects $scenario', (tester) async {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Sorcerer',
        level: scenario == 'beast' ? 5 : 3,
        additionalClassLevels: scenario == 'level'
            ? {'Fighter': 1}
            : scenario == 'beast'
            ? {'Druid': 2}
            : {},
        subclasses: {
          'Sorcerer': scenario == 'subclass' ? 'Other' : 'Draconic Sorcery',
        },
      );
      final session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          character,
        ).copyWith(wildShapeForm: scenario == 'beast' ? 'Wolf' : null),
        inventory: [],
        archivedInventory: [],
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
      expect(find.text(label), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
