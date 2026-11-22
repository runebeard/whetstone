import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/hp_box.dart';

void main() {
  final fiend = seedCharacters.first.copyWith(
    characterClass: 'Warlock',
    level: 10,
    subclasses: {'Warlock': 'Fiend Patron'},
  );
  test(
    'Fiendish Resilience covers each allowed type once and remains passive',
    () {
      final allowed = IncomingDamageType.values.where(
        (t) => t != IncomingDamageType.force && t != IncomingDamageType.other,
      );
      for (final selected in allowed) {
        final state = CharacterState.fromCharacter(fiend).copyWith(
          fiendishResistance: selected,
          currentHp: 0,
          activeConditions: {'Incapacitated'},
        );
        for (final incoming in IncomingDamageType.values) {
          expect(
            state.damageAfterResistance(15, incoming),
            incoming == selected ? 7 : 15,
          );
        }
        expect(
          state.damageAfterResistance(
            15,
            selected,
            additionalResistance: selected,
          ),
          7,
        );
        expect(
          state
              .copyWith(
                activeConditions: {ragingCondition, superiorDefenseCondition},
                currentHp: 22,
              )
              .damageAfterResistance(15, selected),
          7,
        );
      }
    },
  );
  test(
    'Either rest refreshes the choice while preserving the current resistance',
    () {
      final spent = CharacterState.fromCharacter(fiend).copyWith(
        fiendishResistance: IncomingDamageType.fire,
        fiendishResilienceAvailable: false,
      );
      for (final rest in RestType.values) {
        final state = RestPlan.forCharacter(
          character: fiend,
          currentState: spent,
          type: rest,
        ).updatedState;
        expect(state.fiendishResilienceAvailable, true);
        expect(state.fiendishResistance, IncomingDamageType.fire);
        final lower = RestPlan.forCharacter(
          character: fiend.copyWith(level: 9),
          currentState: spent,
          type: rest,
        ).updatedState;
        expect(lower.fiendishResistance, isNull);
        expect(lower.fiendishResilienceAvailable, false);
      }
      expect(
        CharacterState.fromCharacter(fiend).fiendishResilienceAvailable,
        true,
      );
      expect(
        CharacterState.fromCharacter(
          fiend.copyWith(subclasses: {'Warlock': 'Other'}),
        ).fiendishResilienceAvailable,
        false,
      );
    },
  );
  test('Legacy, future and disallowed resistance fields decode safely', () {
    final legacy = CharacterState.fromCharacter(seedCharacters.first).toJson();
    expect(CharacterState.fromJson(legacy).fiendishResilienceAvailable, false);
    for (final value in ['force', 'other', 'future-type']) {
      expect(
        CharacterState.fromJson({
          ...legacy,
          'fiendishResistance': value,
        }).fiendishResistance,
        isNull,
      );
    }
    final saved = CharacterState.fromCharacter(fiend).copyWith(
      fiendishResistance: IncomingDamageType.cold,
      fiendishResilienceAvailable: false,
    );
    final restored = CharacterState.fromJson(saved.toJson());
    expect(restored.fiendishResistance, IncomingDamageType.cold);
    expect(restored.fiendishResilienceAvailable, false);
  });
  testWidgets(
    'Resilience choice saves, applies typed damage and refreshes after an actual rest',
    (tester) async {
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(fiend).copyWith(
          currentHp: 42,
          resourceValues: {magicalCunningResourceId: 0},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: false,
      );
      var generation = 0;
      Widget app() => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(generation),
          character: fiend,
          initialSession: session,
          onCharacterChanged: (_) {},
          onSessionChanged: (v) => session = v,
        ),
      );
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(app());
      final button = find.widgetWithText(
        OutlinedButton,
        'Fiendish Resilience · After Rest',
      );
      await tap(button);
      expect(find.widgetWithText(SimpleDialogOption, 'Force'), findsNothing);
      expect(
        find.widgetWithText(SimpleDialogOption, 'Other or unspecified'),
        findsNothing,
      );
      await tap(find.text('Cancel'));
      expect(session.characterState.fiendishResilienceAvailable, true);
      await tap(button);
      await tap(find.widgetWithText(SimpleDialogOption, 'Fire'));
      expect(
        session.characterState.fiendishResistance,
        IncomingDamageType.fire,
      );
      expect(session.characterState.fiendishResilienceAvailable, false);
      expect(session.usedCombatActions, isEmpty);
      expect(session.characterState.currentHp, 42);
      session = CharacterSession.fromJson(session.toJson());
      generation++;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      for (final type in ['Fire', 'Force']) {
        await tap(find.byType(HpBox));
        await tester.enterText(find.byType(TextField), '15');
        await tap(find.byType(DropdownButtonFormField<IncomingDamageType>));
        await tap(find.text(type).last);
        await tap(find.text('🗡 Damage'));
      }
      expect(session.characterState.currentHp, 20);
      await tap(find.text('Short Rest'));
      await tap(find.text('Take Short Rest'));
      expect(session.characterState.fiendishResilienceAvailable, true);
      expect(
        session.characterState.fiendishResistance,
        IncomingDamageType.fire,
      );
      await tap(button);
      await tap(find.widgetWithText(SimpleDialogOption, 'Cold'));
      expect(
        session.characterState.fiendishResistance,
        IncomingDamageType.cold,
      );
      expect(session.characterState.fiendishResilienceAvailable, false);
      expect(
        session.characterState.resourceValues[magicalCunningResourceId],
        0,
      );
      expect(session.characterState.currentHp, 20);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Reload removes resistance after losing the qualifying class or subclass',
    (tester) async {
      for (final character in [
        fiend.copyWith(level: 9),
        fiend.copyWith(subclasses: {'Warlock': 'Other'}),
      ]) {
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            fiend,
          ).copyWith(fiendishResistance: IncomingDamageType.fire),
          inventory: [],
          archivedInventory: [],
          isInCombat: false,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey('${character.subclasses}-${character.level}'),
              character: character,
              initialSession: session,
              onCharacterChanged: (_) {},
              onSessionChanged: (v) => session = v,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(session.characterState.fiendishResistance, isNull);
        expect(session.characterState.fiendishResilienceAvailable, false);
        expect(find.text('Fiendish Resilience · After Rest'), findsNothing);
      }
    },
  );
}
