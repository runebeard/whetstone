import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../persistence/portable_character_document.dart';

class CharacterImportDialog extends StatefulWidget {
  const CharacterImportDialog({super.key});

  @override
  State<CharacterImportDialog> createState() => _CharacterImportDialogState();
}

class _CharacterImportDialogState extends State<CharacterImportDialog> {
  final packageController = TextEditingController();
  PortableCharacterDocument? preview;
  String? error;

  @override
  void dispose() {
    packageController.dispose();
    super.dispose();
  }

  Future<void> pastePackage() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) return;
    setState(() {
      packageController.text = data!.text!;
      error = null;
    });
  }

  void review() {
    try {
      final parsed = PortableCharacterDocument.decode(packageController.text);
      setState(() {
        preview = parsed;
        error = null;
      });
    } on UnsupportedPortableCharacterVersion {
      setState(() {
        error = 'This package was created by an unsupported Whetstone version.';
      });
    } catch (_) {
      setState(() {
        error = 'This is not a valid Whetstone character package.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(preview == null ? 'Import Character' : 'Review Import'),
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
            'Paste a Whetstone character package below. Nothing will be '
            'changed until you review and confirm it.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('paste-character-package'),
            onPressed: pastePackage,
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste from Clipboard'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('import-package-text'),
              controller: packageController,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Character package',
                alignLabelWithHint: true,
                errorText: error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => error = null),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('review-character-package'),
            onPressed: packageController.text.trim().isEmpty ? null : review,
            child: const Text('Review Character'),
          ),
        ],
      ),
    );
  }

  Widget buildPreview(BuildContext context) {
    final document = preview!;
    final character = document.character;
    final session = document.session;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(
          Icons.person_outline,
          size: 54,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          character.name,
          key: const ValueKey('import-preview-name'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          'Level ${character.level} ${character.characterClass}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: const Text('Current HP'),
                trailing: Text(
                  '${session.characterState.currentHp} / '
                  '${session.characterState.maxHp}',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.backpack_outlined),
                title: const Text('Inventory'),
                trailing: Text('${session.inventory.length} entries'),
              ),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Journal'),
                trailing: Text('${character.journalEntries.length} entries'),
              ),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Current activity'),
                trailing: Text(session.isInCombat ? 'In Combat' : 'Exploring'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'If this character already exists, Whetstone will create a separate '
          'copy rather than overwrite it.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('confirm-character-import'),
          onPressed: () => Navigator.pop(context, document),
          icon: const Icon(Icons.download_done),
          label: const Text('Import Character'),
        ),
      ],
    );
  }
}
