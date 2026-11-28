import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/class_spells.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/metamagic.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as helpers;
import 'life_domain_spells_test.dart' as fixtures;
import 'support/sequence_dice_roller.dart';

Future<void> targetCount(WidgetTester tester, int count) async {
  await tester.enterText(find.byType(TextField).last, '$count');
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await helpers.tap(tester, find.text('Save'));
}

void main() {
  for (final (
        name,
        cleric,
        slot,
        choice,
        others,
        dice,
        sides,
        total,
        gained,
        supreme,
      )
      in [
        ('Cure Wounds', 3, 1, 'Heal yourself', 0, 2, 8, 14, 14, false),
        (
          'Cure Wounds',
          6,
          3,
          'Heal other injured targets',
          1,
          6,
          8,
          32,
          5,
          false,
        ),
        (
          'Cure Wounds',
          5,
          1,
          'Heal other injured targets',
          1,
          2,
          8,
          14,
          0,
          false,
        ),
        (
          'Mass Healing Word',
          9,
          4,
          'Heal yourself and other injured targets',
          2,
          3,
          4,
          21,
          27,
          false,
        ),
        (
          'Mass Cure Wounds',
          9,
          5,
          'Heal other injured targets',
          6,
          5,
          8,
          30,
          7,
          false,
        ),
        ('Cure Wounds', 17, 1, 'Heal yourself', 0, 2, 8, 22, 22, true),
        (
          'Mass Healing Word',
          18,
          3,
          'Heal yourself and other injured targets',
          5,
          2,
          4,
          16,
          21,
          true,
        ),
      ]) {
    testWidgets(
      '$name Cleric $cleric slot $slot $choice uses one cast with scoped Life bonuses',
      (tester) async {
        var character = withBuiltInSpellGrants(
          fixtures.life(cleric),
        ).copyWith(currentHp: 10, maxHp: 80);
        final spell = character.spells.singleWhere((s) => s.name == name);
        character = character.copyWith(
          initiallyPinnedActionKeys: {spell.actionKey},
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final roller = SequenceDiceRoller(List.filled(dice, 4));
        final available = character.resources
            .singleWhere((r) => r.id == spellSlotId(slot))
            .initialValue;
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              diceRoller: roller,
              onCharacterChanged: (_) {},
              onSessionChanged: (v) => session = v,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text(name).first);
        await helpers.tap(tester, find.text('Cast').last);
        await helpers.tap(tester, find.text(choice));
        if (name != 'Cure Wounds' && others > 0) {
          await targetCount(tester, others);
        }
        await helpers.tap(
          tester,
          find.text('Level $slot · $available remaining'),
        );
        expect(session.timeline.first.title, '$name healing: $total');
        expect(session.timeline.first.detail, contains('${dice}d$sides'));
        expect(session.characterState.currentHp, 10 + gained);
        expect(
          session.characterState.resourceValues[spellSlotId(slot)],
          available - 1,
        );
        expect(session.usedCombatActions, {
          name == 'Mass Healing Word'
              ? CombatActionCost.bonusAction
              : CombatActionCost.action,
        });
        expect(roller.index, supreme ? 0 : dice);
        if (others > 0) {
          expect(
            session.timeline.first.detail,
            contains('each of $others confirmed other targets'),
          );
        }
        if (supreme) {
          expect(session.timeline.first.detail, contains('Supreme Healing'));
        }
        final restored = CharacterSession.fromJson(session.toJson());
        expect(restored.characterState.currentHp, 10 + gained);
        expect(
          restored.characterState.resourceValues[spellSlotId(slot)],
          available - 1,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Healing target and slot cancellation preserve HP, slots, actions and dice',
    (tester) async {
      var character = withBuiltInSpellGrants(
        fixtures.life(9),
      ).copyWith(currentHp: 10, maxHp: 80);
      final spell = character.spells.singleWhere(
        (s) => s.name == 'Cure Wounds',
      );
      character = character.copyWith(
        initiallyPinnedActionKeys: {spell.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final roller = SequenceDiceRoller([]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            diceRoller: roller,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final cancelSlot in [false, true]) {
        await helpers.tap(tester, find.text(spell.name).first);
        await helpers.tap(tester, find.text('Cast').last);
        if (cancelSlot) {
          await helpers.tap(tester, find.text('Heal yourself'));
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } else {
          await helpers.tap(tester, find.text('Cancel'));
        }
        expect(session.characterState.currentHp, 10);
        expect(session.characterState.resourceValues[spellSlotId(1)] ?? 4, 4);
        expect(session.usedCombatActions, isEmpty);
        expect(roller.index, 0);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final cleric in [9, 17]) {
    testWidgets(
      'Subtle free healing at Cleric $cleric excludes slot-based Life bonuses',
      (tester) async {
        var character = withBuiltInSpellGrants(
          fixtures
              .life(cleric + 2)
              .copyWith(
                additionalClassLevels: {'Sorcerer': 2},
                metamagicOptions: {Metamagic.subtle},
                currentHp: 10,
                maxHp: 80,
              ),
        );
        final spell = character.spells.singleWhere(
          (s) => s.name == 'Cure Wounds',
        );
        final free = CharacterResource(
          id: 'whetstone:free-cast:${spell.id}',
          name: 'Free Cure Wounds',
          maximum: 1,
          initialValue: 1,
          rechargePeriod: RechargePeriod.longRest,
        );
        character = character.copyWith(
          initiallyPinnedActionKeys: {spell.actionKey},
          resources: [...character.resources, free],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final roller = SequenceDiceRoller([4, 4]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              diceRoller: roller,
              onCharacterChanged: (_) {},
              onSessionChanged: (v) => session = v,
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> begin() async {
          await helpers.tap(tester, find.text(spell.name).first);
          await helpers.tap(tester, find.text('Subtle Spell'));
          await helpers.tap(tester, find.text('Use Free Cast'));
        }

        await begin();
        await helpers.tap(tester, find.text('Cancel'));
        expect(session.characterState.resourceValues[free.id] ?? 1, 1);
        expect(session.usedCombatActions, isEmpty);
        await begin();
        await helpers.tap(tester, find.text('Heal other injured targets'));
        expect(
          session.timeline.first.title,
          'Cure Wounds healing: ${cleric >= 17 ? 19 : 11}',
        );
        expect(
          session.timeline.first.detail,
          isNot(contains('Disciple of Life')),
        );
        expect(
          session.timeline.first.detail,
          isNot(contains('Blessed Healer')),
        );
        expect(session.characterState.currentHp, 10);
        expect(session.characterState.resourceValues[free.id], 0);
        expect(session.characterState.resourceValues[spellSlotId(1)] ?? 4, 4);
        expect(roller.index, cleric >= 17 ? 0 : 2);
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (choice, count) in [
    ('Heal other injured targets', 7),
    ('Heal yourself and other injured targets', 6),
  ]) {
    testWidgets('Mass healing rejects excess targets $choice', (tester) async {
      var character = withBuiltInSpellGrants(fixtures.life(9));
      final spell = character.spells.singleWhere(
        (s) => s.name == 'Mass Healing Word',
      );
      character = character.copyWith(
        initiallyPinnedActionKeys: {spell.actionKey},
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
            diceRoller: SequenceDiceRoller([]),
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text(spell.name).first);
      await helpers.tap(tester, find.text('Cast').last);
      await helpers.tap(tester, find.text(choice));
      await targetCount(tester, count);
      expect(session.usedCombatActions, isEmpty);
      expect(session.characterState.resourceValues[spellSlotId(3)] ?? 3, 3);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Quickened healing spends the Bonus Action and points once', (
    tester,
  ) async {
    var character = withBuiltInSpellGrants(
      fixtures
          .life(11)
          .copyWith(
            additionalClassLevels: {'Sorcerer': 2},
            metamagicOptions: {Metamagic.quickened},
            currentHp: 10,
            maxHp: 80,
          ),
    );
    final spell = character.spells.singleWhere((s) => s.name == 'Cure Wounds');
    character = character.copyWith(
      initiallyPinnedActionKeys: {spell.actionKey},
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
          diceRoller: SequenceDiceRoller([4, 4]),
          onCharacterChanged: (_) {},
          onSessionChanged: (v) => session = v,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await helpers.tap(tester, find.text(spell.name).first);
    await helpers.tap(tester, find.text('Quickened Spell'));
    await helpers.tap(tester, find.text('Heal yourself'));
    await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
    expect(session.characterState.currentHp, 24);
    expect(session.characterState.resourceValues[sorceryPointsResourceId], 0);
    expect(session.usedCombatActions, {CombatActionCost.bonusAction});
    expect(
      session.timeline.where((e) => e.title == 'Quickened Spell · Cure Wounds'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  for (final (name, cost) in [
    ('Cure Wounds', CombatActionCost.action),
    ('Mass Healing Word', CombatActionCost.bonusAction),
  ]) {
    testWidgets('Spent $cost blocks $name before target selection', (
      tester,
    ) async {
      var character = withBuiltInSpellGrants(
        fixtures.life(9),
      ).copyWith(currentHp: 10, maxHp: 80);
      final spell = character.spells.singleWhere((s) => s.name == name);
      character = character.copyWith(
        initiallyPinnedActionKeys: {spell.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        usedCombatActions: {cost},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            diceRoller: SequenceDiceRoller([]),
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text(name).first);
      await helpers.tap(tester, find.text('Cast').last);
      expect(find.text('Heal yourself'), findsNothing);
      expect(session.characterState.currentHp, 10);
      expect(session.usedCombatActions, {cost});
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Healing caps at maximum HP and zero base healing does not trigger slot bonuses',
    (tester) async {
      var character = withBuiltInSpellGrants(
        fixtures.life(9),
      ).copyWith(abilityScores: {Ability.wisdom: 6}, currentHp: 79, maxHp: 80);
      final spell = character.spells.singleWhere(
        (s) => s.name == 'Cure Wounds',
      );
      character = character.copyWith(
        initiallyPinnedActionKeys: {spell.actionKey},
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
            diceRoller: SequenceDiceRoller([1, 1, 4, 4]),
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> heal() async {
        await helpers.tap(tester, find.text(spell.name).first);
        await helpers.tap(tester, find.text('Cast').last);
        await helpers.tap(tester, find.text('Heal yourself'));
      }

      await heal();
      await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
      expect(session.timeline.first.title, 'Cure Wounds healing: 0');
      expect(session.characterState.currentHp, 79);
      await helpers.tap(tester, find.text('Next Turn'));
      await heal();
      await helpers.tap(tester, find.text('Level 1 · 3 remaining'));
      expect(session.characterState.currentHp, 80);
      expect(tester.takeException(), isNull);
    },
  );
}
