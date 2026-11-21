import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  test(
    'Wholeness requires Open Hand six, uses Wisdom and recovers only on Long Rest',
    () {
      for (final (level, subclass, wisdom, uses) in [
        (5, 'Warrior of the Open Hand', 3, 0),
        (6, 'Other', 3, 0),
        (6, 'Warrior of the Open Hand', -1, 1),
        (6, 'Warrior of the Open Hand', 3, 3),
      ]) {
        final resources = BuiltInClass.monk.classResources(
          level,
          charismaModifier: 0,
          wisdomModifier: wisdom,
          subclass: subclass,
        );
        final pool = resources
            .where((resource) => resource.id == wholenessOfBodyResourceId)
            .firstOrNull;
        if (uses == 0) {
          expect(pool, isNull);
          continue;
        }
        expect(pool!.maximum, uses);
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: level,
          resources: resources,
          subclasses: {'Monk': subclass},
        );
        final state = CharacterState.fromCharacter(
          monk,
        ).copyWith(resourceValues: {wholenessOfBodyResourceId: 0});
        for (final type in RestType.values) {
          expect(
            RestPlan.forCharacter(
              character: monk,
              currentState: state,
              type: type,
            ).updatedState.resourceValues[wholenessOfBodyResourceId],
            type == RestType.longRest ? uses : 0,
          );
        }
      }
    },
  );
  for (final (level, wisdom, die, hp, expected, combat) in [
    (6, 16, 6, 20, 29, true),
    (11, 8, 1, 20, 21, false),
    (17, 18, 8, 40, 42, true),
  ]) {
    testWidgets(
      'Wholeness level $level wisdom=$wisdom heals and preserves Focus combat=$combat',
      (tester) async {
        var monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: level,
          resources: [],
          subclasses: {'Monk': 'Warrior of the Open Hand'},
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.wisdom: wisdom,
          },
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            monk,
          ).copyWith(currentHp: hp, resourceValues: {focusResourceId: 2}),
          inventory: [],
          archivedInventory: [],
          isInCombat: combat,
        );
        final dice = SequenceDiceRoller([die]);
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(session.characterState.currentHp),
            character: monk,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (value) => monk = value,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        final pool = monk.resources.singleWhere(
          (resource) => resource.id == wholenessOfBodyResourceId,
        );
        expect(pool.maximum, ((wisdom - 10) ~/ 2).clamp(1, 10));
        final button = find.text('Wholeness of Body');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.characterState.currentHp, hp);
        expect(session.usedCombatActions, isEmpty);
        expect(dice.index, 0);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use Wholeness · Heal yourself'));
        await tester.pumpAndSettle();
        expect(session.characterState.currentHp, expected);
        expect(
          session.characterState.resourceValues[wholenessOfBodyResourceId],
          pool.maximum - 1,
        );
        expect(session.characterState.resourceValues[focusResourceId], 2);
        expect(
          session.usedCombatActions,
          combat ? {CombatActionCost.bonusAction} : <CombatActionCost>{},
        );
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        final restored = find.text('Wholeness of Body').first;
        await tester.ensureVisible(restored);
        await tester.tap(restored);
        await tester.pumpAndSettle();
        expect(find.text('Use Wholeness · Heal yourself'), findsNothing);
        expect(dice.index, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
