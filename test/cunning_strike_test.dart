import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/cunning_strike.dart';
import 'package:whetstone/models/inventory_item.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/sneak_attack_dialog.dart';

import 'support/sequence_dice_roller.dart';

void main() {
  test(
    'Cunning Strike validates level, equipment, effect count and dice budget',
    () {
      bool valid(
        Set<CunningStrike> effects,
        int level,
        int dice, {
        bool kit = true,
      }) => SneakAttackSelection(
        effects,
      ).isValid(rogueLevel: level, sneakDice: dice, hasPoisonersKit: kit);
      expect(valid({CunningStrike.trip}, 4, 2), isFalse);
      expect(valid({CunningStrike.poison}, 5, 3, kit: false), isFalse);
      expect(
        valid({CunningStrike.trip, CunningStrike.withdraw}, 10, 5),
        isFalse,
      );
      expect(
        valid({CunningStrike.trip, CunningStrike.withdraw}, 11, 6),
        isTrue,
      );
      expect(valid({CunningStrike.daze}, 13, 7), isFalse);
      expect(
        valid({CunningStrike.knockOut, CunningStrike.obscure}, 14, 7),
        isFalse,
      );
      expect(
        valid({CunningStrike.knockOut, CunningStrike.withdraw}, 14, 7),
        isTrue,
      );
    },
  );

  testWidgets('selection limits effects and disables Poison without its kit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<SneakAttackSelection>(
                context: context,
                builder: (_) => const SneakAttackDialog(
                  weaponName: 'Dagger',
                  damageType: 'piercing',
                  rogueLevel: 5,
                  diceCount: 3,
                  critical: true,
                  hasPoisonersKit: false,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Poison'),
          )
          .onChanged,
      isNull,
    );
    final trip = find.widgetWithText(CheckboxListTile, 'Trip');
    await tester.ensureVisible(trip);
    await tester.tap(trip);
    await tester.pumpAndSettle();
    expect(find.text('Trade 1 dice · roll 4d6'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Withdraw'),
          )
          .onChanged,
      isNull,
    );
    expect(find.text('Knock Out'), findsNothing);
  });

  for (final level in [5, 11, 14]) {
    testWidgets(
      'Cunning Strike level $level resolves damage and effects together',
      (tester) async {
        final rogue = seedCharacters.first.copyWith(
          characterClass: 'Rogue',
          level: level,
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
          inventory: [
            InventoryItem(
              name: 'Poisoner’s Kit',
              quantity: 1,
              weightPerItem: 2,
              category: ItemCategory.equipment,
            ),
          ],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller(
          level == 5
              ? [20, 2, 3, 1, 2, 3, 4]
              : level == 11
              ? [10, 4, 1, 2, 3, 4]
              : [10, 2],
        );
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
        final attack = find.byKey(
          const ValueKey('attack-attacks-weapon:dagger'),
        );
        await tester.ensureVisible(attack);
        await tester.tap(attack);
        await tester.pumpAndSettle();
        final damage = find.byKey(
          const ValueKey('damage-attacks-weapon:dagger'),
        );
        await tester.ensureVisible(damage);
        await tester.tap(damage);
        await tester.pumpAndSettle();
        final effects = level == 5
            ? ['Trip']
            : level == 11
            ? ['Poison', 'Withdraw']
            : ['Knock Out', 'Withdraw'];
        for (final name in effects) {
          final option = find.widgetWithText(CheckboxListTile, name);
          await tester.ensureVisible(option);
          await tester.tap(option);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Eligible hit · Roll Sneak Attack'));
        await tester.pumpAndSettle();
        expect(session.sneakAttackUsedThisTurn, isTrue);
        expect(
          session.timeline.any(
            (event) =>
                event.title ==
                (level == 5
                    ? 'Sneak Attack Critical Damage: 10'
                    : level == 11
                    ? 'Sneak Attack Damage: 10'
                    : 'Sneak Attack Damage: 0'),
          ),
          isTrue,
        );
        expect(find.textContaining('DC 13'), findsOneWidget);
        await tester.tap(
          find.text(level == 11 ? 'Save succeeded' : 'Save failed'),
        );
        await tester.pumpAndSettle();
        expect(
          session.timeline.any(
            (event) =>
                event.title ==
                'Cunning Strike · ${effects.first} · ${level == 11 ? 'successful save' : 'failed save'}',
          ),
          isTrue,
        );
        if (level >= 11) {
          expect(session.timeline.first.title, 'Cunning Strike · Withdraw');
        }
        expect(session.characterState.activeConditions, isEmpty);
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(session.inventory.single.quantity, 1);
        expect(
          dice.index,
          level == 5
              ? 7
              : level == 11
              ? 6
              : 2,
        );
      },
    );
  }
}
