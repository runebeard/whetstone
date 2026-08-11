import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/widgets/saving_throw_grid.dart';

void main() {
  testWidgets('saving throws calculate proficiency and emit checks', (
    tester,
  ) async {
    SavingThrowCheck? selectedCheck;
    final character = Character(
      name: 'Save Tester',
      characterClass: 'Wizard',
      level: 5,
      currentHp: 20,
      maxHp: 20,
      armourClass: 12,
      initiativeModifier: 2,
      status: 'In Combat',
      abilityScores: const {Ability.intelligence: 18},
      proficiencyBonus: 3,
      savingThrowProficiencies: const {Ability.intelligence},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 328,
            child: SavingThrowGrid(
              character: character,
              onSavingThrowTap: (check) {
                selectedCheck = check;
              },
            ),
          ),
        ),
      ),
    );

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.crossAxisCount, 3);
    expect(find.text('+7'), findsOneWidget);

    await tester.tap(find.text('INT'));
    await tester.pump();

    expect(selectedCheck?.ability, Ability.intelligence);
    expect(selectedCheck?.modifier, 7);
    expect(selectedCheck?.proficient, isTrue);
  });
}
