import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  for (final existing in [0, 20]) {
    testWidgets(
      'Heightened Patient Defense retains larger temporary HP pool $existing',
      (tester) async {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: 11,
          weapons: [],
          resources: BuiltInClass.monk.classResources(11, charismaModifier: 0),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            monk,
          ).copyWith(temporaryHp: existing),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([6, 7]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: monk,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
              diceRoller: dice,
            ),
          ),
        );
        final button = find.widgetWithText(
          OutlinedButton,
          'Monk’s Focus · Movement and defense',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Patient Defense · Disengage + Dodge (1 Focus)'),
        );
        await tester.pumpAndSettle();
        expect(
          session.characterState.temporaryHp,
          existing > 13 ? existing : 13,
        );
        expect(session.characterState.resourceValues[focusResourceId], 10);
        expect(
          session.timeline.first.detail,
          contains('6 + 7 = 13 Temporary HP'),
        );
        expect(dice.index, 2);
      },
    );
  }
}
