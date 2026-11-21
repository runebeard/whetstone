import 'package:flutter/material.dart';
import '../models/cunning_strike.dart';

class SneakAttackDialog extends StatefulWidget {
  final String weaponName;
  final String damageType;
  final int rogueLevel;
  final int diceCount;
  final bool critical;
  final bool hasPoisonersKit;

  const SneakAttackDialog({
    super.key,
    required this.weaponName,
    required this.damageType,
    required this.rogueLevel,
    required this.diceCount,
    required this.critical,
    required this.hasPoisonersKit,
  });

  @override
  State<SneakAttackDialog> createState() => _SneakAttackDialogState();
}

class _SneakAttackDialogState extends State<SneakAttackDialog> {
  final selected = <CunningStrike>{};

  @override
  Widget build(BuildContext context) {
    final cost = SneakAttackSelection(selected).diceCost;
    final rolledDice = (widget.diceCount - cost) * (widget.critical ? 2 : 1);
    return AlertDialog(
      title: Text('${widget.weaponName} · Sneak Attack'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'After this attack hits one creature, add $rolledDice'
            'd6 ${widget.damageType} damage. '
            'Confirm that you had Advantage, or an ally able to act was within 5 feet of the target '
            'and you did not have Disadvantage. Only one Sneak Attack is allowed per turn.',
          ),
          if (widget.rogueLevel >= 5) ...[
            const SizedBox(height: 12),
            Text(
              'Cunning Strike · choose up to ${widget.rogueLevel >= 11 ? 2 : 1} effects',
            ),
            const Text(
              'Trade Sneak Attack dice before doubling the remaining dice for a critical hit. Confirm target eligibility at the table.',
            ),
            for (final effect in CunningStrike.values)
              if (widget.rogueLevel >= effect.minimumLevel)
                CheckboxListTile(
                  title: Text(effect.label),
                  subtitle: Text('${effect.diceCost}d6 · ${effect.effect}'),
                  value: selected.contains(effect),
                  onChanged:
                      !selected.contains(effect) &&
                          !SneakAttackSelection({...selected, effect}).isValid(
                            rogueLevel: widget.rogueLevel,
                            sneakDice: widget.diceCount,
                            hasPoisonersKit: widget.hasPoisonersKit,
                          )
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            selected.add(effect);
                          } else {
                            selected.remove(effect);
                          }
                        }),
                ),
            Text(
              'Trade $cost dice · roll $rolledDice'
              'd6',
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, SneakAttackSelection(selected)),
          child: const Text('Eligible hit · Roll Sneak Attack'),
        ),
      ],
    );
  }
}
