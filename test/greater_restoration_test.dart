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

class Scenario {
  late CharacterSession session;
  late String freeId;
  late String concentration;

  Future<void> boot(
    WidgetTester tester, {
    Set<String> conditions = const {'Charmed', 'Poisoned'},
    Set<CombatActionCost> used = const {},
    bool freeSubtle = false,
    int exhaustion = 0,
  }) async {
    var character = withBuiltInSpellGrants(
      fixtures
          .life(freeSubtle ? 11 : 9)
          .copyWith(
            additionalClassLevels: freeSubtle ? {'Sorcerer': 2} : {},
            metamagicOptions: freeSubtle ? {Metamagic.subtle} : {},
          ),
    );
    final spell = character.spells.singleWhere(
      (s) => s.name == 'Greater Restoration',
    );
    concentration = character.spells.singleWhere((s) => s.name == 'Bless').id;
    freeId = 'whetstone:free-cast:${spell.id}';
    character = character.copyWith(
      initiallyPinnedActionKeys: {spell.actionKey},
      resources: [
        ...character.resources,
        if (freeSubtle)
          CharacterResource(
            id: freeId,
            name: 'Free Restoration',
            maximum: 1,
            initialValue: 1,
            rechargePeriod: RechargePeriod.longRest,
          ),
      ],
    );
    session = CharacterSession(
      characterState: CharacterState.fromCharacter(character).copyWith(
        currentHp: 22,
        exhaustionLevel: exhaustion,
        activeConditions: conditions,
        conditionTurns: {for (final condition in conditions) condition: 7},
        concentrationSpellId: concentration,
        concentrationTurnsRemaining: 8,
      ),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
      usedCombatActions: used,
    );
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
  }

  Future<void> begin(WidgetTester tester) async {
    await helpers.tap(tester, find.text('Greater Restoration').first);
    await helpers.tap(tester, find.text('Cast').last);
  }

  Future<void> choose(WidgetTester tester, String label) async {
    await helpers.tap(tester, find.text(label));
  }
}

