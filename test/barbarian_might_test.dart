import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/check_roll.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/skill_tile.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  test(
    'Minimum totals preserve natural dice and apply after modifiers and minimum rolls',
    () {
      const low = CheckRoll(
        label: 'Strength',
        naturalRoll: 1,
        modifier: 5,
        minimumTotal: 20,
      );
      expect(low.total, 20);
      expect(low.unadjustedTotal, 6);
      expect(low.naturalRoll, 1);
      expect(low.isNaturalOne, true);
      const negative = CheckRoll(
        label: 'Check',
        naturalRoll: 2,
        modifier: -3,
        minimumTotal: 8,
      );
      expect(negative.total, 8);
      const combined = CheckRoll(
        label: 'Check',
        naturalRoll: 1,
        modifier: 12,
        minimumRoll: 10,
        minimumTotal: 20,
      );
      expect(combined.total, 22);
      expect(combined.effectiveRoll, 10);
    },
  );
  for (final (primary, level, secondary, applies) in [
    ('Barbarian', 18, 0, true),
    ('Barbarian', 17, 0, false),
    ('Fighter', 20, 17, false),
  ]) {
    testWidgets('Indomitable Might $primary $level Barbarian secondary $secondary', (
      tester,
    ) async {
      final character = seedCharacters.first.copyWith(
        characterClass: primary,
        level: level,
        additionalClassLevels: secondary == 0 ? {} : {'Barbarian': secondary},
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.strength: 20,
        },
        skillProficiencies: {},
        savingThrowProficiencies: {},
        resources: [],
      );
      var session = CharacterSession.fromCharacter(character);
      final dice = SequenceDiceRoller([1, 20, 1, 1, 1]);
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
      final athletics = standardSkills.singleWhere((s) => s.id == 'athletics');
      final tile = find.byWidgetPredicate(
        (w) => w is SkillTile && w.check.skill.id == athletics.id,
      );
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(tile);
      expect(
        session.timeline.first.title,
        'Athletics: ${applies ? 20 : 1 + character.modifierFor(athletics)}',
      );
      if (applies) {
        expect(session.timeline.first.detail, contains('Indomitable Might'));
      }
      await tap(tile);
      expect(
        session.timeline.first.title,
        'Athletics: ${20 + character.modifierFor(athletics)}',
      );
      await tap(find.text('Combat'));
      await tap(find.byIcon(Icons.check));
      await tap(find.byTooltip('Strength saving throw'));
      // This Fighter fixture stays below Indomitable's own reroll threshold by using only three Fighter levels.
      if (find.text('Keep Result').evaluate().isNotEmpty) {
        await tap(find.text('Keep Result'));
      }
      expect(
        session.timeline.first.title,
        'Strength Save: ${applies ? 20 : 1 + character.savingThrowFor(Ability.strength).modifier}',
      );
      await tap(find.byTooltip('Dexterity saving throw'));
      if (find.text('Keep Result').evaluate().isNotEmpty) {
        await tap(find.text('Keep Result'));
      }
      expect(
        session.timeline.first.title,
        'Dexterity Save: ${1 + character.savingThrowFor(Ability.dexterity).modifier}',
      );
      expect(session.usedCombatActions, isEmpty);
      expect(session.characterState.currentHp, character.currentHp);
      expect(dice.index, 5);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Indomitable Might never changes an attack total', (
    tester,
  ) async {
    const weapon = Weapon(
      id: 'might-test',
      name: 'Test axe',
      attackModifier: 5,
      damage: '1d6',
    );
    final character = seedCharacters.first.copyWith(
      characterClass: 'Barbarian',
      level: 18,
      weapons: [weapon],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(character),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: character,
          initialSession: session,
          onCharacterChanged: (_) {},
          onSessionChanged: (v) => session = v,
          diceRoller: SequenceDiceRoller([1]),
        ),
      ),
    );
    final button = find.byKey(ValueKey('attack-attacks-${weapon.actionKey}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Test axe Attack: 6');
    expect(session.timeline.first.detail, isNot(contains('Indomitable Might')));
  });
}
