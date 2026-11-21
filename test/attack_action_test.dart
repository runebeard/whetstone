import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/screens/character_overview.dart';

import 'support/sequence_dice_roller.dart';

void main() {
  test('Extra Attack uses individual class levels and does not stack', () {
    final base = seedCharacters.first;
    for (final name in ['Barbarian', 'Monk', 'Paladin', 'Ranger']) {
      expect(base.copyWith(characterClass: name, level: 4).attacksPerAction, 1);
      expect(base.copyWith(characterClass: name, level: 5).attacksPerAction, 2);
    }
    expect(
      base.copyWith(characterClass: 'Wizard', level: 20).attacksPerAction,
      1,
    );
    expect(
      base
          .copyWith(
            characterClass: 'Fighter',
            level: 10,
            additionalClassLevels: {'Paladin': 5},
          )
          .attacksPerAction,
      2,
    );
    expect(
      base
          .copyWith(
            characterClass: 'Fighter',
            level: 8,
            additionalClassLevels: {'Paladin': 4},
          )
          .attacksPerAction,
      1,
    );
    expect(
      base
          .copyWith(
            characterClass: 'Fighter',
            level: 16,
            additionalClassLevels: {'Paladin': 5},
          )
          .attacksPerAction,
      3,
    );
  });

  testWidgets(
    'a readied Reaction does not spend or grant Attack action attacks',
    (tester) async {
      final fighter = seedCharacters.first.copyWith(
        characterClass: 'Fighter',
        level: 5,
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(fighter),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        usedCombatActions: {CombatActionCost.action},
        attackActionAttacksRemaining: 1,
        readiedAction: 'When the enemy approaches',
        readiedEffect: 'weapon:quarterstaff',
      );
      final dice = SequenceDiceRoller([10, 11]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: fighter,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: dice,
          ),
        ),
      );
      await tester.ensureVisible(find.text('Trigger'));
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, {
        CombatActionCost.action,
        CombatActionCost.reaction,
      });
      expect(session.attackActionAttacksRemaining, 1);
      expect(dice.index, 1);
      final attack = find.byKey(
        const ValueKey('attack-attacks-weapon:quarterstaff'),
      );
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      expect(session.attackActionAttacksRemaining, 0);
      expect(dice.index, 2);
    },
  );

  testWidgets(
    'damage-only and missing ammunition preserve the Action and Surge',
    (tester) async {
      final fighter = seedCharacters.first.copyWith(
        characterClass: 'Fighter',
        level: 5,
        weapons: const [
          Weapon(
            id: 'bow',
            name: 'Bow',
            attackModifier: 5,
            damage: '1d6 + 3',
            damageFormula: '1d6 + 3',
            ammunitionName: 'Arrows',
          ),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(fighter),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        actionSurge: ActionSurgeState.available,
      );
      final dice = SequenceDiceRoller([4]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: fighter,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: dice,
          ),
        ),
      );
      final damage = find.byKey(const ValueKey('damage-attacks-weapon:bow'));
      await tester.ensureVisible(damage);
      await tester.tap(damage);
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Bow Damage: 7');
      final attack = find.byKey(const ValueKey('attack-attacks-weapon:bow'));
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, isEmpty);
      expect(session.actionSurge, ActionSurgeState.available);
      expect(session.attackActionAttacksRemaining, 0);
      expect(dice.index, 1);
      expect(find.text('No Arrows remaining.'), findsOneWidget);
    },
  );

  for (final (level, attacks, surge) in [
    (1, 1, false),
    (5, 2, false),
    (11, 3, false),
    (20, 4, false),
    (5, 4, true),
  ]) {
    testWidgets('Fighter $level permits $attacks attacks with surge=$surge', (
      tester,
    ) async {
      final fighter = seedCharacters.first.copyWith(
        characterClass: 'Fighter',
        level: level,
        weapons: const [
          Weapon(
            id: 'staff',
            name: 'Quarterstaff',
            attackModifier: 5,
            damage: '1d6 + 3',
            damageFormula: '1d6 + 3',
          ),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(fighter),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        actionSurge: surge ? ActionSurgeState.available : null,
      );
      final roller = SequenceDiceRoller(List.filled(attacks + 2, 10));
      Widget app() => MaterialApp(
        home: CharacterOverview(
          character: fighter,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: roller,
        ),
      );
      await tester.pumpWidget(app());
      final attack = find.byKey(const ValueKey('attack-attacks-weapon:staff'));
      for (var i = 0; i < attacks; i++) {
        await tester.ensureVisible(attack);
        await tester.tap(attack);
        await tester.pumpAndSettle();
        expect(
          session.attackActionAttacksRemaining,
          (attacks - i - 1) % fighter.attacksPerAction,
        );
        if (i == 0) {
          session = CharacterSession.fromJson(session.toJson());
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
        }
      }
      expect(session.usedCombatActions, contains(CombatActionCost.action));
      if (surge) expect(session.actionSurge, ActionSurgeState.spent);
      final count = session.timeline
          .where((e) => e.title.startsWith('Quarterstaff Attack'))
          .length;
      expect(count, attacks);
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      expect(
        session.timeline
            .where((e) => e.title.startsWith('Quarterstaff Attack'))
            .length,
        count,
      );
      final next = find.text('Next Turn');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(session.attackActionAttacksRemaining, 0);
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      expect(
        session.attackActionAttacksRemaining,
        fighter.attacksPerAction - 1,
      );
    });
  }
}
