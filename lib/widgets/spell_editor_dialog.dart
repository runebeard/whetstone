import 'package:flutter/material.dart';

import '../models/spell.dart';
import '../models/check_roll.dart';

class SpellEditorResult {
  final Spell spell;
  final bool pinned;

  const SpellEditorResult({required this.spell, required this.pinned});
}

class SpellEditorDialog extends StatefulWidget {
  final Spell? spell;
  final bool initiallyPinned;

  const SpellEditorDialog({
    super.key,
    this.spell,
    this.initiallyPinned = false,
  });

  @override
  State<SpellEditorDialog> createState() => _SpellEditorDialogState();
}

class _SpellEditorDialogState extends State<SpellEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController summaryController;
  late final TextEditingController rollModifierController;
  late final TextEditingController damageController;
  late final TextEditingController damageTypeController;
  late int level;
  late bool prepared;
  late bool pinned;

  bool get canBePinned => level == 0 || prepared;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.spell?.name ?? '');
    summaryController = TextEditingController(
      text: widget.spell?.summary ?? '',
    );
    rollModifierController = TextEditingController(
      text: widget.spell?.rollModifier?.toString() ?? '',
    );
    damageController = TextEditingController(
      text: widget.spell?.damageFormula ?? '',
    );
    damageTypeController = TextEditingController(
      text: widget.spell?.damageType ?? '',
    );
    level = widget.spell?.level ?? 0;
    prepared = level > 0 && (widget.spell?.prepared ?? false);
    pinned = widget.initiallyPinned && (level == 0 || prepared);
  }

  @override
  void dispose() {
    nameController.dispose();
    summaryController.dispose();
    rollModifierController.dispose();
    damageController.dispose();
    damageTypeController.dispose();
    super.dispose();
  }

  String? requiredText(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    final damageExpression = DiceExpression.tryParse(damageController.text);
    final spell = Spell(
      id: widget.spell?.id ?? 'spell-${DateTime.now().microsecondsSinceEpoch}',
      name: nameController.text.trim(),
      level: level,
      prepared: level > 0 && prepared,
      summary: summaryController.text.trim(),
      rollModifier: int.tryParse(rollModifierController.text),
      damageFormula: damageExpression?.notation,
      damageType:
          damageExpression == null || damageTypeController.text.trim().isEmpty
          ? null
          : damageTypeController.text.trim(),
    );
    Navigator.pop(
      context,
      SpellEditorResult(spell: spell, pinned: pinned && canBePinned),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.spell == null ? 'Add Spell' : 'Edit Spell'),
          leading: IconButton(
            tooltip: 'Cancel',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          actions: [
            TextButton(
              key: const ValueKey('save-spell'),
              onPressed: save,
              child: Text(widget.spell == null ? 'Add Spell' : 'Save Spell'),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('spell-name'),
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Spell name'),
                    validator: requiredText,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: const ValueKey('spell-level'),
                    initialValue: level,
                    decoration: const InputDecoration(labelText: 'Spell level'),
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('Cantrip')),
                      for (var spellLevel = 1; spellLevel <= 9; spellLevel++)
                        DropdownMenuItem(
                          value: spellLevel,
                          child: Text('Level $spellLevel'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        level = value;
                        if (level == 0) {
                          prepared = false;
                        } else if (!prepared) {
                          pinned = false;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('spell-summary'),
                    controller: summaryController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'At-a-glance summary',
                      hintText: 'Action • 120 ft • 1d10 fire',
                    ),
                    validator: requiredText,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('spell-roll-modifier'),
                    controller: rollModifierController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Roll modifier (optional)',
                      hintText: '+7',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final modifier = int.tryParse(value);
                      return modifier == null || modifier < -99 || modifier > 99
                          ? '-99–99'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('spell-damage'),
                    controller: damageController,
                    decoration: const InputDecoration(
                      labelText: 'Damage roll (optional)',
                      hintText: '2d10',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      return DiceExpression.tryParse(value) == null
                          ? 'Use dice notation, e.g. 2d10 or 1d4 + 1'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('spell-damage-type'),
                    controller: damageTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Damage type or note (optional)',
                      hintText: 'Fire or force per dart',
                    ),
                    validator: (value) {
                      if ((value?.trim().isNotEmpty ?? false) &&
                          damageController.text.trim().isEmpty) {
                        return 'Add a damage roll first';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const ValueKey('spell-prepared'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Prepared'),
                    subtitle: Text(
                      level == 0
                          ? 'Cantrips are always available'
                          : 'Show in prepared spells',
                    ),
                    value: level > 0 && prepared,
                    onChanged: level == 0
                        ? null
                        : (value) {
                            setState(() {
                              prepared = value;
                              if (!prepared) pinned = false;
                            });
                          },
                  ),
                  SwitchListTile(
                    key: const ValueKey('spell-pinned'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pin to Combat'),
                    subtitle: Text(
                      canBePinned
                          ? 'Show alongside attacks'
                          : 'Prepare this spell before pinning it',
                    ),
                    value: canBePinned && pinned,
                    onChanged: canBePinned
                        ? (value) => setState(() => pinned = value)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
