import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/skill.dart';
import 'skill_tile.dart';

class SkillGrid extends StatelessWidget {
  final Character character;
  final ValueChanged<SkillCheck> onSkillTap;
  final ValueChanged<SkillCheck>? onSkillLongPress;

  const SkillGrid({
    super.key,
    required this.character,
    required this.onSkillTap,
    this.onSkillLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final skills = [...character.skills]
      ..sort((left, right) => left.name.compareTo(right.name));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: skills.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 3.4,
      ),
      itemBuilder: (context, index) {
        final check = character.checkFor(skills[index]);

        return SkillTile(
          check: check,
          onTap: () => onSkillTap(check),
          onLongPress: onSkillLongPress == null
              ? null
              : () => onSkillLongPress!(check),
        );
      },
    );
  }
}
