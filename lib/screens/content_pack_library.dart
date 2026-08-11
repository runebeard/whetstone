import 'package:flutter/material.dart';

import '../content/starter_content_pack.dart';
import '../models/content_pack.dart';
import '../widgets/content_pack_import_dialog.dart';

class ContentPackLibrary extends StatefulWidget {
  final Map<String, ContentPack> initialPacks;
  final ValueChanged<Map<String, ContentPack>> onPacksChanged;

  const ContentPackLibrary({
    super.key,
    required this.initialPacks,
    required this.onPacksChanged,
  });

  @override
  State<ContentPackLibrary> createState() => _ContentPackLibraryState();
}

class _ContentPackLibraryState extends State<ContentPackLibrary> {
  late Map<String, ContentPack> installedPacks;

  @override
  void initState() {
    super.initState();
    installedPacks = {...widget.initialPacks};
  }

  void publish(Map<String, ContentPack> updated) {
    setState(() => installedPacks = updated);
    widget.onPacksChanged({...updated});
  }

  Future<void> importPack() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final pack = await showDialog<ContentPack>(
      context: context,
      builder: (context) => const ContentPackImportDialog(),
    );
    if (!mounted || pack == null) return;
    await installPack(pack);
  }

  Future<void> installPack(ContentPack pack) async {
    if (installedPacks.containsKey(pack.id)) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Content Pack?'),
          content: Text(
            '${pack.name} is already installed. Replace it with version '
            '${pack.version}? Characters already using its content will not '
            'be changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-content-pack-update'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update Pack'),
            ),
          ],
        ),
      );
      if (!mounted || replace != true) return;
    }

    publish({...installedPacks, pack.id: pack});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${pack.name} installed')));
  }

  Future<void> removePack(ContentPack pack) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Content Pack?'),
        content: Text(
          'Remove ${pack.name} from the Library? Characters already using its '
          'content will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-content-pack-remove'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Pack'),
          ),
        ],
      ),
    );
    if (!mounted || remove != true) return;
    publish({...installedPacks}..remove(pack.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${pack.name} removed')));
  }

  @override
  Widget build(BuildContext context) {
    final packs = installedPacks.values.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    final starterInstalled = installedPacks.containsKey(starterContentPack.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Library'),
        actions: [
          TextButton.icon(
            key: const ValueKey('import-content-pack'),
            onPressed: importPack,
            icon: const Icon(Icons.download_outlined, size: 20),
            label: const Text('Import'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.auto_stories_outlined),
              title: Text('Reusable, not restrictive'),
              subtitle: Text(
                'Packs save entry time. Content copied to a character remains '
                'fully editable and survives if the pack is removed.',
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Installed Packs',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (packs.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.library_books_outlined),
                title: Text('No packs installed'),
                subtitle: Text('Install the starter pack or import your own.'),
              ),
            )
          else
            for (final pack in packs)
              _ContentPackCard(
                pack: pack,
                installed: true,
                onAction: () => removePack(pack),
              ),
          if (!starterInstalled) ...[
            const SizedBox(height: 18),
            const Text(
              'Available Packs',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _ContentPackCard(
              pack: starterContentPack,
              installed: false,
              onAction: () => installPack(starterContentPack),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContentPackCard extends StatelessWidget {
  final ContentPack pack;
  final bool installed;
  final VoidCallback onAction;

  const _ContentPackCard({
    required this.pack,
    required this.installed,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<String>>{
      'Weapons': pack.weapons.map((entry) => entry.name).toList(),
      'Spells': pack.spells.map((entry) => entry.name).toList(),
      'Resources': pack.resources.map((entry) => entry.name).toList(),
      'Features': pack.features.map((entry) => entry.name).toList(),
      'Items': pack.items.map((entry) => entry.name).toList(),
    };

    return Card(
      key: ValueKey('content-pack-${pack.id}'),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(
          installed ? Icons.library_books : Icons.library_add_outlined,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                pack.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!installed) ...[
              const SizedBox(width: 8),
              FilledButton(
                key: ValueKey('install-content-pack-${pack.id}'),
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Install'),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${pack.gameSystem} • v${pack.version} • ${pack.entryCount} entries',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(pack.description)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'by ${pack.author}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: 12),
          for (final category in categories.entries)
            if (category.value.isNotEmpty)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${category.key} (${category.value.length})'),
                subtitle: Text(category.value.join(', ')),
              ),
          const SizedBox(height: 8),
          if (installed)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: ValueKey('remove-content-pack-${pack.id}'),
                onPressed: onAction,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove Pack'),
              ),
            ),
        ],
      ),
    );
  }
}
