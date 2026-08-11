import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/character_session.dart';

class CharacterCard extends StatelessWidget {
  final Character character;
  final CharacterSession session;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const CharacterCard({
    super.key,
    required this.character,
    required this.session,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final state = session.characterState;
    final depletedResources = character.resources.where((resource) {
      final current =
          state.resourceValues[resource.id] ?? resource.initialValue;
      return current == 0;
    }).length;
    final healthColour = _healthColour(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          character.name,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Level ${character.level} '
                          '${character.characterClass}',
                        ),
                      ],
                    ),
                  ),
                  _ActivityChip(isInCombat: session.isInCombat),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _LiveStat(
                      icon: Icons.favorite,
                      label: 'HP',
                      value: '${state.currentHp} / ${state.maxHp}',
                      colour: healthColour,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LiveStat(
                      icon: Icons.shield_outlined,
                      label: 'AC',
                      value: '${state.armourClass}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LiveStat(
                      icon: Icons.bolt,
                      label: 'Init',
                      value: _signed(state.initiativeModifier),
                    ),
                  ),
                ],
              ),
              if (state.temporaryHp > 0 ||
                  state.activeConditions.isNotEmpty ||
                  depletedResources > 0 ||
                  state.currentHp == 0) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (state.temporaryHp > 0)
                      _SummaryPill(
                        icon: Icons.add_circle_outline,
                        label: '${state.temporaryHp} temporary HP',
                      ),
                    if (state.activeConditions.isNotEmpty)
                      _SummaryPill(
                        icon: Icons.warning_amber_rounded,
                        label: state.activeConditions.length == 1
                            ? state.activeConditions.single
                            : '${state.activeConditions.length} conditions',
                        warning: true,
                      ),
                    if (depletedResources > 0)
                      _SummaryPill(
                        icon: Icons.battery_alert_outlined,
                        label: depletedResources == 1
                            ? '1 depleted resource'
                            : '$depletedResources depleted resources',
                        warning: true,
                      ),
                    if (state.currentHp == 0)
                      _SummaryPill(
                        icon: Icons.monitor_heart_outlined,
                        label:
                            'Death saves ${state.deathSaveSuccesses} / '
                            '${state.deathSaveFailures}',
                        warning: true,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _healthColour(BuildContext context) {
    final state = session.characterState;
    if (state.currentHp == 0) {
      return Theme.of(context).colorScheme.error;
    }
    if (state.currentHp * 2 <= state.maxHp) {
      return Colors.orange;
    }
    return Colors.redAccent;
  }

  static String _signed(int value) => value >= 0 ? '+$value' : '$value';
}

class _ActivityChip extends StatelessWidget {
  final bool isInCombat;

  const _ActivityChip({required this.isInCombat});

  @override
  Widget build(BuildContext context) {
    final colour = isInCombat ? Colors.redAccent : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isInCombat ? Icons.shield : Icons.explore_outlined,
            size: 15,
            color: colour,
          ),
          const SizedBox(width: 5),
          Text(
            isInCombat ? 'In Combat' : 'Exploring',
            style: TextStyle(
              color: colour,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? colour;

  const _LiveStat({
    required this.icon,
    required this.label,
    required this.value,
    this.colour,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: colour),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '$label $value',
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool warning;

  const _SummaryPill({
    required this.icon,
    required this.label,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final colour = warning
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colour),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
