import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  testWidgets(
    'Lore grants exactly three new proficiencies, preserves existing grants and reloads',
    (tester) async {
      var bard = seedCharacters.first.copyWith(
        characterClass: 'Bard',
        level: 3,
        subclasses: {'Bard': 'College of Lore'},
        features: [],
        skillProficiencies: {
          'athletics': SkillProficiency.proficient,
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
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      Future<void> open() async {
        final button = find.text('Lore Bard · Choose three skills');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await open();
      expect(find.widgetWithText(CheckboxListTile, 'Athletics'), findsNothing);
      expect(find.widgetWithText(CheckboxListTile, 'Stealth'), findsNothing);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Acrobatics'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm three proficiencies'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(bard.features, isEmpty);
      expect(bard.skillProficiencies['acrobatics'], isNull);
      await open();
      for (final name in ['Acrobatics', 'Animal Handling', 'Arcana']) {
        final checkbox = find.widgetWithText(CheckboxListTile, name);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Deception'),
            )
            .onChanged,
        isNull,
      );
      await tester.tap(find.text('Confirm three proficiencies'));
      await tester.pumpAndSettle();
      for (final id in ['acrobatics', 'animal_handling', 'arcana']) {
        // Resolve the standard skill ID instead of assuming its separator.
        final skill = standardSkills.singleWhere(
          (s) => s.name.toLowerCase().replaceAll(' ', '_') == id,
        );
        expect(bard.proficiencyFor(skill), SkillProficiency.proficient);
      }
      expect(bard.skillProficiencies['athletics'], SkillProficiency.proficient);
      expect(bard.skillProficiencies['stealth'], SkillProficiency.expertise);
      expect(bard.features.single.id, 'whetstone:class:lore-proficiencies');
      bard = Character.fromJson(bard.toJson());
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(app());
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Lore Bard · Choose three skills'), findsNothing);
      expect(find.text('Bard Expertise · Choose skills'), findsOneWidget);
      expect(session.characterState.currentHp, 22);
      expect(session.characterState.resourceValues['custom'], 0);
      expect(session.usedCombatActions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Lore choice requires class level three and Lore subclass', (
    tester,
  ) async {
    for (final (level, subclass) in [(2, 'College of Lore'), (3, 'Other')]) {
      final bard = seedCharacters.first.copyWith(
        characterClass: 'Bard',
        level: level,
        subclasses: {'Bard': subclass},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            key: ValueKey('$level-$subclass'),
            character: bard,
            initialSession: CharacterSession.fromCharacter(bard),
            onCharacterChanged: (_) {},
            onSessionChanged: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Lore Bard · Choose three skills'), findsNothing);
    }
  });
}
