import 'package:flutter/material.dart';

import '../models/rest.dart';

class RestConfirmationDialog extends StatelessWidget {
  final RestPlan plan;

  const RestConfirmationDialog({super.key, required this.plan});

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
                  : 'Nothing currently needs to recover.',
            ),
            if (plan.hasChanges) ...[
              const SizedBox(height: 12),
              for (final change in plan.changes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $change'),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              isShortRest
                  ? 'HP will not change until hit-dice recovery is added.'
                  : 'Conditions will not be removed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (isShortRest) ...[
              const SizedBox(height: 4),
              Text(
                'Conditions will not be removed.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(plan.hasChanges ? 'Cancel' : 'Close'),
        ),
        if (plan.hasChanges)
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Take ${plan.type.label}'),
          ),
      ],
    );
  }
}
