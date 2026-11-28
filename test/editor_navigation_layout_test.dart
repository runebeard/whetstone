import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/screens/character_editor.dart';
import 'cleric_channel_divinity_test.dart' as fixtures;

void main() {
  for (final (size, scale) in [
    (const Size(360, 640), 1.0),
    (const Size(320, 568), 1.6),
  ]) {
    testWidgets(
      'Editor navigation stays reachable at $size text scale $scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        var character = fixtures
            .cleric(3)
            .copyWith(currentHp: 13, divineOrder: DivineOrder.thaumaturge);
        final originalSpells = character.spells.length;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      final result = await Navigator.push<Character>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CharacterEditor(character: character),
                        ),
                      );
                      if (result != null) character = result;
                    },
                    child: const Text('Edit'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        for (var i = 0; i < 8; i++) {
          FocusManager.instance.primaryFocus?.unfocus();
          tester.testTextInput.hide();
          await tester.pumpAndSettle();
          if (i == 3) {
            await tester.tap(find.text('Back').hitTestable());
            await tester.pumpAndSettle();
            expect(tester.widget<Stepper>(find.byType(Stepper)).currentStep, 2);
            await tester.tap(
              find.byKey(const ValueKey('creator-continue-2')).hitTestable(),
            );
            await tester.pumpAndSettle();
          }
          final button = find
              .byKey(ValueKey('creator-continue-$i'))
              .hitTestable();
          expect(button, findsOneWidget);
          expect(tester.getRect(button).bottom, lessThanOrEqualTo(size.height));
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(
            tester.widget<Stepper>(find.byType(Stepper)).currentStep,
            i + 1,
          );
          expect(tester.takeException(), isNull);
        }
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        final save = find.byKey(const ValueKey('creator-save')).hitTestable();
        expect(save, findsOneWidget);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.byType(CharacterEditor), findsNothing);
        expect(character.currentHp, 13);
        expect(character.divineOrder, DivineOrder.thaumaturge);
        expect(character.spells.length, originalSpells);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
