import 'package:flutter/material.dart';

import '../models/character_action.dart';
import '../models/spell.dart';

class ActionDetailsDialog extends StatelessWidget {
  final CharacterAction action;
  final VoidCallback? onCast;
  final int? spellSaveDc;
  final VoidCallback? onRollDamage;
  final String? spellDamageFormula;

  const ActionDetailsDialog({
    super.key,
    required this.action,
    this.onCast,
    this.spellSaveDc,
    this.onRollDamage,
    this.spellDamageFormula,
  });

  @override
  Widget build(BuildContext context) {
    final spell = action is Spell ? action as Spell : null;
    return AlertDialog(
      title: Text(action.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(action.summary),
            if (spell != null) ...[
              if (spell.savingThrowAbility case final ability?)
                Text(
                  spellSaveDc == null
                      ? '${ability.label} saving throw'
                      : 'DC $spellSaveDc ${ability.label} saving throw',
                ),
              if (spell.castingTime case final value?)
                Text('Casting time: $value'),
              if (spell.range case final value?) Text('Range: $value'),
              if (spell.duration case final value?) Text('Duration: $value'),
              if (spell.components case final value?)
                Text('Components: $value'),
              if (spell.ritual) const Text('Ritual'),
              if (spell.rollEffectOnCast)
                const Text(
                  'Rolls damage on cast when no attack roll is required',
                ),
              if (spellDamageFormula case final formula?)
                Text('Damage: $formula'),
              if (spell.halfDamageOnSave && spell.savingThrowAbility != null)
                const Text('Half damage on a successful save'),
            ],
            if (spell?.concentration == true) ...[
              const SizedBox(height: 8),
              const Text('Requires concentration'),
              if (spell!.repeatableEffect) const Text('Repeatable effect'),
            ],
          ],
        ),
      ),
      actions: [
        if (onRollDamage != null)
          TextButton(onPressed: onRollDamage, child: const Text('Roll Damage')),
        if (onCast != null)
          TextButton(onPressed: onCast, child: const Text('Cast')),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
