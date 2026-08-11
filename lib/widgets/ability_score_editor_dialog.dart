import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ability.dart';

class AbilityScoreEditorDialog extends StatefulWidget {
  final Ability ability;
  final int currentScore;

  const AbilityScoreEditorDialog({
    super.key,
    required this.ability,
    required this.currentScore,
  });

  @override
  State<AbilityScoreEditorDialog> createState() =>
      _AbilityScoreEditorDialogState();
}

class _AbilityScoreEditorDialogState extends State<AbilityScoreEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: '${widget.currentScore}');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, int.parse(controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.ability.label}'),
      content: Form(
        key: formKey,
        child: TextFormField(
          key: const ValueKey('profile-ability-score'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Ability score'),
          validator: (value) {
            final score = int.tryParse(value ?? '');
            return score == null || score < 1 || score > 30 ? '1–30' : null;
          },
          onFieldSubmitted: (_) => save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-profile-ability'),
          onPressed: save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
