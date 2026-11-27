import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_resource.dart';
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

void main() {
  test('Composite save effects retain distinct targets through JSON', () {
    const effect = SpellSaveEffect(Metamagic.careful, [
      'Ally',
      'Friend',
    ], heightenedTarget: 'Enemy');
    final restored = SpellSaveEffect.fromJson(effect.toJson())!;
    expect(restored.targets, ['Ally', 'Friend']);
    expect(restored.heightenedTarget, 'Enemy');
    expect(restored.guidance, contains('Ally, Friend automatically succeed'));
    expect(restored.guidance, contains('Enemy has Disadvantage'));
  });
  test(
    'Legacy and invalid additional target data preserve the valid primary effect',
    () {
      for (final extra in [null, '', '   ', 42, List.filled(81, 'x').join()]) {
        final restored = SpellSaveEffect.fromJson({
          'option': 'careful',
          'targets': ['Ally'],
          'heightenedTarget': extra,
        })!;
        expect(restored.targets, ['Ally']);
        expect(restored.heightenedTarget, isNull);
        expect(restored.toJson().containsKey('heightenedTarget'), isFalse);
      }
      expect(
        SpellSaveEffect.fromJson({
          'option': 'careful',
          'targets': ['Ally'],
          'heightenedTarget': ' Enemy ',
        })!.heightenedTarget,
        'Enemy',
      );
    },
  );

  testWidgets(
    'Careful plus Heightened cancels safely, saves both targets and clears on normal recast',
    (tester) async {
      const spell = saves.burst;
      final character = base.sorcerer().copyWith(
        abilityScores: {Ability.charisma: 14},
        spells: [spell],
        metamagicOptions: {Metamagic.careful, Metamagic.heightened},
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
      final roller = SequenceDiceRoller([4, 5, 3, 2]);
      Widget app(int key) => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(key),
          character: character,
          initialSession: session,
          diceRoller: roller,
          onCharacterChanged: (_) {},
          onSessionChanged: (value) => session = value,
        ),
      );
      await tester.pumpWidget(app(0));
      await tester.pumpAndSettle();
      Future<void> begin() async {
        await helpers.tap(tester, find.text(spell.name).first);
        await helpers.tap(tester, find.text('Other Metamagic combinations'));
        await helpers.tap(tester, find.text('Careful Spell'));
        await helpers.tap(
          tester,
          find.text('Heightened Spell · 3 total Sorcery Points'),
        );
      }

      await begin();
      await helpers.tap(tester, find.text('Cancel'));
      await begin();
      await saves.targets(tester, 'Ally, Friend');
      await helpers.tap(tester, find.text('Cancel'));
      expect(session.characterState.spellSaveEffects, isEmpty);
      expect(
        session.characterState.resourceValues[sorceryPointsResourceId] ?? 7,
        7,
      );
      Future<void> preview() async {
        await begin();
        await saves.targets(tester, 'Ally, Friend');
        await saves.targets(tester, 'Enemy');
      }

      await preview();
      await helpers.tap(tester, find.text('Cast with Metamagic'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(session.characterState.spellSaveEffects, isEmpty);
      expect(session.usedCombatActions, isEmpty);
      await preview();
      await helpers.tap(tester, find.text('Cast with Metamagic'));
      await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
      expect(
        find.textContaining('Ally, Friend automatically succeed'),
        findsOneWidget,
      );
      expect(find.textContaining('Enemy has Disadvantage'), findsOneWidget);
      await helpers.tap(tester, find.text('Protected target · Automatic save'));
      expect(session.timeline.first.title, 'Save Burst Damage: 0');
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 4);
      expect(session.characterState.resourceValues[spellSlotId(1)], 3);
      expect(session.usedCombatActions, {CombatActionCost.action});
      session = CharacterSession.fromJson(session.toJson());
      expect(session.characterState.spellSaveEffects[spell.id]?.targets, [
        'Ally',
        'Friend',
      ]);
      expect(
        session.characterState.spellSaveEffects[spell.id]?.heightenedTarget,
        'Enemy',
      );
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text(spell.name).first);
      await helpers.tap(tester, find.text('Roll Damage'));
      expect(find.textContaining('Enemy has Disadvantage'), findsOneWidget);
      await helpers.tap(tester, find.text('Failed save'));
      expect(session.timeline.first.title, 'Save Burst Damage: 9');
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 4);
      await helpers.tap(tester, find.text('Next Turn'));
      await helpers.tap(tester, find.text(spell.name).first);
      await helpers.tap(tester, find.text('Cast').last);
      await helpers.tap(tester, find.text('Level 1 · 3 remaining'));
      expect(find.textContaining('Enemy has Disadvantage'), findsNothing);
      expect(find.text('Protected target · Automatic save'), findsNothing);
      await helpers.tap(tester, find.text('Failed save'));
      expect(session.characterState.spellSaveEffects, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Composite control free cast shares Apotheosis and preserves slots',
    (tester) async {
      const spell = Spell(
        id: 'control',
        name: 'Control Spell',
        level: 1,
        prepared: true,
        castingTime: 'Action',
        savingThrowAbility: Ability.wisdom,
        summary: 'Control a target.',
      );
      const free = CharacterResource(
        id: 'whetstone:free-cast:control',
        name: 'Free Control',
        maximum: 1,
        initialValue: 1,
        rechargePeriod: RechargePeriod.longRest,
      );
      final original = base.sorcerer(level: 20);
      final character = original.copyWith(
        spells: [spell],
        resources: [...original.resources, free],
        metamagicOptions: {Metamagic.careful, Metamagic.heightened},
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
            onCharacterChanged: (_) {},
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text(spell.name).first);
      expect(find.text('Other Metamagic combinations'), findsNothing);
      await helpers.tap(tester, find.text('My turn · Arm free Metamagic'));
      await helpers.tap(tester, find.text('Other Metamagic combinations'));
      await helpers.tap(tester, find.text('Careful Spell'));
      await helpers.tap(
        tester,
        find.text('Heightened Spell · 1 total Sorcery Points'),
      );
      await saves.targets(tester, 'Ally');
      await saves.targets(tester, 'Enemy');
      await helpers.tap(tester, find.text('Use Free Cast'));
      expect(find.textContaining('Ally automatically succeed'), findsOneWidget);
      expect(find.textContaining('Enemy has Disadvantage'), findsOneWidget);
      await helpers.tap(tester, find.text('Failed save'));
      expect(session.apotheosisUsedThisTurn, isTrue);
      expect(session.apotheosisArmed, isFalse);
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 0);
      expect(session.characterState.resourceValues[free.id], 0);
      expect(session.characterState.resourceValues[spellSlotId(1)] ?? 4, 4);
      expect(
        session.characterState.spellSaveEffects[spell.id]?.heightenedTarget,
        'Enemy',
      );
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(tester.takeException(), isNull);
    },
  );

  for (final (level, active, points, actionUsed) in [
    (6, true, 6, false),
    (7, false, 7, false),
    (7, true, 2, false),
    (7, true, 7, true),
  ]) {
    testWidgets('Composite gate $level/$active/$points/$actionUsed', (
      tester,
    ) async {
      const spell = saves.burst;
      final character = base
          .sorcerer(level: level)
          .copyWith(
            spells: [spell],
            metamagicOptions: {Metamagic.careful, Metamagic.heightened},
            initiallyPinnedActionKeys: {spell.actionKey},
          );
      final session = CharacterSession(
        characterState: CharacterSession.fromCharacter(character).characterState
            .copyWith(
              activeConditions: active ? {innateSorceryCondition} : {},
              resourceValues: {sorceryPointsResourceId: points},
            ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        usedCombatActions: actionUsed ? {CombatActionCost.action} : {},
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
      expect(find.text('Other Metamagic combinations'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
