import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character_resource.dart';

class CharacterResourceEditorDialog extends StatefulWidget {
  final CharacterResource? resource;

  const CharacterResourceEditorDialog({super.key, this.resource});

  @override
  State<CharacterResourceEditorDialog> createState() =>
      _CharacterResourceEditorDialogState();
}

class _CharacterResourceEditorDialogState
    extends State<CharacterResourceEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController maximumController;
  late RechargePeriod rechargePeriod;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.resource?.name ?? '');
    maximumController = TextEditingController(
      text: '${widget.resource?.maximum ?? 1}',
    );
    rechargePeriod = widget.resource?.rechargePeriod ?? RechargePeriod.longRest;
  }

  @override
  void dispose() {
    nameController.dispose();
    maximumController.dispose();
    super.dispose();
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    final maximum = int.parse(maximumController.text);
    Navigator.pop(
      context,
      CharacterResource(
        id:
            widget.resource?.id ??
            'resource-${DateTime.now().microsecondsSinceEpoch}',
        name: nameController.text.trim(),
        maximum: maximum,
        initialValue: maximum,
        rechargePeriod: rechargePeriod,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.resource == null ? 'Add Resource' : 'Edit Resource'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('resource-name'),
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Resource name'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('resource-maximum'),
                controller: maximumController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Maximum uses'),
                validator: (value) {
                  final maximum = int.tryParse(value ?? '');
                  return maximum == null || maximum < 1 || maximum > 20
                      ? '1–20'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RechargePeriod>(
                key: const ValueKey('resource-recharge'),
                initialValue: rechargePeriod,
                decoration: const InputDecoration(labelText: 'Recovers on'),
                items: [
                  for (final period in RechargePeriod.values)
                    DropdownMenuItem(value: period, child: Text(period.label)),
                ],
                onChanged: (value) {
                  if (value != null) rechargePeriod = value;
                },
              ),
              const SizedBox(height: 12),
              Text(
                'New resources begin full.',
                style: Theme.of(context).textTheme.bodySmall,
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
          key: const ValueKey('save-resource'),
          onPressed: save,
          child: Text(
            widget.resource == null ? 'Add Resource' : 'Save Resource',
          ),
        ),
      ],
    );
  }
}
