import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/widgets/skill_grid.dart';

void main() {
  testWidgets('shows alphabetical skills in two columns and emits a check', (
    tester,
  ) async {
    SkillCheck? selectedCheck;
    final character = Character(
      name: 'Skill Tester',
      characterClass: 'Wizard',
      level: 5,
      currentHp: 20,
      maxHp: 20,
      armourClass: 12,
      initiativeModifier: 2,
      status: 'Exploring',
      abilityScores: const {Ability.intelligence: 18, Ability.wisdom: 12},
      proficiencyBonus: 3,
      skillProficiencies: const {
        'arcana': SkillProficiency.proficient,
        'perception': SkillProficiency.expertise,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 328,
              child: SkillGrid(
                character: character,
                onSkillTap: (check) {
                  selectedCheck = check;
                },
              ),
            ),
          ),
        ),
      ),
    );

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.crossAxisCount, 2);
    expect(tester.getSize(find.byType(GridView)).height, lessThan(470));
    expect(find.text('Acrobatics'), findsOneWidget);
    expect(find.text('Survival'), findsOneWidget);

    final displayedNames = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((text) => standardSkills.any((skill) => skill.name == text))
        .cast<String>()
        .toList();
    final sortedNames = [...displayedNames]..sort();

    expect(displayedNames, sortedNames);

    await tester.tap(find.text('Arcana'));
    await tester.pump();

    expect(selectedCheck?.skill.id, 'arcana');
    expect(selectedCheck?.modifier, 7);
    expect(selectedCheck?.proficiency, SkillProficiency.proficient);
  });
}
