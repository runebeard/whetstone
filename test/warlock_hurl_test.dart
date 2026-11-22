import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

const activate = 'Hurl Through Hell · Confirm hit';
const restore = 'Hurl Through Hell · Restore use';

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final (level, subclass, stunned) in [
    (13, 'Fiend Patron', false),
    (14, 'Other', false),
    (14, 'Fiend Patron', true),
  ]) {
    testWidgets('Hurl eligibility Warlock $level $subclass stunned=$stunned', (
      tester,
    ) async {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Warlock',
        level: 14,
        additionalClassLevels: level == 13 ? {'Fighter': 1} : {},
        subclasses: {'Warlock': subclass},
      );
      final session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          character,
        ).copyWith(activeConditions: stunned ? {'Stunned'} : {}),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onSessionChanged: (_) {},
            onCharacterChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(OutlinedButton, activate);
      if (stunned) {
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      } else {
        expect(button, findsNothing);
        expect(find.text(restore), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'Hurl resource requires Fiend fourteen and only Long Rest recovers it',
    () {
      for (final (level, subclass, expected) in [
        (13, 'Fiend Patron', false),
        (14, 'Fiend Patron', true),
        (20, 'Other', false),
      ]) {
        final resources = BuiltInClass.warlock.classResources(
          level,
          charismaModifier: 3,
          subclass: subclass,
        );
        expect(
          resources.any((r) => r.id == hurlThroughHellResourceId),
          expected,
        );
      }
      final character = seedCharacters.first.copyWith(
        characterClass: 'Warlock',
        level: 14,
        subclasses: {'Warlock': 'Fiend Patron'},
        resources: BuiltInClass.warlock.classResources(
          14,
          charismaModifier: 3,
          subclass: 'Fiend Patron',
        ),
      );
      for (final rest in RestType.values) {
        final result = RestPlan.forCharacter(
          character: character,
          currentState: CharacterState.fromCharacter(
            character,
          ).copyWith(resourceValues: {hurlThroughHellResourceId: 0}),
          type: rest,
        ).updatedState;
        expect(
          result.resourceValues[hurlThroughHellResourceId],
          rest == RestType.longRest ? 1 : 0,
        );
      }
      expect(
        CharacterSession.fromJson(
          CharacterSession.fromCharacter(character).toJson(),
        ).hurlThroughHellUsedThisTurn,
        isFalse,
      );
    },
  );
  for (final outcome in [
    'Cancel',
    'Target saved',
    'Failed · Fiend target',
    'Failed · Roll Psychic damage',
  ]) {
    testWidgets(
      'Hurl $outcome preserves actions and restores without clearing turn limit',
      (tester) async {
        var character = seedCharacters.first.copyWith(
          characterClass: 'Warlock',
          level: 14,
          proficiencyBonus: 5,
          subclasses: {'Warlock': 'Fiend Patron'},
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.charisma: 16,
          },
          resources: [
            CharacterResource(
              id: pactSlotId(5),
              name: 'Pact Magic',
              maximum: 3,
              initialValue: 2,
              rechargePeriod: RechargePeriod.shortRest,
            ),
            CharacterResource(
              id: spellSlotId(5),
              name: 'Spell Slots',
              maximum: 3,
              initialValue: 3,
              rechargePeriod: RechargePeriod.longRest,
            ),
          ],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(currentHp: 22),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: CombatActionCost.values.toSet(),
          attackRollMadeThisTurn: true,
        );
        final dice = SequenceDiceRoller(List.filled(8, 5));
        var generation = 0;
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (value) => character = value,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          character.resources.any((r) => r.id == hurlThroughHellResourceId),
          isTrue,
        );
        await tap(tester, activate);
        expect(find.textContaining('DC 16 Charisma'), findsOneWidget);
        await tap(tester, outcome);
        final cancelled = outcome == 'Cancel';
        expect(
          session.characterState.resourceValues[hurlThroughHellResourceId] ?? 1,
          cancelled ? 1 : 0,
        );
        expect(session.hurlThroughHellUsedThisTurn, !cancelled);
        expect(session.usedCombatActions, CombatActionCost.values.toSet());
        expect(session.characterState.currentHp, 22);
        expect(session.characterState.activeConditions, isEmpty);
        expect(dice.index, outcome == 'Failed · Roll Psychic damage' ? 8 : 0);
        if (outcome == 'Failed · Roll Psychic damage') {
          expect(session.timeline.first.title, 'Hurl Through Hell Damage: 40');
          expect(
            session.timeline.first.detail,
            contains('no critical doubling'),
          );
        }
        if (outcome == 'Failed · Fiend target') {
          expect(
            session.timeline.first.detail,
            contains('Fiend target: no Psychic damage'),
          );
        }
        if (!cancelled) {
          await tap(tester, restore);
          await tap(tester, 'Cancel');
          expect(session.characterState.resourceValues[pactSlotId(5)] ?? 2, 2);
          await tap(tester, restore);
          await tap(tester, 'Spend Pact slot · Restore use');
          expect(
            session.characterState.resourceValues[hurlThroughHellResourceId],
            1,
          );
          expect(session.characterState.resourceValues[pactSlotId(5)], 1);
          expect(session.characterState.resourceValues[spellSlotId(5)] ?? 3, 3);
          expect(session.hurlThroughHellUsedThisTurn, isTrue);
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, activate),
                )
                .onPressed,
            isNull,
          );
          session = CharacterSession.fromJson(session.toJson());
          generation++;
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, activate),
                )
                .onPressed,
            isNull,
          );
          await tap(tester, 'Next Turn');
          expect(session.hurlThroughHellUsedThisTurn, isFalse);
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, activate),
                )
                .onPressed,
            isNotNull,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final (combat, pactUses) in [(false, 1), (true, 0)]) {
    testWidgets(
      'Hurl restoration combat=$combat Pact uses=$pactUses excludes ordinary slots',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Warlock',
          level: 14,
          subclasses: {'Warlock': 'Fiend Patron'},
          resources: [
            CharacterResource(
              id: pactSlotId(5),
              name: 'Pact Magic',
              maximum: 3,
              initialValue: pactUses,
              rechargePeriod: RechargePeriod.shortRest,
            ),
            CharacterResource(
              id: spellSlotId(5),
              name: 'Spell Slots',
              maximum: 3,
              initialValue: 3,
              rechargePeriod: RechargePeriod.longRest,
            ),
          ],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(resourceValues: {hurlThroughHellResourceId: 0}),
          inventory: [],
          archivedInventory: [],
          isInCombat: combat,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, restore),
        );
        if (pactUses == 0) {
          expect(button.onPressed, isNull);
        } else {
          await tap(tester, restore);
          await tap(tester, 'Spend Pact slot · Restore use');
          expect(
            session.characterState.resourceValues[hurlThroughHellResourceId],
            1,
          );
          expect(session.characterState.resourceValues[pactSlotId(5)], 0);
          expect(session.isInCombat, isFalse);
        }
        expect(session.characterState.resourceValues[spellSlotId(5)] ?? 3, 3);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
