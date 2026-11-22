import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/rest_confirmation_dialog.dart';

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Sorcery pools begin at class two/five and only recover on Long Rest',
    () {
      for (final level in [1, 2, 4, 5, 20]) {
        final resources = BuiltInClass.sorcerer.classResources(
          level,
          charismaModifier: 3,
        );
        final points = resources
            .where((r) => r.id == sorceryPointsResourceId)
            .firstOrNull;
        expect(points?.maximum, level >= 2 ? level : null);
        expect(
          resources.any((r) => r.id == sorcerousRestorationResourceId),
          level >= 5,
        );
        final character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: level,
          resources: resources,
        );
        for (final type in RestType.values) {
          final plan = RestPlan.forCharacter(
            type: type,
            character: character,
            currentState: CharacterState.fromCharacter(character).copyWith(
              resourceValues: {
                sorceryPointsResourceId: 0,
                sorcerousRestorationResourceId: 0,
              },
            ),
          );
          if (level >= 2) {
            expect(
              plan.updatedState.resourceValues[sorceryPointsResourceId],
              type == RestType.longRest ? level : 0,
            );
          }
          if (level >= 5) {
            expect(
              plan.updatedState.resourceValues[sorcerousRestorationResourceId],
              type == RestType.longRest ? 1 : 0,
            );
          }
        }
      }
    },
  );
  test(
    'Restoration is capped, optional, once per Long Rest, and uses Sorcerer levels',
    () {
      for (final (level, current, uses, extra, expected) in [
        (5, 0, 1, 0, 2),
        (7, 6, 1, 0, 7),
        (20, 0, 1, 0, 10),
        (5, 0, 0, 0, 0),
        (4, 0, 1, 0, 0),
        (5, 0, 1, 5, 2),
        (5, 5, 1, 0, 5),
      ]) {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: level + extra,
          additionalClassLevels: extra > 0 ? {'Fighter': extra} : {},
          resources: BuiltInClass.sorcerer.classResources(
            level,
            charismaModifier: 3,
          ),
        );
        final plan = RestPlan.forCharacter(
          type: RestType.shortRest,
          character: character,
          currentState: CharacterState.fromCharacter(character).copyWith(
            resourceValues: {
              sorceryPointsResourceId: current,
              sorcerousRestorationResourceId: uses,
            },
          ),
        );
        expect(
          plan.updatedState.resourceValues[sorceryPointsResourceId],
          current,
        );
        final recovered = plan.recoverSorceryPoints(character);
        expect(
          recovered.updatedState.resourceValues[sorceryPointsResourceId],
          expected,
        );
        expect(
          recovered.updatedState.resourceValues[sorcerousRestorationResourceId],
          expected > current ? 0 : uses,
        );
        expect(
          recovered
              .recoverSorceryPoints(character)
              .updatedState
              .resourceValues[sorceryPointsResourceId],
          expected,
        );
      }
    },
  );
  for (final (level, current, extra, choice, expected) in [
    (5, 0, 0, 'accept', 2),
    (5, 0, 0, 'decline', 0),
    (5, 0, 0, 'cancel', 0),
    (7, 6, 0, 'accept', 7),
    (20, 0, 0, 'accept', 10),
    (5, 0, 5, 'accept', 2),
  ]) {
    testWidgets(
      'Short Rest Sorcerer $level Fighter $extra $choice from $current',
      (tester) async {
        var character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: level + extra,
          additionalClassLevels: extra > 0 ? {'Fighter': extra} : {},
          resources: [
            CharacterResource(
              id: spellSlotId(1),
              name: 'Spell Slots',
              maximum: 3,
              initialValue: 0,
              rechargePeriod: RechargePeriod.longRest,
            ),
          ],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 42,
            maxHp: 42,
            resourceValues: {
              sorceryPointsResourceId: current,
              sorcerousRestorationResourceId: 1,
            },
          ),
          inventory: [],
          archivedInventory: [],
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
        expect(
          character.resources
              .singleWhere((r) => r.id == sorceryPointsResourceId)
              .maximum,
          level,
        );
        await tap(tester, 'Short Rest');
        final option = find.byType(CheckboxListTile);
        expect(option, findsOneWidget);
        expect(tester.widget<CheckboxListTile>(option).value, isFalse);
        if (choice != 'decline') {
          await tester.tap(option);
          await tester.pumpAndSettle();
        }
        await tap(tester, choice == 'cancel' ? 'Cancel' : 'Take Short Rest');
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          expected,
        );
        expect(
          session.characterState.resourceValues[sorcerousRestorationResourceId],
          choice == 'accept' ? 0 : 1,
        );
        expect(session.characterState.resourceValues[spellSlotId(1)] ?? 0, 0);
        expect(session.characterState.currentHp, 42);
        expect(session.characterState.hitDiceSpentBySize, isEmpty);
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tap(tester, 'Short Rest');
        expect(
          find.byType(CheckboxListTile),
          choice == 'accept' ? findsNothing : findsOneWidget,
        );
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          expected,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Restoration does not appear when there is nothing to recover', (
    tester,
  ) async {
    final character = seedCharacters.first.copyWith(
      characterClass: 'Sorcerer',
      level: 5,
      resources: BuiltInClass.sorcerer.classResources(5, charismaModifier: 3),
    );
    final plan = RestPlan.forCharacter(
      type: RestType.shortRest,
      character: character,
      currentState: CharacterState.fromCharacter(character),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RestConfirmationDialog(
          plan: plan,
          sorcerousRestorationAmount: plan.sorcerousRestorationAmount(
            character,
          ),
        ),
      ),
    );
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Take Short Rest'), findsNothing);
  });
}
