import 'package:flutter/material.dart';

import '../models/character_action.dart';
import '../models/check_roll.dart';

class CombatActionCard extends StatelessWidget {
  final CharacterAction action;
  final bool isPinned;
  final int? attackModifier;
  final String? ammunitionLabel;
  final String? damageFormula;
  final VoidCallback onDetails;
  final VoidCallback? onAttack;
  final VoidCallback? onDamage;
  final VoidCallback? onLongPress;
  final String controlKeyPrefix;

  const CombatActionCard({
    super.key,
    required this.action,
    required this.isPinned,
    required this.onDetails,
    required this.controlKeyPrefix,
    this.attackModifier,
    this.ammunitionLabel,
    this.damageFormula,
    this.onAttack,
    this.onDamage,
    this.onLongPress,
  });

  IconData get actionIcon => switch (action.type) {
    CharacterActionType.weapon => Icons.gavel_outlined,
    CharacterActionType.spell => Icons.auto_awesome_outlined,
    CharacterActionType.feature => Icons.bolt_outlined,
    CharacterActionType.item => Icons.backpack_outlined,
  };

  String get hitLabel {
    final modifier = (attackModifier ?? action.rollModifier)!;
    return modifier >= 0 ? 'Hit +$modifier' : 'Hit −${modifier.abs()}';
  }

  String get damageLabel {
    final formula = (damageFormula ?? action.damageFormula)!.trim();
    final expression = DiceExpression.tryParse(formula);
    return 'Dmg ${expression?.notation ?? formula}';
  }

  String get supportingSummary {
    final normalizedFormula = action.damageFormula == null
        ? null
        : normalize(action.damageFormula!);
    final parts = action.summary.split('•').map((part) => part.trim()).where((
      part,
    ) {
      if (part.isEmpty) return false;
      final lower = part.toLowerCase();
      if ((attackModifier ?? action.rollModifier) != null &&
          (lower.contains('to hit') ||
              lower.contains('attack roll') ||
              lower.contains('spell attack'))) {
        return false;
      }
      if (normalizedFormula != null &&
          normalize(part).contains(normalizedFormula)) {
        return false;
      }
      return true;
    }).toList();
    return parts.join(' • ');
  }

  String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('−', '-')
        .replaceAll(RegExp(r'\s+'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Row(
            children: [
              Icon(actionIcon, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: onDetails,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                action.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isPinned) ...[
                              const SizedBox(width: 4),
                              const Tooltip(
                                message: 'Pinned to Combat',
                                child: Icon(Icons.push_pin, size: 15),
                              ),
                            ],
                          ],
                        ),
                        if (ammunitionLabel case final label?)
                          Text(
                            label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (supportingSummary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            supportingSummary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (onAttack != null)
                OutlinedButton(
                  key: ValueKey('attack-$controlKeyPrefix-${action.actionKey}'),
                  onPressed: onAttack,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(hitLabel),
                ),
              if (onAttack != null && onDamage != null)
                const SizedBox(width: 6),
              if (onDamage != null)
                FilledButton.tonal(
                  key: ValueKey('damage-$controlKeyPrefix-${action.actionKey}'),
                  onPressed: onDamage,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(damageLabel),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
