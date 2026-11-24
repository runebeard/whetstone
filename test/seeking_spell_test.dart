import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/metamagic.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as helpers;
import 'metamagic_test.dart' as base;
import 'support/sequence_dice_roller.dart';

const ray = Spell(
  id: 'seeking-ray',
  name: 'Seeking Ray',
  level: 1,
  prepared: true,
  castingTime: 'Action',
  rollModifier: 5,
  damageFormula: '1d6',
  damageType: 'Fire',
  summary: 'A spell attack.',
);

void main() {
  for (final (mode, dice, index, replacement, natural, critical) in [
    ('Normal', [8], 0, 3, 3, false),
    ('Normal', [1], 0, 20, 20, true),
    ('Advantage', [2, 5], 0, 20, 20, true),
    ('Disadvantage', [2, 15], 0, 20, 15, false),
    ('Advantage', [7, 9], 1, 1, 7, false),
  ]) {
    testWidgets(
      'Seeking $mode replaces only die ${index + 1}, retains result $natural and critical=$critical',
      (tester) async {
        var character = base.sorcerer().copyWith(
          spells: [ray],
          metamagicOptions: {Metamagic.seeking},
          initiallyPinnedActionKeys: {ray.actionKey},
        );
        var session = CharacterSession(
          characterState: CharacterSession.fromCharacter(
            character,
          ).characterState,
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final roller = SequenceDiceRoller([...dice, replacement, 3, 4]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              diceRoller: roller,
              onCharacterChanged: (value) => character = value,
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (mode != 'Normal') {
          await helpers.tap(tester, find.byTooltip('Next d20 roll: Normal'));
          await helpers.tap(tester, find.text(mode));
        }
        await helpers.tap(tester, find.text('Seeking Ray').first);
        await helpers.tap(tester, find.text('Cast').last);
        await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
        await helpers.tap(
          tester,
          find.text('Miss · Reroll die ${index + 1} (${dice[index]})'),
        );
        expect(
          session.timeline.first.title,
          'Seeking Ray Attack · Seeking Spell: ${natural + 5}',
        );
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          6,
        );
        expect(session.characterState.resourceValues[spellSlotId(1)], 3);
        expect(roller.index, dice.length + 1);
        await helpers.tap(tester, find.text('Seeking Ray').first);
        await helpers.tap(tester, find.text('Roll Damage'));
        expect(
          session.timeline.first.title,
          'Seeking Ray ${critical ? 'Critical Damage: 7' : 'Damage: 3'}',
        );
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          6,
        );
        expect(session.characterState.resourceValues[spellSlotId(1)], 3);
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final (roll, points, known, skip) in [
    (8, 7, true, true),
    (20, 7, true, false),
    (8, 0, true, false),
    (8, 7, false, false),
  ]) {
    testWidgets(
      'Seeking keep/eligibility roll=$roll points=$points known=$known',
      (tester) async {
        var character = base.sorcerer().copyWith(
          spells: [ray],
          metamagicOptions: known ? {Metamagic.seeking} : {},
          initiallyPinnedActionKeys: {ray.actionKey},
        );
        var session = CharacterSession(
          characterState: CharacterSession.fromCharacter(character)
              .characterState
              .copyWith(
                resourceValues: {
                  ...CharacterSession.fromCharacter(
                    character,
                  ).characterState.resourceValues,
                  sorceryPointsResourceId: points,
                },
              ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([roll]);
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
        await helpers.tap(tester, find.text('Seeking Ray').first);
        await helpers.tap(tester, find.text('Cast').last);
        await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
        if (skip) {
          await helpers.tap(tester, find.text('Keep Attack'));
        } else {
          expect(find.text('Keep Attack'), findsNothing);
        }
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          points,
        );
        expect(dice.index, 1);
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Seeking and Empowered can modify a Quickened cast independently',
    (tester) async {
      var character = base
          .sorcerer(level: 10)
          .copyWith(
            spells: [ray],
            metamagicOptions: {
              Metamagic.quickened,
              Metamagic.seeking,
              Metamagic.empowered,
            },
            initiallyPinnedActionKeys: {ray.actionKey},
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
            diceRoller: SequenceDiceRoller([1, 20, 1, 6, 4]),
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Seeking Ray').first);
      await helpers.tap(tester, find.text('Quickened Spell'));
      await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
      await helpers.tap(tester, find.text('Miss · Reroll die 1 (1)'));
      await helpers.tap(tester, find.text('Seeking Ray').first);
      await helpers.tap(tester, find.text('Roll Damage'));
      await helpers.tap(tester, find.byKey(const ValueKey('empowered-die-0')));
      await helpers.tap(tester, find.text('Reroll Selected Dice'));
      expect(session.timeline.first.title, 'Seeking Ray Critical Damage: 10');
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 6);
      expect(session.characterState.resourceValues[spellSlotId(1)], 3);
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(tester.takeException(), isNull);
    },
  );
}
