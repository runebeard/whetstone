import 'package:flutter/material.dart';

import '../models/character_resource.dart';

class ResourceCard extends StatelessWidget {
  final CharacterResource resource;
  final int currentValue;
  final String? rechargeLabel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ResourceCard({
    super.key,
    required this.resource,
    required this.currentValue,
    this.rechargeLabel,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${resource.name}, $currentValue of ${resource.maximum} remaining, '
          '${rechargeLabel ?? resource.rechargePeriod.label}. Tap to use. Long press to '
          'adjust.',
      child: Card(
        key: ValueKey('resource-${resource.id}-$currentValue'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        resource.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (resource.maximum > 6)
                      Text(
                        '$currentValue/${resource.maximum}',
                        style: const TextStyle(fontSize: 13),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (
                            var index = 0;
                            index < resource.maximum;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(width: 3),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index < currentValue
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  rechargeLabel ?? resource.rechargePeriod.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    height: 1,
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
