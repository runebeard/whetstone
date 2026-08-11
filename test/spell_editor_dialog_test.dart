import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/widgets/spell_editor_dialog.dart';

void main() {
  testWidgets('leveled spells must be prepared before they can be pinned', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SpellEditorDialog())),
    );

    SwitchListTile pinnedTile() => tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('spell-pinned')),
    );
    SwitchListTile preparedTile() => tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('spell-prepared')),
    );

    expect(preparedTile().onChanged, isNull);
    expect(pinnedTile().onChanged, isNotNull);

    await tester.tap(find.byKey(const ValueKey('spell-level')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 1').last);
    await tester.pumpAndSettle();

    expect(preparedTile().onChanged, isNotNull);
    expect(pinnedTile().onChanged, isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('spell-prepared')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spell-prepared')));
    await tester.pump();
    expect(pinnedTile().onChanged, isNotNull);

    await tester.ensureVisible(find.byKey(const ValueKey('spell-pinned')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spell-pinned')));
    await tester.pump();
    expect(pinnedTile().value, isTrue);

    await tester.ensureVisible(find.byKey(const ValueKey('spell-prepared')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spell-prepared')));
    await tester.pump();
    expect(pinnedTile().value, isFalse);
    expect(pinnedTile().onChanged, isNull);
  });
}
