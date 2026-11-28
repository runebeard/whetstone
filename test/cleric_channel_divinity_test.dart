import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as helpers;
import 'support/sequence_dice_roller.dart';

Character cleric(int level, {int wisdom = 16}) => seedCharacters.first.copyWith(
  characterClass: 'Cleric',
  level: level,
  abilityScores: {Ability.wisdom: wisdom},
  resources: BuiltInClass.cleric.classResources(level, charismaModifier: 0),
);

Future<void> openPool(WidgetTester tester, int remaining) => helpers.tap(
  tester,
  find.byKey(ValueKey('resource-$clericChannelDivinityId-$remaining')),
);

void main() {
  for (final (level, fighter, dice) in [
    (2, 0, 1),
    (7, 0, 2),
    (13, 0, 3),
    (18, 0, 4),
    (20, 18, 1),
  ]) {
    testWidgets(
      'Divine Spark healing level $level Fighter $fighter scales by Cleric levels without healing self',
      (tester) async {
        final character = cleric(level).copyWith(
          additionalClassLevels: fighter == 0 ? {} : {'Fighter': fighter},
          resources: BuiltInClass.cleric.classResources(
            level - fighter,
            charismaModifier: 0,
          ),
        );
        final initial = CharacterSession.fromCharacter(character);
        var session = CharacterSession(
          characterState: initial.characterState,
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final roller = SequenceDiceRoller(List.filled(dice, 4));
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              diceRoller: roller,
              onCharacterChanged: (_) {},
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final pool = character.resources.singleWhere(
          (r) => r.id == clericChannelDivinityId,
        );
        await openPool(tester, pool.maximum);
        await helpers.tap(tester, find.text('Cancel'));
        expect(roller.index, 0);
        await openPool(tester, pool.maximum);
        await helpers.tap(
          tester,
          find.text('Divine Spark · Heal another creature'),
        );
        expect(
          session.timeline.first.title,
          'Divine Spark healing: ${dice * 4 + 3}',
        );
        expect(
          session.characterState.currentHp,
          initial.characterState.currentHp,
        );
        expect(
          session.characterState.resourceValues[pool.id],
          pool.maximum - 1,
        );
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(roller.index, dice);
        final restored = CharacterSession.fromJson(session.toJson());
        expect(
          restored.characterState.resourceValues[pool.id],
          pool.maximum - 1,
        );
        expect(restored.usedCombatActions, {CombatActionCost.action});
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (choice, save, result) in [
    ('Radiant', 'Failed save', 7),
    ('Necrotic', 'Successful save', 3),
    ('Radiant', 'Resolve at Table', 7),
  ]) {
    testWidgets(
      'Divine Spark $choice $save preserves defenses and halves after Wisdom',
      (tester) async {
        final character = cleric(2);
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final roller = SequenceDiceRoller([4]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              diceRoller: roller,
              onCharacterChanged: (_) {},
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await openPool(tester, 2);
        expect(find.text('Turn Undead + Sear Undead'), findsNothing);
        await helpers.tap(tester, find.text('Divine Spark · $choice damage'));
        await helpers.tap(tester, find.text('Cancel'));
        expect(roller.index, 0);
        expect(session.usedCombatActions, isEmpty);
        await openPool(tester, 2);
        await helpers.tap(tester, find.text('Divine Spark · $choice damage'));
        expect(find.textContaining('Constitution save'), findsOneWidget);
        await helpers.tap(tester, find.text(save));
        expect(session.timeline.first.title, 'Divine Spark $choice: $result');
        expect(
          session.characterState.resourceValues[clericChannelDivinityId],
          1,
        );
        expect(roller.index, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final sear in [false, true]) {
    testWidgets(
      'Turn Undead sear=$sear uses one action/pool and leaves enemies table-managed',
      (tester) async {
        final character = cleric(5);
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final roller = SequenceDiceRoller([2, 3, 4]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              diceRoller: roller,
              onCharacterChanged: (_) {},
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = sear ? 'Turn Undead + Sear Undead' : 'Turn Undead';
        await openPool(tester, 2);
        await helpers.tap(tester, find.text(label));
        await helpers.tap(tester, find.text('Cancel'));
        expect(roller.index, 0);
        await openPool(tester, 2);
        await helpers.tap(tester, find.text(label));
        await helpers.tap(tester, find.text('Confirm Turn Undead'));
        expect(session.timeline.first.title, label);
        expect(session.timeline.first.detail, contains('Wisdom saves'));
        expect(session.timeline.first.detail, contains('1 minute'));
        if (sear) {
          expect(
            session.timeline.first.detail,
            contains('9 Radiant damage per failed save'),
          );
          expect(
            session.timeline.first.detail,
            contains('does not end turning'),
          );
        }
        expect(roller.index, sear ? 3 : 0);
        expect(session.characterState.activeConditions, isEmpty);
        expect(
          session.characterState.resourceValues[clericChannelDivinityId],
          1,
        );
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (level, healing, dice, maximum) in [
    (16, true, 3, false),
    (17, true, 3, true),
    (18, true, 4, true),
    (18, false, 4, false),
  ]) {
    testWidgets('Life Cleric $level Supreme Healing healing=$healing', (
      tester,
    ) async {
      final character = cleric(
        level,
      ).copyWith(subclasses: {'Cleric': 'Life Domain'});
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final roller = SequenceDiceRoller(List.filled(dice, 4));
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            diceRoller: roller,
            onCharacterChanged: (_) {},
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openPool(tester, level >= 18 ? 4 : 3);
      await helpers.tap(
        tester,
        find.text(
          healing
              ? 'Divine Spark · Heal another creature'
              : 'Divine Spark · Radiant damage',
        ),
      );
      if (!healing) {
        await helpers.tap(tester, find.text('Failed save'));
      }
      expect(
        session.timeline.first.title,
        '${healing ? 'Divine Spark healing' : 'Divine Spark Radiant'}: ${dice * (maximum ? 8 : 4) + 3}',
      );
      expect(roller.index, maximum ? 0 : dice);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (wisdom, sear, total) in [(6, false, 0), (6, true, 1)]) {
    testWidgets('Negative Wisdom clamps healing and Sear minimum sear=$sear', (
      tester,
    ) async {
      final character = cleric(5, wisdom: wisdom);
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final roller = SequenceDiceRoller([1]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            diceRoller: roller,
            onCharacterChanged: (_) {},
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openPool(tester, 2);
      await helpers.tap(
        tester,
        find.text(
          sear
              ? 'Turn Undead + Sear Undead'
              : 'Divine Spark · Heal another creature',
        ),
      );
      if (sear) await helpers.tap(tester, find.text('Confirm Turn Undead'));
      expect(
        session.timeline.first.detail,
        contains(sear ? '$total Radiant damage' : 'Apply $total HP'),
      );
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(roller.index, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final condition in ['Stunned', 'action']) {
    testWidgets('Cleric Magic action blocked by $condition', (tester) async {
      final character = cleric(5);
      final session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          character,
        ).copyWith(activeConditions: condition == 'Stunned' ? {'Stunned'} : {}),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        usedCombatActions: condition == 'action'
            ? {CombatActionCost.action}
            : {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openPool(tester, 2);
      expect(find.byType(SimpleDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
