import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  test('Presence is Berserker fourteen and recovers on Long Rest only', () {
    for (final (level, subclass, exists) in [
      (13, 'Path of the Berserker', false),
      (14, 'Other', false),
      (14, 'Path of the Berserker', true),
    ]) {
      final resources = BuiltInClass.barbarian.classResources(
        level,
        charismaModifier: 0,
        subclass: subclass,
      );
      expect(
        resources.any((r) => r.id == intimidatingPresenceResourceId),
        exists,
      );
      if (!exists) continue;
      final character = seedCharacters.first.copyWith(
        characterClass: 'Barbarian',
        level: level,
        subclasses: {'Barbarian': subclass},
        resources: resources,
      );
      for (final rest in RestType.values) {
        final state = RestPlan.forCharacter(
          character: character,
          currentState: CharacterState.fromCharacter(
            character,
          ).copyWith(resourceValues: {intimidatingPresenceResourceId: 0}),
          type: rest,
        ).updatedState;
        expect(
          state.resourceValues[intimidatingPresenceResourceId],
          rest == RestType.longRest ? 1 : 0,
        );
      }
    }
  });
  for (final initial in [0, 1]) {
    testWidgets(
      'Presence initial=$initial migrates, restores with Rage and spends Bonus Action',
      (tester) async {
        var character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: 14,
          proficiencyBonus: 5,
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.strength: 18,
          },
          subclasses: {'Barbarian': 'Path of the Berserker'},
          resources: BuiltInClass.barbarian.classResources(
            14,
            charismaModifier: 0,
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 22,
            resourceValues: {
              intimidatingPresenceResourceId: initial,
              rageResourceId: 2,
            },
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: initial == 0
              ? CombatActionCost.values.toSet()
              : {CombatActionCost.action, CombatActionCost.reaction},
        );
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(session.timeline.length),
            character: character,
            initialSession: session,
            onCharacterChanged: (v) => character = v,
            onSessionChanged: (v) => session = v,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          character.resources
              .where((r) => r.id == intimidatingPresenceResourceId)
              .length,
          1,
        );
        final button = find.widgetWithText(
          OutlinedButton,
          'Intimidating Presence',
        );
        Future<void> open() async {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
        }

        await open();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          session.characterState.resourceValues[intimidatingPresenceResourceId],
          initial,
        );
        expect(session.characterState.resourceValues[rageResourceId], 2);
        if (initial == 0) {
          await open();
          await tester.tap(find.text('Spend one Rage · Restore use'));
          await tester.pumpAndSettle();
          expect(session.characterState.resourceValues[rageResourceId], 1);
          expect(
            session
                .characterState
                .resourceValues[intimidatingPresenceResourceId],
            1,
          );
          expect(session.characterState.isRaging, false);
          expect(session.usedCombatActions, CombatActionCost.values.toSet());
          expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
          final next = find.text('Next Turn');
          await tester.ensureVisible(next);
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
        await open();
        expect(find.textContaining('DC 17 Wisdom'), findsOneWidget);
        await tester.tap(find.text('Unleash presence'));
        await tester.pumpAndSettle();
        expect(
          session.characterState.resourceValues[intimidatingPresenceResourceId],
          0,
        );
        expect(
          session.characterState.resourceValues[rageResourceId],
          initial == 0 ? 1 : 2,
        );
        expect(
          session.usedCombatActions.contains(CombatActionCost.bonusAction),
          true,
        );
        expect(session.characterState.currentHp, 22);
        expect(session.characterState.activeConditions, isEmpty);
        expect(session.timeline.first.detail, contains('DC 17 Wisdom'));
        expect(session.timeline.first.detail, contains('each target turn'));
        final spent = {...session.usedCombatActions};
        session = CharacterSession.fromJson(session.toJson());
        character = Character.fromJson(character.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          character.resources
              .where((r) => r.id == intimidatingPresenceResourceId)
              .length,
          1,
        );
        expect(
          session.characterState.resourceValues[intimidatingPresenceResourceId],
          0,
        );
        await open();
        await tester.tap(find.text('Spend one Rage · Restore use'));
        await tester.pumpAndSettle();
        expect(session.usedCombatActions, spent);
        expect(
          session.characterState.resourceValues[rageResourceId],
          initial == 0 ? 0 : 1,
        );
        expect(
          session.characterState.resourceValues[intimidatingPresenceResourceId],
          1,
        );
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Presence guards subclass, class level, costs and incapacitation',
    (tester) async {
      for (final (level, subclass, presence, rage, bonus, incap) in [
        (13, 'Path of the Berserker', 1, 1, false, false),
        (14, 'Other', 1, 1, false, false),
        (14, 'Path of the Berserker', 0, 0, false, false),
        (14, 'Path of the Berserker', 1, 1, true, false),
        (14, 'Path of the Berserker', 1, 1, false, true),
      ]) {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: level,
          subclasses: {'Barbarian': subclass},
          resources: BuiltInClass.barbarian.classResources(
            level,
            charismaModifier: 0,
            subclass: subclass,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey('$level-$subclass-$presence-$rage-$bonus-$incap'),
              character: character,
              initialSession: CharacterSession(
                characterState: CharacterState.fromCharacter(character)
                    .copyWith(
                      resourceValues: {
                        intimidatingPresenceResourceId: presence,
                        rageResourceId: rage,
                      },
                      activeConditions: incap ? {'Incapacitated'} : {},
                    ),
                inventory: [],
                archivedInventory: [],
                isInCombat: true,
                usedCombatActions: bonus ? {CombatActionCost.bonusAction} : {},
              ),
              onCharacterChanged: (_) {},
              onSessionChanged: (_) {},
            ),
          ),
        );
        final button = find.widgetWithText(
          OutlinedButton,
          'Intimidating Presence',
        );
        if (level < 14 || subclass == 'Other') {
          expect(button, findsNothing);
        } else {
          expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        }
      }
    },
  );
}
