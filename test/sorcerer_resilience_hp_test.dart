import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_advancement.dart';
import 'package:whetstone/screens/character_overview.dart';

const label = 'Draconic Resilience · HP';
Future<void> tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Unknown Draconic HP remains unknown in old saves; recorded bonuses round-trip',
    () {
      final base = seedCharacters.first;
      expect(Character.fromJson(base.toJson()).draconicHpBonus, isNull);
      for (final value in [0, 3, 20]) {
        expect(
          Character.fromJson(
            base.copyWith(draconicHpBonus: value).toJson(),
          ).draconicHpBonus,
          value,
        );
      }
    },
  );
  for (final (choice, prior, expectedMax, expectedMarker) in [
    ('apply', null, 55, 5),
    ('included', null, 50, 5),
    ('cancel', null, 50, null),
    ('apply', 3, 52, 5),
  ]) {
    testWidgets(
      'Draconic HP review $choice prior=$prior preserves live HP and avoids duplicates',
      (tester) async {
        var character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: 5,
          subclasses: {'Sorcerer': 'Draconic Sorcery'},
          draconicHpBonus: prior,
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(currentHp: 22, maxHp: 50),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: CombatActionCost.values.toSet(),
        );
        var generation = 0;
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tap(tester, find.widgetWithText(OutlinedButton, label));
        await tap(
          tester,
          find.text(
            choice == 'cancel'
                ? 'Cancel'
                : choice == 'included'
                ? 'HP already includes +5'
                : 'Apply +${5 - (prior ?? 0)} maximum HP',
          ),
        );
        expect(session.characterState.maxHp, expectedMax);
        expect(session.characterState.currentHp, 22);
        expect(character.draconicHpBonus, expectedMarker);
        expect(session.usedCombatActions, CombatActionCost.values.toSet());
        character = Character.fromJson(character.toJson());
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(session.characterState.maxHp, expectedMax);
        if (choice != 'cancel') {
          await tap(tester, find.widgetWithText(OutlinedButton, label));
          expect(find.textContaining('already recorded'), findsOneWidget);
          expect(find.textContaining('Apply +'), findsNothing);
          await tap(tester, find.text('Done'));
          expect(session.characterState.maxHp, expectedMax);
          expect(character.draconicHpBonus, 5);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final (
        oldLevel,
        newLevel,
        prior,
        oldWarlock,
        newWarlock,
        manual,
        applyBonus,
        expectedMax,
        expectedMarker,
      )
      in [
        (3, 4, 3, 0, 0, null, true, 57, 4),
        (3, 4, 3, 0, 0, 90, true, 91, 4),
        (3, 4, 3, 0, 0, 90, false, 90, 4),
        (3, 4, null, 0, 0, null, true, 56, null),
        (2, 3, null, 0, 0, null, true, 59, 3),
        (5, 6, 3, 2, 2, null, true, 57, 4),
        (5, 6, 3, 2, 3, null, true, 57, 3),
        (3, 2, 3, 0, 0, 50, true, 47, 0),
      ]) {
    testWidgets(
      'Draconic HP advancement $oldLevel->$newLevel prior=$prior Warlock=$newWarlock manual=$manual apply=$applyBonus',
      (tester) async {
        var character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: oldLevel,
          currentHp: 22,
          maxHp: 50,
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.constitution: 14,
            Ability.charisma: 16,
          },
          subclasses: {'Sorcerer': 'Draconic Sorcery'},
          additionalClassLevels: oldWarlock > 0 ? {'Warlock': oldWarlock} : {},
          draconicHpBonus: prior,
        );
        Character? result;
        Widget app() => MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Character>(
                    MaterialPageRoute(
                      builder: (_) =>
                          CharacterAdvancement(character: character),
                    ),
                  );
                },
                child: const Text('Advance'),
              ),
            ),
          ),
        );
        await tester.pumpWidget(app());
        await tap(tester, find.text('Advance'));
        await tester.enterText(
          find.byKey(const ValueKey('advancement-level')),
          '$newLevel',
        );
        await tester.pumpAndSettle();
        if (newWarlock > 0) {
          final field = find.byKey(const ValueKey('advancement-class-warlock'));
          await tester.ensureVisible(field);
          await tester.enterText(field, '$newWarlock');
          await tester.pumpAndSettle();
        }
        if (newLevel > oldLevel) {
          await tap(tester, find.text('Apply level-up HP and proficiency'));
        }
        if (manual != null) {
          final field = find.byKey(const ValueKey('advancement-max-hp'));
          await tester.ensureVisible(field);
          await tester.enterText(field, '$manual');
          await tester.pumpAndSettle();
        }
        if (!applyBonus) {
          await tap(
            tester,
            find.byKey(const ValueKey('advancement-draconic-hp')),
          );
        }
        await tap(tester, find.byKey(const ValueKey('save-advancement')));
        expect(result, isNotNull);
        expect(result!.maxHp, expectedMax);
        expect(result!.currentHp, 22);
        expect(result!.draconicHpBonus, expectedMarker);
        character = Character.fromJson(result!.toJson());
        result = null;
        await tap(tester, find.text('Advance'));
        await tap(tester, find.byKey(const ValueKey('save-advancement')));
        expect(result!.maxHp, expectedMax);
        expect(result!.draconicHpBonus, expectedMarker);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
