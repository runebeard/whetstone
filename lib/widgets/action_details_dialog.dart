import 'package:flutter/material.dart';

import '../models/character_action.dart';
import '../models/spell.dart';

class ActionDetailsDialog extends StatelessWidget {
  final CharacterAction action;
  final VoidCallback? onCast;
  final VoidCallback? onCastRitual;
  final VoidCallback? onCastQuickened;
  final VoidCallback? onCastQuickenedFree;
  final VoidCallback? onCastSubtle;
  final VoidCallback? onCastDistant;
  final VoidCallback? onCastExtended;
  final VoidCallback? onCastTransmuted;
  final VoidCallback? onCastTwinned;
  final VoidCallback? onCastCareful;
  final VoidCallback? onCastHeightened;
  final VoidCallback? onArcaneApotheosis;
  final VoidCallback? onQuickenedPair;
  final VoidCallback? onSubtlePair;
  final VoidCallback? onDistantPair;
  final VoidCallback? onExtendedPair;
  final VoidCallback? onEffectPair;
  final bool freeMetamagic;
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
    this.onCastSubtle,
    this.onCastDistant,
    this.onCastExtended,
    this.onCastTransmuted,
    this.onCastTwinned,
    this.onCastCareful,
    this.onCastHeightened,
    this.onArcaneApotheosis,
    this.onQuickenedPair,
    this.onSubtlePair,
    this.onDistantPair,
    this.onExtendedPair,
    this.onEffectPair,
    this.freeMetamagic = false,
    this.spellSaveDc,
    this.onRollDamage,
    this.spellDamageFormula,
    this.spellRange,
    this.spellComponents,
  });

  @override
  Widget build(BuildContext context) {
    final spell = action is Spell ? action as Spell : null;
    final controls = <Widget>[
      if (onSubtlePair != null)
        TextButton(
          onPressed: onSubtlePair,
          child: const Text('Subtle + another option'),
        ),
      if (onDistantPair != null)
        TextButton(
          onPressed: onDistantPair,
          child: const Text('Distant + another option'),
        ),
      if (onExtendedPair != null)
        TextButton(
          onPressed: onExtendedPair,
          child: const Text('Extended + another option'),
        ),
      if (onEffectPair != null)
        TextButton(
          onPressed: onEffectPair,
          child: const Text('Other Metamagic combinations'),
        ),
      if (onQuickenedPair != null)
        TextButton(
          onPressed: onQuickenedPair,
          child: const Text('Quickened + another option'),
        ),
      if (onArcaneApotheosis != null)
        TextButton(
          onPressed: onArcaneApotheosis,
          child: Text(
            freeMetamagic
                ? 'Cancel free Metamagic'
                : 'My turn · Arm free Metamagic',
          ),
        ),
      if (onCastCareful != null)
        TextButton(
          onPressed: onCastCareful,
          child: const Text('Careful Spell'),
        ),
      if (onCastHeightened != null)
        TextButton(
          onPressed: onCastHeightened,
          child: const Text('Heightened Spell'),
        ),
      if (onCastTwinned != null)
        TextButton(
          onPressed: onCastTwinned,
          child: const Text('Twinned Spell'),
        ),
      if (onCastTransmuted != null)
        TextButton(
          onPressed: onCastTransmuted,
          child: const Text('Transmuted Spell'),
        ),
      if (onCastExtended != null)
        TextButton(
          onPressed: onCastExtended,
          child: const Text('Extended Spell'),
        ),
      if (onCastSubtle != null)
        TextButton(onPressed: onCastSubtle, child: const Text('Subtle Spell')),
      if (onCastDistant != null)
        TextButton(
          onPressed: onCastDistant,
          child: const Text('Distant Spell'),
        ),
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
    ];
    return AlertDialog(
      title: Text(action.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(action.summary),
            if (freeMetamagic)
              const Text(
                'Arcane Apotheosis: the next supported Metamagic option is free on this turn.',
              ),
            if (onCastQuickened != null)
              Text(
                'Quickened Spell: ${freeMetamagic ? '0' : '2'} Sorcery Points; this cast uses a Bonus Action.',
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
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: controls),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
