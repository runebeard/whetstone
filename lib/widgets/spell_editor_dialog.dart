import 'package:flutter/material.dart';

import '../models/ability.dart';
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
  late bool concentration;
  late bool repeatableEffect;
  late bool rollEffectOnCast;
  late bool ritual;
  Ability? castingAbility;
  bool deriveAttackModifier = false;
  bool scaleCantripDamage = false;
  int additionalDicePerSlotLevel = 0;
  bool addCastingModifierToDamage = false;
  Ability? savingThrowAbility;
  bool halfDamageOnSave = false;
  late final Map<String, TextEditingController> castingDetails;
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
    concentration = widget.spell?.concentration ?? false;
    repeatableEffect = widget.spell?.repeatableEffect ?? false;
    rollEffectOnCast = widget.spell?.rollEffectOnCast ?? false;
    ritual = widget.spell?.ritual ?? false;
    castingAbility = widget.spell?.castingAbility;
    deriveAttackModifier = widget.spell?.deriveAttackModifier ?? false;
    scaleCantripDamage = widget.spell?.scaleCantripDamage ?? false;
    additionalDicePerSlotLevel = widget.spell?.additionalDicePerSlotLevel ?? 0;
    addCastingModifierToDamage =
        widget.spell?.addCastingModifierToDamage ?? false;
    savingThrowAbility = widget.spell?.savingThrowAbility;
    halfDamageOnSave = widget.spell?.halfDamageOnSave ?? false;
    castingDetails = {
      'Casting time': TextEditingController(text: widget.spell?.castingTime),
      'Range': TextEditingController(text: widget.spell?.range),
      'Duration': TextEditingController(text: widget.spell?.duration),
      'Components': TextEditingController(text: widget.spell?.components),
    };
    pinned = widget.initiallyPinned && (level == 0 || prepared);
  }

  @override
  void dispose() {
    nameController.dispose();
    summaryController.dispose();
    rollModifierController.dispose();
    damageController.dispose();
    damageTypeController.dispose();
    for (final controller in castingDetails.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? requiredText(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? castingDetail(String label) {
    final text = castingDetails[label]!.text.trim();
    return text.isEmpty ? null : text;
  }

  Widget abilityPicker(
    String label,
    Ability? selected,
    ValueChanged<Ability?> onChanged,
  ) {
    return DropdownButtonFormField<Ability>(
      decoration: InputDecoration(labelText: label),
      initialValue: selected,
      items: [
        const DropdownMenuItem(child: Text('None')),
        for (final ability in Ability.values)
          DropdownMenuItem(value: ability, child: Text(ability.label)),
      ],
      onChanged: onChanged,
    );
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    final damageExpression = DiceExpression.tryParse(damageController.text);
    final spell = Spell(
      id: widget.spell?.id ?? 'spell-${DateTime.now().microsecondsSinceEpoch}',
      name: nameController.text.trim(),
      level: level,
      prepared: level > 0 && prepared,
      concentration: concentration,
      rollEffectOnCast: damageExpression != null && rollEffectOnCast,
      repeatableEffect:
          concentration && damageExpression != null && repeatableEffect,
      ritual: ritual,
      castingAbility: castingAbility,
      deriveAttackModifier: deriveAttackModifier && castingAbility != null,
      savingThrowAbility: savingThrowAbility,
      halfDamageOnSave: savingThrowAbility != null && halfDamageOnSave,
      castingTime: castingDetail('Casting time'),
      range: castingDetail('Range'),
      duration: castingDetail('Duration'),
      components: castingDetail('Components'),
      summary: summaryController.text.trim(),
      rollModifier: int.tryParse(rollModifierController.text),
      damageFormula: damageExpression?.notation,
      scaleCantripDamage: level == 0 && scaleCantripDamage,
      additionalDicePerSlotLevel: level > 0 && damageExpression != null
          ? additionalDicePerSlotLevel
          : 0,
      addCastingModifierToDamage:
          castingAbility != null && addCastingModifierToDamage,
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
                    key: const ValueKey('spell-concentration'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Concentration'),
                    value: concentration,
                    onChanged: (value) => setState(() => concentration = value),
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
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Casting details'),
                    children: [
                      abilityPicker(
                        'Casting ability',
                        castingAbility,
                        (value) => setState(() => castingAbility = value),
                      ),
                      abilityPicker(
                        'Target saving throw',
                        savingThrowAbility,
                        (value) => setState(() => savingThrowAbility = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Calculate spell attack bonus'),
                        subtitle: const Text(
                          'Uses casting ability and proficiency',
                        ),
                        value: deriveAttackModifier && castingAbility != null,
                        onChanged: castingAbility == null
                            ? null
                            : (value) =>
                                  setState(() => deriveAttackModifier = value),
                      ),
                      SwitchListTile(
                        title: const Text('Add casting modifier to damage'),
                        value:
                            castingAbility != null &&
                            addCastingModifierToDamage,
                        onChanged: castingAbility == null
                            ? null
                            : (value) => setState(
                                () => addCastingModifierToDamage = value,
                              ),
                      ),
                      if (level == 0)
                        SwitchListTile(
                          title: const Text('Scale cantrip damage with level'),
                          subtitle: const Text(
                            'Adds one die at levels 5, 11, and 17',
                          ),
                          value: scaleCantripDamage,
                          onChanged: (value) =>
                              setState(() => scaleCantripDamage = value),
                        ),
                      if (savingThrowAbility != null)
                        SwitchListTile(
                          title: const Text('Half damage on a successful save'),
                          value: halfDamageOnSave,
                          onChanged: (value) =>
                              setState(() => halfDamageOnSave = value),
                        ),
                      if (level > 0 && level < 9)
                        DropdownButtonFormField<int>(
                          initialValue: additionalDicePerSlotLevel.clamp(0, 9),
                          decoration: const InputDecoration(
                            labelText:
                                'Extra damage dice per higher slot level',
                          ),
                          items: [
                            for (var count = 0; count <= 9; count++)
                              DropdownMenuItem(
                                value: count,
                                child: Text('$count'),
                              ),
                          ],
                          onChanged: (count) => setState(
                            () => additionalDicePerSlotLevel = count ?? 0,
                          ),
                        ),
                      if (concentration)
                        SwitchListTile(
                          title: const Text(
                            'Repeat effect while concentrating',
                          ),
                          subtitle: const Text(
                            'Uses the spell’s damage formula',
                          ),
                          value: repeatableEffect,
                          onChanged: (value) =>
                              setState(() => repeatableEffect = value),
                        ),
                      SwitchListTile(
                        key: const ValueKey('spell-roll-effect-on-cast'),
                        title: const Text('Roll damage on cast'),
                        subtitle: const Text(
                          'For spells without an attack roll',
                        ),
                        value: rollEffectOnCast,
                        onChanged: (value) =>
                            setState(() => rollEffectOnCast = value),
                      ),
                      for (final detail in castingDetails.entries)
                        TextFormField(
                          controller: detail.value,
                          decoration: InputDecoration(labelText: detail.key),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ritual'),
                        value: ritual,
                        onChanged: (value) => setState(() => ritual = value),
                      ),
                    ],
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
