import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/conditions_box.dart';
import 'package:whetstone/widgets/conditions_dialog.dart';
import 'package:whetstone/widgets/initiative_box.dart';
import 'package:whetstone/widgets/skill_tile.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  final character = seedCharacters.first;
  testWidgets(
    'Exhaustion reduces a skill check without changing its ability score',
    (tester) async {
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          character,
        ).copyWith(exhaustionLevel: 3),
        inventory: [],
        archivedInventory: [],
        isInCombat: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: SequenceDiceRoller([10]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final skill = find.byWidgetPredicate(
        (w) => w is SkillTile && w.check.skill.id == 'acrobatics',
      );
      await tester.ensureVisible(skill);
      await tester.tap(skill);
      await tester.pumpAndSettle();
      final base = character.modifierFor(
        standardSkills.singleWhere((s) => s.id == 'acrobatics'),
      );
      expect(session.timeline.first.title, endsWith(': ${10 + base - 6}'));
      expect(character.scoreFor(Ability.dexterity), 14);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Exhaustion reduces weapon attacks while damage stays unchanged',
    (tester) async {
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          character,
        ).copyWith(exhaustionLevel: 2),
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
            diceRoller: SequenceDiceRoller([10, 6]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final attack = find.byKey(
        const ValueKey('attack-attacks-weapon:quarterstaff'),
      );
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, endsWith(': 8'));
      final damage = find.byKey(
        const ValueKey('damage-attacks-weapon:quarterstaff'),
      );
      await tester.ensureVisible(damage);
      await tester.tap(damage);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('latest-roll-total')))
            .data,
        '5',
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (var level = 0; level <= 6; level++) {
    test('Exhaustion $level persists and recovers one level on Long Rest', () {
      final state = CharacterState.fromCharacter(character).copyWith(
        exhaustionLevel: level,
        currentHp: 10,
        activeConditions: {'Poisoned'},
      );
      final restored = CharacterState.fromJson(state.toJson());
      expect(restored.exhaustionLevel, level);
      expect(restored.exhaustionPenalty, 2 * level);
      expect(restored.exhaustionSpeedReduction, 5 * level);
      expect(restored.copyWith(currentHp: 9).exhaustionLevel, level);
      expect(restored.copyWith(exhaustionLevel: -1).exhaustionLevel, 0);
      expect(restored.copyWith(exhaustionLevel: 20).exhaustionLevel, 6);
      final short = RestPlan.forCharacter(
        type: RestType.shortRest,
        character: character,
        currentState: restored,
      );
      final long = RestPlan.forCharacter(
        type: RestType.longRest,
        character: character,
        currentState: restored,
      );
      expect(short.updatedState.exhaustionLevel, level);
      expect(
        long.updatedState.exhaustionLevel,
        level == 6 ? 6 : (level - 1).clamp(0, 6),
      );
      if (level == 6) {
        expect(long.updatedState.currentHp, 10);
        expect(long.hasChanges, isFalse);
        expect(state.canConcentrate, isFalse);
        expect(state.copyWith(currentHp: 0).canRollDeathSave, isFalse);
      }
    });
  }
  test(
    'Older state defaults to no Exhaustion and imported levels are bounded',
    () {
      final json = CharacterState.fromCharacter(character).toJson();
      expect(json.containsKey('exhaustionLevel'), isFalse);
      expect(CharacterState.fromJson(json).exhaustionLevel, 0);
      expect(
        CharacterState.fromJson({
          ...json,
          'exhaustionLevel': 20,
        }).exhaustionLevel,
        6,
      );
      expect(
        CharacterState.fromJson({
          ...json,
          'exhaustionLevel': -3,
        }).exhaustionLevel,
        0,
      );
    },
  );

  testWidgets(
    'Exhaustion controls persist through condition changes and reload',
    (tester) async {
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          character,
        ).copyWith(activeConditions: {'Poisoned'}),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      Widget app(int generation) => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(generation),
          character: character,
          initialSession: session,
          onCharacterChanged: (_) {},
          onSessionChanged: (v) => session = v,
        ),
      );
      await tester.pumpWidget(app(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ConditionsBox));
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byTooltip('Increase Exhaustion'));
        await tester.pumpAndSettle();
      }
      expect(session.characterState.exhaustionLevel, 6);
      expect(find.textContaining('Six levels cause death'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Increase Exhaustion',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Reduce Exhaustion'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Poisoned'),
        200,
        scrollable: find.descendant(
          of: find.byType(ConditionsDialog),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Poisoned'));
      await tester.pumpAndSettle();
      expect(session.characterState.activeConditions, isEmpty);
      expect(session.characterState.exhaustionLevel, 5);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      expect(session.characterState.exhaustionLevel, 5);
      expect(find.text('• Exhaustion · 5 / 6'), findsOneWidget);
      expect(
        session.timeline.any((event) => event.title == 'Exhaustion: 6 → 5'),
        isTrue,
      );
      expect(
        session.timeline.any(
          (event) =>
              event.title == 'Exhaustion: 5 → 6' &&
              event.detail!.contains('death'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final reroll in [false, true]) {
    testWidgets('Exhaustion applies once to a save with Survivor=$reroll', (
      tester,
    ) async {
      final monk = character.copyWith(
        characterClass: 'Monk',
        level: reroll ? 14 : 1,
        resources: BuiltInClass.monk.classResources(
          reroll ? 14 : 1,
          charismaModifier: 0,
        ),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          monk,
        ).copyWith(exhaustionLevel: 2),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([10, 10]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: monk,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final save = find.byTooltip('Intelligence saving throw');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      if (reroll) {
        await tester.tap(find.text('Spend 1 Focus · Reroll Failed Save'));
        await tester.pumpAndSettle();
      }
      final expected =
          10 + monk.savingThrowFor(Ability.intelligence).modifier - 4;
      expect(session.timeline.first.title, endsWith(': $expected'));
      expect(dice.index, reroll ? 2 : 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final natural in [1, 10, 20]) {
    testWidgets(
      'Exhaustion affects death-save totals but preserves natural $natural',
      (tester) async {
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(currentHp: 0, exhaustionLevel: 2),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character.copyWith(characterClass: 'Cleric', level: 1),
              initialSession: session,
              onCharacterChanged: (_) {},
              onSessionChanged: (v) => session = v,
              diceRoller: SequenceDiceRoller([natural]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final roll = find.byKey(const ValueKey('roll-death-save'));
        await tester.ensureVisible(roll);
        await tester.tap(roll);
        await tester.pumpAndSettle();
        expect(session.characterState.currentHp, natural == 20 ? 1 : 0);
        expect(
          session.characterState.deathSaveFailures,
          natural == 20
              ? 0
              : natural == 1
              ? 2
              : 1,
        );
        expect(session.characterState.deathSaveSuccesses, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Initiative subtracts Exhaustion without changing the saved modifier',
    (tester) async {
      final hero = character.copyWith(
        characterClass: 'Cleric',
        level: 1,
        initiativeModifier: 3,
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          hero,
        ).copyWith(exhaustionLevel: 2),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: hero,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: SequenceDiceRoller([10]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InitiativeBox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record Initiative'));
      await tester.pumpAndSettle();
      expect(session.characterState.initiativeModifier, 3);
      expect(session.combatInitiative, 9);
      expect(tester.takeException(), isNull);
    },
  );
}
