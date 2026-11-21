import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  testWidgets(
    'Flurry exhausts two save-based strikes without spending the Attack action',
    (tester) async {
      final monk = seedCharacters.first.copyWith(
        characterClass: 'Monk',
        level: 2,
        weapons: [],
        resources: BuiltInClass.monk.classResources(2, charismaModifier: 0),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          monk,
        ).copyWith(resourceValues: {focusResourceId: 0}),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        flurryAttacksRemaining: 2,
        usedCombatActions: {CombatActionCost.bonusAction},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: monk,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        ),
      );
      for (final count in [2, 1]) {
        final strike = find.text('Flurry of Blows · $count strikes remaining');
        await tester.ensureVisible(strike);
        await tester.tap(strike);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Basic strike'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Grapple'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Resolve later'));
        await tester.pumpAndSettle();
        expect(session.flurryAttacksRemaining, count - 1);
        expect(session.characterState.resourceValues[focusResourceId], 0);
        expect(session.usedCombatActions, {CombatActionCost.bonusAction});
        expect(session.attackActionAttacksRemaining, 0);
        expect(find.text('Open Hand Technique'), findsNothing);
      }
      final start = find.widgetWithText(
        OutlinedButton,
        'Flurry of Blows (1 Focus)',
      );
      expect(tester.widget<OutlinedButton>(start).onPressed, isNull);
      expect(
        CharacterSession.fromJson(session.toJson()).flurryAttacksRemaining,
        0,
      );
    },
  );
  testWidgets(
    'Empty Focus disables starting Flurry but preserves free Monk movement',
    (tester) async {
      final monk = seedCharacters.first.copyWith(
        characterClass: 'Monk',
        level: 2,
        weapons: [],
        resources: BuiltInClass.monk.classResources(2, charismaModifier: 0),
      );
      final session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          monk,
        ).copyWith(resourceValues: {focusResourceId: 0}),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: monk,
            initialSession: session,
            onSessionChanged: (_) {},
            onCharacterChanged: (_) {},
          ),
        ),
      );
      final start = find.widgetWithText(
        OutlinedButton,
        'Flurry of Blows (1 Focus)',
      );
      await tester.ensureVisible(start);
      expect(tester.widget<OutlinedButton>(start).onPressed, isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(
                OutlinedButton,
                'Monk’s Focus · Movement and defense',
              ),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets('Incapacitation clears restored Flurry strikes', (tester) async {
    final monk = seedCharacters.first.copyWith(
      characterClass: 'Monk',
      level: 10,
      weapons: [],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        monk,
      ).copyWith(activeConditions: {'Incapacitated'}),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
      flurryAttacksRemaining: 3,
      usedCombatActions: {CombatActionCost.bonusAction},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: monk,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(session.flurryAttacksRemaining, 0);
    expect(session.usedCombatActions, {CombatActionCost.bonusAction});
  });
}
