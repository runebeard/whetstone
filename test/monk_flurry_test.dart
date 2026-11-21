import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  for (final level in [2, 10]) {
    testWidgets(
      'Flurry level $level saves its strike budget and expires next turn',
      (tester) async {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: level,
          weapons: [],
          resources: BuiltInClass.monk.classResources(
            level,
            charismaModifier: 0,
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(monk),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([1]);
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(session.flurryAttacksRemaining),
            character: monk,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        final start = find.text('Flurry of Blows (1 Focus)');
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.usedCombatActions, isEmpty);
        expect(session.characterState.resourceValues[focusResourceId], level);
        await tester.tap(start);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Spend 1 Focus · Begin Flurry'));
        await tester.pumpAndSettle();
        final count = level >= 10 ? 3 : 2;
        expect(session.flurryAttacksRemaining, count);
        expect(session.usedCombatActions, {CombatActionCost.bonusAction});
        expect(
          session.characterState.resourceValues[focusResourceId],
          level - 1,
        );
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        final strike = find.text('Flurry of Blows · $count strikes remaining');
        await tester.ensureVisible(strike);
        await tester.tap(strike);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.flurryAttacksRemaining, count);
        await tester.tap(strike);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Basic strike'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Damage').last);
        await tester.pumpAndSettle();
        expect(session.flurryAttacksRemaining, count - 1);
        expect(session.attackActionAttacksRemaining, 0);
        expect(session.usedCombatActions, {CombatActionCost.bonusAction});
        expect(dice.index, 1);
        final next = find.text('Next Turn');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(session.flurryAttacksRemaining, 0);
        expect(session.usedCombatActions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final (effect, outcome, detail) in [
    ('Addle', null, 'Target cannot make opportunity attacks'),
    ('Push', 'Save failed', 'Push target up to 15 feet'),
    ('Topple', 'Save succeeded', 'Target avoids the effect'),
    ('Topple', 'Resolve later', 'DC 12 Dexterity save'),
  ]) {
    testWidgets(
      'Open Hand $effect outcome=$outcome only applies after Flurry hits',
      (tester) async {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: 5,
          weapons: [],
          subclasses: {'Monk': 'Warrior of the Open Hand'},
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(monk),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          flurryAttacksRemaining: 2,
          usedCombatActions: {CombatActionCost.bonusAction},
        );
        final dice = SequenceDiceRoller([10, 4]);
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
        final strike = find.text('Flurry of Blows · 2 strikes remaining');
        await tester.ensureVisible(strike);
        await tester.tap(strike);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eligible · Use Martial Arts'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Damage').last);
        await tester.pumpAndSettle();
        expect(find.text('Open Hand Technique'), findsNothing);
        await tester.tap(find.text('Hit · Apply unarmed damage'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(effect).last);
        await tester.pumpAndSettle();
        if (outcome != null) {
          expect(
            find.textContaining(
              effect == 'Push' ? 'DC 12 Strength save' : 'DC 12 Dexterity save',
            ),
            findsOneWidget,
          );
          await tester.tap(find.text(outcome));
          await tester.pumpAndSettle();
        }
        expect(session.timeline.first.detail, contains(detail));
        expect(session.flurryAttacksRemaining, 1);
        expect(session.usedCombatActions, {CombatActionCost.bonusAction});
        expect(session.characterState.activeConditions, isEmpty);
        expect(dice.index, 2);
      },
    );
  }
}

