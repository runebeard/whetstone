import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  test(
    'Superior Defense resists every specified type except Force without stacking',
    () {
      final state = CharacterState.fromCharacter(
        seedCharacters.first,
      ).copyWith(activeConditions: {superiorDefenseCondition, ragingCondition});
      for (final type in IncomingDamageType.values) {
        expect(
          state.damageAfterResistance(25, type),
          type == IncomingDamageType.force || type == IncomingDamageType.other
              ? 25
              : 12,
        );
      }
      expect(
        state
            .copyWith(
              activeConditions: {superiorDefenseCondition, 'Incapacitated'},
            )
            .damageAfterResistance(25, IncomingDamageType.fire),
        25,
      );
    },
  );
  test(
    'Superior Defense expires at ten turn boundaries and on either rest',
    () {
      final monk = seedCharacters.first.copyWith(
        characterClass: 'Monk',
        level: 18,
      );
      var state = CharacterState.fromCharacter(monk).copyWith(
        activeConditions: {superiorDefenseCondition},
        conditionTurns: {superiorDefenseCondition: 10},
      );
      for (final type in RestType.values) {
        expect(
          RestPlan.forCharacter(
            character: monk,
            currentState: state,
            type: type,
          ).updatedState.activeConditions,
          isNot(contains(superiorDefenseCondition)),
        );
      }
      for (var i = 0; i < 9; i++) {
        state = state.advanceConditionTurn();
        expect(state.activeConditions, contains(superiorDefenseCondition));
      }
      expect(
        state.advanceConditionTurn().activeConditions,
        isNot(contains(superiorDefenseCondition)),
      );
    },
  );
  testWidgets(
    'Superior Defense cancellation, Focus cost and reload timer preserve actions',
    (tester) async {
      final monk = seedCharacters.first.copyWith(
        characterClass: 'Monk',
        level: 18,
        weapons: [],
        resources: BuiltInClass.monk.classResources(18, charismaModifier: 0),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(monk),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      Widget app() => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(
            session.characterState.conditionTurns[superiorDefenseCondition],
          ),
          character: monk,
          initialSession: session,
          onSessionChanged: (v) => session = v,
          onCharacterChanged: (_) {},
        ),
      );
      await tester.pumpWidget(app());
      final button = find.text('Superior Defense · Start of turn');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.characterState.resourceValues[focusResourceId], 18);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start of turn · Spend 3 Focus'));
      await tester.pumpAndSettle();
      expect(session.characterState.resourceValues[focusResourceId], 15);
      expect(session.usedCombatActions, isEmpty);
      expect(
        session.characterState.conditionTurns[superiorDefenseCondition],
        10,
      );
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final next = find.text('Next Turn');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        session.characterState.conditionTurns[superiorDefenseCondition],
        9,
      );
      expect(session.characterState.resourceValues[focusResourceId], 15);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Reopening incapacitated Superior Defense clears the effect', (
    tester,
  ) async {
    final monk = seedCharacters.first.copyWith(
      characterClass: 'Monk',
      level: 18,
      weapons: [],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(monk).copyWith(
        activeConditions: {superiorDefenseCondition, 'Incapacitated'},
        conditionTurns: {superiorDefenseCondition: 8},
      ),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: monk,
          initialSession: session,
          onSessionChanged: (v) => session = v,
          onCharacterChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      session.characterState.activeConditions,
      isNot(contains(superiorDefenseCondition)),
    );
    expect(
      session.characterState.conditionTurns.containsKey(
        superiorDefenseCondition,
      ),
      isFalse,
    );
  });
}
