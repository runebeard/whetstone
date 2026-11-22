import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  test(
    'Magical Cunning begins at Warlock two and refreshes only on Long Rest',
    () {
      expect(
        BuiltInClass.warlock
            .classResources(1, charismaModifier: 0)
            .where((r) => r.id == magicalCunningResourceId),
        isEmpty,
      );
      final character = seedCharacters.first.copyWith(
        characterClass: 'Warlock',
        level: 2,
        resources: BuiltInClass.warlock.classResources(2, charismaModifier: 0),
      );
      for (final rest in RestType.values) {
        final result = RestPlan.forCharacter(
          character: character,
          currentState: CharacterState.fromCharacter(
            character,
          ).copyWith(resourceValues: {magicalCunningResourceId: 0}),
          type: rest,
        ).updatedState;
        expect(
          result.resourceValues[magicalCunningResourceId],
          rest == RestType.longRest ? 1 : 0,
        );
      }
    },
  );
  for (final (level, wizard, initial, expected) in [
    (2, 0, 0, 1),
    (11, 0, 0, 2),
    (11, 0, 2, 3),
    (20, 0, 0, 4),
    (3, 2, 0, 1),
    (19, 1, 0, 2),
  ]) {
    testWidgets(
      'Cunning Warlock $level Wizard $wizard recovers $initial to $expected without other slots',
      (tester) async {
        final total = level + wizard;
        final slots = spellSlotsForClassLevels(
          'Warlock',
          total,
          wizard == 0 ? {} : {'Wizard': wizard},
        );
        final pact = wizard == 0
            ? slots.single
            : slots.singleWhere((r) => r.id.startsWith('whetstone:pact-slot:'));
        final ordinary = CharacterResource(
          id: spellSlotId(wizard == 0 ? 9 : spellSlotLevel(pact)!),
          name: 'Ordinary Spell Slots',
          maximum: 3,
          initialValue: 0,
          rechargePeriod: RechargePeriod.shortRest,
        );
        var character = seedCharacters.first.copyWith(
          characterClass: 'Warlock',
          level: total,
          additionalClassLevels: wizard == 0 ? {} : {'Wizard': wizard},
          resources: [
            pact,
            ordinary,
            wildResurgenceSlot,
            natureMagicianSlots.first,
          ],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 22,
            resourceValues: {
              pact.id: initial,
              ordinary.id: 0,
              wildResurgenceSlot.id: 0,
              natureMagicianSlots.first.id: 0,
              magicalCunningResourceId: 1,
            },
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: false,
        );
        var generation = 0;
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onCharacterChanged: (v) => character = v,
            onSessionChanged: (v) => session = v,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          character.resources
              .where((r) => r.id == magicalCunningResourceId)
              .length,
          1,
        );
        final label = level >= 20
            ? 'Eldritch Master · Magical Cunning'
            : 'Magical Cunning · Pact slots';
        final button = find.widgetWithText(OutlinedButton, label);
        Future<void> open() async {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
        }

        await open();
        expect(find.textContaining('1-minute'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.characterState.resourceValues[pact.id], initial);
        expect(
          session.characterState.resourceValues[magicalCunningResourceId],
          1,
        );
        await open();
        await tester.tap(find.text('Rite complete · Recover Pact slots'));
        await tester.pumpAndSettle();
        expect(session.characterState.resourceValues[pact.id], expected);
        expect(
          session.characterState.resourceValues[magicalCunningResourceId],
          0,
        );
        for (final id in [
          ordinary.id,
          wildResurgenceSlot.id,
          natureMagicianSlots.first.id,
        ]) {
          expect(session.characterState.resourceValues[id], 0);
        }
        expect(session.characterState.currentHp, 22);
        expect(session.usedCombatActions, isEmpty);
        expect(
          session.timeline.first.title,
          level >= 20 ? 'Eldritch Master' : 'Magical Cunning',
        );
        character = Character.fromJson(character.toJson());
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        expect(
          character.resources
              .where((r) => r.id == magicalCunningResourceId)
              .length,
          1,
        );
        expect(
          session.characterState.resourceValues[magicalCunningResourceId],
          0,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Cunning rejects absent/full Pact pools, spent use, incapacitation and Warlock one',
    (tester) async {
      for (final (level, poolPresent, full, use, incap) in [
        (1, true, false, 1, false),
        (2, false, false, 1, false),
        (2, true, true, 1, false),
        (2, true, false, 0, false),
        (2, true, false, 1, true),
      ]) {
        final pact = spellSlotsForClass('Warlock', level).single;
        final character = seedCharacters.first.copyWith(
          characterClass: 'Warlock',
          level: level,
          resources: poolPresent ? [pact] : [],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey('$level-$poolPresent-$full-$use-$incap'),
              character: character,
              initialSession: CharacterSession(
                characterState: CharacterState.fromCharacter(character)
                    .copyWith(
                      resourceValues: {
                        pact.id: full ? pact.maximum : 0,
                        magicalCunningResourceId: use,
                      },
                      activeConditions: incap ? {'Incapacitated'} : {},
                    ),
                inventory: [],
                archivedInventory: [],
                isInCombat: false,
              ),
              onCharacterChanged: (_) {},
              onSessionChanged: (_) {},
            ),
          ),
        );
        final button = find.widgetWithText(
          OutlinedButton,
          'Magical Cunning · Pact slots',
        );
        if (level < 2) {
          expect(button, findsNothing);
        } else {
          expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        }
      }
    },
  );
}
