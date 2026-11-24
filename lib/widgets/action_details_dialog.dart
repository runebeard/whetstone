import 'package:flutter/material.dart';

import '../models/character_action.dart';
import '../models/spell.dart';

class ActionDetailsDialog extends StatelessWidget {
  final CharacterAction action;
  final VoidCallback? onCast;
  final VoidCallback? onCastRitual;
  final VoidCallback? onCastQuickened;
  final VoidCallback? onCastQuickenedFree;
  final int? spellSaveDc;
  final VoidCallback? onRollDamage;
  final String? spellDamageFormula;
  final String? spellRange;
  final String? spellComponents;

  const ActionDetailsDialog({
    super.key,
    required this.action,
    this.onCast,
    this.onCastRitual,
    this.onCastQuickened,
    this.onCastQuickenedFree,
    this.spellSaveDc,
    this.onRollDamage,
    this.spellDamageFormula,
    this.spellRange,
    this.spellComponents,
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
            if (onCastQuickened != null)
              const Text(
                'Quickened Spell: 2 Sorcery Points; this cast uses a Bonus Action.',
              ),
            if (spell != null) ...[
              if (spell.savingThrowAbility case final ability?)
                Text(
                  spellSaveDc == null
                      ? '${ability.label} saving throw'
                      : 'DC $spellSaveDc ${ability.label} saving throw',
                ),
              if (spell.castingTime case final value?)
                Text('Casting time: $value'),
              if ((spellRange ?? spell.range) case final value?)
                Text('Range: $value'),
              if (spell.duration case final value?) Text('Duration: $value'),
              if ((spellComponents ?? spell.components) case final value?)
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
              if (!spell.halfDamageOnSave &&
                  spell.savingThrowAbility != null &&
                  spell.damageFormula != null &&
                  !spell.deriveAttackModifier &&
                  spell.rollModifier == null)
                const Text('No damage on a successful save'),
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
        if (onCastQuickenedFree != null)
          TextButton(
            onPressed: onCastQuickenedFree,
            child: const Text('Quickened Spell · Free cast'),
          ),
        if (onCastQuickened != null)
          TextButton(
            onPressed: onCastQuickened,
            child: const Text('Quickened Spell'),
          ),
        if (onRollDamage != null)
          TextButton(onPressed: onRollDamage, child: const Text('Roll Damage')),
        if (onCastRitual != null)
          TextButton(
            onPressed: onCastRitual,
            child: const Text('Cast as Ritual'),
          ),
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
