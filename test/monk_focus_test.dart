import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  test('Focus progression and both rest types recover the full pool', () {
    expect(BuiltInClass.monk.classResources(1, charismaModifier: 0), isEmpty);
    for (final level in [2, 5, 20]) {
      final resources = BuiltInClass.monk.classResources(
        level,
        charismaModifier: 0,
      );
      expect(
        resources
            .firstWhere((resource) => resource.id == focusResourceId)
            .maximum,
        level,
      );
      final monk = seedCharacters.first.copyWith(
        characterClass: 'Monk',
        level: level,
        resources: resources,
      );
      final state = CharacterState.fromCharacter(
        monk,
      ).copyWith(resourceValues: {focusResourceId: 0});
      for (final type in RestType.values) {
        final plan = RestPlan.forCharacter(
          character: monk,
          currentState: state,
          type: type,
        );
        expect(plan.updatedState.resourceValues[focusResourceId], level);
      }
    }
  });
  for (final (label, effects, spent) in [
    ('Patient Defense · Disengage (free)', {disengagingCondition}, false),
    (
      'Patient Defense · Disengage + Dodge (1 Focus)',
      {disengagingCondition, dodgingCondition},
      true,
    ),
    ('Step of the Wind · Dash (free)', {dashingCondition}, false),
    (
      'Step of the Wind · Dash + Disengage (1 Focus)',
      {dashingCondition, disengagingCondition},
      true,
    ),
  ]) {
    testWidgets('$label saves costs and expires next turn', (tester) async {
      var monk = seedCharacters.first.copyWith(
        characterClass: 'Monk',
        level: 5,
        weapons: [],
        resources: [],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(monk),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: monk,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (value) => monk = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        monk.resources
            .firstWhere((resource) => resource.id == focusResourceId)
            .id,
        focusResourceId,
      );
      final button = find.widgetWithText(
        OutlinedButton,
        'Monk’s Focus · Movement and defense',
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, isEmpty);
      expect(session.characterState.resourceValues[focusResourceId], isNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(session.characterState.activeConditions, containsAll(effects));
      expect(
        session.characterState.resourceValues[focusResourceId] ?? 5,
        spent ? 4 : 5,
      );
      session = CharacterSession.fromJson(session.toJson());
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      final next = find.text('Next Turn');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        session.characterState.activeConditions.intersection(effects),
        isEmpty,
      );
      expect(session.usedCombatActions, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Depleted Focus still permits the free movement options', (
    tester,
  ) async {
    final monk = seedCharacters.first.copyWith(
      characterClass: 'Monk',
      level: 2,
      weapons: [],
      resources: BuiltInClass.monk.classResources(2, charismaModifier: 0),
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        monk,
      ).copyWith(resourceValues: {focusResourceId: 0}),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: monk,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
        ),
      ),
    );
    final button = find.widgetWithText(
      OutlinedButton,
      'Monk’s Focus · Movement and defense',
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SimpleDialogOption>(
            find.widgetWithText(
              SimpleDialogOption,
              'Patient Defense · Disengage + Dodge (1 Focus)',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<SimpleDialogOption>(
            find.widgetWithText(
              SimpleDialogOption,
              'Step of the Wind · Dash + Disengage (1 Focus)',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Step of the Wind · Dash (free)'));
    await tester.pumpAndSettle();
    expect(session.characterState.resourceValues[focusResourceId], 0);
    expect(session.characterState.activeConditions, contains(dashingCondition));
  });
}
