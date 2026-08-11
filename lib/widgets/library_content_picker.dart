import 'package:flutter/material.dart';

import '../models/content_pack.dart';
import '../models/inventory_item.dart';

enum LibraryContentType {
  weapon('Weapon', Icons.gavel_outlined),
  spell('Spell', Icons.auto_awesome_outlined),
  resource('Resource', Icons.battery_charging_full_outlined),
  feature('Feature', Icons.bolt_outlined),
  item('Item', Icons.backpack_outlined);

  final String label;
  final IconData icon;

  const LibraryContentType(this.label, this.icon);
}

class LibraryContentSelection {
  final Object content;
  final String entryKey;

  const LibraryContentSelection({
    required this.content,
    required this.entryKey,
  });
}

class LibraryContentPicker extends StatefulWidget {
  final LibraryContentType type;
  final List<ContentPack> packs;

  const LibraryContentPicker({
    super.key,
    required this.type,
    required this.packs,
  });

  @override
  State<LibraryContentPicker> createState() => _LibraryContentPickerState();
}

class _LibraryContentPickerState extends State<LibraryContentPicker> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<_PickerEntry> get entries {
    final results = <_PickerEntry>[];
    for (final pack in widget.packs) {
      switch (widget.type) {
        case LibraryContentType.weapon:
          for (final entry in pack.weapons) {
            results.add(
              _PickerEntry(
                key: '${pack.id}:weapon:${entry.id}',
                name: entry.name,
                subtitle: entry.summary,
                pack: pack,
                content: entry,
              ),
            );
          }
        case LibraryContentType.spell:
          for (final entry in pack.spells) {
            results.add(
              _PickerEntry(
                key: '${pack.id}:spell:${entry.id}',
                name: entry.name,
                subtitle: '${entry.levelLabel} • ${entry.summary}',
                pack: pack,
                content: entry,
              ),
            );
          }
        case LibraryContentType.resource:
          for (final entry in pack.resources) {
            results.add(
              _PickerEntry(
                key: '${pack.id}:resource:${entry.id}',
                name: entry.name,
                subtitle:
                    '${entry.maximum} uses • ${entry.rechargePeriod.label}',
                pack: pack,
                content: entry,
              ),
            );
          }
        case LibraryContentType.feature:
          for (final entry in pack.features) {
            results.add(
              _PickerEntry(
                key: '${pack.id}:feature:${entry.id}',
                name: entry.name,
                subtitle: entry.summary,
                pack: pack,
                content: entry,
              ),
            );
          }
        case LibraryContentType.item:
          for (var index = 0; index < pack.items.length; index++) {
            final entry = pack.items[index];
            results.add(
              _PickerEntry(
                key: '${pack.id}:item:$index',
                name: entry.name,
                subtitle:
                    '${itemCategoryLabel(entry.category)} • '
                    '${entry.quantity} carried',
                pack: pack,
                content: entry,
              ),
            );
          }
      }
    }
    results.sort((left, right) => left.name.compareTo(right.name));
    if (query.isEmpty) return results;
    final normalized = query.toLowerCase();
    return results
        .where(
          (entry) =>
              entry.name.toLowerCase().contains(normalized) ||
              entry.subtitle.toLowerCase().contains(normalized) ||
              entry.pack.name.toLowerCase().contains(normalized),
        )
        .toList();
  }

  String itemCategoryLabel(ItemCategory category) {
    return switch (category) {
      ItemCategory.consumable => 'Consumable',
      ItemCategory.equipment => 'Equipment',
      ItemCategory.tool => 'Tool',
      ItemCategory.quest => 'Quest Item',
      ItemCategory.general => 'General',
    };
  }

  @override
  Widget build(BuildContext context) {
    final visibleEntries = entries;
    return Scaffold(
      appBar: AppBar(title: Text('Add ${widget.type.label} from Library')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: ValueKey('search-library-${widget.type.name}'),
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search installed packs',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => query = value.trim()),
            ),
          ),
          Expanded(
            child: visibleEntries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.packs.isEmpty
                            ? 'No content packs are installed. Add packs from '
                                  'the Vault Library first.'
                            : 'No matching ${widget.type.label.toLowerCase()} '
                                  'content found.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: visibleEntries.length,
                    itemBuilder: (context, index) {
                      final entry = visibleEntries[index];
                      return Card(
                        child: ListTile(
                          key: ValueKey('library-entry-${entry.key}'),
                          leading: Icon(widget.type.icon),
                          title: Text(entry.name),
                          subtitle: Text(
                            '${entry.subtitle}\n${entry.pack.name}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          onTap: () => Navigator.pop(
                            context,
                            LibraryContentSelection(
                              content: entry.content,
                              entryKey: entry.key,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PickerEntry {
  final String key;
  final String name;
  final String subtitle;
  final ContentPack pack;
  final Object content;

  const _PickerEntry({
    required this.key,
    required this.name,
    required this.subtitle,
    required this.pack,
    required this.content,
  });
}
