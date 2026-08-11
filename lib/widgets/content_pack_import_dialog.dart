import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../persistence/portable_content_pack_document.dart';

class ContentPackImportDialog extends StatefulWidget {
  const ContentPackImportDialog({super.key});

  @override
  State<ContentPackImportDialog> createState() =>
      _ContentPackImportDialogState();
}

class _ContentPackImportDialogState extends State<ContentPackImportDialog> {
  final packageController = TextEditingController();
  PortableContentPackDocument? preview;
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
      final parsed = PortableContentPackDocument.decode(packageController.text);
      setState(() {
        preview = parsed;
        error = null;
      });
    } on UnsupportedPortableContentPackVersion {
      setState(() {
        error = 'This pack was created by an unsupported Whetstone version.';
      });
    } catch (_) {
      setState(() {
        error = 'This is not a valid Whetstone content pack.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(preview == null ? 'Import Content Pack' : 'Review Pack'),
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
            'Paste a versioned Whetstone content-pack package. You can review '
            'its system, author, and contents before installing it.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('paste-content-pack'),
            onPressed: pastePackage,
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste from Clipboard'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('import-content-pack-text'),
              controller: packageController,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Content-pack package',
                alignLabelWithHint: true,
                errorText: error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => error = null),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('review-content-pack'),
            onPressed: packageController.text.trim().isEmpty ? null : review,
            child: const Text('Review Content Pack'),
          ),
        ],
      ),
    );
  }

  Widget buildPreview(BuildContext context) {
    final pack = preview!.pack;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(
          Icons.library_books_outlined,
          size: 54,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          pack.name,
          key: const ValueKey('content-pack-preview-name'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          '${pack.gameSystem} • v${pack.version}',
          textAlign: TextAlign.center,
        ),
        Text('by ${pack.author}', textAlign: TextAlign.center),
        const SizedBox(height: 18),
        Text(pack.description, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        _PackCounts(document: preview!),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('confirm-content-pack-import'),
          onPressed: () => Navigator.pop(context, pack),
          icon: const Icon(Icons.library_add_outlined),
          label: const Text('Install Content Pack'),
        ),
      ],
    );
  }
}

class _PackCounts extends StatelessWidget {
  final PortableContentPackDocument document;

  const _PackCounts({required this.document});

  @override
  Widget build(BuildContext context) {
    final pack = document.pack;
    final counts = {
      'Weapons': pack.weapons.length,
      'Spells': pack.spells.length,
      'Resources': pack.resources.length,
      'Features': pack.features.length,
      'Items': pack.items.length,
    };
    return Card(
      child: Column(
        children: [
          for (final entry in counts.entries)
            ListTile(
              dense: true,
              title: Text(entry.key),
              trailing: Text('${entry.value}'),
            ),
        ],
      ),
    );
  }
}
