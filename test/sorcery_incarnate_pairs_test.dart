import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/class_spells.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/metamagic.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as helpers;
import 'metamagic_test.dart' as base;
import 'save_metamagic_test.dart' as saves;
import 'support/sequence_dice_roller.dart';

Spell pairedSpell(Metamagic option) => Spell(
  id: 'paired',
  name: 'Paired Spell',
  level: 1,
  prepared: true,
  castingTime: 'Action',
  range: '60 feet',
  components: 'V, S',
  concentration: option == Metamagic.extended,
  duration: option == Metamagic.extended
      ? 'Concentration, up to 1 minute'
      : 'Instantaneous',
  damageType: option == Metamagic.extended ? null : 'Fire',
  damageFormula: option == Metamagic.extended ? null : '2d6',
  rollEffectOnCast: option != Metamagic.extended,
  savingThrowAbility: {Metamagic.careful, Metamagic.heightened}.contains(option)
      ? Ability.dexterity
      : null,
  halfDamageOnSave: true,
  summary: 'A paired test spell.',
);

void main() {
  testWidgets(
    'Quickened plus Twinned preserves effective Fly level and charges once',
    (tester) async {
      var character = withDraconicSpellGrants(
        helpers
            .draconic(7)
            .copyWith(
              metamagicOptions: {Metamagic.quickened, Metamagic.twinned},
            ),
      );
      final spell = character.spells.singleWhere((s) => s.name == 'Fly');
      character = character.copyWith(
        initiallyPinnedActionKeys: {spell.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterSession.fromCharacter(character).characterState
            .copyWith(
              activeConditions: {innateSorceryCondition},
              conditionTurns: {innateSorceryCondition: 10},
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
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Fly').first);
      await helpers.tap(tester, find.text('Quickened + another option'));
      await helpers.tap(
        tester,
        find.text('Twinned Spell · 3 total Sorcery Points'),
      );
      await helpers.tap(tester, find.text('Cast with Metamagic'));
      await helpers.tap(tester, find.text('Level 3 · 3 remaining'));
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 4);
      expect(session.characterState.resourceValues[spellSlotId(3)], 2);
      expect(session.characterState.concentrationSlotLevel, 4);
      expect(session.characterState.concentrationTurnsRemaining, 100);
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(tester.takeException(), isNull);
    },
  );
  for (final option in [
    Metamagic.subtle,
    Metamagic.distant,
    Metamagic.extended,
    Metamagic.transmuted,
    Metamagic.careful,
    Metamagic.heightened,
  ]) {
    testWidgets(
      'Incarnate Quickened plus ${option.label} charges both and preserves effects',
      (tester) async {
        final spell = pairedSpell(option);
        var character = base.sorcerer().copyWith(
          spells: [spell],
          metamagicOptions: {Metamagic.quickened, option},
          initiallyPinnedActionKeys: {spell.actionKey},
        );
        var session = CharacterSession(
          characterState: CharacterSession.fromCharacter(character)
              .characterState
              .copyWith(
                activeConditions: {innateSorceryCondition},
                conditionTurns: {innateSorceryCondition: 10},
              ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: {CombatActionCost.action},
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              diceRoller: SequenceDiceRoller([4, 5]),
              onCharacterChanged: (value) => character = value,
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> begin() async {
          await helpers.tap(tester, find.text(spell.name).first);
          await helpers.tap(tester, find.text('Quickened + another option'));
        }

        await begin();
        await helpers.tap(tester, find.text('Cancel'));
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId] ?? 7,
          7,
        );
        await begin();
        final cost = 2 + option.pointCost;
        await helpers.tap(
          tester,
          find.text('${option.label} · $cost total Sorcery Points'),
        );
        if (option == Metamagic.transmuted) {
          await helpers.tap(tester, find.text('Cold'));
        }
        if ({Metamagic.careful, Metamagic.heightened}.contains(option)) {
          await saves.targets(tester, 'Target');
        }
        await helpers.tap(tester, find.text('Cast with Metamagic'));
        if (option == Metamagic.subtle) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId] ?? 7,
            7,
          );
          expect(session.usedCombatActions, {CombatActionCost.action});
          await begin();
          await helpers.tap(
            tester,
            find.text('${option.label} · $cost total Sorcery Points'),
          );
          await helpers.tap(tester, find.text('Cast with Metamagic'));
        }
        await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
        if (spell.savingThrowAbility != null) {
          await helpers.tap(
            tester,
            find.text(
              option == Metamagic.careful
                  ? 'Protected target · Automatic save'
                  : 'Failed save',
            ),
          );
        }
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          7 - cost,
        );
        expect(session.characterState.resourceValues[spellSlotId(1)], 3);
        expect(session.usedCombatActions, {
          CombatActionCost.action,
          CombatActionCost.bonusAction,
        });
        expect(session.quickenedSpellUsedThisTurn, isTrue);
        expect(
          session.timeline.any(
            (event) => event.title == '${option.label} · ${spell.name}',
          ),
          isTrue,
        );
        expect(
          session.timeline.any(
            (event) => event.title == 'Quickened Spell · ${spell.name}',
          ),
          isTrue,
        );
        if (option == Metamagic.extended) {
          expect(session.characterState.extendedConcentration, isTrue);
          expect(session.characterState.concentrationTurnsRemaining, 20);
        }
        if (option == Metamagic.distant) {
          expect(
            session.timeline
                .singleWhere((e) => e.title == 'Distant Spell · ${spell.name}')
                .detail,
            contains('120 feet'),
          );
        }
        if (option == Metamagic.transmuted) {
          expect(session.characterState.spellDamageTypes[spell.id], 'Cold');
        }
        if (option == Metamagic.careful) {
          expect(session.timeline.first.title, 'Paired Spell Damage: 0');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final (level, active, points, bonusUsed) in [
    (6, true, 6, false),
    (7, false, 7, false),
    (7, true, 2, false),
    (7, true, 7, true),
  ]) {
    testWidgets(
      'Paired gate level=$level active=$active points=$points bonusUsed=$bonusUsed',
      (tester) async {
        final spell = pairedSpell(Metamagic.extended);
        final character = base
            .sorcerer(level: level)
            .copyWith(
              spells: [spell],
              metamagicOptions: {Metamagic.quickened, Metamagic.extended},
              initiallyPinnedActionKeys: {spell.actionKey},
            );
        final session = CharacterSession(
          characterState: CharacterSession.fromCharacter(character)
              .characterState
              .copyWith(
                activeConditions: active ? {innateSorceryCondition} : {},
                resourceValues: {sorceryPointsResourceId: points},
              ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: bonusUsed ? {CombatActionCost.bonusAction} : {},
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
        await helpers.tap(tester, find.text(spell.name).first);
        expect(find.text('Quickened + another option'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Paired Apotheosis waives Quickened only and spends one point on Extended',
    (tester) async {
      final spell = pairedSpell(Metamagic.extended);
      var character = base
          .sorcerer(level: 20)
          .copyWith(
            spells: [spell],
            metamagicOptions: {Metamagic.quickened, Metamagic.extended},
            initiallyPinnedActionKeys: {spell.actionKey},
          );
      var session = CharacterSession(
        characterState: CharacterSession.fromCharacter(character).characterState
            .copyWith(
              activeConditions: {innateSorceryCondition},
              conditionTurns: {innateSorceryCondition: 10},
              resourceValues: {
                ...CharacterSession.fromCharacter(
                  character,
                ).characterState.resourceValues,
                sorceryPointsResourceId: 1,
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
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text(spell.name).first);
      expect(find.text('Quickened + another option'), findsNothing);
      await helpers.tap(tester, find.text('My turn · Arm free Metamagic'));
      await helpers.tap(tester, find.text('Quickened + another option'));
      await helpers.tap(
        tester,
        find.text('Extended Spell · 1 total Sorcery Points'),
      );
      await helpers.tap(tester, find.text('Cast with Metamagic'));
      await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
      expect(session.apotheosisUsedThisTurn, isTrue);
      expect(session.apotheosisArmed, isFalse);
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 0);
      expect(session.characterState.extendedConcentration, isTrue);
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(tester.takeException(), isNull);
    },
  );
}
