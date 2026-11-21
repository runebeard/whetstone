import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  for (final type in RestType.values) {
    test(
      '$type ends Divine Sense and Rage while recovering Channel Divinity',
      () {
        final paladin = seedCharacters.first.copyWith(
          characterClass: 'Paladin',
          level: 9,
          resources: BuiltInClass.paladin.classResources(
            9,
            charismaModifier: 3,
          ),
        );
        final state = CharacterState.fromCharacter(paladin).copyWith(
          activeConditions: {divineSenseCondition, ragingCondition, 'Poisoned'},
          conditionTurns: {
            divineSenseCondition: 100,
            ragingCondition: 2,
            'Poisoned': 5,
          },
          rageTurnsElapsed: 32,
          resourceValues: {paladinChannelDivinityId: 0},
        );
        final plan = RestPlan.forCharacter(
          type: type,
          character: paladin,
          currentState: state,
        );
        expect(plan.updatedState.activeConditions, {'Poisoned'});
        expect(plan.updatedState.conditionTurns, {'Poisoned': 5});
        expect(plan.updatedState.rageTurnsElapsed, 0);
        expect(
          plan.updatedState.resourceValues[paladinChannelDivinityId],
          type == RestType.shortRest ? 1 : 2,
        );
      },
    );
  }
  testWidgets(
    'Divine Sense persists, counts down and ends when incapacitated',
    (tester) async {
      final paladin = seedCharacters.first.copyWith(
        characterClass: 'Paladin',
        level: 3,
        resources: BuiltInClass.paladin.classResources(3, charismaModifier: 3),
      );
      var session = CharacterSession.fromCharacter(paladin);
      session = CharacterSession(
        characterState: session.characterState,
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      Widget app() => MaterialApp(
        home: CharacterOverview(
          character: paladin,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
        ),
      );
      await tester.pumpWidget(app());
      Future<void> openPool(int remaining) async {
        final pool = find.byKey(
          ValueKey('resource-$paladinChannelDivinityId-$remaining'),
        );
        await tester.ensureVisible(pool);
        await tester.tap(pool);
        await tester.pumpAndSettle();
      }

      await openPool(2);
      expect(find.text('Abjure Foes · Magic Action'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, isEmpty);
      await openPool(2);
      await tester.tap(find.text('Divine Sense · Bonus Action'));
      await tester.pumpAndSettle();
      expect(session.characterState.conditionTurns[divineSenseCondition], 100);
      expect(
        session.characterState.resourceValues[paladinChannelDivinityId],
        1,
      );
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await openPool(1);
      expect(find.text('Divine Sense · Bonus Action'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next Turn'));
      await tester.tap(find.text('Next Turn'));
      await tester.pumpAndSettle();
      expect(session.characterState.conditionTurns[divineSenseCondition], 99);
      session = CharacterSession(
        characterState: session.characterState.copyWith(
          activeConditions: {divineSenseCondition, 'Incapacitated'},
        ),
        inventory: [],
        archivedInventory: [],
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        session.characterState.activeConditions,
        isNot(contains(divineSenseCondition)),
      );
      expect(
        session.characterState.conditionTurns,
        isNot(contains(divineSenseCondition)),
      );
    },
  );

  testWidgets(
    'Abjure Foes validates target count and shares Channel Divinity',
    (tester) async {
      final paladin = seedCharacters.first.copyWith(
        characterClass: 'Paladin',
        level: 9,
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.charisma: 16,
        },
        resources: BuiltInClass.paladin.classResources(9, charismaModifier: 3),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(paladin).copyWith(
          activeConditions: {ragingCondition},
          conditionTurns: {ragingCondition: 1},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: paladin,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        ),
      );
      Future<void> abjure(int targets) async {
        final pool = find.byKey(
          ValueKey('resource-$paladinChannelDivinityId-2'),
        );
        await tester.ensureVisible(pool);
        await tester.tap(pool);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Abjure Foes · Magic Action'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '$targets');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      }

      await abjure(4);
      expect(session.usedCombatActions, isEmpty);
      expect(
        session.characterState.resourceValues[paladinChannelDivinityId],
        2,
      );
      await abjure(2);
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(
        session.characterState.resourceValues[paladinChannelDivinityId],
        1,
      );
      expect(session.characterState.conditionTurns[ragingCondition], 2);
      expect(find.textContaining('DC 14 Wisdom save'), findsOneWidget);
      await tester.tap(find.text('1 failed save'));
      await tester.pumpAndSettle();
      expect(
        session.timeline.first.detail,
        contains('1 of 2 targets Frightened'),
      );
      expect(
        session.characterState.activeConditions,
        isNot(contains('Frightened')),
      );
      final pool = find.byKey(ValueKey('resource-$paladinChannelDivinityId-1'));
      await tester.ensureVisible(pool);
      await tester.tap(pool);
      await tester.pumpAndSettle();
      expect(find.text('Abjure Foes · Magic Action'), findsNothing);
      await tester.tap(find.text('Divine Sense · Bonus Action'));
      await tester.pumpAndSettle();
      expect(
        session.characterState.resourceValues[paladinChannelDivinityId],
        0,
      );
      expect(session.usedCombatActions, {
        CombatActionCost.action,
        CombatActionCost.bonusAction,
      });
    },
  );

  testWidgets('Action Surge cannot pay for Abjure Foes Magic action', (
    tester,
  ) async {
    final paladin = seedCharacters.first.copyWith(
      characterClass: 'Paladin',
      level: 9,
      resources: BuiltInClass.paladin.classResources(9, charismaModifier: 3),
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(paladin),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
      usedCombatActions: {
        CombatActionCost.action,
        CombatActionCost.bonusAction,
      },
      actionSurge: ActionSurgeState.available,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: paladin,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
        ),
      ),
    );
    final pool = find.byKey(ValueKey('resource-$paladinChannelDivinityId-2'));
    await tester.ensureVisible(pool);
    await tester.tap(pool);
    await tester.pumpAndSettle();
    expect(find.text('Abjure Foes · Magic Action'), findsNothing);
    expect(find.text('Divine Sense · Bonus Action'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(session.characterState.resourceValues[paladinChannelDivinityId], 2);
    expect(session.actionSurge, ActionSurgeState.available);
  });
}
