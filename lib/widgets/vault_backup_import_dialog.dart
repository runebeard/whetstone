import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../persistence/portable_vault_document.dart';

class VaultBackupImportDialog extends StatefulWidget {
  const VaultBackupImportDialog({super.key});

  @override
  State<VaultBackupImportDialog> createState() =>
      _VaultBackupImportDialogState();
}

class _VaultBackupImportDialogState extends State<VaultBackupImportDialog> {
  final packageController = TextEditingController();
  PortableVaultDocument? preview;
  String? error;

  @override
  void dispose() {
    packageController.dispose();
    super.dispose();
  }

  Future<void> pasteBackup() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) return;
    setState(() {
      packageController.text = data!.text!;
      error = null;
    });
  }

  void review() {
    try {
      final parsed = PortableVaultDocument.decode(packageController.text);
      setState(() {
        preview = parsed;
        error = null;
      });
    } on UnsupportedPortableVaultVersion {
      setState(() {
        error = 'This backup was created by an unsupported Whetstone version.';
      });
    } catch (_) {
      setState(() {
        error = 'This is not a valid Whetstone Vault backup.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(preview == null ? 'Restore Vault' : 'Review Backup'),
          leading: IconButton(
            onPressed: preview == null
                ? () => Navigator.pop(context)
                : () => setState(() => preview = null),
            icon: Icon(preview == null ? Icons.close : Icons.arrow_back),
          ),
        ),
        body: preview == null ? buildEntry(context) : buildPreview(context),
      ),
    );
  }

  Widget buildEntry(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Paste a Whetstone Vault backup below. You can inspect it before '
            'anything is replaced.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('paste-vault-backup'),
            onPressed: pasteBackup,
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste from Clipboard'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('restore-vault-package-text'),
              controller: packageController,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Vault backup',
                alignLabelWithHint: true,
                errorText: error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => error = null),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('review-vault-backup'),
            onPressed: packageController.text.trim().isEmpty ? null : review,
            child: const Text('Review Backup'),
          ),
        ],
      ),
    );
  }

  Widget buildPreview(BuildContext context) {
    final document = preview!;
    final characters = document.characters.values.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    final inventoryEntries = document.sessions.values.fold<int>(
      0,
      (total, session) =>
          total + session.inventory.length + session.archivedInventory.length,
    );
    final timelineEntries = document.sessions.values.fold<int>(
      0,
      (total, session) => total + session.timeline.length,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(
          Icons.inventory_2_outlined,
          size: 54,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          '${characters.length} ${characters.length == 1 ? 'character' : 'characters'}',
          key: const ValueKey('vault-backup-preview-count'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.backpack_outlined),
                title: const Text('Inventory'),
                trailing: Text('$inventoryEntries entries'),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Timeline'),
                trailing: Text('$timelineEntries events'),
              ),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Characters in Combat'),
                trailing: Text(
                  '${document.sessions.values.where((session) => session.isInCombat).length}',
                ),
              ),
            ],
          ),
        ),
        if (characters.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Characters', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final character in characters)
            ListTile(
              dense: true,
              leading: const Icon(Icons.person_outline),
              title: Text(character.name),
              subtitle: Text(
                'Level ${character.level} ${character.characterClass}',
              ),
            ),
        ],
        const SizedBox(height: 20),
        Text(
          'Restoring this backup will replace every character currently in '
          'this Vault. Installed content packs will not be changed.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('continue-vault-restore'),
          onPressed: () => Navigator.pop(context, document),
          icon: const Icon(Icons.restore),
          label: const Text('Continue to Restore'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
