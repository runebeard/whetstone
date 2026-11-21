import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/screens/character_overview.dart';

import 'support/sequence_dice_roller.dart';

void main() {
  testWidgets('Steady Aim preserves cancelled and ammunition-blocked attacks', (
    tester,
  ) async {
    final rogue = seedCharacters.first.copyWith(
      characterClass: 'Rogue',
      level: 3,
      weapons: const [
        Weapon(
          id: 'bow',
          name: 'Shortbow',
          attackModifier: 5,
          damage: '1d6 + 2',
          damageFormula: '1d6 + 2',
          ammunitionName: 'Arrows',
        ),
      ],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(rogue),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    final dice = SequenceDiceRoller([]);
    Widget app() => MaterialApp(
      home: CharacterOverview(
        character: rogue,
        initialSession: session,
        onSessionChanged: (value) => session = value,
        onCharacterChanged: (_) {},
        diceRoller: dice,
      ),
    );
    await tester.pumpWidget(app());
    final aim = find.widgetWithText(OutlinedButton, 'Steady Aim');
    await tester.ensureVisible(aim);
    await tester.tap(aim);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(session.usedCombatActions, isEmpty);
    await tester.tap(aim);
    await tester.pumpAndSettle();
    await tester.tap(find.text('No movement · Use Steady Aim'));
    await tester.pumpAndSettle();
    expect(session.steadyAimAttackPending, isTrue);
    expect(session.usedCombatActions, {CombatActionCost.bonusAction});
    session = CharacterSession.fromJson(session.toJson());
    expect(session.steadyAimAttackPending, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final attack = find.byKey(const ValueKey('attack-attacks-weapon:bow'));
    await tester.ensureVisible(attack);
    await tester.tap(attack);
    await tester.pumpAndSettle();
    expect(session.steadyAimAttackPending, isTrue);
    expect(dice.index, 0);
    final boundary = find.text('Track another creature’s turn');
    await tester.ensureVisible(boundary);
    await tester.tap(boundary);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Different turn confirmed'));
    await tester.pumpAndSettle();
    expect(session.steadyAimAttackPending, isFalse);
    expect(
      session.characterState.activeConditions,
      isNot(contains(steadyAimCondition)),
    );
    expect(session.usedCombatActions, {CombatActionCost.bonusAction});
  });

  testWidgets(
    'Steady Aim applies once to unarmed damage attacks and keeps Speed zero',
    (tester) async {
      final rogue = seedCharacters.first.copyWith(
        characterClass: 'Rogue',
        level: 3,
        weapons: [],
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.strength: 16,
        },
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(rogue).copyWith(
          activeConditions: {steadyAimCondition},
          conditionTurns: {steadyAimCondition: 1},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        steadyAimAttackPending: true,
        usedCombatActions: {CombatActionCost.bonusAction},
      );
      final dice = SequenceDiceRoller([3, 17]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: rogue,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: dice,
          ),
        ),
      );
      final unarmed = find.widgetWithText(OutlinedButton, 'Unarmed Strike');
      await tester.ensureVisible(unarmed);
      await tester.tap(unarmed);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Damage').last);
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Unarmed Strike Attack: 23');
      await tester.tap(find.text('Hit · Apply unarmed damage'));
      await tester.pumpAndSettle();
      expect(dice.index, 2);
      expect(session.steadyAimAttackPending, isFalse);
      expect(
        session.characterState.activeConditions,
        contains(steadyAimCondition),
      );
      await tester.ensureVisible(find.text('Next Turn'));
      await tester.tap(find.text('Next Turn'));
      await tester.pumpAndSettle();
      expect(
        session.characterState.activeConditions,
        isNot(contains(steadyAimCondition)),
      );
    },
  );

  for (final sameTurn in [false, true]) {
    testWidgets('readied attack handles Steady Aim sameTurn=$sameTurn', (
      tester,
    ) async {
      final rogue = seedCharacters.first.copyWith(
        characterClass: 'Rogue',
        level: 3,
        weapons: const [
          Weapon(
            id: 'bow',
            name: 'Shortbow',
            attackModifier: 5,
            damage: '1d6 + 2',
            damageFormula: '1d6 + 2',
          ),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(rogue).copyWith(
          activeConditions: {steadyAimCondition},
          conditionTurns: {steadyAimCondition: 1},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        steadyAimAttackPending: true,
        usedCombatActions: {
          CombatActionCost.action,
          CombatActionCost.bonusAction,
        },
        readiedAction: 'When the enemy approaches',
        readiedEffect: 'weapon:bow',
      );
      final dice = SequenceDiceRoller(sameTurn ? [3, 17] : [10]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: rogue,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: dice,
          ),
        ),
      );
      final trigger = find.text('Trigger');
      await tester.ensureVisible(trigger);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.steadyAimAttackPending, isTrue);
      expect(
        session.usedCombatActions,
        isNot(contains(CombatActionCost.reaction)),
      );
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(sameTurn ? 'Same turn' : 'Another creature’s turn'),
      );
      await tester.pumpAndSettle();
      expect(
        session.timeline.first.title,
        sameTurn ? 'Shortbow Attack: 22' : 'Shortbow Attack: 15',
      );
      expect(session.steadyAimAttackPending, isFalse);
      expect(
        session.characterState.activeConditions.contains(steadyAimCondition),
        sameTurn,
      );
      expect(session.usedCombatActions, contains(CombatActionCost.reaction));
    });
  }
}
