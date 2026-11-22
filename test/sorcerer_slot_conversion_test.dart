import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';

const label = 'Font of Magic · Slot to points';
Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final scenario in [
    'explore',
    'combat',
    'pact',
    'cap',
    'cancel-picker',
    'cancel-confirm',
    'full',
    'stunned',
    'empty',
  ]) {
    testWidgets('Font of Magic slot conversion: $scenario', (tester) async {
      final combat = scenario != 'explore';
      final pact = scenario == 'pact';
      final current = scenario == 'full'
          ? 5
          : scenario == 'cap'
          ? 4
          : 1;
      final slots = scenario == 'empty' ? 0 : 2;
      final slotId = pact ? pactSlotId(3) : spellSlotId(2);
      var character = seedCharacters.first.copyWith(
        characterClass: 'Sorcerer',
        level: pact ? 10 : 5,
        additionalClassLevels: pact ? {'Warlock': 5} : {},
        resources: [
          CharacterResource(
            id: slotId,
            name: pact ? 'Pact Magic' : 'Spell Slots',
            maximum: 2,
            initialValue: slots,
            rechargePeriod: pact
                ? RechargePeriod.shortRest
                : RechargePeriod.longRest,
          ),
          if (pact)
            CharacterResource(
              id: spellSlotId(2),
              name: 'Ordinary Slots',
              maximum: 2,
              initialValue: 2,
              rechargePeriod: RechargePeriod.longRest,
            ),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character).copyWith(
          currentHp: 22,
          activeConditions: scenario == 'stunned' ? {'Stunned'} : {},
          resourceValues: {sorceryPointsResourceId: current},
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
          onCharacterChanged: (value) => character = value,
          onSessionChanged: (value) => session = value,
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final button = find.widgetWithText(OutlinedButton, label);
      final disabled = ['full', 'stunned', 'empty'].contains(scenario);
      if (disabled) {
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      } else {
        await tap(tester, label);
        if (scenario == 'cancel-picker') {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } else {
          await tap(
            tester,
            pact ? 'Level 3 Pact Magic · 2 remaining' : 'Level 2 · 2 remaining',
          );
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId],
            current,
          );
          expect(session.characterState.resourceValues[slotId] ?? slots, slots);
          if (scenario == 'cap') {
            expect(
              find.textContaining('excess points are lost'),
              findsOneWidget,
            );
          }
          await tap(
            tester,
            scenario == 'cancel-confirm'
                ? 'Cancel'
                : 'Spend slot · Recover points',
          );
        }
      }
      final converted = !disabled && !scenario.startsWith('cancel-');
      final expected = converted
          ? (current + (pact ? 3 : 2)).clamp(0, 5)
          : current;
      expect(
        session.characterState.resourceValues[sorceryPointsResourceId],
        expected,
      );
      expect(
        session.characterState.resourceValues[slotId] ?? slots,
        slots - (converted ? 1 : 0),
      );
      if (pact) {
        expect(session.characterState.resourceValues[spellSlotId(2)] ?? 2, 2);
      }
      expect(session.characterState.currentHp, 22);
      expect(
        session.usedCombatActions,
        combat ? CombatActionCost.values.toSet() : isEmpty,
      );
      if (converted) {
        expect(session.timeline.first.detail, contains('No action spent'));
      }
      session = CharacterSession.fromJson(session.toJson());
      generation++;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        session.characterState.resourceValues[sorceryPointsResourceId],
        expected,
      );
      expect(
        session.characterState.resourceValues[slotId] ?? slots,
        slots - (converted ? 1 : 0),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
