import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';

import 'support/sequence_dice_roller.dart';

void main() {
  testWidgets(
    'Aura of Protection applies to concentration saves after damage',
    (tester) async {
      final paladin = seedCharacters.first.copyWith(
        characterClass: 'Paladin',
        level: 6,
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.charisma: 16,
        },
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          paladin,
        ).copyWith(concentrationSpellId: 'detect_magic'),
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
            diceRoller: SequenceDiceRoller([5]),
          ),
        ),
      );
      await tester.tap(find.text('34 / 42'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2');
      await tester.tap(find.textContaining('Damage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Roll Save'));
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Concentration Save: 10');
      expect(session.characterState.concentrationSpellId, 'detect_magic');
      expect(find.text('DC 10 · Concentration maintained'), findsOneWidget);
    },
  );

  test('live save bonuses apply after Beast minima and are not serialized', () {
    final character = seedCharacters.first.copyWith(
      abilityScores: {Ability.dexterity: 10},
      savingThrowProficiencies: {},
      saveModifierMinimums: {Ability.dexterity: 4},
      savingThrowBonus: 3,
    );
    expect(character.savingThrowFor(Ability.dexterity).modifier, 7);
    expect(character.copyWith(name: 'Renamed').savingThrowBonus, 3);
    expect(Character.fromJson(character.toJson()).savingThrowBonus, 0);
  });

  for (final (level, charisma, incapacitated, total, radius) in [
    (5, 16, false, 12, 0),
    (6, 16, false, 15, 10),
    (6, 8, false, 13, 10),
    (6, 16, true, 12, 0),
    (18, 16, false, 15, 30),
  ]) {
    testWidgets(
      'Paladin $level CHA $charisma incapacitated=$incapacitated aura',
      (tester) async {
        final paladin = seedCharacters.first.copyWith(
          characterClass: 'Paladin',
          level: level,
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.charisma: charisma,
          },
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            paladin,
          ).copyWith(activeConditions: incapacitated ? {'Incapacitated'} : {}),
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
              diceRoller: SequenceDiceRoller([10]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (radius > 0) {
          expect(find.textContaining('$radius-foot Emanation'), findsOneWidget);
        } else {
          expect(find.textContaining('Aura of Protection +'), findsNothing);
        }
        final save = find.byTooltip('Dexterity saving throw');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(session.timeline.first.title, 'Dexterity Save: $total');
      },
    );
  }
}
