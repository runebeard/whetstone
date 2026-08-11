import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VaultBackupExportDialog extends StatelessWidget {
  final int characterCount;
  final String packageText;

  const VaultBackupExportDialog({
    super.key,
    required this.characterCount,
    required this.packageText,
  });

  Future<void> copyBackup(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: packageText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Vault backup copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Back Up Vault'),
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
                '$characterCount ${characterCount == 1 ? 'character' : 'characters'}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'This backup includes every character and their current live '
                'state, inventory, journal, combat status, and Timeline.',
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
                      key: const ValueKey('vault-backup-package-text'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('copy-vault-backup'),
                onPressed: () => copyBackup(context),
                icon: const Icon(Icons.copy),
                label: const Text('Copy Vault Backup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
