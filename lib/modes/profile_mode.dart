import 'package:flutter/material.dart';

import '../models/ability.dart';
import '../models/character.dart';
import '../models/character_action.dart';
import '../models/character_state.dart';
import '../models/feature.dart';
import '../widgets/action_card.dart';
import '../widgets/ability_score_grid.dart';

class ProfileModeView extends StatelessWidget {
  final Character character;
  final ValueChanged<Ability>? onAbilityLongPress;
  final VoidCallback onExitCharacter;
  final CharacterState characterState;
  final ValueChanged<CharacterAction> onFeatureTap;
  final ValueChanged<Feature> onManageFeature;
  final VoidCallback onAddFeature;
  final VoidCallback onAdvanceCharacter;
  final VoidCallback? onScholar;
  final VoidCallback? onBardExpertise;

  const ProfileModeView({
    super.key,
    required this.character,
    this.onAbilityLongPress,
    required this.onExitCharacter,
    required this.characterState,
    required this.onFeatureTap,
    required this.onManageFeature,
    required this.onAddFeature,
    required this.onAdvanceCharacter,
    this.onScholar,
    this.onBardExpertise,
  });

  String get displayProficiencyBonus {
    final bonus = character.proficiencyBonus;
    return bonus > 0 ? '+$bonus' : '$bonus';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(
                character.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Level ${character.level} ${character.characterClass}'
                '${character.subclasses.isEmpty ? '' : '\n${character.subclasses.values.join(' · ')}'}'
                '${character.primalOrder == null ? '' : '\nPrimal Order · ${character.primalOrder!.label}'}',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Proficiency Bonus'),
              trailing: Text(
                displayProficiencyBonus,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: const ValueKey('advance-character'),
              leading: const Icon(Icons.trending_up),
              title: const Text('Advance Character'),
              subtitle: Text(
                'Level ${character.level} • Max HP ${character.maxHp} • '
                'Proficiency $displayProficiencyBonus',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: onAdvanceCharacter,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Features & Traits',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                key: const ValueKey('add-profile-feature'),
                tooltip: 'Add feature or action',
                onPressed: onAddFeature,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            character.features.isEmpty
                ? 'Use + to add a feature or action.'
                : 'Long press a feature to edit, pin, or remove it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (character.features.isEmpty)
            const Card(
              child: ListTile(
                dense: true,
                leading: Icon(Icons.bolt_outlined),
                title: Text('No features or actions added yet'),
                subtitle: Text('Use the + button above to add one.'),
              ),
            )
          else
            for (final feature in character.features)
              ActionCard(
                action: feature,
                isPinned: characterState.pinnedActionKeys.contains(
                  feature.actionKey,
                ),
                onTap: () => onFeatureTap(feature),
                onLongPress: () => onManageFeature(feature),
              ),
          const SizedBox(height: 20),
          const Text(
            'Ability Scores',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          AbilityScoreGrid(
            character: character,
            onAbilityLongPress: onAbilityLongPress,
          ),
          const SizedBox(height: 28),
          if (onScholar != null)
            OutlinedButton(
              onPressed: onScholar,
              child: const Text('Scholar · Choose Expertise'),
            ),
          if (onBardExpertise != null)
            OutlinedButton(
              onPressed: onBardExpertise,
              child: const Text('Bard Expertise · Choose skills'),
            ),
          OutlinedButton.icon(
            onPressed: onExitCharacter,
            icon: const Icon(Icons.logout),
            label: const Text('Exit Character'),
          ),
        ],
      ),
    );
  }
}
