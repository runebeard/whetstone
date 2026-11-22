import 'package:flutter/material.dart';

import '../models/rest.dart';

class RestConfirmationDialog extends StatefulWidget {
  final RestPlan plan;
  final bool canChangeMastery;
  final bool canUseNaturalRecovery;
  final bool canChooseDruidLand;
  final Map<int, int> availableHitDice;
  final int sorcerousRestorationAmount;
  final ValueChanged<bool>? onSorcerousRestorationChanged;

  const RestConfirmationDialog({
    super.key,
    required this.plan,
    this.canChangeMastery = false,
    this.canUseNaturalRecovery = false,
    this.canChooseDruidLand = false,
    this.availableHitDice = const {},
    this.sorcerousRestorationAmount = 0,
    this.onSorcerousRestorationChanged,
  });

  @override
  State<RestConfirmationDialog> createState() => _RestConfirmationDialogState();
}

class _RestConfirmationDialogState extends State<RestConfirmationDialog> {
  final hitDice = <int, int>{};
  bool useSorcerousRestoration = false;
  RestPlan get plan => widget.plan;
  bool get canConfirm =>
      plan.hasChanges ||
      hitDice.values.any((count) => count > 0) ||
      widget.canChangeMastery ||
      widget.canUseNaturalRecovery ||
      widget.canChooseDruidLand ||
      widget.sorcerousRestorationAmount > 0;

  @override
  Widget build(BuildContext context) {
    final isShortRest = plan.type == RestType.shortRest;
    final dice = widget.availableHitDice.entries
        .where((entry) => entry.value > 0)
        .toList();

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
                  : dice.isNotEmpty
                  ? 'You can spend Hit Dice to recover HP.'
                  : widget.canUseNaturalRecovery
                  ? 'You can recover spell slots with Natural Recovery.'
                  : widget.canChooseDruidLand
                  ? 'You can choose your Circle of the Land terrain.'
                  : widget.sorcerousRestorationAmount > 0
                  ? 'You can recover Sorcery Points with Sorcerous Restoration.'
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
            if (isShortRest && widget.sorcerousRestorationAmount > 0)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Sorcerous Restoration · Recover ${widget.sorcerousRestorationAmount} Sorcery Points',
                ),
                subtitle: const Text('Optional · Once per Long Rest'),
                value: useSorcerousRestoration,
                onChanged: (value) {
                  setState(() => useSorcerousRestoration = value ?? false);
                  widget.onSorcerousRestorationChanged?.call(
                    useSorcerousRestoration,
                  );
                },
              ),
            for (final die in dice)
              if (isShortRest)
                DropdownButtonFormField<int>(
                  key: ValueKey(
                    dice.length == 1
                        ? 'short-rest-hit-dice'
                        : 'short-rest-hit-dice-${die.key}',
                  ),
                  decoration: InputDecoration(
                    labelText:
                        'Spend Hit Dice (${die.value} d${die.key} available)',
                  ),
                  initialValue: 0,
                  items: [
                    for (var count = 0; count <= die.value; count++)
                      DropdownMenuItem(value: count, child: Text('$count')),
                  ],
                  onChanged: (count) =>
                      setState(() => hitDice[die.key] = count ?? 0),
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
