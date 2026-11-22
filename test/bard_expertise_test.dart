import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  for (final level in [2, 9]) {
    testWidgets('Bard Expertise level $level grants independent saved pairs', (
      tester,
    ) async {
      var bard = seedCharacters.first.copyWith(
        characterClass: 'Bard',
        level: level,
        features: [],
        skillProficiencies: {
          for (final id in [
            'arcana',
            'history',
            'investigation',
            'medicine',
            'nature',
            'religion',
          ])
            id: SkillProficiency.proficient,
          'stealth': SkillProficiency.expertise,
        },
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          bard,
        ).copyWith(currentHp: 22, resourceValues: {'custom': 0}),
        inventory: [],
        archivedInventory: [],
        isInCombat: false,
        usedCombatActions: {
          CombatActionCost.action,
          CombatActionCost.bonusAction,
        },
      );
      Widget app() => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(bard.features.length),
          character: bard,
          initialSession: session,
          onCharacterChanged: (v) => bard = v,
          onSessionChanged: (v) => session = v,
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      Future<void> open() async {
        final button = find.text('Bard Expertise · Choose skills');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await open();
      expect(find.widgetWithText(CheckboxListTile, 'Stealth'), findsNothing);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Arcana'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm two Expertise skills'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'History'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Investigation'),
            )
            .onChanged,
        isNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(bard.features, isEmpty);
      await open();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Arcana'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm two Expertise skills'));
      await tester.pumpAndSettle();
      expect(bard.skillProficiencies['arcana'], SkillProficiency.expertise);
      expect(bard.skillProficiencies['history'], SkillProficiency.expertise);
      expect(
        bard.modifierFor(standardSkills.singleWhere((s) => s.id == 'arcana')),
        10,
      );
      bard = Character.fromJson(bard.toJson());
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      if (level == 9) {
        await open();
        expect(find.widgetWithText(CheckboxListTile, 'Arcana'), findsNothing);
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Medicine'));
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Nature'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm two Expertise skills'));
        await tester.pumpAndSettle();
        expect(bard.skillProficiencies['medicine'], SkillProficiency.expertise);
      }
      expect(find.text('Bard Expertise · Choose skills'), findsNothing);
      expect(bard.features.length, level == 9 ? 2 : 1);
      expect(session.characterState.currentHp, 22);
      expect(session.characterState.resourceValues['custom'], 0);
      expect(session.usedCombatActions, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Bard Expertise cannot complete with one eligible skill', (
    tester,
  ) async {
    var bard = seedCharacters.first.copyWith(
      characterClass: 'Bard',
      level: 2,
      features: [],
      skillProficiencies: {
        'arcana': SkillProficiency.proficient,
        'history': SkillProficiency.expertise,
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: bard,
          initialSession: CharacterSession.fromCharacter(bard),
          onCharacterChanged: (v) => bard = v,
          onSessionChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    final button = find.text('Bard Expertise · Choose skills');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Two eligible proficient skills are required. Review your skill proficiencies first.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Arcana'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm two Expertise skills'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(bard.features, isEmpty);
  });
  testWidgets('Bard Expertise uses Bard class level', (tester) async {
    final bard = seedCharacters.first.copyWith(
      characterClass: 'Fighter',
      level: 20,
      additionalClassLevels: {'Bard': 1},
      features: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: bard,
          initialSession: CharacterSession.fromCharacter(bard),
          onCharacterChanged: (_) {},
          onSessionChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Bard Expertise · Choose skills'), findsNothing);
  });
}
