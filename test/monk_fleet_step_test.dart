import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  for (final paid in [false, true]) {
    testWidgets('Fleet Step paid=$paid preserves Bonus Action and saves use', (
      tester,
    ) async {
      final monk = seedCharacters.first.copyWith(
        characterClass: 'Monk',
        level: 11,
        weapons: [],
        subclasses: {'Monk': 'Warrior of the Open Hand'},
        resources: BuiltInClass.monk.classResources(11, charismaModifier: 0),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          monk,
        ).copyWith(resourceValues: {focusResourceId: paid ? 1 : 0}),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        usedCombatActions: {
          CombatActionCost.action,
          CombatActionCost.bonusAction,
        },
        attackActionAttacksRemaining: 1,
      );
      Widget app() => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(session.fleetStepUsedThisTurn),
          character: monk,
          initialSession: session,
          onSessionChanged: (v) => session = v,
          onCharacterChanged: (_) {},
        ),
      );
      await tester.pumpWidget(app());
      final button = find.text('Fleet Step · Follow Bonus Action');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Patient Defense · Disengage (free)'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.fleetStepUsedThisTurn, isFalse);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          paid
              ? 'Step of the Wind · Dash + Disengage (1 Focus)'
              : 'Step of the Wind · Dash (free)',
        ),
      );
      await tester.pumpAndSettle();
      expect(session.characterState.resourceValues[focusResourceId], 0);
      expect(
        session.characterState.activeConditions,
        contains(dashingCondition),
      );
      expect(
        session.characterState.activeConditions.contains(disengagingCondition),
        paid,
      );
      expect(session.fleetStepUsedThisTurn, isTrue);
      expect(session.stepOfWindUsedThisTurn, isTrue);
      expect(session.usedCombatActions, {
        CombatActionCost.action,
        CombatActionCost.bonusAction,
      });
      expect(session.attackActionAttacksRemaining, 1);
      if (paid) {
        expect(
          session.timeline.first.detail,
          contains('willing Large or smaller'),
        );
      }
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(
                OutlinedButton,
                'Fleet Step · Follow Bonus Action',
              ),
            )
            .onPressed,
        isNull,
      );
      final next = find.text('Next Turn');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(session.fleetStepUsedThisTurn, isFalse);
      expect(session.stepOfWindUsedThisTurn, isFalse);
      expect(session.usedCombatActions, isEmpty);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(
                OutlinedButton,
                'Fleet Step · Follow Bonus Action',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Normal Step of the Wind cannot chain Fleet Step after reload', (
    tester,
  ) async {
    final monk = seedCharacters.first.copyWith(
      characterClass: 'Monk',
      level: 11,
      weapons: [],
      subclasses: {'Monk': 'Warrior of the Open Hand'},
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(monk),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    Widget app() => MaterialApp(
      home: CharacterOverview(
        key: ValueKey(session.stepOfWindUsedThisTurn),
        character: monk,
        initialSession: session,
        onSessionChanged: (v) => session = v,
        onCharacterChanged: (_) {},
      ),
    );
    await tester.pumpWidget(app());
    final move = find.text('Monk’s Focus · Movement and defense');
    await tester.ensureVisible(move);
    await tester.tap(move);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Step of the Wind · Dash (free)'));
    await tester.pumpAndSettle();
    expect(session.stepOfWindUsedThisTurn, isTrue);
    expect(session.fleetStepUsedThisTurn, isFalse);
    session = CharacterSession.fromJson(session.toJson());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(
              OutlinedButton,
              'Fleet Step · Follow Bonus Action',
            ),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('Fleet Step requires Open Hand eleven', (tester) async {
    for (final (level, subclass) in [
      (10, 'Warrior of the Open Hand'),
      (11, 'Other'),
    ]) {
      final monk = seedCharacters.first.copyWith(
        characterClass: 'Monk',
        level: level,
        weapons: [],
        subclasses: {'Monk': subclass},
      );
      final session = CharacterSession(
        characterState: CharacterState.fromCharacter(monk),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        usedCombatActions: {CombatActionCost.bonusAction},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            key: ValueKey(subclass),
            character: monk,
            initialSession: session,
            onSessionChanged: (_) {},
            onCharacterChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Fleet Step · Follow Bonus Action'), findsNothing);
    }
  });
}
