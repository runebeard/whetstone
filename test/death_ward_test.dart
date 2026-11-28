import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/class_spells.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/conditions_dialog.dart';
import 'life_domain_spells_test.dart' as fixtures;
import 'draconic_spell_grants_test.dart' as helpers;

void main() {
  testWidgets(
    'Tracked wards can be ended manually without clearing conditions',
    (tester) async {
      var conditions = {deathWardCondition, 'Poisoned'};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConditionsDialog(
              activeConditions: conditions,
              conditionTurns: const {deathWardCondition: 4800},
              onChanged: (value) => conditions = value,
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text(deathWardCondition),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text(deathWardCondition));
      await tester.pumpAndSettle();
      expect(conditions, {'Poisoned'});
      expect(find.text('4800 turns remaining'), findsNothing);
    },
  );
  for (final (hp, temp, damage, result, consumed) in [
    (10, 0, 9, 1, false),
    (10, 0, 10, 1, true),
    (10, 5, 14, 1, false),
    (10, 5, 15, 1, true),
    (10, 0, 100, 1, true),
    (0, 0, 5, 0, false),
  ]) {
    test('Ward damage $hp/$temp/$damage consumes=$consumed', () {
      final state = CharacterState.fromCharacter(fixtures.life(9)).copyWith(
        currentHp: hp,
        temporaryHp: temp,
        activeConditions: {deathWardCondition, 'Poisoned'},
        conditionTurns: {deathWardCondition: 4800},
        concentrationSpellId: 'bless',
        concentrationTurnsRemaining: 7,
      );
      final next = state.takeDamage(damage);
      expect(next.currentHp, result);
      expect(next.activeConditions.contains(deathWardCondition), !consumed);
      expect(next.activeConditions, contains('Poisoned'));
      if (consumed) {
        expect(next.concentrationSpellId, 'bless');
        expect(next.conditionTurns.containsKey(deathWardCondition), isFalse);
        expect(next.takeDamage(1).currentHp, 0);
      }
      expect(CharacterState.fromJson(next.toJson()).currentHp, result);
    });
  }
  for (final (type, turns, remaining) in [
    (RestType.shortRest, 4800, 4200),
    (RestType.shortRest, 500, 0),
    (RestType.longRest, 4800, 0),
    (RestType.longRest, 9600, 4800),
  ]) {
    test('Ward rest expiry $type/$turns', () {
      final character = fixtures.life(9);
      final state = CharacterState.fromCharacter(character).copyWith(
        activeConditions: {deathWardCondition},
        conditionTurns: {deathWardCondition: turns},
      );
      final result = RestPlan.forCharacter(
        type: type,
        character: character,
        currentState: state,
      ).updatedState;
      expect(
        result.activeConditions.contains(deathWardCondition),
        remaining > 0,
      );
      expect(
        result.conditionTurns[deathWardCondition],
        remaining == 0 ? null : remaining,
      );
    });
  }
  for (final self in [true, false]) {
    testWidgets(
      'Death Ward casting self=$self cancels safely and preserves concentration',
      (tester) async {
        var character = withBuiltInSpellGrants(fixtures.life(9));
        final spell = character.spells.singleWhere(
          (s) => s.name == 'Death Ward',
        );
        character = character.copyWith(
          initiallyPinnedActionKeys: {spell.actionKey},
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 22,
            concentrationSpellId: character.spells
                .singleWhere((s) => s.name == 'Bless')
                .id,
            concentrationTurnsRemaining: 7,
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final concentration = session.characterState.concentrationSpellId;
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              onCharacterChanged: (_) {},
              onSessionChanged: (v) => session = v,
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> begin() async {
          await helpers.tap(tester, find.text('Death Ward').first);
          await helpers.tap(tester, find.text('Cast').last);
        }

        await begin();
        await helpers.tap(tester, find.text('Cancel'));
        expect(session.usedCombatActions, isEmpty);
        await begin();
        await helpers.tap(
          tester,
          find.text(self ? 'Yourself' : 'Another creature'),
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(session.usedCombatActions, isEmpty);
        await begin();
        await helpers.tap(
          tester,
          find.text(self ? 'Yourself' : 'Another creature'),
        );
        await helpers.tap(tester, find.text('Level 4 · 3 remaining'));
        expect(
          session.characterState.activeConditions.contains(deathWardCondition),
          self,
        );
        expect(
          session.characterState.conditionTurns[deathWardCondition],
          self ? 4800 : null,
        );
        expect(session.characterState.concentrationSpellId, concentration);
        expect(session.characterState.currentHp, 22);
        expect(session.characterState.resourceValues[spellSlotId(4)], 2);
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(tester.takeException(), isNull);
      },
    );
  }
}
