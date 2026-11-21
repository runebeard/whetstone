import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/check_roll.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/skill_tile.dart';

import 'support/sequence_dice_roller.dart';

void main() {
  for (final choice in ['Dash', 'Disengage', 'Hide']) {
    testWidgets('Cunning Action $choice preserves Action and Surge', (
      tester,
    ) async {
      final rogue = seedCharacters.first.copyWith(
        characterClass: 'Rogue',
        level: 7,
        skillProficiencies: {'stealth': SkillProficiency.proficient},
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(rogue),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        actionSurge: ActionSurgeState.available,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: rogue,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: SequenceDiceRoller([1]),
          ),
        ),
      );
      final button = find.widgetWithText(OutlinedButton, 'Cunning Action');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Dodge'), findsNothing);
      expect(find.text('Ready'), findsNothing);
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(session.actionSurge, ActionSurgeState.available);
      if (choice == 'Hide') {
        expect(
          session.timeline.first.title,
          'Cunning Action · Hide · Stealth: 15',
        );
        expect(session.timeline.first.detail, contains('Reliable Talent'));
      } else {
        expect(
          session.characterState.activeConditions,
          contains(choice == 'Dash' ? dashingCondition : disengagingCondition),
        );
      }
      await tester.ensureVisible(button);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      await tester.ensureVisible(find.text('Next Turn'));
      await tester.tap(find.text('Next Turn'));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, isEmpty);
      expect(
        session.characterState.activeConditions,
        isNot(contains(dashingCondition)),
      );
      expect(
        session.characterState.activeConditions,
        isNot(contains(disengagingCondition)),
      );
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
    });
  }

  test(
    'a minimum changes the effective result while preserving the natural die',
    () {
      const roll = CheckRoll(
        label: 'Skill',
        naturalRoll: 1,
        modifier: 5,
        minimumRoll: 10,
      );
      expect(roll.total, 15);
      expect(roll.effectiveRoll, 10);
      expect(roll.naturalRoll, 1);
      expect(roll.isNaturalOne, isTrue);
    },
  );

  test(
    'Slippery Mind uses Rogue levels and does not double existing proficiency',
    () {
      final base = seedCharacters.first.copyWith(
        characterClass: 'Rogue',
        level: 15,
        abilityScores: {Ability.wisdom: 12, Ability.charisma: 16},
        proficiencyBonus: 5,
        savingThrowProficiencies: {Ability.wisdom},
      );
      expect(base.savingThrowFor(Ability.wisdom).modifier, 6);
      expect(base.savingThrowFor(Ability.charisma).modifier, 8);
      expect(
        base.copyWith(level: 14).savingThrowFor(Ability.charisma).modifier,
        3,
      );
      expect(
        base
            .copyWith(level: 20, additionalClassLevels: {'Fighter': 6})
            .savingThrowFor(Ability.charisma)
            .modifier,
        3,
      );
    },
  );

  for (final (level, proficiency, die, total) in [
    (6, SkillProficiency.proficient, 1, 6),
    (7, SkillProficiency.proficient, 1, 15),
    (7, SkillProficiency.expertise, 4, 18),
    (7, SkillProficiency.none, 1, 3),
    (7, SkillProficiency.proficient, 17, 22),
  ]) {
    testWidgets(
      'Reliable Talent level $level proficiency=$proficiency natural=$die',
      (tester) async {
        final rogue = seedCharacters.first.copyWith(
          characterClass: 'Rogue',
          level: level,
          skillProficiencies: {'stealth': proficiency},
        );
        var session = CharacterSession.fromCharacter(rogue);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: rogue,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
              diceRoller: SequenceDiceRoller([die]),
            ),
          ),
        );
        final stealth = find.widgetWithText(SkillTile, 'Stealth');
        await tester.ensureVisible(stealth);
        await tester.tap(stealth);
        await tester.pumpAndSettle();
        expect(session.timeline.first.title, 'Stealth: $total');
        if (level >= 7 && proficiency != SkillProficiency.none && die < 10) {
          expect(
            session.timeline.first.detail,
            contains('Reliable Talent: use 10'),
          );
          expect(session.timeline.first.detail, contains('d20 $die → 10'));
        }
      },
    );
  }
}
