import 'package:flutter/material.dart';

import '../models/skill.dart';

class SkillTile extends StatelessWidget {
  final SkillCheck check;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const SkillTile({
    super.key,
    required this.check,
    required this.onTap,
    this.onLongPress,
  });

  String get displayModifier {
    return check.modifier > 0 ? '+${check.modifier}' : '${check.modifier}';
  }

  Widget get proficiencyMarker {
    return switch (check.proficiency) {
      SkillProficiency.none => const SizedBox(width: 10),
      SkillProficiency.proficient => const Tooltip(
        message: 'Proficient',
        child: Icon(Icons.circle, size: 8),
      ),
      SkillProficiency.expertise => const Tooltip(
        message: 'Expertise',
        child: Icon(Icons.diamond, size: 12),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            children: [
              proficiencyMarker,
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  check.skill.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayModifier,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    check.skill.ability.shortLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      height: 1,
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
