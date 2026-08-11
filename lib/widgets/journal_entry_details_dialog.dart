import 'package:flutter/material.dart';

import '../models/journal_entry.dart';

class JournalEntryDetailsDialog extends StatelessWidget {
  final JournalEntry entry;

  const JournalEntryDetailsDialog({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(entry.title),
      content: SingleChildScrollView(
        child: Text(entry.notes.isEmpty ? 'No notes yet.' : entry.notes),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
