import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/skill_tile.dart';
import 'support/sequence_dice_roller.dart';

const weapon = Weapon(
  id: 'peerless-test',
  name: 'Test blade',
  attackModifier: 3,
  damage: '1d6',
  damageFormula: '1d6',
);
const peerlessLabel = 'Peerless Skill · Last check or attack';

void main() {
  for (final (attack, success) in [
    (false, true),
    (false, false),
    (true, true),
    (true, false),
  ]) {
    testWidgets(
      'Peerless attack=$attack success=$success spends only on success once per roll',
      (tester) async {
        final bard = seedCharacters.first.copyWith(
          characterClass: 'Bard',
          level: 14,
          subclasses: {'Bard': 'College of Lore'},
          weapons: [weapon],
          skillProficiencies: {},
          resources: BuiltInClass.bard.classResources(14, charismaModifier: 3),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            bard,
          ).copyWith(resourceValues: {bardicInspirationResourceId: 2}),
          inventory: [],
          archivedInventory: [],
          isInCombat: attack,
          usedCombatActions: attack
              ? {CombatActionCost.bonusAction, CombatActionCost.reaction}
              : {},
        );
        final dice = SequenceDiceRoller([4, success ? 6 : 2]);
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(session.timeline.length),
            character: bard,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        final button = find.widgetWithText(OutlinedButton, peerlessLabel);
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        if (attack) {
          final hit = find.byKey(
            ValueKey('attack-attacks-${weapon.actionKey}'),
          );
          await tester.ensureVisible(hit);
          await tester.tap(hit);
        } else {
          final skill = find.byWidgetPredicate(
            (w) => w is SkillTile && w.check.skill.id == 'acrobatics',
          );
          await tester.ensureVisible(skill);
          await tester.tap(skill);
        }
        await tester.pumpAndSettle();
        final original = attack
            ? 7
            : 4 +
                  bard.modifierFor(
                    standardSkills.singleWhere((s) => s.id == 'acrobatics'),
                  );
        final originalCosts = {...session.usedCombatActions};
        Future<void> open() async {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
        }

        await open();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(dice.index, 1);
        expect(
          session.characterState.resourceValues[bardicInspirationResourceId],
          2,
        );
        await open();
        await tester.enterText(find.byType(TextField), '${original + 4}');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(
          session.timeline.first.title,
          'Peerless Skill · ${attack ? 'Test blade Attack' : 'Acrobatics'}: ${original + (success ? 6 : 2)}',
        );
        expect(
          session.timeline.first.detail,
          contains(success ? 'One Inspiration spent' : 'Inspiration retained'),
        );
        expect(
          session.characterState.resourceValues[bardicInspirationResourceId],
          success ? 1 : 2,
        );
        expect(session.usedCombatActions, originalCosts);
        expect(dice.index, 2);
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Peerless excludes automatic attack misses and critical hits', (
    tester,
  ) async {
    for (final natural in [1, 20]) {
      final bard = seedCharacters.first.copyWith(
        characterClass: 'Bard',
        level: 14,
        subclasses: {'Bard': 'College of Lore'},
        weapons: [weapon],
        resources: BuiltInClass.bard.classResources(14, charismaModifier: 3),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            key: ValueKey(natural),
            character: bard,
            initialSession: CharacterSession(
              characterState: CharacterState.fromCharacter(bard),
              inventory: [],
              archivedInventory: [],
              isInCombat: true,
            ),
            onCharacterChanged: (_) {},
            onSessionChanged: (_) {},
            diceRoller: SequenceDiceRoller([natural]),
          ),
        ),
      );
      final hit = find.byKey(ValueKey('attack-attacks-${weapon.actionKey}'));
      await tester.ensureVisible(hit);
      await tester.tap(hit);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, peerlessLabel),
            )
            .onPressed,
        isNull,
      );
    }
  });
  testWidgets(
    'Peerless rejects a successful total and expires on saves or next turn',
    (tester) async {
      final bard = seedCharacters.first.copyWith(
        characterClass: 'Bard',
        level: 14,
        subclasses: {'Bard': 'College of Lore'},
        weapons: [weapon],
        resources: BuiltInClass.bard.classResources(14, charismaModifier: 3),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(bard),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([4, 3, 5]);
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
      final hit = find.byKey(ValueKey('attack-attacks-${weapon.actionKey}'));
      final button = find.widgetWithText(OutlinedButton, peerlessLabel);
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(hit);
      await tap(button);
      await tester.enterText(find.byType(TextField), '7');
      await tap(find.text('Save'));
      expect(dice.index, 1);
      expect(
        session.characterState.resourceValues[bardicInspirationResourceId],
        3,
      );
      await tap(find.byTooltip('Intelligence saving throw'));
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      await tap(find.text('Next Turn'));
      await tap(hit);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      await tap(find.text('Next Turn'));
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(dice.index, 3);
    },
  );
  testWidgets('Peerless requires fourteen Bard levels and Lore subclass', (
    tester,
  ) async {
    for (final (level, subclass) in [(13, 'College of Lore'), (14, 'Other')]) {
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
      expect(find.text(peerlessLabel), findsNothing);
    }
  });
}
