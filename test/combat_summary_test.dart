import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/widgets/combat_summary.dart';

void main() {
  testWidgets('edited max HP controls current HP and healing', (tester) async {
    final character = Character(
      name: 'Test Hero',
      characterClass: 'Fighter',
      level: 1,
      currentHp: 10,
      maxHp: 10,
      armourClass: 15,
      initiativeModifier: 2,
      status: 'Testing',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: CombatSummary(character: character),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('10 / 10'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('5 / 5'), findsOneWidget);

    await tester.tap(find.text('5 / 5'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10');
    await tester.tap(find.textContaining('Heal'));
    await tester.pumpAndSettle();

    expect(find.text('5 / 5'), findsOneWidget);

    await tester.longPress(find.text('5 / 5'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '20');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('5 / 20'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '30');
    await tester.tap(find.textContaining('Heal'));
    await tester.pumpAndSettle();

    expect(find.text('20 / 20'), findsOneWidget);
  });

  testWidgets('long press edits AC and signed initiative modifier', (
    tester,
  ) async {
    final character = Character(
      name: 'Test Hero',
      characterClass: 'Fighter',
      level: 1,
      currentHp: 10,
      maxHp: 10,
      armourClass: 15,
      initiativeModifier: 2,
      status: 'Testing',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: CombatSummary(character: character),
          ),
        ),
      ),
    );

    expect(find.text('+2'), findsOneWidget);

    await tester.longPress(find.text('15'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '18');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('18'), findsOneWidget);

    await tester.longPress(find.text('+2'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '-3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('-3'), findsOneWidget);
  });

  testWidgets('tap Initiative rolls again with an injected d20 roller', (
    tester,
  ) async {
    final rolls = [7, 19];
    final character = Character(
      name: 'Test Hero',
      characterClass: 'Fighter',
      level: 1,
      currentHp: 10,
      maxHp: 10,
      armourClass: 15,
      initiativeModifier: 2,
      status: 'Testing',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: CombatSummary(
              character: character,
              rollD20: () => rolls.removeAt(0),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('+2'));
    await tester.pumpAndSettle();

    expect(find.text('Initiative Roll'), findsOneWidget);
    expect(_textAtKey(tester, 'initiative-die-result'), '7');
    expect(_textAtKey(tester, 'initiative-roll-modifier'), '+2');
    expect(_textAtKey(tester, 'initiative-roll-total'), '9');

    await tester.tap(find.text('Roll Again'));
    await tester.pumpAndSettle();

    expect(_textAtKey(tester, 'initiative-die-result'), '19');
    expect(_textAtKey(tester, 'initiative-roll-total'), '21');

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Initiative Roll'), findsNothing);
  });

  testWidgets('tap Conditions adds and removes checkbox conditions', (
    tester,
  ) async {
    final character = Character(
      name: 'Test Hero',
      characterClass: 'Fighter',
      level: 1,
      currentHp: 10,
      maxHp: 10,
      armourClass: 15,
      initiativeModifier: 2,
      status: 'Testing',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: CombatSummary(character: character),
          ),
        ),
      ),
    );

    expect(find.text('None'), findsOneWidget);

    await tester.tap(find.text('Conditions'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Poisoned'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Poisoned'));
    await tester.tap(find.text('Prone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('• Poisoned'), findsOneWidget);
    expect(find.text('• Prone'), findsOneWidget);

    await tester.tap(find.text('Conditions'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Poisoned'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Poisoned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('• Poisoned'), findsNothing);
    expect(find.text('• Prone'), findsOneWidget);
  });
}

String? _textAtKey(WidgetTester tester, String key) {
  return tester.widget<Text>(find.byKey(ValueKey(key))).data;
}
