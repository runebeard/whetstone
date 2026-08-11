import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/main.dart';
import 'package:whetstone/persistence/character_definition_repository.dart';
import 'package:whetstone/persistence/character_session_repository.dart';
import 'package:whetstone/widgets/skill_tile.dart';

import 'support/sequence_dice_roller.dart';

void main() {
  testWidgets('records, restores, and clears the Session Timeline', (
    tester,
  ) async {
    final sessions = InMemoryCharacterSessionRepository();
    final definitions = InMemoryCharacterDefinitionRepository();
    final diceRoller = SequenceDiceRoller([15]);

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessions,
          definitionRepository: definitions,
          diceRoller: diceRoller,
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('34 / 42'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.textContaining('Damage'));
    await tester.pumpAndSettle();

    final perception = find.widgetWithText(SkillTile, 'Perception');
    await tester.ensureVisible(perception);
    await tester.pumpAndSettle();
    await tester.tap(perception);
    await tester.pumpAndSettle();

    final combatButton = find.widgetWithText(FilledButton, 'Combat');
    await tester.ensureVisible(combatButton);
    await tester.pumpAndSettle();
    await tester.tap(combatButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();

    final recorded = (await sessions.loadSessions())['eldrin']!.timeline;
    expect(recorded.map((event) => event.title), [
      'Combat ended',
      'Combat began',
      'Perception: 19',
      'Took 5 damage',
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-session-timeline')));
    await tester.pumpAndSettle();

    expect(find.text('Session Timeline'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Combat ended'), findsOneWidget);
    expect(find.text('Perception: 19'), findsOneWidget);
    expect(find.text('Took 5 damage'), findsOneWidget);
    expect(find.text('34 -> 29 HP'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clear-session-timeline')));
    await tester.pumpAndSettle();
    expect(find.text('Clear Session Timeline?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirm-clear-session-timeline')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Session Timeline'), findsNothing);
    expect((await sessions.loadSessions())['eldrin']!.timeline, isEmpty);
  });
}
