import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/weapon.dart';
import '../models/check_roll.dart';

class WeaponEditorDialog extends StatefulWidget {
  final Weapon? weapon;

  const WeaponEditorDialog({super.key, this.weapon});

  @override
  State<WeaponEditorDialog> createState() => _WeaponEditorDialogState();
}

class _WeaponEditorDialogState extends State<WeaponEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController attackController;
  late final TextEditingController damageController;
  late final TextEditingController damageTypeController;
  late final TextEditingController rangeController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.weapon?.name ?? '');
    attackController = TextEditingController(
      text: '${widget.weapon?.attackModifier ?? 0}',
    );
    damageController = TextEditingController(
      text: widget.weapon?.damageFormula ?? '',
    );
    damageTypeController = TextEditingController(
      text:
          widget.weapon?.damageType ??
          (widget.weapon?.damageFormula == null ? widget.weapon?.damage : '') ??
          '',
    );
    rangeController = TextEditingController(text: widget.weapon?.range ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    attackController.dispose();
    damageController.dispose();
    damageTypeController.dispose();
    rangeController.dispose();
    super.dispose();
  }

  String? requiredText(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  void save() {
    if (!formKey.currentState!.validate()) {
      return;
    }
    final damageFormula = DiceExpression.tryParse(
      damageController.text,
    )!.notation;
    final damageType = damageTypeController.text.trim();
    Navigator.pop(
      context,
      Weapon(
        id:
            widget.weapon?.id ??
            'weapon-${DateTime.now().microsecondsSinceEpoch}',
        name: nameController.text.trim(),
        attackModifier: int.parse(attackController.text),
        damage: damageType.isEmpty
            ? damageFormula
            : '$damageFormula $damageType',
        damageFormula: damageFormula,
        damageType: damageType.isEmpty ? null : damageType,
        range: rangeController.text.trim().isEmpty
            ? null
            : rangeController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.weapon == null ? 'Add Weapon' : 'Edit Weapon'),
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
                  key: const ValueKey('weapon-name'),
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Weapon name'),
                  validator: requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('weapon-attack-modifier'),
                  controller: attackController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Attack modifier',
                    hintText: '+5',
                  ),
                  validator: (value) {
                    final modifier = int.tryParse(value ?? '');
                    return modifier == null || modifier < -20 || modifier > 20
                        ? '-20–20'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('weapon-damage'),
                  controller: damageController,
                  decoration: const InputDecoration(
                    labelText: 'Damage roll',
                    hintText: '1d8 + 3',
                  ),
                  validator: (value) =>
                      DiceExpression.tryParse(value ?? '') == null
                      ? 'Use dice notation, e.g. 1d8 + 3'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('weapon-damage-type'),
                  controller: damageTypeController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Damage type (optional)',
                    hintText: 'Slashing',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('weapon-range'),
                  controller: rangeController,
                  decoration: const InputDecoration(
                    labelText: 'Range (optional)',
                    hintText: 'Melee or 80/320 ft',
                  ),
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
          key: const ValueKey('save-weapon'),
          onPressed: save,
          child: Text(widget.weapon == null ? 'Add Weapon' : 'Save Weapon'),
        ),
      ],
    );
  }
}
