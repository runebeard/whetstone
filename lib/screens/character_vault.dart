import 'dart:math';

import 'package:flutter/material.dart';

import '../content/sample_characters.dart';
import '../models/character.dart';
import '../models/app_settings.dart';
import '../models/check_roll.dart';
import '../models/character_session.dart';
import '../models/feature.dart';
import '../models/content_pack.dart';
import '../models/spell.dart';
import '../models/weapon.dart';
import '../widgets/character_card.dart';
import '../widgets/character_export_dialog.dart';
import '../widgets/character_import_dialog.dart';
import '../widgets/vault_backup_export_dialog.dart';
import '../widgets/vault_backup_import_dialog.dart';
import '../persistence/character_session_repository.dart';
import '../persistence/character_definition_repository.dart';
import '../persistence/portable_character_document.dart';
import '../persistence/portable_vault_document.dart';
import '../persistence/content_pack_repository.dart';
import '../persistence/app_settings_repository.dart';
import 'character_editor.dart';
import 'character_overview.dart';
import 'content_pack_library.dart';
import 'first_launch_screen.dart';

class CharacterVault extends StatefulWidget {
  final CharacterSessionRepository? repository;
  final CharacterDefinitionRepository? definitionRepository;
  final DiceRoller? diceRoller;
  final ContentPackRepository? contentPackRepository;
  final AppSettingsRepository? settingsRepository;

  const CharacterVault({
    super.key,
    this.repository,
    this.definitionRepository,
    this.diceRoller,
    this.contentPackRepository,
    this.settingsRepository,
  });

  @override
  State<CharacterVault> createState() => _CharacterVaultState();
}

class _CharacterVaultState extends State<CharacterVault> {
  late final CharacterSessionRepository repository;
  late final CharacterDefinitionRepository definitionRepository;
  late final ContentPackRepository contentPackRepository;
  late final AppSettingsRepository settingsRepository;
  Map<String, CharacterSession> sessions = {};
  Map<String, Character> savedDefinitions = {};
  Set<String> deletedCharacterIds = {};
  Map<String, ContentPack> installedContentPacks = {};
  AppSettings appSettings = const AppSettings();
  bool isLoading = true;
  Object? loadError;

  @override
  void initState() {
    super.initState();
    repository = widget.repository ?? InMemoryCharacterSessionRepository();
    definitionRepository =
        widget.definitionRepository ?? InMemoryCharacterDefinitionRepository();
    contentPackRepository =
        widget.contentPackRepository ?? InMemoryContentPackRepository();
    settingsRepository =
        widget.settingsRepository ??
        InMemoryAppSettingsRepository(
          settings: const AppSettings(
            onboardingComplete: true,
            sampleCharactersEnabled: true,
          ),
        );
    loadSessions();
  }

