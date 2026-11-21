import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  for (final (level, speed) in [
    (1, 0),
    (2, 10),
    (6, 15),
    (9, 15),
    (10, 20),
    (14, 25),
    (18, 30),
  ]) {
    testWidgets(
      'Monk defense level $level movement $speed preserves actions and saves AC',
      (tester) async {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: level,
          weapons: [],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(monk),
          inventory: [],
          archivedInventory: [],
          isInCombat: level.isEven,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: monk,
              initialSession: session,
              onSessionChanged: (v) => session = v,
              onCharacterChanged: (_) {},
            ),
          ),
        );
        final button = find.text('Monk · Unarmored defense and movement');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.textContaining('adds $speed feet'), findsOneWidget);
        if (level >= 9) {
          expect(find.textContaining('Acrobatic Movement'), findsOneWidget);
        }
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(session.characterState.armourClass, 15);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unarmored · Apply AC 13'));
        await tester.pumpAndSettle();
        expect(
          CharacterSession.fromJson(
            session.toJson(),
          ).characterState.armourClass,
          13,
        );
        expect(session.usedCombatActions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
