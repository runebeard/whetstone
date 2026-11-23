import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/class_spells.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as grants;

void main() {
  testWidgets(
    'Combat slot cancellation preserves action and concentration; successful cast spends one action',
    (tester) async {
      var character = withDraconicSpellGrants(grants.draconic(18));
      final spell = character.spells.singleWhere(
        (s) => s.name == 'Summon Dragon',
      );
      character = character.copyWith(
        initiallyPinnedActionKeys: {spell.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character).copyWith(
          concentrationSpellId: spell.id,
          concentrationTurnsRemaining: 600,
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
      Future<void> begin() async {
        await grants.tap(tester, find.text('Summon Dragon').first);
        await grants.tap(tester, find.text('Cast').last);
        expect(
          find.text('End concentration on the earlier dragon first'),
          findsOneWidget,
        );
        expect(
          find.text('Dragon Companion · No concentration · 1 minute'),
          findsNothing,
        );
        await grants.tap(tester, find.text('Concentrate · 1 hour'));
      }

      await begin();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, isEmpty);
      expect(session.characterState.resourceValues[spellSlotId(5)], 3);
      expect(session.characterState.concentrationSpellId, spell.id);
      await begin();
      await grants.tap(tester, find.text('Level 5 · 3 remaining'));
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(session.characterState.resourceValues[spellSlotId(5)], 2);
      expect(
        session.characterState.resourceValues[dragonCompanionResourceId] ?? 1,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Dragon Companion requires eighteen Sorcerer levels and Draconic subclass',
    () {
      for (final level in [17, 18]) {
        final character = grants.draconic(level);
        expect(character.hasDragonCompanion, level == 18);
        final resources = BuiltInClass.sorcerer.classResources(
          level,
          subclass: 'Draconic Sorcery',
          charismaModifier: 3,
        );
        expect(
          resources.any((r) => r.id == dragonCompanionResourceId),
          level == 18,
        );
      }
      expect(
        grants.draconic(18).copyWith(subclasses: {}).hasDragonCompanion,
        isFalse,
      );
    },
  );
  test(
    'Saved companion expires without ending other concentration or summons',
    () {
      final character = grants.draconic(18);
      var state = CharacterState.fromCharacter(character).copyWith(
        dragonCompanionSpellId: 'dragon',
        activeConditions: {dragonCompanionCondition},
        conditionTurns: {dragonCompanionCondition: 10},
        concentrationSpellId: 'other',
        concentrationTurnsRemaining: 100,
        spellSummons: {'dragon': 'Spirit', 'other': 'Other summon'},
      );
      state = CharacterState.fromJson(state.toJson());
      expect(state.dragonCompanionSpellId, 'dragon');
      for (var i = 0; i < 10; i++) {
        state = state.advanceConditionTurn().normalizeDragonCompanion(
          character,
        );
      }
      expect(state.dragonCompanionSpellId, isNull);
      expect(state.spellSummons, {'other': 'Other summon'});
      expect(state.concentrationSpellId, 'other');
      expect(state.activeConditions, isNot(contains(dragonCompanionCondition)));
    },
  );
  test(
    'Rest ends companion, only Long Rest restores daily cast; class loss cleans up',
    () {
      var character = grants.draconic(18);
      character = character.copyWith(
        resources: [
          ...character.resources,
          ...BuiltInClass.sorcerer.classResources(
            18,
            subclass: 'Draconic Sorcery',
            charismaModifier: 3,
          ),
        ],
      );
      final state = CharacterState.fromCharacter(character).copyWith(
        dragonCompanionSpellId: 'dragon',
        activeConditions: {dragonCompanionCondition},
        conditionTurns: {dragonCompanionCondition: 10},
        spellSummons: {'dragon': 'Spirit'},
        resourceValues: {dragonCompanionResourceId: 0},
      );
      for (final type in RestType.values) {
        final after = RestPlan.forCharacter(
          type: type,
          character: character,
          currentState: state,
        ).updatedState;
        expect(after.dragonCompanionSpellId, isNull);
        expect(after.spellSummons, isEmpty);
        expect(
          after.resourceValues[dragonCompanionResourceId],
          type == RestType.longRest ? 1 : 0,
        );
      }
      expect(
        state.normalizeDragonCompanion(grants.draconic(17)).spellSummons,
        isEmpty,
      );
    },
  );
  for (final free in [true, false]) {
    for (final nonConcentration in [true, false]) {
      testWidgets(
        '${free ? 'Free' : 'Slot'} dragon cast, concentration waived $nonConcentration',
        (tester) async {
          var character = withDraconicSpellGrants(grants.draconic(18));
          var session = CharacterSession(
            characterState: CharacterState.fromCharacter(character).copyWith(
              concentrationSpellId: 'other',
              concentrationTurnsRemaining: 100,
              spellSummons: {'other': 'Other summon'},
            ),
            inventory: [],
            archivedInventory: [],
          );
          Widget app(int generation) => MaterialApp(
            home: CharacterOverview(
              key: ValueKey(generation),
              character: character,
              initialSession: session,
              onCharacterChanged: (value) => character = value,
              onSessionChanged: (value) => session = value,
            ),
          );
          await tester.pumpWidget(app(0));
          await tester.pumpAndSettle();
          await grants.tap(tester, find.text('Spellbook'));
          Future<void> beginCast() async {
            if (free) {
              await tester.ensureVisible(find.text('Summon Dragon'));
              await tester.longPress(find.text('Summon Dragon'));
              await tester.pumpAndSettle();
              await grants.tap(
                tester,
                find.text('Dragon Companion · Free cast'),
              );
            } else {
              await grants.tap(tester, find.text('Summon Dragon'));
              expect(
                find.textContaining('waives the Material component'),
                findsOneWidget,
              );
              await grants.tap(tester, find.text('Cast'));
            }
          }

          await beginCast();
          await grants.tap(tester, find.text('Cancel'));
          expect(session.characterState.concentrationSpellId, 'other');
          expect(session.characterState.resourceValues[spellSlotId(5)], 3);
          expect(
            session.characterState.resourceValues[dragonCompanionResourceId] ??
                1,
            1,
          );
          await beginCast();
          await grants.tap(
            tester,
            find.text(
              nonConcentration
                  ? 'Dragon Companion · No concentration · 1 minute'
                  : 'Concentrate · 1 hour',
            ),
          );
          if (!free) {
            await grants.tap(tester, find.text('Level 5 · 3 remaining'));
          }
          final dragon = character.spells.singleWhere(
            (s) => s.name == 'Summon Dragon',
          );
          expect(
            session.characterState.resourceValues[spellSlotId(5)],
            free ? 3 : 2,
          );
          expect(
            session.characterState.resourceValues[dragonCompanionResourceId] ??
                1,
            free ? 0 : 1,
          );
          expect(
            session.characterState.concentrationSpellId,
            nonConcentration ? 'other' : dragon.id,
          );
          expect(
            session.characterState.concentrationTurnsRemaining,
            nonConcentration ? 100 : 600,
          );
          expect(
            session.characterState.dragonCompanionSpellId,
            nonConcentration ? dragon.id : null,
          );
          if (nonConcentration) {
            expect(
              session.characterState.conditionTurns[dragonCompanionCondition],
              10,
            );
            session = CharacterSession.fromJson(session.toJson());
            await tester.pumpWidget(app(1));
            await tester.pumpAndSettle();
            await grants.tap(tester, find.text('Spellbook'));
            await grants.tap(
              tester,
              find.text(
                'Draconic Spirit · Dragon Companion (no concentration)',
              ),
            );
            await grants.tap(tester, find.text('Dismiss Summon'));
            expect(session.characterState.dragonCompanionSpellId, isNull);
            expect(session.characterState.concentrationSpellId, 'other');
            expect(session.characterState.spellSummons, {
              'other': 'Other summon',
            });
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
