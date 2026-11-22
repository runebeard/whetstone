import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

const blade = Weapon(
  id: 'reckless-blade',
  name: 'Strength blade',
  attackModifier: 5,
  damage: '1d6',
  usesStrength: true,
  category: WeaponCategory.martialMelee,
);
const bow = Weapon(
  id: 'reckless-bow',
  name: 'Dexterity bow',
  attackModifier: 4,
  damage: '1d6',
  category: WeaponCategory.martialRanged,
);
const declaration = 'Reckless Attack · First attack';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> prepare(WidgetTester tester) async {
  await tap(tester, find.text(declaration));
  await tap(tester, find.text('Prepare first attack'));
}

Finder attack(Weapon weapon) =>
    find.byKey(ValueKey('attack-attacks-${weapon.actionKey}'));

void main() {
  for (final accept in [true, false]) {
    testWidgets(
      'Reckless prepared=$accept survives reload and affects Strength attacks until next turn',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: 5,
          weapons: [blade],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        var generation = 0;
        final dice = SequenceDiceRoller([3, 14, 4, 11]);
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        await tap(tester, find.text(declaration));
        await tap(tester, find.text('Cancel'));
        expect(session.recklessAttackArmed, false);
        await prepare(tester);
        expect(session.recklessAttackArmed, true);
        expect(session.usedCombatActions, isEmpty);
        expect(
          session.characterState.activeConditions.contains(
            recklessAttackCondition,
          ),
          false,
        );
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        if (!accept) {
          await tap(tester, find.text('Reckless Attack prepared · Cancel'));
        }
        await tap(tester, attack(blade));
        expect(
          session.timeline.first.title,
          'Strength blade Attack: ${accept ? 19 : 8}',
        );
        expect(session.attackRollMadeThisTurn, true);
        expect(session.recklessAttackArmed, false);
        expect(
          session.characterState.activeConditions.contains(
            recklessAttackCondition,
          ),
          accept,
        );
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(session.attackActionAttacksRemaining, 1);
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, declaration),
              )
              .onPressed,
          isNull,
        );
        await tap(tester, attack(blade));
        expect(
          session.timeline.first.title,
          'Strength blade Attack: ${accept ? 16 : 19}',
        );
        expect(dice.index, accept ? 4 : 2);
        await tap(tester, find.text('Next Turn'));
        expect(session.attackRollMadeThisTurn, false);
        expect(
          session.characterState.activeConditions.contains(
            recklessAttackCondition,
          ),
          false,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, declaration),
              )
              .onPressed,
          isNotNull,
        );
        expect(session.characterState.currentHp, character.currentHp);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Reckless first Dexterity attack activates drawback but boosts only later Strength attacks',
    (tester) async {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Barbarian',
        level: 5,
        weapons: [blade, bow],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([4, 3, 17]);
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
      await prepare(tester);
      await tap(tester, attack(bow));
      expect(session.timeline.first.title, 'Dexterity bow Attack: 8');
      expect(dice.index, 1);
      expect(
        session.characterState.activeConditions,
        contains(recklessAttackCondition),
      );
      await tap(tester, attack(blade));
      expect(session.timeline.first.title, 'Strength blade Attack: 22');
      expect(dice.index, 3);
    },
  );
  testWidgets(
    'Reckless supports Strength unarmed strikes and later Retaliation without a new declaration',
    (tester) async {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Barbarian',
        level: 10,
        subclasses: {'Barbarian': 'Path of the Berserker'},
        weapons: [blade],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([4, 12, 6, 18]);
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
      await prepare(tester);
      await tap(tester, find.widgetWithText(OutlinedButton, 'Unarmed Strike'));
      await tap(tester, find.text('Damage').last);
      await tap(tester, find.text('Miss'));
      expect(dice.index, 2);
      expect(session.attackRollMadeThisTurn, true);
      final remaining = session.attackActionAttacksRemaining;
      await tap(tester, find.text('Retaliation · Reaction'));
      await tap(tester, find.text('Retaliate with Strength blade'));
      expect(session.timeline.first.title, 'Strength blade Attack: 23');
      expect(dice.index, 4);
      expect(session.usedCombatActions, {
        CombatActionCost.action,
        CombatActionCost.reaction,
      });
      expect(session.attackActionAttacksRemaining, remaining);
    },
  );
  testWidgets('Reckless Advantage cancels selected Disadvantage', (
    tester,
  ) async {
    final character = seedCharacters.first.copyWith(
      characterClass: 'Barbarian',
      level: 2,
      weapons: [blade],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(character),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    final dice = SequenceDiceRoller([7]);
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
    await prepare(tester);
    await tap(tester, find.byTooltip('Next d20 roll: Normal'));
    await tap(tester, find.text('Disadvantage'));
    await tap(tester, attack(blade));
    expect(dice.index, 1);
    expect(session.timeline.first.title, 'Strength blade Attack: 12');
    expect(
      session.characterState.activeConditions,
      contains(recklessAttackCondition),
    );
  });
  testWidgets('Reckless remains prepared when attack lacks ammunition', (
    tester,
  ) async {
    const weapon = Weapon(
      id: 'reckless-ammo',
      name: 'Ammo blade',
      attackModifier: 5,
      damage: '1d6',
      usesStrength: true,
      ammunitionName: 'Missing ammo',
      category: WeaponCategory.martialMelee,
    );
    final character = seedCharacters.first.copyWith(
      characterClass: 'Barbarian',
      level: 2,
      weapons: [weapon],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(character),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    final dice = SequenceDiceRoller([7]);
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
    await prepare(tester);
    await tap(tester, attack(weapon));
    expect(dice.index, 0);
    expect(session.recklessAttackArmed, true);
    expect(session.attackRollMadeThisTurn, false);
    expect(session.usedCombatActions, isEmpty);
    expect(
      session.characterState.activeConditions,
      isNot(contains(recklessAttackCondition)),
    );
  });
  testWidgets(
    'Reckless requires Barbarian two and cannot be declared after an earlier attack',
    (tester) async {
      for (final (level, made, remaining) in [
        (1, false, 0),
        (2, true, 0),
        (5, false, 1),
      ]) {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: level,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey('$level-$made-$remaining'),
              character: character,
              initialSession: CharacterSession(
                characterState: CharacterState.fromCharacter(character),
                inventory: [],
                archivedInventory: [],
                isInCombat: true,
                attackRollMadeThisTurn: made,
                attackActionAttacksRemaining: remaining,
              ),
              onCharacterChanged: (_) {},
              onSessionChanged: (_) {},
            ),
          ),
        );
        final button = find.widgetWithText(OutlinedButton, declaration);
        if (level < 2) {
          expect(button, findsNothing);
        } else {
          expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        }
      }
    },
  );
  test(
    'Reckless rest cleanup and legacy session defaults preserve compatibility',
    () {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Barbarian',
        level: 2,
      );
      final state = CharacterState.fromCharacter(character).copyWith(
        activeConditions: {recklessAttackCondition},
        conditionTurns: {recklessAttackCondition: 1},
      );
      for (final rest in RestType.values) {
        final result = RestPlan.forCharacter(
          character: character,
          currentState: state,
          type: rest,
        ).updatedState;
        expect(
          result.activeConditions,
          isNot(contains(recklessAttackCondition)),
        );
        expect(
          result.conditionTurns.containsKey(recklessAttackCondition),
          false,
        );
      }
      final legacy = CharacterSession.fromJson(
        CharacterSession.fromCharacter(character).toJson(),
      );
      expect(legacy.attackRollMadeThisTurn, false);
      expect(legacy.recklessAttackArmed, false);
    },
  );
}
