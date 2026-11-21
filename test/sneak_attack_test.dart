import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/screens/character_overview.dart';

import 'support/sequence_dice_roller.dart';

void main() {
  testWidgets(
    'Nick can deliver Sneak Attack while preserving the primary critical',
    (tester) async {
      final rogue = seedCharacters.first.copyWith(
        characterClass: 'Rogue',
        level: 3,
        weapons: const [
          Weapon(
            id: 'main',
            name: 'Shortsword',
            attackModifier: 5,
            damage: '1d6 + 2',
            damageFormula: '1d6 + 2',
            damageType: 'piercing',
          ),
          Weapon(
            id: 'dagger',
            name: 'Dagger',
            attackModifier: 5,
            damage: '1d4 + 2',
            damageFormula: '1d4 + 2',
            damageType: 'piercing',
            mastery: WeaponMastery.nick,
          ),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(rogue),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([20, 10, 4, 3, 4, 2, 3]);
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
      final attack = find.byKey(const ValueKey('attack-attacks-weapon:main'));
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nick · Dagger'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hit · Roll Nick Damage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eligible hit · Roll Sneak Attack'));
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Sneak Attack Damage: 7');
      final damage = find.byKey(const ValueKey('damage-attacks-weapon:main'));
      await tester.ensureVisible(damage);
      await tester.tap(damage);
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Shortsword Critical Damage: 7');
      expect(find.text('Eligible hit · Roll Sneak Attack'), findsNothing);
      expect(dice.index, 7);
      expect(session.usedCombatActions, {CombatActionCost.action});
      await tester.ensureVisible(find.text('Next Turn'));
      await tester.tap(find.text('Next Turn'));
      await tester.pumpAndSettle();
      expect(session.sneakAttackUsedThisTurn, isFalse);
    },
  );

  test(
    'Sneak Attack uses Rogue level and excludes a thrown non-Finesse weapon',
    () {
      final base = seedCharacters.first.copyWith(
        characterClass: 'Rogue',
        level: 20,
        additionalClassLevels: {'Fighter': 11},
      );
      expect(base.sneakAttackDice, 5);
      Weapon weapon(
        String name, {
        WeaponCategory? category,
        List<String> properties = const [],
      }) => Weapon(
        id: name,
        name: name,
        attackModifier: 5,
        damage: '',
        category: category,
        properties: properties,
      );
      expect(
        weapon('Handaxe', properties: ['Thrown']).sneakAttackEligible,
        isFalse,
      );
      expect(weapon('Dagger').sneakAttackEligible, isTrue);
      expect(weapon('Dart').sneakAttackEligible, isTrue);
      expect(
        weapon(
          'Custom',
          category: WeaponCategory.martialRanged,
        ).sneakAttackEligible,
        isTrue,
      );
      expect(
        weapon('Custom', properties: ['Finesse']).sneakAttackEligible,
        isTrue,
      );
    },
  );

  for (final critical in [false, true]) {
    testWidgets(
      'Sneak Attack scales critical=$critical and persists its turn limit',
      (tester) async {
        final rogue = seedCharacters.first.copyWith(
          characterClass: 'Rogue',
          level: 3,
          weapons: const [
            Weapon(
              id: 'dagger',
              name: 'Dagger',
              attackModifier: 5,
              damage: '1d4 + 2',
              damageFormula: '1d4 + 2',
              damageType: 'piercing',
            ),
          ],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(rogue),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller(
          critical ? [20, 2, 3, 1, 2, 3, 4, 2] : [10, 2, 3, 4, 2],
        );
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
        final attack = find.byKey(
          const ValueKey('attack-attacks-weapon:dagger'),
        );
        final damage = find.byKey(
          const ValueKey('damage-attacks-weapon:dagger'),
        );
        await tester.ensureVisible(attack);
        await tester.tap(attack);
        await tester.pumpAndSettle();
        await tester.ensureVisible(damage);
        await tester.tap(damage);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eligible hit · Roll Sneak Attack'));
        await tester.pumpAndSettle();
        expect(
          session.timeline.first.title,
          critical
              ? 'Sneak Attack Critical Damage: 10'
              : 'Sneak Attack Damage: 7',
        );
        expect(
          session.timeline.first.detail,
          contains('before applying resistance'),
        );
        expect(session.usedCombatActions, {CombatActionCost.action});
        session = CharacterSession.fromJson(session.toJson());
        expect(session.sneakAttackUsedThisTurn, isTrue);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.ensureVisible(damage);
        await tester.tap(damage);
        await tester.pumpAndSettle();
        expect(find.text('Eligible hit · Roll Sneak Attack'), findsNothing);
        final usedActions = {...session.usedCombatActions};
        final turn = find.text('Track another creature’s turn');
        await tester.ensureVisible(turn);
        await tester.tap(turn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.sneakAttackUsedThisTurn, isTrue);
        await tester.tap(turn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Different turn confirmed'));
        await tester.pumpAndSettle();
        expect(session.sneakAttackUsedThisTurn, isFalse);
        expect(session.usedCombatActions, usedActions);
        await tester.ensureVisible(find.text('Next Turn'));
        await tester.tap(find.text('Next Turn'));
        await tester.pumpAndSettle();
        expect(session.sneakAttackUsedThisTurn, isFalse);
      },
    );
  }

  testWidgets(
    'Sneak Attack cancellation preserves its use on an eligible later hit',
    (tester) async {
      final rogue = seedCharacters.first.copyWith(
        characterClass: 'Rogue',
        level: 1,
        weapons: const [
          Weapon(
            id: 'dagger',
            name: 'Dagger',
            attackModifier: 5,
            damage: '1d4 + 2',
            damageFormula: '1d4 + 2',
            damageType: 'piercing',
          ),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(rogue),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: rogue,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: SequenceDiceRoller([2, 3, 4]),
          ),
        ),
      );
      final damage = find.byKey(const ValueKey('damage-attacks-weapon:dagger'));
      await tester.ensureVisible(damage);
      await tester.tap(damage);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(session.sneakAttackUsedThisTurn, isFalse);
      await tester.tap(damage);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eligible hit · Roll Sneak Attack'));
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Sneak Attack Damage: 4');
      expect(session.usedCombatActions, isEmpty);
    },
  );
}
