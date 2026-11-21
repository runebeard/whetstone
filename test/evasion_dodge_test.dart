import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/hp_box.dart';

import 'support/sequence_dice_roller.dart';

void main() {
  for (final (name, result, expectedHp) in [
    ('Rogue', 'failure', 27),
    ('Rogue', 'success', 34),
    ('Monk', 'failure', 27),
  ]) {
    testWidgets(
      '$name Evasion $result reduces damage before temp HP and concentration',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: name,
          level: 7,
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(temporaryHp: 5, concentrationSpellId: 'detect_magic'),
          inventory: [],
          archivedInventory: [],
          isInCombat: result != 'success',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
              diceRoller: SequenceDiceRoller([8]),
            ),
          ),
        );
        await tester.tap(find.byType(HpBox));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '24');
        await tester.tap(find.text('🗡 Damage'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .text(
                result == 'success'
                    ? 'Success · half-damage save'
                    : 'Failure · half-damage save',
              )
              .last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply damage'));
        await tester.pumpAndSettle();
        if (result == 'failure') {
          expect(
            find.text('Detect Magic · DC 10 after 12 damage'),
            findsOneWidget,
          );
          await tester.tap(find.text('Roll Save'));
          await tester.pumpAndSettle();
        } else {
          expect(find.text('Roll Save'), findsNothing);
        }
        expect(session.characterState.currentHp, expectedHp);
        expect(session.characterState.temporaryHp, result == 'success' ? 5 : 0);
        expect(session.characterState.concentrationSpellId, 'detect_magic');
        expect(session.usedCombatActions, isEmpty);
      },
    );
  }

  testWidgets(
    'Uncanny Dodge spends one Reaction and applies resistance afterward',
    (tester) async {
      final rogue = seedCharacters.first.copyWith(
        characterClass: 'Rogue',
        level: 5,
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          rogue,
        ).copyWith(activeConditions: {ragingCondition}),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      Widget app() => MaterialApp(
        home: CharacterOverview(
          character: rogue,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
        ),
      );
      await tester.pumpWidget(app());
      Future<void> damage() async {
        await tester.tap(find.byType(HpBox));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '13');
        await tester.tap(
          find.byType(DropdownButtonFormField<IncomingDamageType>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Slashing').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('🗡 Damage'));
        await tester.pumpAndSettle();
      }

      await damage();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Uncanny Dodge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply damage'));
      await tester.pumpAndSettle();
      expect(session.characterState.currentHp, 31);
      expect(session.usedCombatActions, {CombatActionCost.reaction});
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await damage();
      expect(find.text('Damage reduction'), findsNothing);
      expect(session.characterState.currentHp, 25);
    },
  );

  testWidgets('cancelled damage reduction preserves HP and Reaction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rogue = seedCharacters.first.copyWith(
      characterClass: 'Rogue',
      level: 7,
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(rogue),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: rogue,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byType(HpBox));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '24');
    await tester.tap(find.text('🗡 Damage'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Uncanny Dodge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(session.characterState.currentHp, 34);
    expect(session.usedCombatActions, isEmpty);
  });

  testWidgets('incapacitation suppresses Evasion and Uncanny Dodge', (
    tester,
  ) async {
    final rogue = seedCharacters.first.copyWith(
      characterClass: 'Rogue',
      level: 7,
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        rogue,
      ).copyWith(activeConditions: {'Stunned'}),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: rogue,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HpBox));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '24');
    await tester.tap(find.text('🗡 Damage'));
    await tester.pumpAndSettle();
    expect(find.text('Damage reduction'), findsNothing);
    expect(session.characterState.currentHp, 10);
  });
}
