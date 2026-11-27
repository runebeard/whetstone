import 'package:flutter/material.dart';
import '../models/check_roll.dart';

class EmpoweredSpellDialog extends StatefulWidget {
  final DamageRoll roll;
  final int maximum;
  final int pointCost;

  const EmpoweredSpellDialog({
    super.key,
    required this.roll,
    required this.maximum,
    this.pointCost = 1,
  });

  @override
  State<EmpoweredSpellDialog> createState() => _EmpoweredSpellDialogState();
}

class _EmpoweredSpellDialogState extends State<EmpoweredSpellDialog> {
  final selected = <int>{};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Empowered Spell'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${widget.roll.label}: ${widget.roll.expression.notation}. '
          'Spend ${widget.pointCost} Sorcery Points to reroll up to ${widget.maximum} damage dice. '
          'Keep the new results, even if lower. No action is spent.',
        ),
        for (var i = 0; i < widget.roll.dice.length; i++)
          CheckboxListTile(
            key: ValueKey('empowered-die-$i'),
            title: Text('Die ${i + 1}: ${widget.roll.dice[i]}'),
            value: selected.contains(i),
            onChanged: selected.contains(i) || selected.length < widget.maximum
                ? (value) => setState(() {
                    if (value == true) {
                      selected.add(i);
                    } else {
                      selected.remove(i);
                    }
                  })
                : null,
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Keep Damage'),
      ),
      FilledButton(
        onPressed: selected.isEmpty
            ? null
            : () => Navigator.pop(context, {...selected}),
        child: const Text('Reroll Selected Dice'),
      ),
    ],
  );
}