void main() {
  testWidgets('Greater Restoration cannot remove absent self Exhaustion', (
    tester,
  ) async {
    final scenario = Scenario();
    await scenario.boot(tester);
    await scenario.begin(tester);
    await scenario.choose(tester, 'Treat yourself');
    expect(find.text('Remove 1 Exhaustion level'), findsNothing);
    expect(find.text('1 Exhaustion level · At the table'), findsNothing);
    await scenario.choose(tester, 'Cancel');
    expect(scenario.session.characterState.exhaustionLevel, 0);
    expect(scenario.session.characterState.resourceValues[spellSlotId(5)], 1);
  });
  for (final target in ['self', 'other-charmed', 'other-petrified']) {
    testWidgets('Greater Restoration removes one effect on $target', (
      tester,
    ) async {
      final scenario = Scenario();
      await scenario.boot(tester);
      await scenario.begin(tester);
      await scenario.choose(
        tester,
        target == 'self' ? 'Treat yourself' : 'Treat another creature',
      );
      final condition = target == 'other-petrified' ? 'Petrified' : 'Charmed';
      await scenario.choose(tester, 'End $condition');
      expect(find.text('Greater Restoration · Components'), findsOneWidget);
      await scenario.choose(tester, 'Confirm components');
      await scenario.choose(tester, 'Level 5 · 1 remaining');
      final state = scenario.session.characterState;
      expect(
        state.activeConditions,
        target == 'self' ? {'Poisoned'} : {'Charmed', 'Poisoned'},
      );
      expect(state.conditionTurns.containsKey('Charmed'), target != 'self');
      expect(state.conditionTurns['Poisoned'], 7);
      expect(state.resourceValues[spellSlotId(5)], 0);
      expect(state.currentHp, 22);
      expect(state.concentrationSpellId, scenario.concentration);
      expect(state.concentrationTurnsRemaining, 8);
      expect(scenario.session.usedCombatActions, {CombatActionCost.action});
      expect(scenario.session.timeline.first.detail, contains('diamond dust'));
      final restored = CharacterSession.fromJson(scenario.session.toJson());
      expect(restored.characterState.activeConditions, state.activeConditions);
      expect(restored.characterState.resourceValues[spellSlotId(5)], 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final effect in [
    '1 Exhaustion level',
    'One curse',
    'One ability score reduction',
    'One maximum HP reduction',
  ]) {
    testWidgets('Greater Restoration records table-managed $effect', (
      tester,
    ) async {
      final scenario = Scenario();
      final exhaustion = effect == '1 Exhaustion level';
      await scenario.boot(
        tester,
        conditions: {'Poisoned'},
        exhaustion: exhaustion ? 2 : 0,
      );
      final maxHp = scenario.session.characterState.maxHp;
      await scenario.begin(tester);
      await scenario.choose(tester, 'Treat yourself');
      expect(find.text('End Charmed'), findsNothing);
      await scenario.choose(
        tester,
        exhaustion ? 'Remove 1 Exhaustion level' : '$effect · At the table',
      );
      expect(
        find.textContaining(
          exhaustion ? 'Exhaustion decreases by one' : 'tracked scores and HP',
        ),
        findsOneWidget,
      );
      await scenario.choose(tester, 'Confirm components');
      await scenario.choose(tester, 'Level 5 · 1 remaining');
      final state = scenario.session.characterState;
      expect(state.activeConditions, {'Poisoned'});
      expect(state.currentHp, 22);
      expect(state.maxHp, maxHp);
      expect(state.resourceValues[spellSlotId(5)], 0);
      expect(state.exhaustionLevel, exhaustion ? 1 : 0);
      expect(
        scenario.session.timeline.first.detail,
        contains(exhaustion ? 'Removed one Exhaustion level' : effect),
      );
      expect(scenario.session.timeline.first.detail, contains('at the table'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Every Greater Restoration cancellation stage preserves costs', (
    tester,
  ) async {
    final scenario = Scenario();
    await scenario.boot(tester);
    for (var stage = 0; stage < 4; stage++) {
      final before = scenario.session.characterState.toJson();
      await scenario.begin(tester);
      if (stage > 0) await scenario.choose(tester, 'Treat yourself');
      if (stage > 1) await scenario.choose(tester, 'End Charmed');
      if (stage == 3) {
        await scenario.choose(tester, 'Confirm components');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      } else {
        await scenario.choose(tester, 'Cancel');
      }
      expect(scenario.session.characterState.toJson(), before);
      expect(scenario.session.usedCombatActions, isEmpty);
    }
    expect(tester.takeException(), isNull);
  });

  for (final gate in ['petrified', 'paralyzed', 'action']) {
    testWidgets('Greater Restoration cannot bypass the $gate gate', (
      tester,
    ) async {
      final scenario = Scenario();
      await scenario.boot(
        tester,
        conditions: {
          if (gate == 'petrified') 'Petrified',
          if (gate == 'paralyzed') 'Paralyzed',
          'Charmed',
        },
        used: gate == 'action' ? {CombatActionCost.action} : {},
      );
      await scenario.begin(tester);
      expect(find.text('Treat yourself'), findsNothing);
      expect(find.text('Confirm components'), findsNothing);
      expect(
        scenario.session.characterState.activeConditions,
        contains('Charmed'),
      );
      expect(scenario.session.characterState.resourceValues[spellSlotId(5)], 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Subtle free Greater Restoration still confirms costly dust', (
    tester,
  ) async {
    final scenario = Scenario();
    await scenario.boot(tester, freeSubtle: true);
    await helpers.tap(tester, find.text('Greater Restoration').first);
    await scenario.choose(tester, 'Subtle Spell');
    await scenario.choose(tester, 'Use Free Cast');
    await scenario.choose(tester, 'Treat yourself');
    await scenario.choose(tester, 'End Charmed');
    await scenario.choose(tester, 'Cancel');
    expect(scenario.session.characterState.resourceValues[scenario.freeId], 1);
    expect(
      scenario.session.characterState.resourceValues[sorceryPointsResourceId] ??
          2,
      2,
    );
    await helpers.tap(tester, find.text('Greater Restoration').first);
    await scenario.choose(tester, 'Subtle Spell');
    await scenario.choose(tester, 'Use Free Cast');
    await scenario.choose(tester, 'Treat yourself');
    await scenario.choose(tester, 'End Charmed');
    expect(find.text('Greater Restoration · Components'), findsOneWidget);
    await scenario.choose(tester, 'Confirm components');
    final state = scenario.session.characterState;
    expect(state.activeConditions, {'Poisoned'});
    expect(state.resourceValues[scenario.freeId], 0);
    expect(state.resourceValues[sorceryPointsResourceId], 1);
    expect(state.resourceValues[spellSlotId(5)], 2);
    expect(scenario.session.usedCombatActions, {CombatActionCost.action});
    expect(tester.takeException(), isNull);
  });
}
