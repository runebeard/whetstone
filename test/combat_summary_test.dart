import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/widgets/combat_summary.dart';
import 'package:whetstone/widgets/conditions_dialog.dart';
import 'package:whetstone/widgets/initiative_roll_dialog.dart';

void main() {
  testWidgets('initiative modes choose the higher or lower d20', (
    tester,
  ) async {
    final rolls = [10, 4, 17, 3, 15].iterator;
    await tester.pumpWidget(
      MaterialApp(
        home: InitiativeRollDialog(
          initiativeModifier: 2,
          rollD20: () {
            rolls.moveNext();
            return rolls.current;
          },
        ),
      ),
    );

    final total = find.byKey(const ValueKey('initiative-roll-total'));
    expect(tester.widget<Text>(total).data, '12');
    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advantage').last);
    await tester.pumpAndSettle();
    expect(find.text('Rolled 4 and 17'), findsOneWidget);
    expect(tester.widget<Text>(total).data, '19');
    await tester.tap(find.text('Advantage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disadvantage').last);
    await tester.pumpAndSettle();
    expect(find.text('Rolled 3 and 15'), findsOneWidget);
    expect(tester.widget<Text>(total).data, '5');
  });

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
            child: _CombatSummaryHarness(character: character),
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
            child: _CombatSummaryHarness(character: character),
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
            child: _CombatSummaryHarness(
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
            child: _CombatSummaryHarness(character: character),
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
      scrollable: _conditionsList(),
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
      scrollable: _conditionsList(),
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

Finder _conditionsList() {
  return find
      .descendant(
        of: find.byType(ConditionsDialog),
        matching: find.byType(Scrollable),
      )
      .last;
}

class _CombatSummaryHarness extends StatefulWidget {
  final Character character;
  final int Function()? rollD20;

  const _CombatSummaryHarness({required this.character, this.rollD20});

  @override
  State<_CombatSummaryHarness> createState() => _CombatSummaryHarnessState();
}

class _CombatSummaryHarnessState extends State<_CombatSummaryHarness> {
  late CharacterState characterState;

  @override
  void initState() {
    super.initState();
    characterState = CharacterState.fromCharacter(widget.character);
  }

  @override
  Widget build(BuildContext context) {
    return CombatSummary(
      characterState: characterState,
      onChanged: (updatedState) {
        setState(() {
          characterState = updatedState;
        });
      },
      rollD20: widget.rollD20,
    );
  }
}
