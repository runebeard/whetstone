import 'package:flutter/material.dart';

import '../models/rest.dart';

class RestConfirmationDialog extends StatefulWidget {
  final RestPlan plan;
  final int availableHitDice;
  final int hitDie;

  const RestConfirmationDialog({
    super.key,
    required this.plan,
    this.availableHitDice = 0,
    this.hitDie = 8,
  });

  @override
  State<RestConfirmationDialog> createState() => _RestConfirmationDialogState();
}

class _RestConfirmationDialogState extends State<RestConfirmationDialog> {
  int hitDice = 0;
  RestPlan get plan => widget.plan;
  bool get canConfirm => plan.hasChanges || hitDice > 0;

  @override
  Widget build(BuildContext context) {
    final isShortRest = plan.type == RestType.shortRest;

    return AlertDialog(
      title: Text('${plan.type.label}?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              plan.hasChanges
                  ? 'This will recover:'
                  : widget.availableHitDice > 0
                  ? 'You can spend Hit Dice to recover HP.'
                  : 'Nothing currently needs to recover.',
            ),
            if (canConfirm) ...[
              const SizedBox(height: 12),
              for (final change in plan.changes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $change'),
                ),
            ],
            const SizedBox(height: 12),
            if (isShortRest && widget.availableHitDice > 0)
              DropdownButtonFormField<int>(
                key: const ValueKey('short-rest-hit-dice'),
                decoration: InputDecoration(
                  labelText:
                      'Spend Hit Dice (${widget.availableHitDice} d${widget.hitDie} available)',
                ),
                initialValue: 0,
                items: [
                  for (var count = 0; count <= widget.availableHitDice; count++)
                    DropdownMenuItem(value: count, child: Text('$count')),
                ],
                onChanged: (count) => setState(() => hitDice = count ?? 0),
              ),
            Text(
              'Conditions will not be removed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(canConfirm ? 'Cancel' : 'Close'),
        ),
        if (canConfirm)
          FilledButton(
            onPressed: () => Navigator.pop(context, hitDice),
            child: Text('Take ${plan.type.label}'),
          ),
      ],
    );
  }
}
