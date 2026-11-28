import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/class_spells.dart';
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

void main() {
  for (final condition in ['Blinded', 'Deafened', 'Poisoned']) {
    testWidgets(
      'Lesser Restoration ends only self $condition with its duration',
      (tester) async {
        var character = withBuiltInSpellGrants(fixtures.life(9));
        final spell = character.spells.singleWhere(
          (s) => s.name == 'Lesser Restoration',
        );
        final bless = character.spells.singleWhere((s) => s.name == 'Bless');
        character = character.copyWith(
          initiallyPinnedActionKeys: {spell.actionKey},
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 22,
            activeConditions: {condition, 'Frightened'},
            conditionTurns: {condition: 4, 'Frightened': 7},
            concentrationSpellId: bless.id,
            concentrationSlotLevel: 1,
            concentrationTurnsRemaining: 8,
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
              diceRoller: SequenceDiceRoller([]),
              onCharacterChanged: (_) {},
              onSessionChanged: (v) => session = v,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text(spell.name).first);
        await helpers.tap(tester, find.text('Cast').last);
        await helpers.tap(tester, find.text('Treat yourself'));
        expect(find.text('End Frightened'), findsNothing);
        await helpers.tap(tester, find.text('End $condition'));
        await helpers.tap(tester, find.text('Level 2 · 3 remaining'));
        expect(session.characterState.activeConditions, {'Frightened'});
        expect(session.characterState.conditionTurns, {'Frightened': 7});
        expect(session.characterState.currentHp, 22);
        expect(session.characterState.concentrationSpellId, bless.id);
        expect(session.characterState.concentrationTurnsRemaining, 8);
        expect(session.characterState.resourceValues[spellSlotId(2)], 2);
        expect(session.usedCombatActions, {CombatActionCost.bonusAction});
        final restored = CharacterSession.fromJson(session.toJson());
        expect(restored.characterState.activeConditions, {'Frightened'});
        expect(restored.characterState.conditionTurns, {'Frightened': 7});
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final condition in ['Blinded', 'Deafened', 'Paralyzed', 'Poisoned']) {
    testWidgets(
      'Restoration of another $condition target preserves caster conditions',
      (tester) async {
        var character = withBuiltInSpellGrants(fixtures.life(9));
        final spell = character.spells.singleWhere(
          (s) => s.name == 'Lesser Restoration',
        );
        character = character.copyWith(
          initiallyPinnedActionKeys: {spell.actionKey},
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 22,
            activeConditions: {'Poisoned'},
            conditionTurns: {'Poisoned': 4},
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
              diceRoller: SequenceDiceRoller([]),
              onCharacterChanged: (_) {},
              onSessionChanged: (v) => session = v,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text(spell.name).first);
        await helpers.tap(tester, find.text('Cast').last);
        await helpers.tap(tester, find.text('Treat another creature'));
        expect(find.text('End Stunned'), findsNothing);
        await helpers.tap(tester, find.text('End $condition'));
        await helpers.tap(tester, find.text('Level 2 · 3 remaining'));
        expect(session.characterState.activeConditions, {'Poisoned'});
        expect(session.characterState.conditionTurns, {'Poisoned': 4});
        expect(session.characterState.currentHp, 22);
        expect(
          session.timeline.first.detail,
          contains('End $condition on the confirmed other target'),
        );
        expect(session.characterState.resourceValues[spellSlotId(2)], 2);
        expect(session.usedCombatActions, {CombatActionCost.bonusAction});
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Cancelling any Restoration stage preserves conditions and costs',
    (tester) async {
      var character = withBuiltInSpellGrants(fixtures.life(9));
      final spell = character.spells.singleWhere(
        (s) => s.name == 'Lesser Restoration',
      );
      character = character.copyWith(
        initiallyPinnedActionKeys: {spell.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character).copyWith(
          activeConditions: {'Poisoned'},
          conditionTurns: {'Poisoned': 4},
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
            diceRoller: SequenceDiceRoller([]),
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var stage = 0; stage < 3; stage++) {
        await helpers.tap(tester, find.text(spell.name).first);
        await helpers.tap(tester, find.text('Cast').last);
        if (stage > 0) {
          await helpers.tap(tester, find.text('Treat yourself'));
        }
        if (stage == 2) {
          await helpers.tap(tester, find.text('End Poisoned'));
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } else {
          await helpers.tap(tester, find.text('Cancel'));
        }
        expect(session.characterState.activeConditions, {'Poisoned'});
        expect(session.characterState.conditionTurns, {'Poisoned': 4});
        expect(session.usedCombatActions, isEmpty);
        expect(session.characterState.resourceValues[spellSlotId(2)] ?? 3, 3);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final gate in ['none', 'paralyzed', 'bonus']) {
    testWidgets(
      'Restoration gate $gate cannot remove an ineligible self condition',
      (tester) async {
        var character = withBuiltInSpellGrants(fixtures.life(9));
        final spell = character.spells.singleWhere(
          (s) => s.name == 'Lesser Restoration',
        );
        character = character.copyWith(
          initiallyPinnedActionKeys: {spell.actionKey},
        );
        final conditions = gate == 'paralyzed' ? {'Paralyzed'} : {'Frightened'};
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(activeConditions: conditions),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: gate == 'bonus'
              ? {CombatActionCost.bonusAction}
              : {},
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
        expect(find.text('Treat yourself'), findsNothing);
        expect(
          find.text('Treat another creature'),
          gate == 'none' ? findsOneWidget : findsNothing,
        );
        expect(session.characterState.activeConditions, conditions);
        expect(session.characterState.resourceValues[spellSlotId(2)] ?? 3, 3);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Subtle free Restoration spends one free use and point, not a slot',
    (tester) async {
      var character = withBuiltInSpellGrants(
        fixtures
            .life(11)
            .copyWith(
              additionalClassLevels: {'Sorcerer': 2},
              metamagicOptions: {Metamagic.subtle},
            ),
      );
      final spell = character.spells.singleWhere(
        (s) => s.name == 'Lesser Restoration',
      );
      final free = CharacterResource(
        id: 'whetstone:free-cast:${spell.id}',
        name: 'Free Restoration',
        maximum: 1,
        initialValue: 1,
        rechargePeriod: RechargePeriod.longRest,
      );
      character = character.copyWith(
        initiallyPinnedActionKeys: {spell.actionKey},
        resources: [...character.resources, free],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          character,
        ).copyWith(currentHp: 22, activeConditions: {'Poisoned'}),
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
      await helpers.tap(tester, find.text('Subtle Spell'));
      await helpers.tap(tester, find.text('Use Free Cast'));
      await helpers.tap(tester, find.text('Treat yourself'));
      await helpers.tap(tester, find.text('End Poisoned'));
      expect(session.characterState.activeConditions, isEmpty);
      expect(session.characterState.currentHp, 22);
      expect(session.characterState.resourceValues[free.id], 0);
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 1);
      expect(session.characterState.resourceValues[spellSlotId(2)] ?? 3, 3);
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(tester.takeException(), isNull);
    },
  );
}
