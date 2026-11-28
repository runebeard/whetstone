import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'cleric_channel_divinity_test.dart' as cleric;
import 'draconic_spell_grants_test.dart' as helpers;
import 'support/sequence_dice_roller.dart';

Future<void> enter(WidgetTester tester, String key, String value) async {
  await tester.enterText(find.byKey(ValueKey(key)), value);
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

bool enabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Use Preserve Life'),
        )
        .onPressed !=
    null;

void main() {
  for (final mixed in [false, true]) {
    testWidgets(
      'Preserve Life mixed=$mixed validates shared budget and keeps cancellation free',
      (tester) async {
        final character = cleric
            .cleric(mixed ? 20 : 3)
            .copyWith(
              additionalClassLevels: mixed ? {'Fighter': 17} : {},
              subclasses: {'Cleric': 'Life Domain'},
              resources: BuiltInClass.cleric.classResources(
                3,
                charismaModifier: 0,
              ),
            );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(currentHp: 7, maxHp: 41),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              diceRoller: SequenceDiceRoller([]),
              onCharacterChanged: (_) {},
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> begin() async {
          await cleric.openPool(tester, 2);
          await helpers.tap(tester, find.text('Preserve Life'));
        }

        await begin();
        expect(find.textContaining('Share up to 15 HP'), findsOneWidget);
        expect(enabled(tester), isFalse);
        await enter(tester, 'preserve-life-self', '14');
        expect(enabled(tester), isFalse);
        await enter(tester, 'preserve-life-self', '-1');
        expect(enabled(tester), isFalse);
        await enter(tester, 'preserve-life-self', '8');
        await enter(tester, 'preserve-life-others', '8');
        expect(enabled(tester), isFalse);
        await helpers.tap(tester, find.byType(CheckboxListTile));
        expect(enabled(tester), isFalse);
        await enter(tester, 'preserve-life-others', '7');
        expect(enabled(tester), isTrue);
        await helpers.tap(tester, find.text('Cancel'));
        expect(session.characterState.currentHp, 7);
        expect(session.usedCombatActions, isEmpty);
        expect(
          session.characterState.resourceValues[clericChannelDivinityId] ?? 2,
          2,
        );
        await begin();
        await enter(tester, 'preserve-life-self', '8');
        await enter(tester, 'preserve-life-others', '7');
        expect(enabled(tester), isFalse);
        await helpers.tap(tester, find.byType(CheckboxListTile));
        await helpers.tap(tester, find.text('Use Preserve Life'));
        expect(session.characterState.currentHp, 15);
        expect(
          session.characterState.resourceValues[clericChannelDivinityId],
          1,
        );
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(session.timeline.first.title, 'Preserve Life · 15 HP');
        expect(session.timeline.first.detail, contains('apply 7 HP'));
        final restored = CharacterSession.fromJson(session.toJson());
        expect(restored.characterState.currentHp, 15);
        expect(
          restored.characterState.resourceValues[clericChannelDivinityId],
          1,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (maxHp, hp, allocation) in [
    (40, 10, 10),
    (41, 20, 0),
    (41, 21, 0),
    (41, 1, 15),
  ]) {
    testWidgets('Preserve Life caps self healing at half $hp/$maxHp', (
      tester,
    ) async {
      final character = cleric
          .cleric(3)
          .copyWith(subclasses: {'Cleric': 'Life Domain'});
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          character,
        ).copyWith(currentHp: hp, maxHp: maxHp),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await cleric.openPool(tester, 2);
      await helpers.tap(tester, find.text('Preserve Life'));
      await enter(tester, 'preserve-life-self', '${allocation + 1}');
      expect(enabled(tester), isFalse);
      await enter(tester, 'preserve-life-self', '$allocation');
      if (allocation == 0) {
        await enter(tester, 'preserve-life-others', '5');
        await helpers.tap(tester, find.byType(CheckboxListTile));
      }
      await helpers.tap(tester, find.text('Use Preserve Life'));
      expect(session.characterState.currentHp, hp + allocation);
      expect(session.characterState.resourceValues[clericChannelDivinityId], 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (level, subclass, offered) in [
    (2, 'Life Domain', false),
    (3, 'Other Domain', false),
    (3, 'Life Domain', true),
  ]) {
    testWidgets('Preserve Life eligibility $level/$subclass', (tester) async {
      final character = cleric
          .cleric(level)
          .copyWith(subclasses: {'Cleric': subclass});
      final session = CharacterSession(
        characterState: CharacterState.fromCharacter(character),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await cleric.openPool(tester, 2);
      expect(
        find.text('Preserve Life'),
        offered ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
