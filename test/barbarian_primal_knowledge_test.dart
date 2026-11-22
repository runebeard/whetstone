import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/skill_tile.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  for (final (id, proficiency, level) in [
    ('acrobatics', SkillProficiency.none, 3),
    ('intimidation', SkillProficiency.proficient, 3),
    ('perception', SkillProficiency.expertise, 3),
    ('stealth', SkillProficiency.none, 18),
    ('survival', SkillProficiency.proficient, 3),
  ]) {
    testWidgets(
      'Primal Knowledge $id retains $proficiency at Barbarian $level',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: level,
          proficiencyBonus: 3,
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.strength: 18,
          },
          skillProficiencies: {id: proficiency},
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            activeConditions: {ragingCondition},
            resourceValues: {'custom': 1},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: false,
        );
        final dice = SequenceDiceRoller([2, 5]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              onCharacterChanged: (_) {},
              onSessionChanged: (v) => session = v,
              diceRoller: dice,
            ),
          ),
        );
        final tile = find.byWidgetPredicate(
          (w) => w is SkillTile && w.check.skill.id == id,
        );
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(dice.index, 0);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use Strength'));
        await tester.pumpAndSettle();
        final total = level == 18 ? 18 : 9 + 3 * proficiency.index;
        final name = standardSkills.singleWhere((s) => s.id == id).name;
        expect(session.timeline.first.title, '$name: $total');
        expect(session.timeline.first.detail, contains('Primal Knowledge'));
        expect(session.timeline.first.detail, contains('Advantage: 2, 5'));
        expect(session.characterState.resourceValues['custom'], 1);
        expect(session.usedCombatActions, isEmpty);
        expect(session.characterState.currentHp, character.currentHp);
        expect(dice.index, 2);
      },
    );
  }
  testWidgets(
    'Primal Knowledge Hide cancellation preserves the action and normal ability remains selectable',
    (tester) async {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Barbarian',
        level: 3,
        skillProficiencies: {},
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.strength: 18,
        },
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          character,
        ).copyWith(activeConditions: {ragingCondition}),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([4]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        ),
      );
      Future<void> hide() async {
        final button = find.text('Use an Action');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hide'));
        await tester.pumpAndSettle();
      }

      await hide();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, isEmpty);
      expect(dice.index, 0);
      await hide();
      await tester.tap(find.text('Use Dexterity'));
      await tester.pumpAndSettle();
      expect(
        session.timeline.first.title,
        'Hide · Stealth: ${4 + character.modifierFor(standardSkills.singleWhere((s) => s.id == 'stealth'))}',
      );
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(dice.index, 1);
    },
  );
  testWidgets(
    'Primal Knowledge roll choice requires Rage, class level and an eligible skill',
    (tester) async {
      for (final (level, raging, id) in [
        (2, true, 'stealth'),
        (3, false, 'stealth'),
        (3, true, 'arcana'),
      ]) {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: level,
          skillProficiencies: {},
        );
        final session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(activeConditions: raging ? {ragingCondition} : {}),
          inventory: [],
          archivedInventory: [],
          isInCombat: false,
        );
        final dice = SequenceDiceRoller([4]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey('$level-$raging-$id'),
              character: character,
              initialSession: session,
              onCharacterChanged: (_) {},
              onSessionChanged: (_) {},
              diceRoller: dice,
            ),
          ),
        );
        final tile = find.byWidgetPredicate(
          (w) => w is SkillTile && w.check.skill.id == id,
        );
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(find.text('Use Strength'), findsNothing);
        expect(dice.index, 1);
      }
    },
  );
  testWidgets(
    'Primal Knowledge proficiency restricts choices and saves a single grant',
    (tester) async {
      var character = seedCharacters.first.copyWith(
        characterClass: 'Barbarian',
        level: 3,
        features: [],
        skillProficiencies: {
          'athletics': SkillProficiency.proficient,
          'nature': SkillProficiency.expertise,
        },
      );
      var session = CharacterSession.fromCharacter(character);
      Widget app() => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(character.features.length),
          character: character,
          initialSession: session,
          onCharacterChanged: (v) => character = v,
          onSessionChanged: (v) => session = v,
        ),
      );
      await tester.pumpWidget(app());
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      Future<void> open() async {
        final button = find.text('Primal Knowledge · Choose skill');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await open();
      for (final name in ['Athletics', 'Nature', 'Arcana']) {
        expect(find.widgetWithText(SimpleDialogOption, name), findsNothing);
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(character.features, isEmpty);
      await open();
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Perception'));
      await tester.pumpAndSettle();
      expect(
        character.skillProficiencies['perception'],
        SkillProficiency.proficient,
      );
      expect(
        character.skillProficiencies['nature'],
        SkillProficiency.expertise,
      );
      expect(
        character.features.single.id,
        'whetstone:class:primal-knowledge-skill',
      );
      character = Character.fromJson(character.toJson());
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(app());
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Primal Knowledge · Choose skill'), findsNothing);
      expect(session.characterState.currentHp, seedCharacters.first.currentHp);
    },
  );
}
