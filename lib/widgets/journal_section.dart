import 'package:flutter/material.dart';

import '../models/journal_entry.dart';

class JournalSection extends StatelessWidget {
  final List<JournalEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<JournalEntry> onTap;
  final ValueChanged<JournalEntry> onLongPress;

  const JournalSection({
    super.key,
    required this.entries,
    required this.onAdd,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final active = entries.where((entry) => !entry.isCompleted).toList();
    final completed = entries.where((entry) => entry.isCompleted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Journal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              key: const ValueKey('add-journal-entry'),
              tooltip: 'Add quest',
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        Text(
          entries.isEmpty
              ? 'Keep important quests and discoveries with this character.'
              : 'Tap to read. Long press to manage.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (active.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.flag_outlined),
              title: Text('No active quests'),
              subtitle: Text('Use + to add your next objective.'),
            ),
          )
        else ...[
          const Text(
            'Active Quests',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          for (final entry in active)
            _JournalEntryCard(
              entry: entry,
              onTap: () => onTap(entry),
              onLongPress: () => onLongPress(entry),
            ),
        ],
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 6),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              key: const PageStorageKey('completed-journal-entries'),
              leading: const Icon(Icons.task_alt),
              title: Text('Completed (${completed.length})'),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                for (final entry in completed)
                  _JournalEntryCard(
                    entry: entry,
                    onTap: () => onTap(entry),
                    onLongPress: () => onLongPress(entry),
                    nested: true,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool nested;

  const _JournalEntryCard({
    required this.entry,
    required this.onTap,
    required this.onLongPress,
    this.nested = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('journal-entry-${entry.id}'),
      margin: EdgeInsets.only(bottom: 6, left: nested ? 4 : 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            entry.isCompleted
                ? Icons.check_circle_outline
                : Icons.flag_outlined,
          ),
          title: Text(
            entry.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              decoration: entry.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: entry.notes.isEmpty
              ? null
              : Text(entry.notes, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
