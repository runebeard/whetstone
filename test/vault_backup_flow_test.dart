import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/main.dart';
import 'package:whetstone/models/app_settings.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/content_pack.dart';
import 'package:whetstone/models/session_event.dart';
import 'package:whetstone/persistence/app_settings_repository.dart';
import 'package:whetstone/persistence/character_definition_repository.dart';
import 'package:whetstone/persistence/character_session_repository.dart';
import 'package:whetstone/persistence/content_pack_repository.dart';
import 'package:whetstone/persistence/portable_vault_document.dart';

void main() {
  Future<void> openTransferOption(WidgetTester tester, String optionKey) async {
    await tester.tap(find.byKey(const ValueKey('transfer-characters')));
    await tester.pumpAndSettle();
    final option = find.byKey(ValueKey(optionKey));
    await tester.scrollUntilVisible(
      option,
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  testWidgets('whole Vault backup includes current live play state', (
    tester,
  ) async {
    final eldrin = seedCharacters[0];
    final baseSession = CharacterSession.fromCharacter(eldrin);
    final liveSession = CharacterSession(
      characterState: baseSession.characterState.copyWith(
        currentHp: eldrin.maxHp - 7,
        temporaryHp: 4,
      ),
      inventory: baseSession.inventory,
      archivedInventory: baseSession.archivedInventory,
      isInCombat: true,
      timeline: [
        SessionEvent(
          id: 'backup-roll',
          occurredAt: DateTime.utc(2026, 8, 11, 11),
          type: SessionEventType.roll,
          title: 'Rolled Perception',
          detail: 'Total 18',
        ),
      ],
    );
    final definitions = InMemoryCharacterDefinitionRepository();
    final sessions = InMemoryCharacterSessionRepository();
    await definitions.saveCatalog(
      CharacterDefinitionCatalog(characters: {eldrin.id: eldrin}),
    );
    await sessions.saveSessions({eldrin.id: liveSession});

    await tester.pumpWidget(
      WhetstoneApp(
        settingsRepository: InMemoryAppSettingsRepository(
          settings: const AppSettings(
            onboardingComplete: true,
            sampleCharactersEnabled: false,
          ),
        ),
        repository: sessions,
        definitionRepository: definitions,
        contentPackRepository: InMemoryContentPackRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await openTransferOption(tester, 'transfer-backup-vault');

    final packageText = tester
        .widget<SelectableText>(
          find.byKey(const ValueKey('vault-backup-package-text')),
        )
        .data!;
    final backup = PortableVaultDocument.decode(packageText);
    expect(backup.characters[eldrin.id]!.name, 'Eldrin');
    expect(
      backup.sessions[eldrin.id]!.characterState.currentHp,
      eldrin.maxHp - 7,
    );
    expect(backup.sessions[eldrin.id]!.characterState.temporaryHp, 4);
    expect(backup.sessions[eldrin.id]!.isInCombat, isTrue);
    expect(
      backup.sessions[eldrin.id]!.timeline.single.title,
      'Rolled Perception',
    );
  });

  testWidgets('restore previews, confirms, replaces, and survives restart', (
    tester,
  ) async {
    final currentCharacter = seedCharacters[0];
    final restoredCharacter = seedCharacters[1];
    final restoredBase = CharacterSession.fromCharacter(restoredCharacter);
    final restoredSession = CharacterSession(
      characterState: restoredBase.characterState.copyWith(
        currentHp: restoredCharacter.maxHp - 2,
        activeConditions: {'Hidden'},
      ),
      inventory: restoredBase.inventory,
      archivedInventory: restoredBase.archivedInventory,
      isInCombat: true,
      timeline: [
        SessionEvent(
          id: 'restore-event',
          occurredAt: DateTime.utc(2026, 8, 11, 12),
          type: SessionEventType.combat,
          title: 'Entered combat',
        ),
      ],
    );
    final backupText = PortableVaultDocument(
      createdAt: DateTime.utc(2026, 8, 11, 12, 5),
      characters: {restoredCharacter.id: restoredCharacter},
      sessions: {restoredCharacter.id: restoredSession},
    ).encode();
    final definitions = InMemoryCharacterDefinitionRepository();
    final sessions = InMemoryCharacterSessionRepository();
    final contentPacks = InMemoryContentPackRepository();
    const installedPack = ContentPack(
      id: 'table-pack',
      name: 'Table Rules',
      gameSystem: 'System Agnostic',
      version: '1.0',
      author: 'Game Master',
      description: 'The table\'s shared rules.',
    );
    final settings = InMemoryAppSettingsRepository(
      settings: const AppSettings(
        onboardingComplete: true,
        sampleCharactersEnabled: false,
      ),
    );
    await definitions.saveCatalog(
      CharacterDefinitionCatalog(
        characters: {currentCharacter.id: currentCharacter},
      ),
    );
    await sessions.saveSessions({
      currentCharacter.id: CharacterSession.fromCharacter(currentCharacter),
    });
    await contentPacks.savePacks({installedPack.id: installedPack});

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(
          settingsRepository: settings,
          repository: sessions,
          definitionRepository: definitions,
          contentPackRepository: contentPacks,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> reviewBackup() async {
      await openTransferOption(tester, 'transfer-restore-vault');
      await tester.enterText(
        find.byKey(const ValueKey('restore-vault-package-text')),
        backupText,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('review-vault-backup')));
      await tester.pumpAndSettle();
      expect(find.text('1 character'), findsOneWidget);
      expect(find.text('Rowan'), findsOneWidget);
      expect(find.text('1 events'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      final continueButton = find.byKey(
        const ValueKey('continue-vault-restore'),
      );
      await tester.dragFrom(const Offset(400, 500), const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Replace Current Vault?'), findsOneWidget);
    }

    await pumpApp();
    expect(find.text('Eldrin'), findsOneWidget);

    await reviewBackup();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Eldrin'), findsOneWidget);
    expect(find.text('Rowan'), findsNothing);

    await reviewBackup();
    await tester.tap(find.byKey(const ValueKey('confirm-vault-restore')));
    await tester.pumpAndSettle();
    expect(find.text('Eldrin'), findsNothing);
    expect(find.text('Rowan'), findsOneWidget);

    final restoredCatalog = await definitions.loadCatalog();
    final restoredSessions = await sessions.loadSessions();
    expect(restoredCatalog.characters.keys, {restoredCharacter.id});
    expect(restoredSessions.keys, {restoredCharacter.id});
    expect(
      restoredSessions[restoredCharacter.id]!.characterState.currentHp,
      restoredCharacter.maxHp - 2,
    );
    expect(
      restoredSessions[restoredCharacter.id]!.characterState.activeConditions,
      {'Hidden'},
    );
    expect((await contentPacks.loadPacks()).keys, {installedPack.id});
    expect(settings.settings.sampleCharactersEnabled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    expect(find.text('Eldrin'), findsNothing);
    expect(find.text('Rowan'), findsOneWidget);
  });
}
