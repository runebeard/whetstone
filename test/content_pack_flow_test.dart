import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/starter_content_pack.dart';
import 'package:whetstone/main.dart';
import 'package:whetstone/models/content_pack.dart';
import 'package:whetstone/models/feature.dart';
import 'package:whetstone/persistence/character_definition_repository.dart';
import 'package:whetstone/persistence/character_session_repository.dart';
import 'package:whetstone/persistence/content_pack_repository.dart';
import 'package:whetstone/persistence/portable_content_pack_document.dart';

void main() {
  testWidgets('installs, imports, removes, and persists content packs', (
    tester,
  ) async {
    final packRepository = InMemoryContentPackRepository();
    final customPack = ContentPack(
      id: 'community-adventures',
      name: 'Community Adventures',
      gameSystem: 'System Agnostic',
      version: '2.1.0',
      author: 'Table Friends',
      description: 'Shared homebrew features for adventurous groups.',
      features: const [
        Feature(
          id: 'lucky-break',
          name: 'Lucky Break',
          summary: 'Once per session • Turn trouble into opportunity',
        ),
      ],
    );
    final customPackage = PortableContentPackDocument(
      pack: customPack,
    ).encode();

    await tester.pumpWidget(
      WhetstoneApp(contentPackRepository: packRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('content-library')));
    await tester.pumpAndSettle();

    expect(find.text('Content Library'), findsOneWidget);
    expect(find.text('No packs installed'), findsOneWidget);
    expect(find.text(starterContentPack.name), findsOneWidget);
    expect(find.text('Training Sword'), findsNothing);
    await tester.tap(
      find.byKey(
        const ValueKey('install-content-pack-whetstone-generic-d20-starter'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Installed Packs'), findsOneWidget);
    expect(find.text('Available Packs'), findsNothing);
    await tester.tap(find.text(starterContentPack.name));
    await tester.pumpAndSettle();
    expect(find.text('Training Sword'), findsOneWidget);
    expect(find.text('Ember Bolt'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('import-content-pack')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('import-content-pack-text')),
      customPackage,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-content-pack')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('content-pack-preview-name')),
      findsOneWidget,
    );
    expect(find.text('System Agnostic • v2.1.0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-content-pack-import')));
    await tester.pumpAndSettle();
    expect(find.text('Community Adventures'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      WhetstoneApp(contentPackRepository: packRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('content-library')));
    await tester.pumpAndSettle();
    expect(find.text(starterContentPack.name), findsOneWidget);
    expect(find.text('Community Adventures'), findsOneWidget);

    await tester.tap(find.text('Community Adventures'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('remove-content-pack-community-adventures')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('remove-content-pack-community-adventures')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-content-pack-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Community Adventures'), findsNothing);
    expect(find.text(starterContentPack.name), findsOneWidget);
  });

  testWidgets('shows Library and Transfer actions at narrow phone width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('content-library')), findsOneWidget);
    expect(find.byKey(const ValueKey('transfer-characters')), findsOneWidget);
  });

  testWidgets('shows the pack install action beside its title on a phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      WhetstoneApp(contentPackRepository: InMemoryContentPackRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('content-library')));
    await tester.pumpAndSettle();

    final install = find.byKey(
      const ValueKey('install-content-pack-whetstone-generic-d20-starter'),
    );
    expect(install.hitTestable(), findsOneWidget);
    expect(find.text('Training Sword'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(install);
    await tester.pumpAndSettle();
    expect(find.text('Available Packs'), findsNothing);
    expect(find.text(starterContentPack.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'creates editable character-owned copies from every library entry type',
    (tester) async {
      final sessions = InMemoryCharacterSessionRepository();
      final definitions = InMemoryCharacterDefinitionRepository();
      final packs = InMemoryContentPackRepository();
      await packs.savePacks({starterContentPack.id: starterContentPack});

      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessions,
          definitionRepository: definitions,
          contentPackRepository: packs,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Create Character'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('character-class')),
        'Adventurer',
      );
      await tester.tap(find.byKey(const ValueKey('creator-continue-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creator-continue-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('creator-continue-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creator-continue-2')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('library-weapon')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Training Sword'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Training Sword'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('weapon-name')),
        "Hero's Sword",
      );
      await tester.tap(find.byKey(const ValueKey('save-weapon')));
      await tester.pumpAndSettle();
      expect(find.text("Hero's Sword"), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('creator-continue-3')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creator-continue-3')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('library-spell')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ember Bolt'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('creator-continue-4')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creator-continue-4')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('library-resource')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Heroic Effort'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('creator-continue-5')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creator-continue-5')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('library-inventory-item')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Healing Draught'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('creator-continue-6')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creator-continue-6')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('library-feature')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rally'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('creator-continue-7')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creator-continue-7')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('character-name')),
        'Library Hero',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('creator-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creator-save')));
      await tester.pumpAndSettle();

      final created = (await definitions.loadCatalog()).characters.values
          .singleWhere((character) => character.name == 'Library Hero');
      expect(created.weapons.single.name, "Hero's Sword");
      expect(created.spells.single.name, 'Ember Bolt');
      expect(created.resources.single.name, 'Heroic Effort');
      expect(created.initialInventory.single.name, 'Healing Draught');
      expect(created.features.single.name, 'Rally');

      await packs.savePacks({});
      final afterPackRemoval = (await definitions.loadCatalog())
          .characters
          .values
          .singleWhere((character) => character.name == 'Library Hero');
      expect(afterPackRemoval.weapons.single.name, "Hero's Sword");
      expect(afterPackRemoval.spells.single.name, 'Ember Bolt');
      expect(afterPackRemoval.resources.single.name, 'Heroic Effort');
      expect(afterPackRemoval.initialInventory.single.name, 'Healing Draught');
      expect(afterPackRemoval.features.single.name, 'Rally');
    },
  );

  testWidgets('adds persistent Library items and spells during normal play', (
    tester,
  ) async {
    final sessions = InMemoryCharacterSessionRepository();
    final definitions = InMemoryCharacterDefinitionRepository();
    final packs = InMemoryContentPackRepository();
    await packs.savePacks({starterContentPack.id: starterContentPack});

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessions,
          definitionRepository: definitions,
          contentPackRepository: packs,
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    final inventoryLibrary = find.byKey(
      const ValueKey('inventory-library-item'),
    );
    await tester.scrollUntilVisible(
      inventoryLibrary,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inventory-create-item')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('inventory-restock-item')),
      findsOneWidget,
    );
    await tester.tap(inventoryLibrary);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Healing Draught'));
    await tester.pumpAndSettle();
    expect(find.text('Healing Draught'), findsOneWidget);

    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('spellbook-create-spell')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('spellbook-library-spell')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ember Bolt'));
    await tester.pumpAndSettle();
    expect(find.text('Ember Bolt'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    expect(find.text('Ember Bolt'), findsOneWidget);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Healing Draught'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Healing Draught'), findsOneWidget);
  });
}
