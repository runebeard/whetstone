import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/main.dart';
import 'package:whetstone/content/starter_content_pack.dart';
import 'package:whetstone/modes/combat_mode.dart';
import 'package:whetstone/modes/exploration_mode.dart';
import 'package:whetstone/modes/profile_mode.dart';
import 'package:whetstone/modes/spellbook_mode.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/inventory_item.dart';
import 'package:whetstone/models/journal_entry.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/persistence/character_session_repository.dart';
import 'package:whetstone/persistence/character_definition_repository.dart';
import 'package:whetstone/persistence/content_pack_repository.dart';
import 'package:whetstone/persistence/portable_character_document.dart';
import 'package:whetstone/widgets/character_card.dart';
import 'package:whetstone/widgets/inventory_item_card.dart';
import 'package:whetstone/widgets/skill_tile.dart';

import 'support/sequence_dice_roller.dart';

class LegacyCharacterDefinitionRepository
    implements CharacterDefinitionRepository {
  CharacterDefinitionCatalog catalog;

  LegacyCharacterDefinitionRepository(this.catalog);

  @override
  Future<CharacterDefinitionCatalog> loadCatalog() async => catalog;

  @override
  Future<void> saveCatalog(CharacterDefinitionCatalog catalog) async {
    this.catalog = catalog;
  }
}

