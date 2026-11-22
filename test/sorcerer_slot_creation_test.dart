import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';

const createLabel = 'Font of Magic · Create slot';
Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Created slot counts, including spent pools, survive Short Rest and expire on Long Rest',
    () {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Sorcerer',
        level: 9,
        resources: BuiltInClass.sorcerer.classResources(9, charismaModifier: 3),
      );
      final state = CharacterState.fromCharacter(character).copyWith(
        resourceValues: {fontOfMagicSlotId(1): 2, fontOfMagicSlotId(5): 0},
      );
      final slots = fontOfMagicSlots(state.resourceValues).toList();
      expect(slots.map(spellSlotLevel), [1, 5]);
      expect(
        slots.every((r) => r.rechargePeriod == RechargePeriod.manual),
        isTrue,
      );
      for (final type in RestType.values) {
        final result = RestPlan.forCharacter(
          type: type,
          character: character,
          currentState: state,
        ).updatedState;
        expect(
          result.resourceValues[fontOfMagicSlotId(1)],
          type == RestType.shortRest ? 2 : null,
        );
        expect(
          result.resourceValues[fontOfMagicSlotId(5)],
          type == RestType.shortRest ? 0 : null,
        );
      }
    },
  );
  for (final (level, slotLevel, cost, cancel) in [
    (2, 1, 2, false),
    (3, 2, 3, false),
    (5, 3, 5, false),
    (7, 4, 6, false),
    (9, 5, 7, false),
    (5, 1, 2, true),
  ]) {
    testWidgets(
      'Create level $slotLevel at Sorcerer $level cost $cost cancel=$cancel',
      (tester) async {
        var character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: level,
          resources: BuiltInClass.sorcerer.classResources(
            level,
            charismaModifier: 3,
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
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
        await tap(tester, createLabel);
        if (!cancel) {
          expect(
            find.text(
              'Level ${slotLevel + 1} · ${fontOfMagicCreationCosts[slotLevel + 1]?.$1} points',
            ),
            findsNothing,
          );
        }
        await tap(
          tester,
          cancel ? 'Cancel' : 'Level $slotLevel · $cost points',
        );
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId] ??
              level,
          cancel ? level : level - cost,
        );
        expect(
          session.characterState.resourceValues[fontOfMagicSlotId(slotLevel)],
          cancel ? null : 1,
        );
        expect(
          session.usedCombatActions,
          cancel ? isEmpty : {CombatActionCost.bonusAction},
        );
        if (!cancel) {
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, createLabel),
                )
                .onPressed,
            isNull,
          );
        }
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          session.characterState.resourceValues[fontOfMagicSlotId(slotLevel)],
          cancel ? null : 1,
        );
        expect(
          session.usedCombatActions,
          cancel ? isEmpty : {CombatActionCost.bonusAction},
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Extra created slots stack, cast separately and retain ordinary slots',
    (tester) async {
      var character = seedCharacters.first.copyWith(
        characterClass: 'Sorcerer',
        level: 6,
        resources: [
          ...BuiltInClass.sorcerer.classResources(6, charismaModifier: 3),
          CharacterResource(
            id: spellSlotId(2),
            name: 'Ordinary Slots',
            maximum: 3,
            initialValue: 0,
            rechargePeriod: RechargePeriod.longRest,
          ),
        ],
        spells: [
          const Spell(
            id: 'font-ward',
            name: 'Font Ward',
            level: 2,
            prepared: true,
            summary: 'A test ward.',
          ),
        ],
      );
      var session = CharacterSession.fromCharacter(character);
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
      for (var index = 0; index < 2; index++) {
        await tap(tester, createLabel);
        await tap(tester, 'Level 2 · 3 points');
      }
      expect(session.characterState.resourceValues[fontOfMagicSlotId(2)], 2);
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 0);
      await tap(tester, 'Spellbook');
      await tap(tester, 'Font Ward');
      await tap(tester, 'Cast');
      await tap(tester, 'Level 2 Font of Magic · 2 remaining');
      expect(session.characterState.resourceValues[fontOfMagicSlotId(2)], 1);
      expect(session.characterState.resourceValues[spellSlotId(2)] ?? 0, 0);
      session = CharacterSession.fromJson(session.toJson());
      generation++;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(session.characterState.resourceValues[fontOfMagicSlotId(2)], 1);
      await tap(tester, 'Short Rest');
      await tap(tester, 'Take Short Rest');
      expect(session.characterState.resourceValues[fontOfMagicSlotId(2)], 1);
      await tap(tester, 'Long Rest');
      await tap(tester, 'Take Long Rest');
      expect(
        session.characterState.resourceValues.containsKey(fontOfMagicSlotId(2)),
        isFalse,
      );
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 6);
      expect(session.characterState.resourceValues[spellSlotId(2)], 3);
      expect(tester.takeException(), isNull);
    },
  );
}
