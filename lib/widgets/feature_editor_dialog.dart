import 'package:flutter/material.dart';

import '../models/feature.dart';

class FeatureEditorResult {
  final Feature feature;
  final bool pinned;

  const FeatureEditorResult({required this.feature, required this.pinned});
}

class FeatureEditorDialog extends StatefulWidget {
  final Feature? feature;
  final bool initiallyPinned;

  const FeatureEditorDialog({
    super.key,
    this.feature,
    this.initiallyPinned = false,
  });

  @override
  State<FeatureEditorDialog> createState() => _FeatureEditorDialogState();
}

class _FeatureEditorDialogState extends State<FeatureEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController summaryController;
  late final TextEditingController rollModifierController;
  late bool pinned;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.feature?.name ?? '');
    summaryController = TextEditingController(
      text: widget.feature?.summary ?? '',
    );
    rollModifierController = TextEditingController(
      text: widget.feature?.rollModifier?.toString() ?? '',
    );
    pinned = widget.initiallyPinned;
  }

  @override
  void dispose() {
    nameController.dispose();
    summaryController.dispose();
    rollModifierController.dispose();
    super.dispose();
  }

  String? requiredText(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    final feature = Feature(
      id:
          widget.feature?.id ??
          'feature-${DateTime.now().microsecondsSinceEpoch}',
      name: nameController.text.trim(),
      summary: summaryController.text.trim(),
      rollModifier: int.tryParse(rollModifierController.text),
    );
    Navigator.pop(
      context,
      FeatureEditorResult(feature: feature, pinned: pinned),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.feature == null ? 'Add Feature' : 'Edit Feature'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * 0.48,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('feature-name'),
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Feature name'),
                  validator: requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('feature-summary'),
                  controller: summaryController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'At-a-glance summary',
                    hintText: 'Bonus action • Recover 1d10 + level HP',
                  ),
                  validator: requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('feature-roll-modifier'),
                  controller: rollModifierController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Roll modifier (optional)',
                    hintText: '+5',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final modifier = int.tryParse(value);
                    return modifier == null || modifier < -99 || modifier > 99
                        ? '-99–99'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const ValueKey('feature-pinned'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pin to Combat'),
                  subtitle: const Text('Show in the Combat Actions section'),
                  value: pinned,
                  onChanged: (value) => setState(() => pinned = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-feature'),
          onPressed: save,
          child: Text(widget.feature == null ? 'Add Feature' : 'Save Feature'),
        ),
      ],
    );
  }
}
