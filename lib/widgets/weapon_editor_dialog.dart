import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/weapon.dart';
import '../models/check_roll.dart';

class WeaponEditorDialog extends StatefulWidget {
  final Weapon? weapon;

  final bool canSelectMastery;
  final bool Function(String)? allowsMasteryFor;

  const WeaponEditorDialog({
    super.key,
    this.weapon,
    this.canSelectMastery = false,
    this.allowsMasteryFor,
  });

  @override
  State<WeaponEditorDialog> createState() => _WeaponEditorDialogState();
}

class _WeaponEditorDialogState extends State<WeaponEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController attackController;
  late final TextEditingController damageController;
  late final TextEditingController versatileDamageController;
  late final TextEditingController damageTypeController;
  late final TextEditingController rangeController;
  late bool usesStrength;
  late final TextEditingController ammunitionController;
  late final TextEditingController propertiesController;
  late final TextEditingController normalRangeController;
  late final TextEditingController longRangeController;
  WeaponCategory? category;
  WeaponMastery? mastery;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.weapon?.name ?? '');
    attackController = TextEditingController(
      text: '${widget.weapon?.attackModifier ?? 0}',
    );
    versatileDamageController = TextEditingController(
      text: widget.weapon?.versatileDamageFormula,
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
    usesStrength = widget.weapon?.usesStrength ?? false;
    ammunitionController = TextEditingController(
      text: widget.weapon?.ammunitionName,
    );
    category = widget.weapon?.category;
    mastery = widget.weapon?.mastery;
    propertiesController = TextEditingController(
      text: widget.weapon?.properties.join(', '),
    );
    normalRangeController = TextEditingController(
      text: widget.weapon?.normalRange?.toString(),
    );
    longRangeController = TextEditingController(
      text: widget.weapon?.longRange?.toString(),
    );
    rangeController = TextEditingController(text: widget.weapon?.range ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    attackController.dispose();
    damageController.dispose();
    versatileDamageController.dispose();
    damageTypeController.dispose();
    rangeController.dispose();
    ammunitionController.dispose();
    propertiesController.dispose();
    normalRangeController.dispose();
    longRangeController.dispose();
    super.dispose();
  }

  String? requiredText(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? validateRange(String? input, {required bool isLong}) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return null;
    final distance = int.tryParse(value);
    if (distance == null || distance <= 0) return 'Enter a positive distance';
    if (isLong) {
      final normal = int.tryParse(normalRangeController.text.trim());
      if (normal == null || distance < normal) {
        return 'Enter at least the normal range';
      }
    }
    return null;
  }

  WeaponMastery? get eligibleMastery {
    final name = nameController.text;
    if (!widget.canSelectMastery ||
        widget.allowsMasteryFor?.call(name) == false) {
      return null;
    }
    return WeaponMastery.forWeapon(name);
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
        usesStrength: usesStrength,
        category: category,
        mastery: eligibleMastery == mastery ? mastery : null,
        properties: propertiesController.text
            .split(',')
            .map((property) => property.trim())
            .where((property) => property.isNotEmpty)
            .toSet()
            .toList(),
        normalRange: int.tryParse(normalRangeController.text.trim()),
        longRange: int.tryParse(longRangeController.text.trim()),
        ammunitionName: ammunitionController.text.trim().isEmpty
            ? null
            : ammunitionController.text.trim(),
        versatileDamageFormula: DiceExpression.tryParse(
          versatileDamageController.text,
        )?.notation,
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
                  onChanged: (_) => setState(() {}),
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Attack uses Strength'),
                  subtitle: const Text('Applies Rage damage when active'),
                  value: usesStrength,
                  onChanged: (value) => setState(() => usesStrength = value),
                ),
                TextFormField(
                  key: const ValueKey('weapon-versatile-damage'),
                  controller: versatileDamageController,
                  decoration: const InputDecoration(
                    labelText: 'Two-handed damage roll (optional)',
                    hintText: '1d10 + 3',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    return DiceExpression.tryParse(value) == null
                        ? 'Use dice notation, e.g. 1d10 + 3'
                        : null;
                  },
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
                  controller: ammunitionController,
                  decoration: const InputDecoration(
                    labelText: 'Ammunition item name (optional)',
                    hintText: 'Arrows',
                  ),
                ),
                const SizedBox(height: 12),
                if (eligibleMastery case final choice?)
                  DropdownButtonFormField<WeaponMastery>(
                    key: ValueKey((choice, nameController.text)),
                    initialValue: mastery == choice ? mastery : null,
                    decoration: const InputDecoration(
                      labelText: 'Weapon Mastery',
                    ),
                    items: [
                      const DropdownMenuItem(child: Text('None')),
                      for (final choice in WeaponMastery.values)
                        DropdownMenuItem(
                          value: choice,
                          child: Text(choice.label),
                        ),
                    ],
                    onChanged: (choice) => setState(() => mastery = choice),
                  ),
                DropdownButtonFormField<WeaponCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Weapon category',
                  ),
                  items: [
                    const DropdownMenuItem(child: Text('Unspecified')),
                    for (final choice in WeaponCategory.values)
                      DropdownMenuItem(
                        value: choice,
                        child: Text(choice.label),
                      ),
                  ],
                  onChanged: (choice) => setState(() => category = choice),
                ),
                TextFormField(
                  controller: propertiesController,
                  decoration: const InputDecoration(
                    labelText: 'Properties (comma-separated)',
                    hintText: 'Finesse, light',
                  ),
                ),
                TextFormField(
                  controller: normalRangeController,
                  decoration: const InputDecoration(
                    labelText: 'Normal range (ft)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => validateRange(value, isLong: false),
                ),
                TextFormField(
                  controller: longRangeController,
                  decoration: const InputDecoration(
                    labelText: 'Long range (ft)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => validateRange(value, isLong: true),
                ),
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
