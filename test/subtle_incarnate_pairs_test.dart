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
import 'sorcery_incarnate_pairs_test.dart' as pairs;
import 'support/sequence_dice_roller.dart';

void main() {
  for (final primary in [Metamagic.subtle, Metamagic.distant]) {
    final pairButton =
        '${primary == Metamagic.subtle ? 'Subtle' : 'Distant'} + another option';
    for (final option in [
      Metamagic.distant,
      Metamagic.extended,
      Metamagic.transmuted,
      Metamagic.twinned,
      Metamagic.careful,
      Metamagic.heightened,
    ]) {
      if (option == primary) continue;
      testWidgets(
        '${primary.label} plus ${option.label} preserves both effects and costs',
        (tester) async {
          final spell = option == Metamagic.twinned
              ? const Spell(
                  id: 'paired',
                  name: 'Hold Person',
                  level: 2,
                  prepared: true,
                  castingTime: 'Action',
                  range: '60 feet',
                  concentration: true,
                  duration: 'Concentration, up to 1 minute',
                  components: 'V, S, M (a small iron bar)',
                  summary: 'A concentrating control spell.',
                )
              : pairs.pairedSpell(option);
          var character = base.sorcerer().copyWith(
            spells: [spell],
            metamagicOptions: {primary, option},
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
            usedCombatActions: {CombatActionCost.bonusAction},
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
            await helpers.tap(tester, find.text(pairButton));
          }

          await begin();
          await helpers.tap(tester, find.text('Cancel'));
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId] ?? 7,
            7,
          );
          await begin();
          final cost = 1 + option.pointCost;
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
          expect(
            find.textContaining(
              primary == Metamagic.subtle
                  ? 'Verbal and Somatic components waived'
                  : 'Range for this casting: 120 feet',
            ),
            findsOneWidget,
          );
          await helpers.tap(tester, find.text('Cast with Metamagic'));
          if (option == Metamagic.distant ||
              (primary == Metamagic.distant && option == Metamagic.extended)) {
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(
              session.characterState.resourceValues[sorceryPointsResourceId] ??
                  7,
              7,
            );
            expect(session.usedCombatActions, {CombatActionCost.bonusAction});
            await begin();
            await helpers.tap(
              tester,
              find.text('${option.label} · $cost total Sorcery Points'),
            );
            await helpers.tap(tester, find.text('Cast with Metamagic'));
          }
          await helpers.tap(
            tester,
            find.text(
              'Level ${spell.level} · ${spell.level == 2 ? 3 : 4} remaining',
            ),
          );
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
          expect(
            session.characterState.resourceValues[spellSlotId(spell.level)],
            spell.level == 2 ? 2 : 3,
          );
          expect(session.usedCombatActions, {
            CombatActionCost.action,
            CombatActionCost.bonusAction,
          });
          expect(session.quickenedSpellUsedThisTurn, isFalse);
          for (final applied in [primary, option]) {
            expect(
              session.timeline.where(
                (e) => e.title == '${applied.label} · ${spell.name}',
              ),
              hasLength(1),
            );
          }
          if (option == Metamagic.extended) {
            expect(session.characterState.extendedConcentration, isTrue);
            expect(session.characterState.concentrationTurnsRemaining, 20);
          }
          if (option == Metamagic.transmuted) {
            expect(session.characterState.spellDamageTypes[spell.id], 'Cold');
          }
          if (option == Metamagic.twinned) {
            expect(session.characterState.concentrationSlotLevel, 3);
            expect(session.characterState.concentrationTurnsRemaining, 10);
          }
          if (option == Metamagic.careful) {
            expect(session.timeline.first.title, 'Paired Spell Damage: 0');
          }
          if (option == Metamagic.heightened) {
            expect(session.characterState.spellSaveEffects[spell.id]?.targets, [
              'Target',
            ]);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final (level, active, points, actionUsed) in [
      (6, true, 6, false),
      (7, false, 7, false),
      (7, true, 1, false),
      (7, true, 7, true),
    ]) {
      testWidgets(
        '${primary.label} pair gate $level/$active/$points/$actionUsed',
        (tester) async {
          final spell = pairs.pairedSpell(Metamagic.extended);
          final character = base
              .sorcerer(level: level)
              .copyWith(
                spells: [spell],
                metamagicOptions: {primary, Metamagic.extended},
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
          expect(find.text(pairButton), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '${primary.label} pair waives Heightened only with one Apotheosis use',
      (tester) async {
        final spell = pairs.pairedSpell(Metamagic.heightened);
        final character = base
            .sorcerer(level: 20)
            .copyWith(
              spells: [spell],
              metamagicOptions: {primary, Metamagic.heightened},
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
        expect(find.text(pairButton), findsNothing);
        await helpers.tap(tester, find.text('My turn · Arm free Metamagic'));
        await helpers.tap(tester, find.text(pairButton));
        await helpers.tap(
          tester,
          find.text('Heightened Spell · 1 total Sorcery Points'),
        );
        await saves.targets(tester, 'Target');
        await helpers.tap(tester, find.text('Cast with Metamagic'));
        await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
        await helpers.tap(tester, find.text('Failed save'));
        expect(session.apotheosisUsedThisTurn, isTrue);
        expect(session.apotheosisArmed, isFalse);
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          0,
        );
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(
          session.timeline
              .singleWhere(
                (e) => e.title == 'Arcane Apotheosis · Heightened Spell',
              )
              .detail,
          contains('no Sorcery Points spent'),
        );
        expect(session.characterState.spellSaveEffects[spell.id]?.targets, [
          'Target',
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
