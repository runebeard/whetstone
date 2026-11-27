import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

Spell effectSpell(Metamagic primary) => primary == Metamagic.transmuted
    ? saves.burst
    : const Spell(
        id: 'hold-person',
        name: 'Hold Person',
        level: 2,
        prepared: true,
        castingTime: 'Action',
        concentration: true,
        duration: 'Concentration, up to 1 minute',
        savingThrowAbility: Ability.wisdom,
        summary: 'A control spell.',
      );

void main() {
  for (final primary in [Metamagic.transmuted, Metamagic.twinned]) {
    for (final secondary in [Metamagic.careful, Metamagic.heightened]) {
      testWidgets(
        '${primary.label} plus ${secondary.label} preserves effects, costs and reload',
        (tester) async {
          final spell = effectSpell(primary);
          final character = base.sorcerer().copyWith(
            spells: [spell],
            metamagicOptions: {primary, secondary},
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
                onCharacterChanged: (_) {},
                onSessionChanged: (value) => session = value,
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> begin() async {
            await helpers.tap(tester, find.text(spell.name).first);
            await helpers.tap(
              tester,
              find.text('Other Metamagic combinations'),
            );
          }

          await begin();
          await helpers.tap(tester, find.text('Cancel'));
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId] ?? 7,
            7,
          );
          await begin();
          await helpers.tap(tester, find.text(primary.label));
          await helpers.tap(tester, find.text('Cancel'));
          expect(session.usedCombatActions, {CombatActionCost.bonusAction});
          Future<void> preview() async {
            await begin();
            await helpers.tap(tester, find.text(primary.label));
            await helpers.tap(
              tester,
              find.text(
                '${secondary.label} · ${1 + secondary.pointCost} total Sorcery Points',
              ),
            );
            await saves.targets(tester, 'Target');
            if (primary == Metamagic.transmuted) {
              await helpers.tap(tester, find.text('Cold'));
            }
          }

          await preview();
          expect(
            find.textContaining(
              primary == Metamagic.transmuted
                  ? 'Damage type for this casting: Cold'
                  : 'effective casting level by 1',
            ),
            findsOneWidget,
          );
          await helpers.tap(tester, find.text('Cast with Metamagic'));
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId] ?? 7,
            7,
          );
          await preview();
          await helpers.tap(tester, find.text('Cast with Metamagic'));
          await helpers.tap(
            tester,
            find.text(
              'Level ${spell.level} · ${spell.level == 1 ? 4 : 3} remaining',
            ),
          );
          await helpers.tap(
            tester,
            find.text(
              secondary == Metamagic.careful
                  ? 'Protected target · Automatic save'
                  : 'Failed save',
            ),
          );
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId],
            6 - secondary.pointCost,
          );
          expect(
            session.characterState.resourceValues[spellSlotId(spell.level)],
            spell.level == 1 ? 3 : 2,
          );
          expect(session.usedCombatActions, {
            CombatActionCost.action,
            CombatActionCost.bonusAction,
          });
          final restored = CharacterSession.fromJson(session.toJson());
          expect(
            restored.characterState.spellSaveEffects[spell.id]?.option,
            secondary,
          );
          expect(restored.characterState.spellSaveEffects[spell.id]?.targets, [
            'Target',
          ]);
          if (primary == Metamagic.transmuted) {
            expect(restored.characterState.spellDamageTypes[spell.id], 'Cold');
            if (secondary == Metamagic.careful) {
              expect(session.timeline.first.title, 'Save Burst Damage: 0');
            }
          } else {
            expect(restored.characterState.concentrationSlotLevel, 3);
            expect(restored.characterState.concentrationTurnsRemaining, 10);
            expect(
              session.timeline
                  .singleWhere(
                    (e) => e.title == 'Twinned Spell targets · Hold Person',
                  )
                  .detail,
              contains('2 targets'),
            );
          }
          for (final option in [primary, secondary]) {
            expect(
              session.timeline.where(
                (e) => e.title == '${option.label} · ${spell.name}',
              ),
              hasLength(1),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final (level, active, points, actionUsed) in [
      (6, true, 6, false),
      (7, false, 7, false),
      (7, true, 2, false),
      (7, true, 7, true),
    ]) {
      testWidgets(
        '${primary.label} effect-pair gate $level/$active/$points/$actionUsed',
        (tester) async {
          final spell = effectSpell(primary);
          final character = base
              .sorcerer(level: level)
              .copyWith(
                spells: [spell],
                metamagicOptions: {primary, Metamagic.heightened},
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
          expect(find.text('Other Metamagic combinations'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('${primary.label} plus Heightened shares one Apotheosis use', (
      tester,
    ) async {
      final spell = effectSpell(primary);
      final character = base
          .sorcerer(level: 20)
          .copyWith(
            spells: [spell],
            metamagicOptions: {primary, Metamagic.heightened},
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
            diceRoller: SequenceDiceRoller([4, 5]),
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
      await helpers.tap(tester, find.text(primary.label));
      await helpers.tap(
        tester,
        find.text('Heightened Spell · 1 total Sorcery Points'),
      );
      await saves.targets(tester, 'Target');
      if (primary == Metamagic.transmuted) {
        await helpers.tap(tester, find.text('Cold'));
      }
      await helpers.tap(tester, find.text('Cast with Metamagic'));
      await helpers.tap(
        tester,
        find.text(
          'Level ${spell.level} · ${spell.level == 1 ? 4 : 3} remaining',
        ),
      );
      await helpers.tap(tester, find.text('Failed save'));
      expect(session.apotheosisUsedThisTurn, isTrue);
      expect(session.apotheosisArmed, isFalse);
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 0);
      expect(
        session.timeline.where(
          (e) => e.title == 'Arcane Apotheosis · Heightened Spell',
        ),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
