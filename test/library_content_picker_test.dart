import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/starter_content_pack.dart';
import 'package:whetstone/widgets/library_content_picker.dart';

void main() {
  testWidgets('searches installed packs and returns the selected entry', (
    tester,
  ) async {
    LibraryContentSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                selection = await Navigator.push<LibraryContentSelection>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LibraryContentPicker(
                      type: LibraryContentType.spell,
                      packs: [starterContentPack],
                    ),
                  ),
                );
              },
              child: const Text('Choose'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(find.text('Add Spell from Library'), findsOneWidget);
    expect(find.text('Ember Bolt'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('search-library-spell')),
      'whetstone d20',
    );
    await tester.pumpAndSettle();
    expect(find.text('Ember Bolt'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-entry-whetstone-generic-d20-starter:spell:ember_bolt',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(selection?.entryKey, contains('spell:ember_bolt'));
    expect(selection?.content, same(starterContentPack.spells.single));
  });

  testWidgets('explains when no content packs are installed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LibraryContentPicker(type: LibraryContentType.feature, packs: []),
      ),
    );

    expect(
      find.text(
        'No content packs are installed. Add packs from the Vault Library first.',
      ),
      findsOneWidget,
    );
  });
}
