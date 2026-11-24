import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/metamagic.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as helpers;
import 'metamagic_test.dart' as base;
import 'support/sequence_dice_roller.dart';

void main() {
  for (final (charisma, keep) in [(14, false), (8, false), (14, true)]) {
    testWidgets('Empowered dice cap CHA=$charisma keep original=$keep', (
      tester,
    ) async {
      const spell = Spell(
        id: 'empower',
        name: 'Empower Test',
        level: 0,
        prepared: true,
        damageFormula: '3d6+2',
        damageType: 'Fire',
        summary: 'A spell.',
      );
      var character = base.sorcerer().copyWith(
        spells: [spell],
        metamagicOptions: {Metamagic.empowered},
        abilityScores: {Ability.charisma: charisma},
        initiallyPinnedActionKeys: {spell.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterSession.fromCharacter(
          character,
        ).characterState,
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([6, 5, 4, 1]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            diceRoller: dice,
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Empower Test').first);
      await helpers.tap(tester, find.text('Roll Damage'));
      expect(find.text('Empowered Spell'), findsOneWidget);
      if (keep) {
        await helpers.tap(tester, find.text('Keep Damage'));
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId] ?? 7,
          7,
        );
        expect(session.timeline.first.title, 'Empower Test Damage: 17');
        expect(dice.index, 3);
      } else {
        await helpers.tap(
          tester,
          find.byKey(const ValueKey('empowered-die-0')),
        );
        if (charisma == 8) {
          expect(
            tester
                .widget<CheckboxListTile>(
                  find.byKey(const ValueKey('empowered-die-1')),
                )
                .onChanged,
            isNull,
          );
        } else {
          await helpers.tap(
            tester,
            find.byKey(const ValueKey('empowered-die-1')),
          );
          expect(
            tester
                .widget<CheckboxListTile>(
                  find.byKey(const ValueKey('empowered-die-2')),
                )
                .onChanged,
            isNull,
          );
          await helpers.tap(
            tester,
            find.byKey(const ValueKey('empowered-die-1')),
          );
        }
        await helpers.tap(tester, find.text('Reroll Selected Dice'));
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          6,
        );
        expect(session.timeline.first.title, 'Empower Test Damage: 12');
        expect(dice.index, 4);
      }
      expect(session.usedCombatActions, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Empowered combines with Quickened critical damage without extra slots or actions',
    (tester) async {
      const spell = Spell(
        id: 'critical-empower',
        name: 'Empowered Ray',
        level: 1,
        prepared: true,
        castingTime: 'Action',
        rollModifier: 5,
        damageFormula: '1d6+3',
        damageType: 'Fire',
        summary: 'A ray.',
      );
      var character = base.sorcerer().copyWith(
        spells: [spell],
        metamagicOptions: {Metamagic.quickened, Metamagic.empowered},
        initiallyPinnedActionKeys: {spell.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterSession.fromCharacter(
          character,
        ).characterState,
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            diceRoller: SequenceDiceRoller([20, 1, 6, 4]),
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Empowered Ray').first);
      await helpers.tap(tester, find.text('Quickened Spell'));
      await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
      await helpers.tap(tester, find.text('Empowered Ray').first);
      await helpers.tap(tester, find.text('Roll Damage'));
      expect(find.text('Die 2: 6'), findsOneWidget);
      await helpers.tap(tester, find.byKey(const ValueKey('empowered-die-0')));
      await helpers.tap(tester, find.text('Reroll Selected Dice'));
      expect(session.timeline.first.title, 'Empowered Ray Critical Damage: 13');
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 4);
      expect(session.characterState.resourceValues[spellSlotId(1)], 3);
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Empowered rerolls before successful-save damage halving', (
    tester,
  ) async {
    const spell = Spell(
      id: 'save-empower',
      name: 'Empowered Burst',
      level: 0,
      prepared: true,
      castingTime: 'Action',
      rollEffectOnCast: true,
      savingThrowAbility: Ability.dexterity,
      halfDamageOnSave: true,
      damageFormula: '2d6+1',
      damageType: 'Fire',
      summary: 'A burst.',
    );
    var character = base.sorcerer().copyWith(
      spells: [spell],
      metamagicOptions: {Metamagic.empowered},
      initiallyPinnedActionKeys: {spell.actionKey},
    );
    var session = CharacterSession(
      characterState: CharacterSession.fromCharacter(character).characterState,
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: character,
          initialSession: session,
          diceRoller: SequenceDiceRoller([1, 4, 6]),
          onCharacterChanged: (value) => character = value,
          onSessionChanged: (value) => session = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await helpers.tap(tester, find.text('Empowered Burst').first);
    await helpers.tap(tester, find.text('Cast').last);
    await helpers.tap(tester, find.text('Successful save'));
    await helpers.tap(tester, find.byKey(const ValueKey('empowered-die-0')));
    await helpers.tap(tester, find.text('Reroll Selected Dice'));
    expect(session.timeline.first.title, 'Empowered Burst Damage: 5');
    expect(session.characterState.resourceValues[sorceryPointsResourceId], 6);
    expect(session.usedCombatActions, {CombatActionCost.action});
    expect(tester.takeException(), isNull);
  });
  for (final damageType in ['Healing', 'Fire']) {
    testWidgets(
      'Empowered excludes healing and exhausted points type=$damageType',
      (tester) async {
        final spell = Spell(
          id: 'not-empower',
          name: 'No Empower',
          level: 0,
          prepared: true,
          damageFormula: '1d6',
          damageType: damageType,
          summary: 'A roll.',
        );
        var character = base.sorcerer().copyWith(
          spells: [spell],
          metamagicOptions: {Metamagic.empowered},
          initiallyPinnedActionKeys: {spell.actionKey},
        );
        var session = CharacterSession(
          characterState: CharacterSession.fromCharacter(character)
              .characterState
              .copyWith(
                resourceValues: {
                  sorceryPointsResourceId: damageType == 'Fire' ? 0 : 7,
                },
              ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              diceRoller: SequenceDiceRoller([4]),
              onCharacterChanged: (value) => character = value,
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text('No Empower').first);
        await helpers.tap(tester, find.text('Roll Damage'));
        expect(find.text('Empowered Spell'), findsNothing);
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          damageType == 'Fire' ? 0 : 7,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
