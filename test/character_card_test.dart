import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/widgets/character_card.dart';

void main() {
  testWidgets('shows live activity, stats, conditions, and warnings', (
    tester,
  ) async {
    var tapped = false;
    final character = Character(
      name: 'Kael',
      characterClass: 'Fighter',
      level: 4,
      currentHp: 20,
      maxHp: 20,
      armourClass: 15,
      initiativeModifier: -1,
      status: 'Exploring',
      resources: const [
        CharacterResource(
          id: 'resource',
          name: 'Resource',
          maximum: 2,
          initialValue: 2,
          rechargePeriod: RechargePeriod.shortRest,
        ),
      ],
    );
    const session = CharacterSession(
      characterState: CharacterState(
        currentHp: 4,
        maxHp: 20,
        temporaryHp: 3,
        armourClass: 17,
        initiativeModifier: -1,
        deathSaveSuccesses: 0,
        deathSaveFailures: 0,
        activeConditions: {'Poisoned'},
        pinnedActionKeys: {},
        resourceValues: {'resource': 0},
      ),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CharacterCard(
            character: character,
            session: session,
            onTap: () => tapped = true,
            onLongPress: () {},
          ),
        ),
      ),
    );

    expect(find.text('In Combat'), findsOneWidget);
    expect(find.text('HP 4 / 20'), findsOneWidget);
    expect(find.text('AC 17'), findsOneWidget);
    expect(find.text('Init -1'), findsOneWidget);
    expect(find.text('3 temporary HP'), findsOneWidget);
    expect(find.text('Poisoned'), findsOneWidget);
    expect(find.text('1 depleted resource'), findsOneWidget);

    await tester.tap(find.byType(CharacterCard));
    expect(tapped, isTrue);
  });
}
