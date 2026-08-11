import 'package:flutter/material.dart';

import '../models/character_action.dart';

class ActionDetailsDialog extends StatelessWidget {
  final CharacterAction action;

  const ActionDetailsDialog({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(action.name),
      content: Text(action.summary),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
