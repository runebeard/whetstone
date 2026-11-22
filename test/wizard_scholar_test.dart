import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/feature.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  for (final id in [
    'arcana',
    'history',
    'investigation',
    'medicine',
    'nature',
    'religion',
  ]) {
    testWidgets(
      'Scholar chooses $id without changing live state and survives export',
      (tester) async {
        final skill = standardSkills.singleWhere((s) => s.id == id);
        final existing = id == 'arcana' ? 'history' : 'arcana';
        var wizard = seedCharacters.first.copyWith(
          level: 2,
          features: [],
          skillProficiencies: {
            id: SkillProficiency.proficient,
            existing: SkillProficiency.expertise,
            'athletics': SkillProficiency.proficient,
          },
        );
        final before = wizard.modifierFor(skill);
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            wizard,
          ).copyWith(currentHp: 21, resourceValues: {'arcane_recovery': 0}),
          inventory: [],
          archivedInventory: [],
        );
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(wizard.features.length),
            character: wizard,
            initialSession: session,
            onCharacterChanged: (v) => wizard = v,
            onSessionChanged: (v) => session = v,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        final button = find.text('Scholar · Choose Expertise');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('Expertise · Athletics'), findsNothing);
        expect(
          find.text(
            'Expertise · ${standardSkills.singleWhere((s) => s.id == existing).name}',
          ),
          findsNothing,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(wizard.proficiencyFor(skill), SkillProficiency.proficient);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Expertise · ${skill.name}'));
        await tester.pumpAndSettle();
        expect(wizard.proficiencyFor(skill), SkillProficiency.expertise);
        expect(wizard.modifierFor(skill), before + wizard.proficiencyBonus);
        expect(wizard.skillProficiencies[existing], SkillProficiency.expertise);
        expect(session.characterState.currentHp, 21);
        expect(session.characterState.resourceValues['arcane_recovery'], 0);
        expect(session.usedCombatActions, isEmpty);
        wizard = Character.fromJson(wizard.toJson());
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(find.text('Scholar · Choose Expertise'), findsNothing);
        expect(
          wizard.features
              .where((f) => f.id == 'whetstone:class:scholar')
              .length,
          1,
        );
        expect(wizard.proficiencyFor(skill), SkillProficiency.expertise);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Scholar does not grant an untrained skill or duplicate Expertise',
    (tester) async {
      var wizard = seedCharacters.first.copyWith(
        level: 2,
        features: [],
        skillProficiencies: {
          'arcana': SkillProficiency.expertise,
          'perception': SkillProficiency.proficient,
        },
      );
      final session = CharacterSession.fromCharacter(wizard);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: wizard,
            initialSession: session,
            onCharacterChanged: (v) => wizard = v,
            onSessionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      final button = find.text('Scholar · Choose Expertise');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No eligible proficient skill without Expertise. Review your skill proficiencies before choosing.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(wizard.features, isEmpty);
    },
  );
  testWidgets('Scholar requires two Wizard class levels', (tester) async {
    for (final multiclass in [false, true]) {
      final wizard = seedCharacters.first.copyWith(
        characterClass: multiclass ? 'Fighter' : 'Wizard',
        level: multiclass ? 20 : 1,
        additionalClassLevels: multiclass ? {'Wizard': 1} : {},
        features: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            key: ValueKey(multiclass),
            character: wizard,
            initialSession: CharacterSession.fromCharacter(wizard),
            onCharacterChanged: (_) {},
            onSessionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Scholar · Choose Expertise'), findsNothing);
    }
  });
  testWidgets('Legacy Scholar feature prevents a second grant', (tester) async {
    final wizard = seedCharacters.first.copyWith(
      features: [
        const Feature(
          id: 'legacy_scholar',
          name: 'Scholar',
          summary: 'Previously granted Expertise',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: wizard,
          initialSession: CharacterSession.fromCharacter(wizard),
          onCharacterChanged: (_) {},
          onSessionChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Scholar · Choose Expertise'), findsNothing);
  });
}
