import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character_session.dart';

import 'package:whetstone/models/skill.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/skill_tile.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  test(
    'Jack of All Trades rounds down and never stacks with proficiency or Expertise',
    () {
      final skill = standardSkills.singleWhere((s) => s.id == 'acrobatics');
      for (final pb in [2, 3, 4, 5, 6]) {
        for (final proficiency in SkillProficiency.values) {
          final bard = seedCharacters.first.copyWith(
            characterClass: 'Bard',
            level: 2,
            proficiencyBonus: pb,
            skillProficiencies: {skill.id: proficiency},
          );
          expect(
            bard.modifierFor(skill),
            2 +
                (proficiency == SkillProficiency.none
                    ? pb ~/ 2
                    : proficiency == SkillProficiency.proficient
                    ? pb
                    : 2 * pb),
          );
          expect(bard.proficiencyFor(skill), proficiency);
          expect(bard.initiativeModifier, 2);
          expect(bard.savingThrowFor(Ability.dexterity).modifier, 2);
        }
      }
    },
  );
  test(
    'Jack requires two Bard class levels and respects already-proficient Beast minima',
    () {
      final skill = standardSkills.singleWhere((s) => s.id == 'acrobatics');
      final base = seedCharacters.first.copyWith(
        characterClass: 'Fighter',
        level: 20,
        additionalClassLevels: {'Bard': 1},
        skillProficiencies: {},
      );
      expect(base.modifierFor(skill), 2);
      final bard = base.copyWith(
        additionalClassLevels: {'Bard': 2},
        skillModifierMinimums: {'acrobatics': 3},
      );
      expect(bard.modifierFor(skill), 3);
      expect(bard.jackOfAllTradesBonusFor(skill), 0);
    },
  );
  testWidgets(
    'Jack applies to skill rolls without activating Reliable Talent',
    (tester) async {
      final bard = seedCharacters.first.copyWith(
        characterClass: 'Rogue',
        level: 9,
        additionalClassLevels: {'Bard': 2},
        skillProficiencies: {},
      );
      var session = CharacterSession.fromCharacter(bard);
      final dice = SequenceDiceRoller([2]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: bard,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        ),
      );
      final tile = find.byWidgetPredicate(
        (w) => w is SkillTile && w.check.skill.id == 'acrobatics',
      );
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Acrobatics: 5');
      expect(session.timeline.first.detail, contains('Jack of All Trades +1'));
      expect(session.timeline.first.detail, isNot(contains('Reliable Talent')));
      expect(dice.index, 1);
    },
  );
}

