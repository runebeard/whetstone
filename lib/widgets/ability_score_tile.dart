import 'package:flutter/material.dart';

import '../models/ability.dart';

class AbilityScoreTile extends StatelessWidget {
  final Ability ability;
  final int score;
  final int modifier;
  final VoidCallback? onLongPress;

  const AbilityScoreTile({
    super.key,
    required this.ability,
    required this.score,
    required this.modifier,
    this.onLongPress,
  });

  String get displayModifier => modifier > 0 ? '+$modifier' : '$modifier';

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: ability.label,
      child: Card(
        key: ValueKey('profile-ability-${ability.name}'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  ability.shortLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayModifier,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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
