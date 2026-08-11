import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CharacterExportDialog extends StatelessWidget {
  final String characterName;
  final String packageText;

  const CharacterExportDialog({
    super.key,
    required this.characterName,
    required this.packageText,
  });

  Future<void> copyPackage(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: packageText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$characterName copied for export')));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Export Character'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                characterName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'This package includes the character and their current live '
                'state. Copy it into another Whetstone installation to import.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      packageText,
                      key: const ValueKey('export-package-text'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('copy-character-package'),
                onPressed: () => copyPackage(context),
                icon: const Icon(Icons.copy),
                label: const Text('Copy Character Package'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
