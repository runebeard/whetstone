import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/class_spells.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'life_domain_spells_test.dart' as fixtures;
import 'draconic_spell_grants_test.dart' as helpers;
import 'support/sequence_dice_roller.dart';

Character cleric(int level) {
  final base = fixtures.life(level);
  return withBuiltInSpellGrants(
    base.copyWith(
      abilityScores: {Ability.wisdom: 16},
      resources: [
        ...base.resources,
        ...BuiltInClass.cleric.classResources(
          level,
          charismaModifier: 0,
          wisdomModifier: 3,
        ),
      ],
    ),
  );
}

class Scenario {
  late Character hero;
  late CharacterSession session;
  late String bless;
  Future<void> boot(
    WidgetTester tester, {
    int level = 10,
    String? gate,
    Set<CombatActionCost> used = const {},
  }) async {
    hero = cleric(level);
    hero = hero.copyWith(
      initiallyPinnedActionKeys: {
        hero.spells
            .singleWhere((s) => s.name == 'Lesser Restoration')
            .actionKey,
      },
    );
    bless = hero.spells.singleWhere((s) => s.name == 'Bless').id;
    session = CharacterSession(
      characterState: CharacterState.fromCharacter(hero).copyWith(
        currentHp: 13,
        concentrationSpellId: bless,
        concentrationTurnsRemaining: 8,
        activeConditions: {
          'Charmed',
          'Poisoned',
          if (gate == 'incapacitated') 'Paralyzed',
          if (gate == 'rage') ragingCondition,
        },
        conditionTurns: {'Charmed': 5, 'Poisoned': 7},
        resourceValues: {
          for (final r in hero.resources)
            r.id: r.id == divineInterventionResourceId && gate == 'empty'
                ? 0
                : r.initialValue,
        },
      ),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
      usedCombatActions: used,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: hero,
          initialSession: session,
          onCharacterChanged: (v) => hero = v,
          onSessionChanged: (v) => session = v,
          diceRoller: SequenceDiceRoller([2, 2]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> begin(WidgetTester tester) async =>
      helpers.tap(tester, find.text('Divine Intervention').first);
}

void main() {
  for (final level in [9, 10, 20]) {
    test(
      'Divine Intervention resource eligibility and rest recovery at $level',
      () {
        final hero = cleric(level);
        final pools = hero.resources.where(
          (r) => r.id == divineInterventionResourceId,
        );
        expect(pools.length, level < 10 ? 0 : 1);
        if (level < 10) return;
        expect(pools.single.maximum, 1);
        final state = CharacterState.fromCharacter(
          hero,
        ).copyWith(resourceValues: {divineInterventionResourceId: 0});
        expect(
          RestPlan.forCharacter(
            type: RestType.shortRest,
            character: hero,
            currentState: state,
          ).updatedState.resourceValues[divineInterventionResourceId],
          0,
        );
        expect(
          RestPlan.forCharacter(
            type: RestType.longRest,
            character: hero,
            currentState: state,
          ).updatedState.resourceValues[divineInterventionResourceId],
          1,
        );
      },
    );
  }
  testWidgets(
    'Intervention Greater Restoration waives dust and slots and preserves other state',
    (tester) async {
      final s = Scenario();
      await s.boot(tester);
      final resources = {...s.session.characterState.resourceValues};
      await s.begin(tester);
      await helpers.tap(tester, find.text('Cast Greater Restoration'));
      await helpers.tap(tester, find.text('Treat yourself'));
      await helpers.tap(tester, find.text('End Charmed'));
      expect(find.text('Greater Restoration · Components'), findsNothing);
      expect(s.session.characterState.activeConditions, {'Poisoned'});
      expect(s.session.characterState.conditionTurns, {'Poisoned': 7});
      expect(s.session.characterState.resourceValues, {
        ...resources,
        divineInterventionResourceId: 0,
      });
      expect(s.session.characterState.currentHp, 13);
      expect(s.session.characterState.concentrationSpellId, s.bless);
      expect(s.session.usedCombatActions, {CombatActionCost.action});
      expect(
        s.session.timeline.first.title,
        'Divine Intervention · Greater Restoration',
      );
      expect(
        s.session.timeline.first.detail,
        contains('without a spell slot or Material'),
      );
      final restored = CharacterSession.fromJson(s.session.toJson());
      expect(
        restored.characterState.resourceValues[divineInterventionResourceId],
        0,
      );
      expect(restored.characterState.activeConditions, {'Poisoned'});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Intervention converts Lesser Restoration to a Magic Action', (
    tester,
  ) async {
    final s = Scenario();
    await s.boot(tester, used: {CombatActionCost.bonusAction});
    final slots = s.session.characterState.resourceValues[spellSlotId(2)];
    await s.begin(tester);
    await helpers.tap(tester, find.text('Cast Lesser Restoration'));
    await helpers.tap(tester, find.text('Treat yourself'));
    await helpers.tap(tester, find.text('End Poisoned'));
    expect(s.session.characterState.activeConditions, {'Charmed'});
    expect(s.session.usedCombatActions, {
      CombatActionCost.action,
      CombatActionCost.bonusAction,
    });
    expect(
      s.session.characterState.resourceValues[divineInterventionResourceId],
      0,
    );
    expect(s.session.characterState.resourceValues[spellSlotId(2)], slots);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Cancelling Intervention clears its action override before ordinary casting',
    (tester) async {
      final s = Scenario();
      await s.boot(tester);
      for (final stage in [0, 1]) {
        await s.begin(tester);
        if (stage == 1) {
          await helpers.tap(tester, find.text('Cast Lesser Restoration'));
        }
        await helpers.tap(tester, find.text('Cancel'));
        expect(
          s.session.characterState.resourceValues[divineInterventionResourceId],
          1,
        );
        expect(s.session.usedCombatActions, isEmpty);
      }
      await helpers.tap(tester, find.text('Lesser Restoration').first);
      await helpers.tap(tester, find.text('Cast').last);
      await helpers.tap(tester, find.text('Treat yourself'));
      await helpers.tap(tester, find.text('End Poisoned'));
      await helpers.tap(tester, find.text('Level 2 · 3 remaining'));
      expect(
        s.session.characterState.resourceValues[divineInterventionResourceId],
        1,
      );
      expect(s.session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Intervention healing does not receive slot-based Life bonuses', (
    tester,
  ) async {
    final s = Scenario();
    await s.boot(tester);
    await s.begin(tester);
    await helpers.tap(tester, find.text('Cast Cure Wounds'));
    await helpers.tap(tester, find.text('Heal yourself'));
    expect(s.session.characterState.currentHp, 20);
    expect(
      s.session.characterState.resourceValues[divineInterventionResourceId],
      0,
    );
    expect(s.session.usedCombatActions, {CombatActionCost.action});
    expect(tester.takeException(), isNull);
  });
  testWidgets('Intervention Bless still starts tracked concentration', (
    tester,
  ) async {
    final s = Scenario();
    await s.boot(tester);
    final resources = {...s.session.characterState.resourceValues};
    await s.begin(tester);
    await helpers.tap(tester, find.text('Cast Bless'));
    expect(s.session.characterState.concentrationSpellId, s.bless);
    expect(s.session.characterState.concentrationTurnsRemaining, 10);
    expect(s.session.characterState.resourceValues, {
      ...resources,
      divineInterventionResourceId: 0,
    });
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Manual Intervention requires eligibility confirmation and tracks concentration at the table',
    (tester) async {
      final s = Scenario();
      await s.boot(tester);
      final spells = s.hero.toJson()['spells'];
      final resources = {...s.session.characterState.resourceValues};
      await s.begin(tester);
      await helpers.tap(
        tester,
        find.text('Another Cleric spell · At the table'),
      );
      final cast = find.widgetWithText(FilledButton, 'Cast at the table');
      expect(tester.widget<FilledButton>(cast).onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, 'Spirit Guardians');
      tester.testTextInput.hide();
      await helpers.tap(tester, find.byType(DropdownButtonFormField<int>));
      expect(find.text('Level 6'), findsNothing);
      await helpers.tap(tester, find.text('Level 3').last);
      await tester.enterText(find.byType(TextField).last, 'Protect the party');
      tester.testTextInput.hide();
      await helpers.tap(tester, find.text('Requires Concentration'));
      await helpers.tap(
        tester,
        find.text('Confirmed Cleric spell, level 0–5, not a Reaction'),
      );
      await helpers.tap(tester, cast);
      expect(s.session.characterState.concentrationSpellId, isNull);
      expect(s.hero.toJson()['spells'], spells);
      expect(s.session.characterState.resourceValues, {
        ...resources,
        divineInterventionResourceId: 0,
      });
      expect(s.session.usedCombatActions, {CombatActionCost.action});
      expect(s.session.timeline.first.detail, contains('Protect the party'));
      expect(
        s.session.timeline.first.detail,
        contains('track this spell’s concentration at the table'),
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final gate in ['low', 'incapacitated', 'rage', 'empty', 'action']) {
    testWidgets('Divine Intervention cannot bypass $gate gate', (tester) async {
      final s = Scenario();
      await s.boot(
        tester,
        level: gate == 'low' ? 9 : 10,
        gate: gate,
        used: gate == 'action' ? {CombatActionCost.action} : {},
      );
      final before = {...s.session.characterState.resourceValues};
      if (gate == 'low') {
        expect(find.text('Divine Intervention'), findsNothing);
      } else {
        await s.begin(tester);
        expect(find.text('Divine Intervention · Spell'), findsNothing);
      }
      expect(s.session.characterState.resourceValues, before);
      expect(tester.takeException(), isNull);
    });
  }
}
