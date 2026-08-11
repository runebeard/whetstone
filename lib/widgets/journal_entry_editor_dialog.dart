import 'package:flutter/material.dart';

import '../models/journal_entry.dart';

class JournalEntryEditorDialog extends StatefulWidget {
  final JournalEntry? entry;

  const JournalEntryEditorDialog({super.key, this.entry});

  @override
  State<JournalEntryEditorDialog> createState() =>
      _JournalEntryEditorDialogState();
}

class _JournalEntryEditorDialogState extends State<JournalEntryEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController notesController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.entry?.title ?? '');
    notesController = TextEditingController(text: widget.entry?.notes ?? '');
  }

  @override
  void dispose() {
    titleController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      JournalEntry(
        id:
            widget.entry?.id ??
            'journal-${DateTime.now().microsecondsSinceEpoch}',
        title: titleController.text.trim(),
        notes: notesController.text.trim(),
        isCompleted: widget.entry?.isCompleted ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'Add Quest' : 'Edit Quest'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('journal-title'),
                controller: titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Quest title'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('journal-notes'),
                controller: notesController,
                minLines: 4,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'What happened, who is involved, and what next?',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-journal-entry'),
          onPressed: save,
          child: Text(widget.entry == null ? 'Add Quest' : 'Save Changes'),
        ),
      ],
    );
  }
}
