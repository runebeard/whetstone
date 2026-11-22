import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

const blade = Weapon(
  id: 'retaliation-blade',
  name: 'Test blade',
  attackModifier: 5,
  damage: '1d6',
  category: WeaponCategory.martialMelee,
);
const bow = Weapon(
  id: 'retaliation-bow',
  name: 'Test bow',
  attackModifier: 5,
  damage: '1d6',
  category: WeaponCategory.martialRanged,
);

void main() {
  for (final packTactics in [false, true]) {
    testWidgets(
      'Beast Retaliation keeps Wolf Pack Tactics choice $packTactics and shared Reaction',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: 12,
          additionalClassLevels: {'Druid': 2},
          subclasses: {'Barbarian': 'Path of the Berserker'},
          weapons: [blade],
          resources: BuiltInClass.druid.classResources(2, charismaModifier: 0),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 22,
            temporaryHp: 5,
            wildShapeForm: 'Wolf',
            wildShapeTurnsRemaining: 100,
            activeConditions: {ragingCondition},
            conditionTurns: {ragingCondition: 1},
            resourceValues: {wildShapeResourceId: 1},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: {
            CombatActionCost.action,
            CombatActionCost.bonusAction,
          },
          attackActionAttacksRemaining: 1,
        );
        final dice = SequenceDiceRoller([2, 16]);
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(session.usedCombatActions.length),
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        final button = find.widgetWithText(
          OutlinedButton,
          'Retaliation · Reaction',
        );
        Future<void> open() async {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.text('Retaliate with Test blade'), findsNothing);
          expect(find.text('Retaliate with Unarmed Strike'), findsNothing);
          await tester.tap(find.text('Retaliate with Wolf Bite'));
          await tester.pumpAndSettle();
        }

        await open();
        expect(find.text('Pack Tactics'), findsOneWidget);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(
          session.usedCombatActions.contains(CombatActionCost.reaction),
          false,
        );
        expect(dice.index, 0);
        await open();
        await tester.tap(find.text(packTactics ? 'Yes' : 'No'));
        await tester.pumpAndSettle();
        expect(
          session.timeline.any(
            (event) =>
                event.title == 'Wolf Bite Attack: ${packTactics ? 20 : 6}',
          ),
          true,
        );
        expect(session.usedCombatActions, CombatActionCost.values.toSet());
        expect(session.attackActionAttacksRemaining, 1);
        expect(session.characterState.wildShapeForm, 'Wolf');
        expect(session.characterState.wildShapeTurnsRemaining, 100);
        expect(session.characterState.resourceValues[wildShapeResourceId], 1);
        expect(session.characterState.currentHp, 22);
        expect(session.characterState.temporaryHp, 5);
        expect(session.characterState.conditionTurns[ragingCondition], 1);
        expect(dice.index, packTactics ? 2 : 1);
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        expect(session.characterState.wildShapeForm, 'Wolf');
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final unarmed in [false, true]) {
    testWidgets(
      'Retaliation unarmed=$unarmed spends shared Reaction and preserves Attack budget and Rage',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: 10,
          subclasses: {'Barbarian': 'Path of the Berserker'},
          weapons: [blade, bow],
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.strength: 18,
          },
          resources: BuiltInClass.barbarian.classResources(
            10,
            charismaModifier: 0,
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 22,
            activeConditions: {ragingCondition},
            conditionTurns: {ragingCondition: 1},
            resourceValues: {rageResourceId: 1},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: {
            CombatActionCost.action,
            CombatActionCost.bonusAction,
          },
          attackActionAttacksRemaining: 1,
        );
        final dice = SequenceDiceRoller([5]);
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(session.usedCombatActions.length),
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        final button = find.widgetWithText(
          OutlinedButton,
          'Retaliation · Reaction',
        );
        Future<void> open() async {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
        }

        await open();
        expect(find.text('Retaliate with Test bow'), findsNothing);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(dice.index, 0);
        expect(session.usedCombatActions, {
          CombatActionCost.action,
          CombatActionCost.bonusAction,
        });
        await open();
        if (unarmed) {
          await tester.tap(find.text('Retaliate with Unarmed Strike'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(
            session.usedCombatActions.contains(CombatActionCost.reaction),
            false,
          );
          await open();
          await tester.tap(find.text('Retaliate with Unarmed Strike'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Damage').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Hit · Apply unarmed damage'));
          await tester.pumpAndSettle();
          expect(session.timeline.first.title, 'Unarmed Strike Damage: 8');
        } else {
          await tester.tap(find.text('Retaliate with Test blade'));
          await tester.pumpAndSettle();
          expect(session.timeline.first.title, 'Test blade Attack: 10');
        }
        expect(session.usedCombatActions, CombatActionCost.values.toSet());
        expect(session.attackActionAttacksRemaining, 1);
        expect(session.characterState.currentHp, 22);
        expect(session.characterState.resourceValues[rageResourceId], 1);
        expect(session.characterState.conditionTurns[ragingCondition], 1);
        expect(dice.index, 1);
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        final next = find.text('Next Turn');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Retaliation does not spend Reaction when required ammunition is unavailable',
    (tester) async {
      const weapon = Weapon(
        id: 'retaliation-ammo',
        name: 'Ammo blade',
        attackModifier: 5,
        damage: '1d6',
        category: WeaponCategory.martialMelee,
        ammunitionName: 'Missing charge',
      );
      final character = seedCharacters.first.copyWith(
        characterClass: 'Barbarian',
        level: 10,
        subclasses: {'Barbarian': 'Path of the Berserker'},
        weapons: [weapon],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([5]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        ),
      );
      final button = find.widgetWithText(
        OutlinedButton,
        'Retaliation · Reaction',
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retaliate with Ammo blade'));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, isEmpty);
      expect(dice.index, 0);
    },
  );
  testWidgets(
    'Retaliation requires Berserker ten and an available conscious Reaction',
    (tester) async {
      for (final (level, subclass, spent, incap) in [
        (9, 'Path of the Berserker', false, false),
        (10, 'Other', false, false),
        (10, 'Path of the Berserker', true, false),
        (10, 'Path of the Berserker', false, true),
      ]) {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: level,
          subclasses: {'Barbarian': subclass},
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey('$level-$subclass-$spent-$incap'),
              character: character,
              initialSession: CharacterSession(
                characterState: CharacterState.fromCharacter(
                  character,
                ).copyWith(activeConditions: incap ? {'Incapacitated'} : {}),
                inventory: [],
                archivedInventory: [],
                isInCombat: true,
                usedCombatActions: spent ? {CombatActionCost.reaction} : {},
              ),
              onCharacterChanged: (_) {},
              onSessionChanged: (_) {},
            ),
          ),
        );
        final button = find.widgetWithText(
          OutlinedButton,
          'Retaliation · Reaction',
        );
        if (level < 10 || subclass == 'Other') {
          expect(button, findsNothing);
        } else {
          expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        }
      }
    },
  );
}
