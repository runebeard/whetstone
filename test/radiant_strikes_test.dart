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
  test(
    'melee classification preserves legacy names and explicit categories',
    () {
      Weapon weapon(String name, [WeaponCategory? category]) => Weapon(
        id: name,
        name: name,
        attackModifier: 2,
        damage: '',
        category: category,
      );
      expect(weapon(' Handaxe ').isMelee, isTrue);
      expect(weapon('Dart').isMelee, isFalse);
      expect(weapon('Shortbow').isMelee, isFalse);
      expect(
        weapon('Custom Blade', WeaponCategory.martialMelee).isMelee,
        isTrue,
      );
      expect(
        weapon('Longsword', WeaponCategory.martialRanged).isMelee,
        isFalse,
      );
      expect(weapon('Unknown').isMelee, isFalse);
    },
  );

  for (final (level, critical, ranged) in [
    (10, false, false),
    (11, false, false),
    (11, true, false),
    (11, false, true),
  ]) {
    testWidgets(
      'Radiant Strikes level $level critical=$critical ranged=$ranged',
      (tester) async {
        final paladin = seedCharacters.first.copyWith(
          characterClass: 'Paladin',
          level: level,
          weapons: [
            Weapon(
              id: 'test',
              name: ranged ? 'Shortbow' : 'Quarterstaff',
              attackModifier: 6,
              damage: '1d6 + 3',
              damageFormula: '1d6 + 3',
              damageType: 'piercing',
            ),
          ],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(paladin),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller(
          critical ? [20, 2, 3, 4, 5] : [10, 2, 4],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: paladin,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
              diceRoller: dice,
            ),
          ),
        );
        final attack = find.byKey(const ValueKey('attack-attacks-weapon:test'));
        await tester.ensureVisible(attack);
        await tester.tap(attack);
        await tester.pumpAndSettle();
        final damage = find.byKey(const ValueKey('damage-attacks-weapon:test'));
        await tester.ensureVisible(damage);
        await tester.tap(damage);
        await tester.pumpAndSettle();
        final radiant = session.timeline.where(
          (e) => e.title.startsWith('Radiant Strikes'),
        );
        if (level < 11 || ranged) {
          expect(radiant, isEmpty);
          expect(dice.index, 2);
        } else {
          expect(
            radiant.single.title,
            critical
                ? 'Radiant Strikes Critical Damage: 9'
                : 'Radiant Strikes Damage: 4',
          );
          expect(
            radiant.single.detail,
            contains('Apply resistance separately'),
          );
          expect(dice.index, critical ? 5 : 3);
        }
      },
    );
  }

  for (final critical in [false, true]) {
    testWidgets(
      'Radiant Strikes adds dice to fixed unarmed damage critical=$critical',
      (tester) async {
        final paladin = seedCharacters.first.copyWith(
          characterClass: 'Paladin',
          level: 11,
          weapons: [],
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.strength: 16,
          },
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(paladin),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: paladin,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
              diceRoller: SequenceDiceRoller(critical ? [20, 4, 5] : [10, 4]),
            ),
          ),
        );
        final unarmed = find.widgetWithText(OutlinedButton, 'Unarmed Strike');
        await tester.ensureVisible(unarmed);
        await tester.tap(unarmed);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Damage').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hit · Apply unarmed damage'));
        await tester.pumpAndSettle();
        expect(
          session.timeline.first.title,
          critical
              ? 'Radiant Strikes Critical Damage: 9'
              : 'Radiant Strikes Damage: 4',
        );
        expect(session.timeline[1].title, 'Unarmed Strike Damage: 4');
        expect(session.attackActionAttacksRemaining, 1);
      },
    );
  }

  for (final cleave in [false, true]) {
    testWidgets(
      'Radiant Strikes applies to mastery extra hits cleave=$cleave',
      (tester) async {
        final paladin = seedCharacters.first.copyWith(
          characterClass: 'Paladin',
          level: 11,
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.strength: 16,
          },
          weapons: [
            Weapon(
              id: 'main',
              name: cleave ? 'Greataxe' : 'Shortsword',
              attackModifier: 6,
              damage: cleave ? '1d12 + 3' : '1d6 + 3',
              damageFormula: cleave ? '1d12 + 3' : '1d6 + 3',
              usesStrength: true,
              mastery: cleave ? WeaponMastery.cleave : null,
            ),
            if (!cleave)
              const Weapon(
                id: 'dagger',
                name: 'Dagger',
                attackModifier: 6,
                damage: '1d4 + 3',
                damageFormula: '1d4 + 3',
                usesStrength: true,
                mastery: WeaponMastery.nick,
              ),
          ],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(paladin),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: paladin,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
              diceRoller: SequenceDiceRoller([10, 10, 4, 3, 5, 2]),
            ),
          ),
        );
        final attack = find.byKey(const ValueKey('attack-attacks-weapon:main'));
        await tester.ensureVisible(attack);
        await tester.tap(attack);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(cleave ? 'Hit · Make Cleave Attack' : 'Nick · Dagger'),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            cleave ? 'Hit · Roll Cleave Damage' : 'Hit · Roll Nick Damage',
          ),
        );
        await tester.pumpAndSettle();
        expect(session.timeline.first.title, 'Radiant Strikes Damage: 3');
        expect(session.attackActionAttacksRemaining, 1);
        final damage = find.byKey(const ValueKey('damage-attacks-weapon:main'));
        await tester.ensureVisible(damage);
        await tester.tap(damage);
        await tester.pumpAndSettle();
        expect(session.timeline.first.title, 'Radiant Strikes Damage: 2');
        expect(
          session.timeline
              .where((e) => e.title.startsWith('Radiant Strikes'))
              .length,
          2,
        );
      },
    );
  }
}
