import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/hp_box.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  for (final (level, option, expectedHp, temporaryHp) in [
    (5, 'Deflect Attacks · hit includes physical damage', 18, 0),
    (13, 'Deflect Energy · attack hit', 26, 0),
    (5, 'Slow Fall · falling damage', 29, 0),
    (5, 'Deflect Attacks · hit includes physical damage', 23, 5),
  ]) {
    testWidgets(
      '$option at level $level temporaryHp=$temporaryHp spends Reaction before damage',
      (tester) async {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: level,
          resources: BuiltInClass.monk.classResources(
            level,
            charismaModifier: 0,
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            monk,
          ).copyWith(temporaryHp: temporaryHp),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([7]);
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(session.usedCombatActions.length),
            character: monk,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        await tester.tap(find.byType(HpBox));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '30');
        await tester.tap(find.text('🗡 Damage'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(option).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.characterState.currentHp, 34);
        expect(session.usedCombatActions, isEmpty);
        expect(dice.index, 0);
        await tester.tap(find.byType(HpBox));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '30');
        await tester.tap(find.text('🗡 Damage'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(option).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply damage'));
        await tester.pumpAndSettle();
        expect(session.characterState.currentHp, expectedHp);
        expect(session.usedCombatActions, {CombatActionCost.reaction});
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.byType(HpBox));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '2');
        await tester.tap(find.text('🗡 Damage'));
        await tester.pumpAndSettle();
        expect(find.byType(DropdownButtonFormField<int>), findsNothing);
        if (level >= 7) {
          await tester.tap(find.text('Apply damage'));
          await tester.pumpAndSettle();
        }
        expect(session.characterState.currentHp, expectedHp - 2);
      },
    );
  }
  for (final redirect in [false, true]) {
    testWidgets(
      'Fully deflected damage redirect=$redirect preserves HP and spends Focus only on acceptance',
      (tester) async {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: 5,
          resources: BuiltInClass.monk.classResources(5, charismaModifier: 0),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            monk,
          ).copyWith(temporaryHp: 5),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([7, 3, 4]);
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
        await tester.tap(find.byType(HpBox));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '10');
        await tester.tap(find.text('🗡 Damage'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Deflect Attacks · hit includes physical damage').last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply damage'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(redirect ? 'Spend 1 Focus · Redirect' : 'Keep Focus'),
        );
        await tester.pumpAndSettle();
        expect(session.characterState.currentHp, 34);
        expect(session.characterState.temporaryHp, 5);
        expect(session.usedCombatActions, {CombatActionCost.reaction});
        expect(
          session.characterState.resourceValues[focusResourceId],
          redirect ? 4 : 5,
        );
        expect(dice.index, redirect ? 3 : 1);
        if (redirect) {
          expect(
            session.timeline.first.detail,
            contains('DC 12 Dexterity save. On failure: 9 damage'),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
