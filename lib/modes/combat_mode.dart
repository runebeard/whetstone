import 'package:flutter/material.dart';

import '../models/ability.dart';
import '../models/character.dart';
import '../models/character_action.dart';
import '../models/character_resource.dart';
import '../models/character_state.dart';
import '../widgets/action_card.dart';
import '../widgets/combat_summary.dart';
import '../widgets/combat_action_card.dart';
import '../widgets/saving_throw_grid.dart';
import '../widgets/resource_grid.dart';

class CombatModeView extends StatelessWidget {
  final Character character;
  final CharacterState characterState;
  final ValueChanged<CharacterState> onCharacterStateChanged;
  final ValueChanged<CharacterAction> onActionTap;
  final ValueChanged<CharacterAction> onActionDetails;
  final ValueChanged<CharacterAction> onAttackRoll;
  final ValueChanged<CharacterAction> onDamageRoll;
  final ValueChanged<CharacterAction> onTogglePinned;
  final ValueChanged<SavingThrowCheck> onSavingThrowTap;
  final ValueChanged<CharacterResource> onResourceSpend;
  final ValueChanged<CharacterResource> onResourceManage;

  const CombatModeView({
    super.key,
    required this.character,
    required this.characterState,
    required this.onCharacterStateChanged,
    required this.onActionTap,
    required this.onActionDetails,
    required this.onAttackRoll,
    required this.onDamageRoll,
    required this.onTogglePinned,
    required this.onSavingThrowTap,
    required this.onResourceSpend,
    required this.onResourceManage,
  });

  bool isPinned(CharacterAction action) {
    return characterState.pinnedActionKeys.contains(action.actionKey);
  }

  Widget buildActionSection(
    String title,
    List<CharacterAction> actions, {
    bool showRollControls = false,
  }) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final action in actions)
          if (showRollControls &&
              (action.rollModifier != null || action.damageFormula != null))
            CombatActionCard(
              action: action,
              controlKeyPrefix: title.toLowerCase().replaceAll(' ', '-'),
              isPinned: isPinned(action),
              onDetails: () => onActionDetails(action),
              onAttack: action.rollModifier == null
                  ? null
                  : () => onAttackRoll(action),
              onDamage: action.damageFormula == null
                  ? null
                  : () => onDamageRoll(action),
              onLongPress: action.type == CharacterActionType.spell
                  ? () => onTogglePinned(action)
                  : null,
            )
          else
            ActionCard(
              action: action,
              isPinned: isPinned(action),
              onTap: () => onActionTap(action),
              onLongPress: () => onTogglePinned(action),
            ),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinnedSpells = character.spells.where(
      (spell) => spell.isAvailableInCombat && isPinned(spell),
    );
    final attacks = <CharacterAction>[...character.weapons, ...pinnedSpells];
    final pinnedFeatures = <CharacterAction>[
      ...character.features.where(isPinned),
    ]..sort((left, right) => left.name.compareTo(right.name));
    final preparedSpells = <CharacterAction>[
      ...character.spells.where((spell) => !spell.isCantrip && spell.prepared),
    ]..sort((left, right) => left.name.compareTo(right.name));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CombatSummary(
            characterState: characterState,
            onChanged: onCharacterStateChanged,
          ),
          const SizedBox(height: 20),
          buildActionSection('Attacks', attacks, showRollControls: true),
          buildActionSection('Actions', pinnedFeatures),
          buildActionSection(
            'Prepared Spells',
            preparedSpells,
            showRollControls: true,
          ),
          if (character.resources.isNotEmpty) ...[
            const Text(
              'Resources',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ResourceGrid(
              character: character,
              characterState: characterState,
              onResourceSpend: onResourceSpend,
              onResourceManage: onResourceManage,
            ),
            const SizedBox(height: 20),
          ],
          const Text(
            'Saving Throws',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SavingThrowGrid(
            character: character,
            onSavingThrowTap: onSavingThrowTap,
          ),
        ],
      ),
    );
  }
}