  Future<void> loadSessions() async {
    try {
      final loadedSessions = await repository.loadSessions();
      final loadedContentPacks = await contentPackRepository.loadPacks();
      var loadedSettings = await settingsRepository.loadSettings();
      var catalog = await definitionRepository.loadCatalog();
      if (catalog.schemaVersion <
          CharacterDefinitionCatalog.currentSchemaVersion) {
        catalog = upgradeLegacyRollModifiers(catalog);
        await definitionRepository.saveCatalog(catalog);
      }
      final hasExistingData =
          loadedSessions.isNotEmpty ||
          loadedContentPacks.isNotEmpty ||
          catalog.characters.isNotEmpty ||
          catalog.deletedCharacterIds.isNotEmpty;
      if (!loadedSettings.onboardingComplete && hasExistingData) {
        loadedSettings = const AppSettings(
          onboardingComplete: true,
          sampleCharactersEnabled: true,
        );
        await settingsRepository.saveSettings(loadedSettings);
      }
      final availableCharacters = mergedCharacters(
        catalog.characters,
        deletedIds: catalog.deletedCharacterIds,
        includeSamples: loadedSettings.sampleCharactersEnabled,
      );
      final mergedSessions = {
        for (final character in availableCharacters)
          character.id:
              loadedSessions[character.id] ??
              CharacterSession.fromCharacter(character),
      };

      if (!mounted) {
        return;
      }

      setState(() {
        sessions = mergedSessions;
        savedDefinitions = catalog.characters;
        deletedCharacterIds = catalog.deletedCharacterIds;
        installedContentPacks = loadedContentPacks;
        appSettings = loadedSettings;
        isLoading = false;
      });

      if (loadedSessions.length != mergedSessions.length) {
        await repository.saveSessions(mergedSessions);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        loadError = error;
        isLoading = false;
      });
    }
  }

  void updateSession(String characterId, CharacterSession session) {
    setState(() {
      sessions = {...sessions, characterId: session};
    });
    repository.saveSessions(sessions);
  }

  void updateCharacterDefinition(Character character) {
    setState(() {
      savedDefinitions = {...savedDefinitions, character.id: character};
      deletedCharacterIds = {...deletedCharacterIds}..remove(character.id);
    });
    saveDefinitionCatalog();
  }

  void updateContentPacks(Map<String, ContentPack> packs) {
    setState(() => installedContentPacks = {...packs});
    contentPackRepository.savePacks(installedContentPacks);
  }

  Future<void> openContentLibrary() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ContentPackLibrary(
          initialPacks: installedContentPacks,
          onPacksChanged: updateContentPacks,
        ),
      ),
    );
  }

  List<Character> mergedCharacters(
    Map<String, Character> definitions, {
    Set<String>? deletedIds,
    bool? includeSamples,
  }) {
    final merged = {
      for (final character in seedCharacters)
        if ((includeSamples ?? appSettings.sampleCharactersEnabled) &&
            !(deletedIds ?? deletedCharacterIds).contains(character.id))
          character.id: character,
    };
    for (final entry in definitions.entries) {
      if (!(deletedIds ?? deletedCharacterIds).contains(entry.key)) {
        merged[entry.key] = entry.value;
      }
    }
    return merged.values.toList();
  }

  CharacterDefinitionCatalog upgradeLegacyRollModifiers(
    CharacterDefinitionCatalog catalog,
  ) {
    final seedsById = {for (final seed in seedCharacters) seed.id: seed};
    final upgraded = <String, Character>{};
    for (final entry in catalog.characters.entries) {
      final seed = seedsById[entry.key];
      final saved = entry.value;
      if (seed == null) {
        upgraded[entry.key] = saved;
        continue;
      }

      final seedSpells = {for (final spell in seed.spells) spell.id: spell};
      final seedWeapons = {
        for (final weapon in seed.weapons) weapon.id: weapon,
      };
      final seedFeatures = {
        for (final feature in seed.features) feature.id: feature,
      };
      upgraded[entry.key] = saved.copyWith(
        weapons: [
          for (final weapon in saved.weapons)
            Weapon(
              id: weapon.id,
              name: weapon.name,
              attackModifier: weapon.attackModifier,
              damage: weapon.damage,
              damageFormula:
                  weapon.damageFormula ?? seedWeapons[weapon.id]?.damageFormula,
              damageType:
                  weapon.damageType ?? seedWeapons[weapon.id]?.damageType,
              range: weapon.range,
            ),
        ],
        spells: [
          for (final spell in saved.spells)
            Spell(
              id: spell.id,
              name: spell.name,
              level: spell.level,
              prepared: spell.prepared,
              summary: spell.summary,
              rollModifier:
                  spell.rollModifier ?? seedSpells[spell.id]?.rollModifier,
              damageFormula:
                  spell.damageFormula ?? seedSpells[spell.id]?.damageFormula,
              damageType: spell.damageType ?? seedSpells[spell.id]?.damageType,
            ),
        ],
        features: [
          for (final feature in saved.features)
            Feature(
              id: feature.id,
              name: feature.name,
              summary: feature.summary,
              rollModifier:
                  feature.rollModifier ??
                  seedFeatures[feature.id]?.rollModifier,
            ),
        ],
      );
    }
    return CharacterDefinitionCatalog(
      characters: upgraded,
      deletedCharacterIds: catalog.deletedCharacterIds,
    );
  }

  List<Character> get characters => mergedCharacters(savedDefinitions);

  Future<void> startCreatingCharacter() async {
    final updatedSettings = const AppSettings(
      onboardingComplete: true,
      sampleCharactersEnabled: false,
    );
    await settingsRepository.saveSettings(updatedSettings);
    if (!mounted) return;
    setState(() => appSettings = updatedSettings);
    await createCharacter();
  }

  Future<void> enableSampleCharacters() async {
    final sampleIds = seedCharacters.map((character) => character.id).toSet();
    final updatedSettings = const AppSettings(
      onboardingComplete: true,
      sampleCharactersEnabled: true,
    );
    final updatedDeletedIds = {...deletedCharacterIds}..removeAll(sampleIds);
    final updatedSessions = {...sessions};
    for (final character in seedCharacters) {
      updatedSessions.putIfAbsent(
        character.id,
        () => CharacterSession.fromCharacter(character),
      );
    }
    setState(() {
      appSettings = updatedSettings;
      deletedCharacterIds = updatedDeletedIds;
      sessions = updatedSessions;
    });
    await Future.wait([
      settingsRepository.saveSettings(updatedSettings),
      saveDefinitionCatalog(),
      repository.saveSessions(updatedSessions),
    ]);
  }

  Future<void> createCharacter() async {
    final character = await Navigator.push<Character>(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterEditor(
          contentPacks: installedContentPacks.values.toList(),
        ),
      ),
    );
    if (!mounted || character == null) {
      return;
    }
    final session = CharacterSession.fromCharacter(character);
    setState(() {
      savedDefinitions = {...savedDefinitions, character.id: character};
      sessions = {...sessions, character.id: session};
      deletedCharacterIds = {...deletedCharacterIds}..remove(character.id);
    });
    await Future.wait([
      saveDefinitionCatalog(),
      repository.saveSessions(sessions),
    ]);
  }

  Future<void> editCharacter(Character character) async {
    final session = sessions[character.id]!;
    final state = session.characterState;
    final editableCharacter = character.copyWith(
      currentHp: state.currentHp,
      maxHp: state.maxHp,
      armourClass: state.armourClass,
      initiativeModifier: state.initiativeModifier,
      initiallyPinnedActionKeys: state.pinnedActionKeys,
      initialInventory: session.inventory,
    );
    final updated = await Navigator.push<Character>(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterEditor(
          character: editableCharacter,
          contentPacks: installedContentPacks.values.toList(),
        ),
      ),
    );
    if (!mounted || updated == null) {
      return;
    }
    final updatedResourceValues = {
      for (final resource in updated.resources)
        resource.id: min(
          state.resourceValues[resource.id] ?? resource.initialValue,
          resource.maximum,
        ),
    };
    final updatedState = state.copyWith(
      currentHp: updated.currentHp,
      maxHp: updated.maxHp,
      armourClass: updated.armourClass,
      initiativeModifier: updated.initiativeModifier,
      pinnedActionKeys: updated.initiallyPinnedActionKeys,
      resourceValues: updatedResourceValues,
    );
    final updatedSession = CharacterSession(
      characterState: updatedState,
      inventory: updated.initialInventory,
      archivedInventory: session.archivedInventory,
      isInCombat: session.isInCombat,
      timeline: session.timeline,
    );
    setState(() {
      savedDefinitions = {...savedDefinitions, updated.id: updated};
      sessions = {...sessions, updated.id: updatedSession};
    });
    await Future.wait([
      saveDefinitionCatalog(),
      repository.saveSessions(sessions),
    ]);
  }

  Future<void> saveDefinitionCatalog() {
    return definitionRepository.saveCatalog(
      CharacterDefinitionCatalog(
        characters: savedDefinitions,
        deletedCharacterIds: deletedCharacterIds,
      ),
    );
  }

  Future<void> showCharacterActions(Character character) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.82,
        child: SafeArea(
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Character'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Duplicate Character'),
                onTap: () => Navigator.pop(context, 'duplicate'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete Character'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await editCharacter(character);
      case 'duplicate':
        await duplicateCharacter(character);
      case 'delete':
        await deleteCharacter(character);
    }
  }

  Future<void> showCharacterTransferOptions() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.82,
        child: SafeArea(
          child: ListView(
            children: [
              const ListTile(
                title: Text(
                  'Transfer Characters',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                key: const ValueKey('transfer-import-character'),
                leading: const Icon(Icons.download_outlined),
                title: const Text('Import Character'),
                subtitle: const Text('Add a character package to this Vault'),
                onTap: () => Navigator.pop(context, 'import'),
              ),
              ListTile(
                key: const ValueKey('transfer-export-character'),
                leading: const Icon(Icons.upload_outlined),
                title: const Text('Export Character'),
                subtitle: const Text('Choose a character package to copy'),
                onTap: () => Navigator.pop(context, 'export'),
              ),
              const Divider(),
              const ListTile(
                title: Text(
                  'Whole Vault',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                key: const ValueKey('transfer-backup-vault'),
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Back Up Entire Vault'),
                subtitle: const Text('Copy every character and live session'),
                onTap: () => Navigator.pop(context, 'backup-vault'),
              ),
              ListTile(
                key: const ValueKey('transfer-restore-vault'),
                leading: const Icon(Icons.restore),
                title: const Text('Restore Vault Backup'),
                subtitle: const Text(
                  'Review a backup before replacing this Vault',
                ),
                onTap: () => Navigator.pop(context, 'restore-vault'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'import':
        await importCharacter();
      case 'export':
        await chooseCharacterToExport();
      case 'backup-vault':
        await backupVault();
      case 'restore-vault':
        await restoreVault();
    }
  }

  Future<void> backupVault() async {
    final activeCharacters = {
      for (final character in characters) character.id: character,
    };
    final activeSessions = {
      for (final id in activeCharacters.keys) id: sessions[id]!,
    };
    final document = PortableVaultDocument(
      createdAt: DateTime.now(),
      characters: activeCharacters,
      sessions: activeSessions,
    );
    await showDialog<void>(
      context: context,
      builder: (context) => VaultBackupExportDialog(
        characterCount: activeCharacters.length,
        packageText: document.encode(pretty: true),
      ),
    );
  }

  Future<void> restoreVault() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final document = await showDialog<PortableVaultDocument>(
      context: context,
      builder: (context) => const VaultBackupImportDialog(),
    );
    if (!mounted || document == null) return;

    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace Current Vault?'),
        content: Text(
          'Replace ${characters.length} current '
          '${characters.length == 1 ? 'character' : 'characters'} with '
          '${document.characters.length} from this backup? This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-vault-restore'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace Vault'),
          ),
        ],
      ),
    );
    if (!mounted || replace != true) return;

    const restoredSettings = AppSettings(
      onboardingComplete: true,
      sampleCharactersEnabled: false,
    );
    setState(() {
      savedDefinitions = {...document.characters};
      sessions = {...document.sessions};
      deletedCharacterIds = {};
      appSettings = restoredSettings;
    });
    await Future.wait([
      saveDefinitionCatalog(),
      repository.saveSessions(sessions),
      settingsRepository.saveSettings(restoredSettings),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${document.characters.length} '
          '${document.characters.length == 1 ? 'character' : 'characters'} restored',
        ),
      ),
    );
  }

  Future<void> chooseCharacterToExport() async {
    final character = await showModalBottomSheet<Character>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Choose a Character',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final character in characters)
                    ListTile(
                      key: ValueKey('export-character-${character.id}'),
                      leading: const Icon(Icons.person_outline),
                      title: Text(character.name),
                      subtitle: Text(
                        'Level ${character.level} ${character.characterClass}',
                      ),
                      onTap: () => Navigator.pop(context, character),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || character == null) return;
    await exportCharacter(character);
  }

  Future<void> exportCharacter(Character character) async {
    final document = PortableCharacterDocument(
      character: character,
      session: sessions[character.id]!,
    );
    await showDialog<void>(
      context: context,
      builder: (context) => CharacterExportDialog(
        characterName: character.name,
        packageText: document.encode(pretty: true),
      ),
    );
  }

  Future<void> importCharacter() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final document = await showDialog<PortableCharacterDocument>(
      context: context,
      builder: (context) => const CharacterImportDialog(),
    );
    if (!mounted || document == null) return;

    final existingIds = characters.map((character) => character.id).toSet();
    final hasCollision = existingIds.contains(document.character.id);
    final importedCharacter = hasCollision
        ? document.character.copyWith(
            id: 'character-${DateTime.now().microsecondsSinceEpoch}',
            name: nextCopyName(document.character.name),
          )
        : document.character;

    setState(() {
      savedDefinitions = {
        ...savedDefinitions,
        importedCharacter.id: importedCharacter,
      };
      sessions = {...sessions, importedCharacter.id: document.session};
      deletedCharacterIds = {...deletedCharacterIds}
        ..remove(importedCharacter.id);
    });
    await Future.wait([
      saveDefinitionCatalog(),
      repository.saveSessions(sessions),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${importedCharacter.name} imported')),
    );
  }

  Future<void> duplicateCharacter(Character source) async {
    final sourceSession = sessions[source.id]!;
    final state = sourceSession.characterState;
    final copy = source.copyWith(
      id: 'character-${DateTime.now().microsecondsSinceEpoch}',
      name: nextCopyName(source.name),
      currentHp: state.maxHp,
      maxHp: state.maxHp,
      armourClass: state.armourClass,
      initiativeModifier: state.initiativeModifier,
      status: 'Exploring',
      initiallyPinnedActionKeys: state.pinnedActionKeys,
      initialInventory: sourceSession.inventory,
    );
    final copySession = CharacterSession.fromCharacter(copy);
    setState(() {
      savedDefinitions = {...savedDefinitions, copy.id: copy};
      sessions = {...sessions, copy.id: copySession};
    });
    await Future.wait([
      saveDefinitionCatalog(),
      repository.saveSessions(sessions),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${copy.name} created')));
  }

  String nextCopyName(String sourceName) {
    final names = characters.map((character) => character.name.toLowerCase());
    var copyNumber = 1;
    var candidate = '$sourceName Copy';
    while (names.contains(candidate.toLowerCase())) {
      copyNumber += 1;
      candidate = '$sourceName Copy $copyNumber';
    }
    return candidate;
  }

  Future<void> deleteCharacter(Character character) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${character.name}?'),
        content: const Text(
          'This permanently deletes the character and their saved session. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      savedDefinitions = {...savedDefinitions}..remove(character.id);
      sessions = {...sessions}..remove(character.id);
      deletedCharacterIds = {...deletedCharacterIds, character.id};
    });
    await Future.wait([
      saveDefinitionCatalog(),
      repository.saveSessions(sessions),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${character.name} permanently deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Whetstone')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.save_outlined, size: 40),
                const SizedBox(height: 16),
                const Text(
                  'Whetstone could not open your saved characters.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      isLoading = true;
                      loadError = null;
                    });
                    loadSessions();
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!appSettings.onboardingComplete) {
      return FirstLaunchScreen(
        onCreateCharacter: startCreatingCharacter,
        onUseSamples: enableSampleCharacters,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Whetstone'),
        actions: [
          TextButton.icon(
            key: const ValueKey('content-library'),
            onPressed: openContentLibrary,
            icon: const Icon(Icons.library_books_outlined, size: 20),
            label: const Text('Library'),
          ),
          TextButton.icon(
            key: const ValueKey('transfer-characters'),
            onPressed: showCharacterTransferOptions,
            icon: const Icon(Icons.import_export, size: 20),
            label: const Text('Transfer'),
          ),
        ],
      ),
      body: characters.isEmpty
          ? _EmptyVault(
              onCreateCharacter: createCharacter,
              onAddSamples: enableSampleCharacters,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: characters.length,
              itemBuilder: (context, index) {
                return CharacterCard(
                  character: characters[index],
                  session: sessions[characters[index].id]!,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CharacterOverview(
                          character: characters[index],
                          initialSession: sessions[characters[index].id]!,
                          onSessionChanged: (session) =>
                              updateSession(characters[index].id, session),
                          onCharacterChanged: updateCharacterDefinition,
                          diceRoller: widget.diceRoller,
                          contentPacks: installedContentPacks.values.toList(),
                        ),
                      ),
                    );
                  },
                  onLongPress: () => showCharacterActions(characters[index]),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: createCharacter,
        tooltip: 'Create Character',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyVault extends StatelessWidget {
  final VoidCallback onCreateCharacter;
  final VoidCallback onAddSamples;

  const _EmptyVault({
    required this.onCreateCharacter,
    required this.onAddSamples,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_add_alt_1_outlined,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Your Vault is empty',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a character to begin, or restore Whetstone\'s sample '
                'adventurers.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                key: const ValueKey('empty-vault-create-character'),
                onPressed: onCreateCharacter,
                icon: const Icon(Icons.add),
                label: const Text('Create Character'),
              ),
              TextButton.icon(
                key: const ValueKey('empty-vault-add-samples'),
                onPressed: onAddSamples,
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('Restore Sample Characters'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
