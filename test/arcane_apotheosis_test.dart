import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

const ray = Spell(
  id: 'apotheosis-ray',
  name: 'Free Ray',
  level: 1,
  prepared: true,
  castingTime: 'Action',
  rollModifier: 5,
  damageFormula: '1d6',
  damageType: 'Fire',
  summary: 'A ray.',
);
const burst = Spell(
  id: 'apotheosis-burst',
  name: 'Free Burst',
  level: 1,
  prepared: true,
  castingTime: 'Action',
  rollEffectOnCast: true,
  savingThrowAbility: null,
  damageFormula: '1d6',
  damageType: 'Fire',
  components: 'V, S',
  summary: 'A burst.',
);

void main() {
  for (final option in [Metamagic.seeking, Metamagic.empowered]) {
    testWidgets('Declining ${option.label} preserves the armed free option', (
      tester,
    ) async {
      final spell = option == Metamagic.seeking ? ray : burst;
      var character = base
          .sorcerer(level: 20)
          .copyWith(
            spells: [spell],
            metamagicOptions: {option},
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
                sorceryPointsResourceId: 0,
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
      await helpers.tap(tester, find.text(spell.name).first);
      await helpers.tap(tester, find.text('My turn · Arm free Metamagic'));
      await helpers.tap(tester, find.text('Cast').last);
      await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
      await helpers.tap(
        tester,
        find.text(option == Metamagic.seeking ? 'Keep Attack' : 'Keep Damage'),
      );
      expect(session.apotheosisUsedThisTurn, isFalse);
      expect(session.apotheosisArmed, isTrue);
      expect(
        CharacterSession.fromJson(session.toJson()).apotheosisArmed,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Paying for Subtle preserves Apotheosis for later Empowered damage',
    (tester) async {
      var character = base
          .sorcerer(level: 20)
          .copyWith(
            spells: [burst],
            metamagicOptions: {Metamagic.subtle, Metamagic.empowered},
            initiallyPinnedActionKeys: {burst.actionKey},
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
                sorceryPointsResourceId: 5,
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
            diceRoller: SequenceDiceRoller([1, 2, 3]),
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text(burst.name).first);
      await helpers.tap(tester, find.text('Subtle Spell'));
      await helpers.tap(tester, find.text('Cast with Metamagic'));
      await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
      await helpers.tap(tester, find.text('Keep Damage'));
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 4);
      expect(session.apotheosisUsedThisTurn, isFalse);
      await helpers.tap(tester, find.text(burst.name).first);
      await helpers.tap(tester, find.text('My turn · Arm free Metamagic'));
      await helpers.tap(tester, find.text('Roll Damage'));
      await helpers.tap(tester, find.byKey(const ValueKey('empowered-die-0')));
      await helpers.tap(tester, find.text('Reroll Selected Dice'));
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 4);
      expect(session.apotheosisUsedThisTurn, isTrue);
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(tester.takeException(), isNull);
    },
  );
  for (final (level, active, combat, used, available) in [
    (19, true, true, false, false),
    (20, false, true, false, false),
    (20, true, false, false, false),
    (20, true, true, true, false),
    (20, true, true, false, true),
  ]) {
    testWidgets(
      'Apotheosis gating level=$level active=$active combat=$combat used=$used',
      (tester) async {
        final character = base
            .sorcerer(level: level)
            .copyWith(
              spells: [ray],
              metamagicOptions: {Metamagic.quickened},
              initiallyPinnedActionKeys: {ray.actionKey},
            );
        final session = CharacterSession(
          characterState: CharacterSession.fromCharacter(character)
              .characterState
              .copyWith(
                activeConditions: active ? {innateSorceryCondition} : {},
                conditionTurns: active ? {innateSorceryCondition: 10} : {},
                resourceValues: {sorceryPointsResourceId: 0},
              ),
          inventory: [],
          archivedInventory: [],
          isInCombat: combat,
          apotheosisUsedThisTurn: used,
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
        if (!combat) await helpers.tap(tester, find.text('Spellbook'));
        await helpers.tap(tester, find.text('Free Ray').first);
        expect(
          find.text('My turn · Arm free Metamagic'),
          available ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Free Quickened cast consumes one shared use, survives reload and resets next turn',
    (tester) async {
      var character = base
          .sorcerer(level: 20)
          .copyWith(
            spells: [ray],
            metamagicOptions: {Metamagic.quickened, Metamagic.seeking},
            initiallyPinnedActionKeys: {ray.actionKey},
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
                sorceryPointsResourceId: 0,
              },
            ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      Widget app(int generation) => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(generation),
          character: character,
          initialSession: session,
          diceRoller: SequenceDiceRoller([5, 6]),
          onCharacterChanged: (value) => character = value,
          onSessionChanged: (value) => session = value,
        ),
      );
      await tester.pumpWidget(app(0));
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Free Ray').first);
      await helpers.tap(tester, find.text('My turn · Arm free Metamagic'));
      expect(session.apotheosisArmed, isTrue);
      expect(session.usedCombatActions, isEmpty);
      await helpers.tap(tester, find.text('Quickened Spell'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(session.apotheosisArmed, isTrue);
      expect(session.apotheosisUsedThisTurn, isFalse);
      await helpers.tap(tester, find.text('Free Ray').first);
      await helpers.tap(tester, find.text('Quickened Spell'));
      await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
      expect(find.text('Keep Attack'), findsNothing);
      expect(session.apotheosisUsedThisTurn, isTrue);
      expect(session.apotheosisArmed, isFalse);
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 0);
      expect(session.characterState.resourceValues[spellSlotId(1)], 3);
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Free Ray').first);
      expect(find.text('My turn · Arm free Metamagic'), findsNothing);
      await helpers.tap(tester, find.text('Done'));
      await helpers.tap(tester, find.text('Next Turn'));
      expect(session.apotheosisUsedThisTurn, isFalse);
      await helpers.tap(tester, find.text('Free Ray').first);
      expect(find.text('My turn · Arm free Metamagic'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final option in [Metamagic.seeking, Metamagic.empowered]) {
    testWidgets(
      'Apotheosis funds ${option.label} at zero points without paying another cast',
      (tester) async {
        final spell = option == Metamagic.seeking ? ray : burst;
        var character = base
            .sorcerer(level: 20)
            .copyWith(
              spells: [spell],
              metamagicOptions: {option},
              initiallyPinnedActionKeys: {spell.actionKey},
            );
        var session = CharacterSession(
          characterState: CharacterSession.fromCharacter(character)
              .characterState
              .copyWith(
                activeConditions: {innateSorceryCondition},
                conditionTurns: {innateSorceryCondition: 10},
                resourceValues: {
                  ...CharacterSession.fromCharacter(
                    character,
                  ).characterState.resourceValues,
                  sorceryPointsResourceId: 0,
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
              diceRoller: SequenceDiceRoller([1, 6, 4]),
              onCharacterChanged: (value) => character = value,
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text(spell.name).first);
        await helpers.tap(tester, find.text('My turn · Arm free Metamagic'));
        await helpers.tap(tester, find.text('Cast').last);
        await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
        if (option == Metamagic.seeking) {
          await helpers.tap(tester, find.text('Miss · Reroll die 1 (1)'));
        } else {
          await helpers.tap(
            tester,
            find.byKey(const ValueKey('empowered-die-0')),
          );
          await helpers.tap(tester, find.text('Reroll Selected Dice'));
        }
        expect(session.apotheosisUsedThisTurn, isTrue);
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          0,
        );
        expect(session.characterState.resourceValues[spellSlotId(1)], 3);
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Apotheosis covers the full two-point Heightened cost', (
    tester,
  ) async {
    final spell = saves.burst;
    var character = base
        .sorcerer(level: 20)
        .copyWith(
          spells: [spell],
          metamagicOptions: {Metamagic.heightened},
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
              sorceryPointsResourceId: 0,
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
          diceRoller: SequenceDiceRoller([4, 5]),
          onCharacterChanged: (value) => character = value,
          onSessionChanged: (value) => session = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await helpers.tap(tester, find.text(spell.name).first);
    await helpers.tap(tester, find.text('My turn · Arm free Metamagic'));
    await helpers.tap(tester, find.text('Heightened Spell'));
    await saves.targets(tester, 'Enemy');
    await helpers.tap(tester, find.text('Cast with Metamagic'));
    await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
    await helpers.tap(tester, find.text('Failed save'));
    expect(session.apotheosisUsedThisTurn, isTrue);
    expect(session.characterState.resourceValues[sorceryPointsResourceId], 0);
    expect(session.characterState.spellSaveEffects[spell.id]!.targets, [
      'Enemy',
    ]);
    expect(tester.takeException(), isNull);
  });
}
