import 'package:flutter/material.dart';

import '../models/ability.dart';
import '../models/character.dart';
import 'ability_score_tile.dart';

class AbilityScoreGrid extends StatelessWidget {
  final Character character;
  final ValueChanged<Ability>? onAbilityLongPress;

  const AbilityScoreGrid({
    super.key,
    required this.character,
    this.onAbilityLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: [
        for (final ability in Ability.values)
          AbilityScoreTile(
            ability: ability,
            score: character.scoreFor(ability),
            modifier: character.abilityModifierFor(ability),
            onLongPress: onAbilityLongPress == null
                ? null
                : () => onAbilityLongPress!(ability),
          ),
      ],
    );
  }
}
