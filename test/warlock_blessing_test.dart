import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';

const label = 'Dark One’s Blessing';

void main() {
  for (final (combat, other, charisma, hp, existing, wizard, expected) in [
    (true, false, 16, 22, 0, 0, 6),
    (false, true, 1, 22, 0, 0, 1),
    (true, true, 16, 0, 0, 0, 6),
    (true, true, 16, 22, 20, 17, 20),
  ]) {
    testWidgets(
      'Blessing combat=$combat other=$other Charisma=$charisma HP=$hp temp=$existing',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Warlock',
          level: 3 + wizard,
          additionalClassLevels: wizard == 0 ? {} : {'Wizard': wizard},
          subclasses: {'Warlock': 'Fiend Patron'},
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.charisma: charisma,
          },
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: hp,
            temporaryHp: existing,
            activeConditions: {'Poisoned'},
            deathSaveSuccesses: 2,
            deathSaveFailures: 1,
            resourceValues: {magicalCunningResourceId: 0, 'custom': 0},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: combat,
          usedCombatActions: combat ? CombatActionCost.values.toSet() : {},
        );
        var generation = 0;
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        final button = find.widgetWithText(OutlinedButton, label);
        Future<void> open() async {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
        }

        await open();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.characterState.temporaryHp, existing);
        await open();
        await tester.tap(
          find.text(
            other ? 'Nearby enemy reduced by another' : 'Enemy reduced by you',
          ),
        );
        await tester.pumpAndSettle();
        expect(session.characterState.temporaryHp, expected);
        expect(session.characterState.currentHp, hp);
        expect(session.characterState.deathSaveSuccesses, 2);
        expect(session.characterState.deathSaveFailures, 1);
        expect(session.characterState.activeConditions, {'Poisoned'});
        expect(
          session.characterState.resourceValues[magicalCunningResourceId],
          0,
        );
        expect(session.characterState.resourceValues['custom'], 0);
        expect(
          session.usedCombatActions,
          combat ? CombatActionCost.values.toSet() : isEmpty,
        );
        expect(session.timeline.first.title, label);
        expect(
          session.timeline.first.detail,
          contains(other ? 'within 10 feet' : 'You reduced an enemy'),
        );
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(session.characterState.temporaryHp, expected);
        expect(session.characterState.currentHp, hp);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Blessing requires Fiend three and is unavailable after death', (
    tester,
  ) async {
    for (final (level, subclass, dead) in [
      (2, 'Fiend Patron', false),
      (3, 'Other', false),
      (3, 'Fiend Patron', true),
    ]) {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Warlock',
        level: level,
        subclasses: {'Warlock': subclass},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            key: ValueKey('$level-$subclass-$dead'),
            character: character,
            initialSession: CharacterSession(
              characterState: CharacterState.fromCharacter(character).copyWith(
                currentHp: dead ? 0 : 22,
                deathSaveFailures: dead ? 3 : 0,
              ),
              inventory: [],
              archivedInventory: [],
              isInCombat: true,
            ),
            onCharacterChanged: (_) {},
            onSessionChanged: (_) {},
          ),
        ),
      );
      final button = find.widgetWithText(OutlinedButton, label);
      if (level < 3 || subclass == 'Other') {
        expect(button, findsNothing);
      } else {
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      }
    }
  });
}
