import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  test('Martial Arts scales by Monk class level', () {
    for (final (level, sides) in [
      (1, 6),
      (4, 6),
      (5, 8),
      (10, 8),
      (11, 10),
      (16, 10),
      (17, 12),
      (20, 12),
    ]) {
      expect(
        seedCharacters.first
            .copyWith(characterClass: 'Monk', level: level)
            .martialArtsDieSides,
        sides,
      );
    }
    expect(seedCharacters.first.martialArtsDieSides, 0);
    expect(
      seedCharacters.first
          .copyWith(
            characterClass: 'Fighter',
            level: 20,
            additionalClassLevels: {'Monk': 1},
          )
          .martialArtsDieSides,
      6,
    );
  });
  for (final critical in [false, true]) {
    testWidgets(
      'Martial Arts damage critical=$critical preserves Attack action',
      (tester) async {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: 5,
          weapons: [],
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.strength: 8,
            Ability.dexterity: 18,
          },
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(monk),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller(critical ? [20, 5, 6] : [10, 5]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: monk,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
              diceRoller: dice,
            ),
          ),
        );
        final bonus = find.text('Martial Arts · Bonus Unarmed Strike');
        await tester.ensureVisible(bonus);
        await tester.tap(bonus);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.usedCombatActions, isEmpty);
        await tester.tap(bonus);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eligible · Use Martial Arts'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Damage').last);
        await tester.pumpAndSettle();
        expect(
          session.timeline.first.title,
          contains('Unarmed Strike Attack: ${critical ? 27 : 17}'),
        );
        await tester.tap(find.text('Hit · Apply unarmed damage'));
        await tester.pumpAndSettle();
        expect(
          session.timeline.first.title,
          'Unarmed Strike Damage: ${critical ? 15 : 9}',
        );
        expect(session.usedCombatActions, {CombatActionCost.bonusAction});
        expect(session.attackActionAttacksRemaining, 0);
        final restored = CharacterSession.fromJson(session.toJson());
        expect(restored.usedCombatActions, {CombatActionCost.bonusAction});
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(
                  OutlinedButton,
                  'Martial Arts · Bonus Unarmed Strike',
                ),
              )
              .onPressed,
          isNull,
        );
        final basic = find.widgetWithText(OutlinedButton, 'Unarmed Strike');
        await tester.ensureVisible(basic);
        await tester.tap(basic);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eligible · Use Martial Arts'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Grapple'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('DC 15 Strength or Dexterity save.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Save failed'));
        await tester.pumpAndSettle();
        expect(session.attackActionAttacksRemaining, 1);
        expect(session.usedCombatActions, {
          CombatActionCost.action,
          CombatActionCost.bonusAction,
        });
        expect(dice.index, critical ? 3 : 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Armored Monk can keep basic unarmed damage', (tester) async {
    final monk = seedCharacters.first.copyWith(
      characterClass: 'Monk',
      level: 1,
      weapons: [],
      abilityScores: {
        ...seedCharacters.first.abilityScores,
        Ability.strength: 16,
        Ability.dexterity: 18,
      },
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(monk),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    final dice = SequenceDiceRoller([20]);
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: monk,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: dice,
        ),
      ),
    );
    final strike = find.widgetWithText(OutlinedButton, 'Unarmed Strike');
    await tester.ensureVisible(strike);
    await tester.tap(strike);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basic strike'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Damage').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hit · Apply unarmed damage'));
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Unarmed Strike Damage: 4');
    expect(dice.index, 1);
  });
}
