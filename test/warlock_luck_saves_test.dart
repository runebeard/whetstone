import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/hp_box.dart';
import 'support/sequence_dice_roller.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final (bonus, maintained) in [(8, true), (1, false)]) {
    testWidgets(
      'Own Luck concentration bonus $bonus applies before maintained=$maintained outcome',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Warlock',
          level: 6,
          subclasses: {'Warlock': 'Fiend Patron'},
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.constitution: 10,
          },
          savingThrowProficiencies: {},
          resources: BuiltInClass.warlock.classResources(
            6,
            charismaModifier: 3,
            subclass: 'Fiend Patron',
          ),
          spells: [
            const Spell(
              id: 'luck-focus',
              name: 'Luck Focus',
              summary: 'Concentration',
              level: 1,
              prepared: true,
              concentration: true,
            ),
          ],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 22,
            concentrationSpellId: 'luck-focus',
            resourceValues: {darkOnesOwnLuckResourceId: 2},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([2, bonus]);
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
        await tap(tester, find.byType(HpBox));
        await tester.enterText(find.byType(TextField), '4');
        await tap(tester, find.text('🗡 Damage'));
        await tap(tester, find.text('Roll Save'));
        expect(session.characterState.concentrationSpellId, 'luck-focus');
        expect(
          session.characterState.resourceValues[darkOnesOwnLuckResourceId],
          2,
        );
        await tap(tester, find.text('Spend use · Boost save'));
        expect(
          session.characterState.concentrationSpellId,
          maintained ? 'luck-focus' : null,
        );
        expect(session.characterState.currentHp, 18);
        expect(
          session.characterState.resourceValues[darkOnesOwnLuckResourceId],
          1,
        );
        expect(session.usedCombatActions, isEmpty);
        expect(dice.index, 2);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(
                  OutlinedButton,
                  'Dark One’s Own Luck · Last check or save',
                ),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final (natural, bonus, successes, failures, hp, uses) in [
    (2, 8, 1, 0, 0, 1),
    (2, 1, 0, 1, 0, 1),
    (1, 0, 0, 2, 0, 2),
    (20, 0, 0, 0, 1, 2),
    (12, 0, 1, 0, 0, 2),
  ]) {
    testWidgets(
      'Own Luck death save natural $natural bonus $bonus preserves special outcomes',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Warlock',
          level: 6,
          subclasses: {'Warlock': 'Fiend Patron'},
          resources: BuiltInClass.warlock.classResources(
            6,
            charismaModifier: 3,
            subclass: 'Fiend Patron',
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 0,
            resourceValues: {darkOnesOwnLuckResourceId: 2},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([natural, if (bonus > 0) bonus]);
        var generation = 0;
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
        await tester.pumpAndSettle();
        await tap(tester, find.byKey(const ValueKey('roll-death-save')));
        if (bonus > 0) {
          expect(session.characterState.deathSaveSuccesses, 0);
          expect(session.characterState.deathSaveFailures, 0);
          await tap(tester, find.text('Spend use · Boost save'));
        } else {
          expect(find.text('Spend use · Boost save'), findsNothing);
        }
        expect(session.characterState.deathSaveSuccesses, successes);
        expect(session.characterState.deathSaveFailures, failures);
        expect(session.characterState.currentHp, hp);
        expect(
          session.characterState.resourceValues[darkOnesOwnLuckResourceId],
          uses,
        );
        expect(session.usedCombatActions, isEmpty);
        expect(dice.index, bonus > 0 ? 2 : 1);
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(session.characterState.deathSaveFailures, failures);
        expect(session.characterState.deathSaveSuccesses, successes);
        expect(
          session.characterState.resourceValues[darkOnesOwnLuckResourceId],
          uses,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
