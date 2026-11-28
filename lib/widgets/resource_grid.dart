import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/built_in_class.dart';
import '../models/character_resource.dart';
import '../models/character_state.dart';
import 'resource_card.dart';

class ResourceGrid extends StatelessWidget {
  final Character character;
  final CharacterState characterState;
  final ValueChanged<CharacterResource> onResourceSpend;
  final ValueChanged<CharacterResource> onResourceManage;

  const ResourceGrid({
    super.key,
    required this.character,
    required this.characterState,
    required this.onResourceSpend,
    required this.onResourceManage,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: character.resources.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.8,
      ),
      itemBuilder: (context, index) {
        final resource = character.resources[index];
        final currentValue =
            characterState.resourceValues[resource.id] ?? resource.initialValue;

        return ResourceCard(
          resource: resource,
          currentValue: currentValue,
          rechargeLabel:
              resource.id == divineInterventionResourceId &&
                  characterState.divineInterventionRestsRemaining > 0
              ? '${characterState.divineInterventionRestsRemaining} Long Rests remaining'
              : null,
          onTap: () => onResourceSpend(resource),
          onLongPress: () => onResourceManage(resource),
        );
      },
    );
  }
}