void main() {
  testWidgets('opens a character from the vault in exploration mode', (
    tester,
  ) async {
    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();

    expect(find.text('Whetstone α'), findsOneWidget);
    expect(find.text('Eldrin'), findsOneWidget);

    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    expect(find.text('Level 6 Wizard'), findsOneWidget);
    expect(find.text('Combat'), findsOneWidget);
    expect(find.text('Spellbook'), findsOneWidget);
    expect(find.byType(ExplorationModeView), findsOneWidget);

    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();

    expect(find.byType(SpellbookModeView), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileModeView), findsOneWidget);
    expect(find.text('Features & Traits'), findsOneWidget);
    expect(find.text('No features or actions added yet'), findsOneWidget);
    expect(find.text('Features & Traits').hitTestable(), findsOneWidget);
    expect(find.text('Ability Scores'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    expect(find.byType(ExplorationModeView), findsOneWidget);
  });

  testWidgets(
    'imports, exports, duplicates, and persists portable characters',
    (tester) async {
      final sessionRepository = InMemoryCharacterSessionRepository();
      final definitionRepository = InMemoryCharacterDefinitionRepository();
      final character = Character(
        id: 'portable-aria',
        name: 'Aria',
        characterClass: 'Bard',
        level: 4,
        currentHp: 24,
        maxHp: 31,
        armourClass: 14,
        initiativeModifier: 2,
        status: 'Exploring',
        journalEntries: [
          JournalEntry(
            id: 'silver-song',
            title: 'Recover the Silver Song',
            notes: 'Search beneath the theatre.',
          ),
        ],
      );
      const session = CharacterSession(
        characterState: CharacterState(
          currentHp: 19,
          maxHp: 31,
          temporaryHp: 2,
          armourClass: 14,
          initiativeModifier: 2,
          deathSaveSuccesses: 0,
          deathSaveFailures: 0,
          activeConditions: {},
          pinnedActionKeys: {},
          resourceValues: {},
        ),
        inventory: [
          InventoryItem(
            name: 'Silver Flute',
            quantity: 1,
            weightPerItem: 1,
            category: ItemCategory.equipment,
          ),
        ],
        archivedInventory: [],
        isInCombat: false,
      );
      final package = PortableCharacterDocument(
        character: character,
        session: session,
      ).encode();

      Future<void> importPackage() async {
        await tester.tap(find.byKey(const ValueKey('transfer-characters')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('transfer-import-character')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('import-package-text')),
          package,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('review-character-package')),
        );
        await tester.tap(
          find.byKey(const ValueKey('review-character-package')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('import-preview-name')),
          findsOneWidget,
        );
        expect(find.text('19 / 31'), findsOneWidget);
        expect(find.text('1 entries'), findsNWidgets(2));
        await tester.tap(
          find.byKey(const ValueKey('confirm-character-import')),
        );
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessionRepository,
          definitionRepository: definitionRepository,
        ),
      );
      await tester.pumpAndSettle();
      await importPackage();
      await tester.ensureVisible(find.text('Aria'));
      await tester.pumpAndSettle();
      expect(find.text('Aria'), findsOneWidget);
      expect(find.text('HP 19 / 31'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('transfer-characters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('transfer-export-character')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('export-character-portable-aria')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('export-character-portable-aria')),
      );
      await tester.pumpAndSettle();
      final exported = tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('export-package-text')),
          )
          .data!;
      final restored = PortableCharacterDocument.decode(exported);
      expect(
        restored.character.journalEntries.single.title,
        'Recover the Silver Song',
      );
      expect(restored.session.inventory.single.name, 'Silver Flute');
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      await importPackage();
      await tester.scrollUntilVisible(find.text('Aria Copy'), 250);
      await tester.pumpAndSettle();
      expect(find.text('Aria Copy'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessionRepository,
          definitionRepository: definitionRepository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Aria Copy'), 250);
      await tester.pumpAndSettle();
      expect(find.text('Aria'), findsOneWidget);
      expect(find.text('Aria Copy'), findsOneWidget);
    },
  );

  testWidgets('rejects invalid character packages before import', (
    tester,
  ) async {
    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer-characters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer-import-character')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('import-package-text')),
      '{"not":"a character"}',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('review-character-package')),
    );
    await tester.tap(find.byKey(const ValueKey('review-character-package')));
    await tester.pumpAndSettle();

    expect(
      find.text('This is not a valid Whetstone character package.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('confirm-character-import')),
      findsNothing,
    );
  });

  testWidgets('manages a persistent quest journal from Explore', (
    tester,
  ) async {
    final definitionRepository = InMemoryCharacterDefinitionRepository();
    await tester.pumpWidget(
      WhetstoneApp(definitionRepository: definitionRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    final addQuest = find.byKey(const ValueKey('add-journal-entry'));
    await tester.ensureVisible(addQuest);
    await tester.pumpAndSettle();
    expect(find.text('No active quests'), findsOneWidget);

    await tester.tap(addQuest);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journal-title')),
      'Find the Moon Key',
    );
    await tester.enterText(
      find.byKey(const ValueKey('journal-notes')),
      'Ask the ferryman about the ruined observatory.',
    );
    await tester.tap(find.byKey(const ValueKey('save-journal-entry')));
    await tester.pumpAndSettle();

    expect(find.text('Active Quests'), findsOneWidget);
    await tester.tap(find.text('Find the Moon Key'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Ask the ferryman about the ruined observatory.'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Find the Moon Key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as Complete'));
    await tester.pumpAndSettle();
    expect(find.text('No active quests'), findsOneWidget);
    expect(find.text('Completed (1)'), findsOneWidget);

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Find the Moon Key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as Active'));
    await tester.pumpAndSettle();
    expect(find.text('Active Quests'), findsOneWidget);

    await tester.longPress(find.text('Find the Moon Key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Quest'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journal-title')),
      'Recover the Moon Key',
    );
    await tester.tap(find.byKey(const ValueKey('save-journal-entry')));
    await tester.pumpAndSettle();
    expect(find.text('Recover the Moon Key'), findsOneWidget);

    await tester.tap(addQuest);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journal-title')),
      'Mistaken Quest',
    );
    await tester.tap(find.byKey(const ValueKey('save-journal-entry')));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Mistaken Quest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Quest'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-remove-journal-entry')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mistaken Quest'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      WhetstoneApp(definitionRepository: definitionRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('add-journal-entry')));
    await tester.pumpAndSettle();
    expect(find.text('Recover the Moon Key'), findsOneWidget);
    expect(find.text('Mistaken Quest'), findsNothing);
  });

  testWidgets('rolls skills, saves, weapons, and configured spell attacks', (
    tester,
  ) async {
    final diceRoller = SequenceDiceRoller([20, 1, 12, 15, 10]);
    await tester.pumpWidget(WhetstoneApp(diceRoller: diceRoller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    final perception = find.widgetWithText(SkillTile, 'Perception');
    await tester.ensureVisible(perception);
    await tester.pumpAndSettle();
    await tester.tap(perception);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('latest-roll-notice')), findsOneWidget);
    expect(find.text('Natural 20'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '24',
    );

    await tester.tap(perception);
    await tester.pumpAndSettle();
    expect(find.text('Natural 1'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '5',
    );
    expect(find.byKey(const ValueKey('roll-notice-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('roll-notice-1')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('roll-notice-1'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('roll-notice-0'))).dy,
      ),
    );

    final combatButton = find.widgetWithText(FilledButton, 'Combat');
    await tester.ensureVisible(combatButton);
    await tester.pumpAndSettle();
    await tester.tap(combatButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Quarterstaff'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('attack-attacks-weapon:quarterstaff')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '14',
    );

    await tester.tap(
      find.byKey(const ValueKey('attack-attacks-spell:fire_bolt')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '22',
    );

    final intelligenceSave = find.byTooltip('Intelligence saving throw');
    await tester.ensureVisible(intelligenceSave);
    await tester.pumpAndSettle();
    await tester.tap(intelligenceSave);
    await tester.pumpAndSettle();
    expect(find.text('Intelligence Save'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '17',
    );

    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mage Hand'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('30 ft spectral hand'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('roll notices fade away after five seconds', (tester) async {
    await tester.pumpWidget(WhetstoneApp(diceRoller: SequenceDiceRoller([12])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    final perception = find.widgetWithText(SkillTile, 'Perception');
    await tester.ensureVisible(perception);
    await tester.tap(perception);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('latest-roll-notice')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3600));
    expect(find.byKey(const ValueKey('latest-roll-notice')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.byKey(const ValueKey('latest-roll-notice')), findsNothing);
  });

  testWidgets('rolls attacks and damage directly from combat cards', (
    tester,
  ) async {
    final diceRoller = SequenceDiceRoller([4, 6, 14, 7, 9, 3]);
    await tester.pumpWidget(WhetstoneApp(diceRoller: diceRoller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final quarterstaffDamage = find.byKey(
      const ValueKey('damage-attacks-weapon:quarterstaff'),
    );
    await tester.ensureVisible(quarterstaffDamage);
    await tester.pumpAndSettle();
    await tester.tap(quarterstaffDamage);
    await tester.pumpAndSettle();
    expect(find.text('Quarterstaff Damage'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '3',
    );
    expect(find.textContaining('bludgeoning damage'), findsOneWidget);

    await tester.tap(quarterstaffDamage);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '5',
    );

    await tester.tap(
      find.byKey(const ValueKey('attack-attacks-weapon:quarterstaff')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '16',
    );
    expect(
      find.byKey(const ValueKey('roll-damage-after-attack')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('damage-attacks-spell:fire_bolt')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fire Bolt Damage'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '16',
    );

    expect(
      find.byKey(const ValueKey('attack-attacks-spell:magic_missile')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('damage-attacks-spell:magic_missile')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Magic Missile Damage'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '4',
    );
    expect(find.textContaining('force per dart damage'), findsOneWidget);
  });

  testWidgets('upgrades Fire Bolt rolls for an existing saved Eldrin', (
    tester,
  ) async {
    final legacyEldrin = Character(
      id: 'eldrin',
      name: 'Eldrin',
      characterClass: 'Wizard',
      level: 6,
      currentHp: 34,
      maxHp: 42,
      armourClass: 15,
      initiativeModifier: 2,
      status: 'Exploring',
      spells: const [
        Spell(
          id: 'fire_bolt',
          name: 'Fire Bolt',
          level: 0,
          prepared: false,
          summary: '+7 to hit • 2d10 fire • 120 ft',
        ),
      ],
      initiallyPinnedActionKeys: const {'spell:fire_bolt'},
    );
    final definitionRepository = LegacyCharacterDefinitionRepository(
      CharacterDefinitionCatalog(
        characters: {'eldrin': legacyEldrin},
        schemaVersion: 1,
      ),
    );
    await tester.pumpWidget(
      WhetstoneApp(
        repository: InMemoryCharacterSessionRepository(),
        definitionRepository: definitionRepository,
        diceRoller: SequenceDiceRoller([10]),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      definitionRepository.catalog.schemaVersion,
      CharacterDefinitionCatalog.currentSchemaVersion,
    );
    expect(
      definitionRepository
          .catalog
          .characters['eldrin']!
          .spells
          .single
          .rollModifier,
      7,
    );
    expect(
      definitionRepository
          .catalog
          .characters['eldrin']!
          .spells
          .single
          .damageFormula,
      '2d10',
    );

    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('attack-attacks-spell:fire_bolt')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '17',
    );
  });

  testWidgets('adds features and edits ability scores from Profile', (
    tester,
  ) async {
    final sessionRepository = InMemoryCharacterSessionRepository();
    final definitionRepository = InMemoryCharacterDefinitionRepository();

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessionRepository,
          definitionRepository: definitionRepository,
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-profile-feature')));
    await tester.pumpAndSettle();
    expect(find.text('Add Feature'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('feature-name')),
      'Ritual Casting',
    );
    await tester.enterText(
      find.byKey(const ValueKey('feature-summary')),
      'Cast ritual spells without preparing them',
    );
    await tester.tap(find.byKey(const ValueKey('save-feature')));
    await tester.pumpAndSettle();
    expect(find.text('Ritual Casting'), findsOneWidget);

    await tester.longPress(find.text('Ritual Casting'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Feature'), findsOneWidget);
    expect(find.text('Pin to Combat'), findsOneWidget);
    expect(find.text('Remove Feature'), findsOneWidget);
    await tester.tap(find.text('Edit Feature'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feature-name')),
      'Improved Ritual Casting',
    );
    await tester.tap(find.byKey(const ValueKey('save-feature')));
    await tester.pumpAndSettle();
    expect(find.text('Improved Ritual Casting'), findsOneWidget);

    await tester.longPress(find.text('Improved Ritual Casting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin to Combat'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Improved Ritual Casting'));
    await tester.pumpAndSettle();
    expect(find.text('Unpin from Combat'), findsOneWidget);
    await tester.tap(find.text('Remove Feature'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Feature?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirm-remove-profile-feature')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Improved Ritual Casting'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-profile-feature')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feature-name')),
      'Ritual Casting',
    );
    await tester.enterText(
      find.byKey(const ValueKey('feature-summary')),
      'Cast ritual spells without preparing them',
    );
    await tester.tap(find.byKey(const ValueKey('save-feature')));
    await tester.pumpAndSettle();

    final strengthTile = find.byKey(const ValueKey('profile-ability-strength'));
    await tester.ensureVisible(strengthTile);
    await tester.pumpAndSettle();
    await tester.longPress(strengthTile);
    await tester.pumpAndSettle();
    expect(find.text('Edit Strength'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('profile-ability-score')),
      '10',
    );
    await tester.tap(find.byKey(const ValueKey('save-profile-ability')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: strengthTile, matching: find.text('10')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strengthTile, matching: find.text('0')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Ritual Casting'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-ability-strength')),
        matching: find.text('10'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('advances a character from Profile while preserving live state', (
    tester,
  ) async {
    final sessionRepository = InMemoryCharacterSessionRepository();
    final definitionRepository = InMemoryCharacterDefinitionRepository();
    final contentPackRepository = InMemoryContentPackRepository();
    await contentPackRepository.savePacks({
      starterContentPack.id: starterContentPack,
    });

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessionRepository,
          definitionRepository: definitionRepository,
          contentPackRepository: contentPackRepository,
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

    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    final arcaneRecovery = find.text('Arcane Recovery');
    await tester.ensureVisible(arcaneRecovery);
    await tester.pumpAndSettle();
    await tester.tap(arcaneRecovery);
    await tester.pumpAndSettle();
    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('advance-character')));
    await tester.pumpAndSettle();
    expect(find.text('Advance Character'), findsOneWidget);
    expect(find.text('Spells'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('advancement-level')),
      '7',
    );
    await tester.enterText(
      find.byKey(const ValueKey('advancement-proficiency')),
      '4',
    );
    await tester.enterText(
      find.byKey(const ValueKey('advancement-max-hp')),
      '50',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();

    final addSpell = find.byKey(const ValueKey('advancement-add-spell'));
    await tester.ensureVisible(addSpell);
    await tester.pumpAndSettle();
    await tester.tap(addSpell);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-name')),
      'Chromatic Spark',
    );
    await tester.enterText(
      find.byKey(const ValueKey('spell-summary')),
      'Action • 60 ft • Elemental damage',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('spell-pinned')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spell-pinned')));
    await tester.tap(find.byKey(const ValueKey('save-spell')));
    await tester.pumpAndSettle();
    expect(find.text('Chromatic Spark'), findsOneWidget);

    final addResource = find.byKey(const ValueKey('advancement-add-resource'));
    await tester.scrollUntilVisible(
      addResource,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(addResource);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('resource-name')),
      'Arcane Surge',
    );
    await tester.enterText(find.byKey(const ValueKey('resource-maximum')), '2');
    await tester.tap(find.byKey(const ValueKey('save-resource')));
    await tester.pumpAndSettle();
    expect(find.text('Arcane Surge'), findsOneWidget);

    final libraryFeature = find.byKey(
      const ValueKey('advancement-library-feature'),
    );
    await tester.scrollUntilVisible(
      libraryFeature,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(libraryFeature);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rally'));
    await tester.pumpAndSettle();
    expect(find.text('Rally'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save-advancement')));
    await tester.pumpAndSettle();
    expect(find.text('Level 7 Wizard'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('advance-character')),
        matching: find.textContaining('Proficiency +4'),
      ),
      findsOneWidget,
    );
    expect(find.text('Rally'), findsOneWidget);

    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    expect(find.text('Chromatic Spark'), findsOneWidget);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('29 / 50'), findsOneWidget);
    final combatButton = find.widgetWithText(FilledButton, 'Combat');
    await tester.ensureVisible(combatButton);
    await tester.pumpAndSettle();
    await tester.tap(combatButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Arcane Recovery'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('resource-arcane_recovery-0')),
      findsOneWidget,
    );
    expect(find.text('Arcane Surge'), findsOneWidget);
    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    expect(find.text('Level 7 Wizard'), findsOneWidget);
    expect(find.text('29 / 50'), findsOneWidget);
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    expect(find.text('Chromatic Spark'), findsOneWidget);
  });

  testWidgets('keeps live character state when combat begins and ends', (
    tester,
  ) async {
    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('34 / 42'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.textContaining('Damage'));
    await tester.pumpAndSettle();

    expect(find.text('29 / 42'), findsOneWidget);

    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('29 / 42'), findsOneWidget);
    expect(find.byType(CombatModeView), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Saving Throws'), findsOneWidget);
    expect(find.text('+7'), findsOneWidget);

    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();

    expect(find.text('29 / 42'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('pinned Spellbook actions appear in Combat attacks', (
    tester,
  ) async {
    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Mage Hand'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin to Combat'));
    await tester.pumpAndSettle();

    expect(find.text('Mage Hand pinned to Combat'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('Attacks'), findsOneWidget);
    expect(find.text('Mage Hand'), findsOneWidget);
    expect(find.text('Prepared Spells'), findsOneWidget);
    expect(find.text('Magic Missile'), findsNWidgets(2));
  });

  testWidgets('edits and safely removes spells from the Spellbook', (
    tester,
  ) async {
    final sessions = InMemoryCharacterSessionRepository();
    final definitions = InMemoryCharacterDefinitionRepository();

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(repository: sessions, definitionRepository: definitions),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Fire Bolt'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Spell'), findsOneWidget);
    expect(find.text('Unpin from Combat'), findsOneWidget);
    expect(find.text('Remove Spell'), findsOneWidget);
    await tester.tap(find.text('Edit Spell'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-name')),
      'Flame Lance',
    );
    await tester.tap(find.byKey(const ValueKey('save-spell')));
    await tester.pumpAndSettle();
    expect(find.text('Flame Lance'), findsOneWidget);
    expect(find.text('Fire Bolt'), findsNothing);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('Flame Lance'), findsOneWidget);
    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Flame Lance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Spell'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Spell?'), findsOneWidget);
    expect(
      find.text('Remove Flame Lance from this character?'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-remove-spellbook-spell')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Flame Lance'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    expect(find.text('Flame Lance'), findsNothing);
    expect(find.text('Fire Bolt'), findsNothing);
  });

  testWidgets('requires confirmation before exiting a character', (
    tester,
  ) async {
    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Exit Character?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(find.text('Level 6 Wizard'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Exit Character'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit Character'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    expect(find.text('Whetstone α'), findsOneWidget);
    expect(find.text('Eldrin'), findsOneWidget);
  });

  testWidgets('resource changes remain when combat is reopened', (
    tester,
  ) async {
    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('resource-level_1_slots-3')),
      findsOneWidget,
    );

    await tester.longPress(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();

    expect(find.text('3 / 4'), findsOneWidget);
    expect(find.text('Spend One'), findsOneWidget);
    expect(find.text('Restore One'), findsOneWidget);
    expect(find.text('Refill'), findsOneWidget);

    await tester.tap(find.text('Restore One'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('resource-level_1_slots-4')),
      findsOneWidget,
    );

    await tester.longPress(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spend One'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('resource-level_1_slots-3')),
      findsOneWidget,
    );

    for (var spend = 0; spend < 3; spend++) {
      await tester.tap(find.text('1st-Level Slots'));
      await tester.pumpAndSettle();
    }
    expect(
      find.byKey(const ValueKey('resource-level_1_slots-0')),
      findsOneWidget,
    );

    await tester.tap(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();
    expect(find.text('No 1st-Level Slots remaining'), findsOneWidget);

    await tester.longPress(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();
    expect(find.text('Spend One'), findsOneWidget);
    expect(find.text('Restore One'), findsOneWidget);
    expect(find.text('Refill'), findsOneWidget);

    await tester.tap(find.text('Spend One'));
    await tester.pump();
    expect(find.text('3 / 4'), findsNothing);
    expect(find.text('0 / 4'), findsOneWidget);
  });

  testWidgets('restores character changes after the app is rebuilt', (
    tester,
  ) async {
    final repository = InMemoryCharacterSessionRepository();

    await tester.pumpWidget(WhetstoneApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('34 / 42'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.textContaining('Damage'));
    await tester.pumpAndSettle();

    expect(find.text('29 / 42'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(WhetstoneApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    expect(find.text('29 / 42'), findsOneWidget);
  });

  testWidgets('long rest restores health and saves the recovery', (
    tester,
  ) async {
    final repository = InMemoryCharacterSessionRepository();

    await tester.pumpWidget(WhetstoneApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('34 / 42'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.textContaining('Damage'));
    await tester.pumpAndSettle();
    expect(find.text('29 / 42'), findsOneWidget);

    await tester.ensureVisible(find.text('Long Rest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Long Rest'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hit points: 29 → 42'), findsOneWidget);
    expect(find.text('Conditions will not be removed.'), findsOneWidget);

    await tester.tap(find.text('Take Long Rest'));
    await tester.pumpAndSettle();
    expect(find.text('42 / 42'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(WhetstoneApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    expect(find.text('42 / 42'), findsOneWidget);
  });

  testWidgets('vault reflects and resumes a character in combat', (
    tester,
  ) async {
    final repository = InMemoryCharacterSessionRepository();

    await tester.pumpWidget(WhetstoneApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    expect(find.text('In Combat'), findsOneWidget);
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    expect(find.byType(CombatModeView), findsOneWidget);
    expect(find.text('End Combat'), findsOneWidget);
  });

  testWidgets('creates, persists, and edits a character with naming last', (
    tester,
  ) async {
    final sessions = InMemoryCharacterSessionRepository();
    final definitions = InMemoryCharacterDefinitionRepository();

    await tester.pumpWidget(
      WhetstoneApp(repository: sessions, definitionRepository: definitions),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create Character'));
    await tester.pumpAndSettle();

    expect(find.text('Class & Essentials'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('character-class')),
      'Paladin',
    );
    expect(find.byKey(const ValueKey('current-hp')), findsNothing);
    expect(find.byKey(const ValueKey('initiative-modifier')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('maximum-hp')), '27');
    await tester.tap(find.byKey(const ValueKey('creator-continue-0')));
    await tester.pumpAndSettle();

    expect(find.text('Ability Scores'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('ability-dexterity')),
      '14',
    );
    await tester.tap(find.byKey(const ValueKey('creator-continue-1')));
    await tester.pumpAndSettle();

    expect(find.text('Proficiencies'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-2')));
    await tester.pumpAndSettle();

    expect(find.text('Weapons'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('add-weapon')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('weapon-name')),
      'Longsword',
    );
    await tester.enterText(
      find.byKey(const ValueKey('weapon-attack-modifier')),
      '4',
    );
    await tester.enterText(
      find.byKey(const ValueKey('weapon-damage')),
      '1d8 + 2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('weapon-damage-type')),
      'slashing',
    );
    await tester.enterText(find.byKey(const ValueKey('weapon-range')), 'Melee');
    await tester.tap(find.byKey(const ValueKey('save-weapon')));
    await tester.pumpAndSettle();
    expect(find.text('Longsword'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-weapon')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('weapon-name')), 'Dagger');
    await tester.enterText(find.byKey(const ValueKey('weapon-damage')), '1d4');
    await tester.enterText(
      find.byKey(const ValueKey('weapon-damage-type')),
      'piercing',
    );
    await tester.tap(find.byKey(const ValueKey('save-weapon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Dagger'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Weapon?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Dagger'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-3')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-3')));
    await tester.pumpAndSettle();

    expect(find.text('Spells'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('add-spell')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-name')),
      'Sacred Flame',
    );
    await tester.enterText(
      find.byKey(const ValueKey('spell-summary')),
      '60 ft • 1d8 radiant',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('spell-pinned')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spell-pinned')));
    await tester.tap(find.byKey(const ValueKey('save-spell')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-spell')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('spell-name')), 'Shield');
    await tester.tap(find.byKey(const ValueKey('spell-level')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 1').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-summary')),
      'Reaction • +5 AC',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('spell-prepared')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spell-prepared')));
    await tester.tap(find.byKey(const ValueKey('save-spell')));
    await tester.pumpAndSettle();
    expect(find.text('Sacred Flame'), findsOneWidget);
    expect(find.text('Shield'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-spell')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-name')),
      'Guidance',
    );
    await tester.enterText(
      find.byKey(const ValueKey('spell-summary')),
      'Touch • Add 1d4 to a check',
    );
    await tester.tap(find.byKey(const ValueKey('save-spell')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Guidance'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Spell?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Guidance'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-4')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-4')));
    await tester.pumpAndSettle();

    expect(find.text('Resources'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('add-resource')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('resource-name')),
      'Channel Divinity',
    );
    await tester.enterText(find.byKey(const ValueKey('resource-maximum')), '2');
    await tester.tap(find.byKey(const ValueKey('resource-recharge')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Short rest').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-resource')));
    await tester.pumpAndSettle();
    expect(find.text('Channel Divinity'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-resource')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('resource-name')),
      'Temporary Resource',
    );
    await tester.tap(find.byKey(const ValueKey('save-resource')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Temporary Resource'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Resource?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Temporary Resource'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-5')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-5')));
    await tester.pumpAndSettle();

    expect(find.text('Starting Inventory'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('add-inventory-item')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('inventory-name')),
      'Potion of Healing',
    );
    await tester.tap(find.byKey(const ValueKey('inventory-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consumable').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('inventory-quantity')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('inventory-weight')),
      '0.5',
    );
    await tester.tap(find.byKey(const ValueKey('save-inventory-item')));
    await tester.pumpAndSettle();
    expect(find.text('Potion of Healing'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-inventory-item')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('inventory-name')),
      'Temporary Item',
    );
    await tester.tap(find.byKey(const ValueKey('save-inventory-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Temporary Item'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Item?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Temporary Item'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-6')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-6')));
    await tester.pumpAndSettle();

    expect(find.text('Features & Actions'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('add-feature')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feature-name')),
      'Second Wind',
    );
    await tester.enterText(
      find.byKey(const ValueKey('feature-summary')),
      'Bonus action • Recover 1d10 + level HP',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('feature-pinned')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feature-pinned')));
    await tester.tap(find.byKey(const ValueKey('save-feature')));
    await tester.pumpAndSettle();
    expect(find.text('Second Wind'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-feature')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feature-name')),
      'Temporary Feature',
    );
    await tester.enterText(
      find.byKey(const ValueKey('feature-summary')),
      'Remove this before creation',
    );
    await tester.tap(find.byKey(const ValueKey('save-feature')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Temporary Feature'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Feature?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Temporary Feature'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-7')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-7')));
    await tester.pumpAndSettle();

    expect(find.text('Name & Review'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('character-name')),
      'Aurelia',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('creator-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-save')));
    await tester.pumpAndSettle();

    expect(find.text('Aurelia'), findsOneWidget);
    expect(find.text('Level 1 Paladin'), findsOneWidget);
    final aureliaCard = find.ancestor(
      of: find.text('Aurelia'),
      matching: find.byType(CharacterCard),
    );
    expect(
      find.descendant(of: aureliaCard, matching: find.text('HP 27 / 27')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: aureliaCard, matching: find.text('Init +2')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      WhetstoneApp(repository: sessions, definitionRepository: definitions),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aurelia'), findsOneWidget);

    await tester.longPress(find.text('Aurelia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Character'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('character-class')),
      'Champion',
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
    expect(find.text('Longsword'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit Longsword'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('weapon-name')),
      'Silvered Longsword',
    );
    await tester.tap(find.byKey(const ValueKey('save-weapon')));
    await tester.pumpAndSettle();
    expect(find.text('Silvered Longsword'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-3')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-3')));
    await tester.pumpAndSettle();
    expect(find.text('Sacred Flame'), findsOneWidget);
    expect(find.text('Shield'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit Sacred Flame'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-name')),
      'Radiant Flame',
    );
    await tester.tap(find.byKey(const ValueKey('save-spell')));
    await tester.pumpAndSettle();
    expect(find.text('Radiant Flame'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-4')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-4')));
    await tester.pumpAndSettle();
    expect(find.text('Channel Divinity'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit Channel Divinity'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('resource-maximum')), '3');
    await tester.tap(find.byKey(const ValueKey('save-resource')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-5')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-5')));
    await tester.pumpAndSettle();
    expect(find.text('Potion of Healing'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit Potion of Healing'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('inventory-quantity')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('save-inventory-item')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-6')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-6')));
    await tester.pumpAndSettle();
    expect(find.text('Second Wind'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit Second Wind'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feature-name')),
      'Heroic Recovery',
    );
    await tester.tap(find.byKey(const ValueKey('save-feature')));
    await tester.pumpAndSettle();
    expect(find.text('Heroic Recovery'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-7')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-7')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('character-name')),
      'Aurelia Brightshield',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('creator-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-save')));
    await tester.pumpAndSettle();

    expect(find.text('Aurelia Brightshield'), findsOneWidget);
    expect(find.text('Level 1 Champion'), findsOneWidget);

    await tester.tap(find.text('Aurelia Brightshield'));
    await tester.pumpAndSettle();
    final potionCard = tester.widget<InventoryItemCard>(
      find.widgetWithText(InventoryItemCard, 'Potion of Healing'),
    );
    expect(potionCard.item.quantity, 2);
    expect(potionCard.item.weightPerItem, 0.5);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Features & Traits'), findsOneWidget);
    expect(find.text('Heroic Recovery'), findsOneWidget);
    expect(find.text('Features & Traits').hitTestable(), findsOneWidget);
    expect(find.text('Heroic Recovery').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('Silvered Longsword'), findsOneWidget);
    expect(find.text('Radiant Flame'), findsOneWidget);
    expect(find.text('Prepared Spells'), findsOneWidget);
    expect(find.text('Shield'), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);
    expect(find.text('Heroic Recovery'), findsOneWidget);
    await tester.ensureVisible(find.text('Channel Divinity'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Channel Divinity'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Channel Divinity'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Channel Divinity'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('duplicates fresh characters and permanently deletes safely', (
    tester,
  ) async {
    final sessionRepository = InMemoryCharacterSessionRepository();
    final definitionRepository = InMemoryCharacterDefinitionRepository();

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessionRepository,
          definitionRepository: definitionRepository,
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
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate Character'));
    await tester.pumpAndSettle();

    expect(find.text('Eldrin Copy'), findsOneWidget);
    final copyCard = find.ancestor(
      of: find.text('Eldrin Copy'),
      matching: find.byType(CharacterCard),
    );
    expect(
      find.descendant(of: copyCard, matching: find.text('HP 42 / 42')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: copyCard, matching: find.text('Exploring')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    expect(find.text('Eldrin Copy'), findsOneWidget);

    await tester.longPress(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Character'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Eldrin?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Eldrin'), findsOneWidget);

    await tester.longPress(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Character'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Eldrin'), findsNothing);
    expect(find.text('Eldrin Copy'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    expect(find.text('Eldrin'), findsNothing);
    expect(find.text('Eldrin Copy'), findsOneWidget);
  });
}
