import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/character_state.dart';
import '../models/inventory_item.dart';
import '../models/journal_entry.dart';
import '../models/skill.dart';
import '../models/rest.dart';
import '../widgets/combat_summary.dart';
import '../widgets/content_add_buttons.dart';
import '../widgets/inventory_section.dart';
import '../widgets/journal_section.dart';
import '../widgets/skill_grid.dart';
import '../widgets/rest_section.dart';

class ExplorationModeView extends StatelessWidget {
  final Character character;
  final CharacterState characterState;
  final int? formArmourClass;
  final ValueChanged<CharacterState> onCharacterStateChanged;
  final ValueChanged<int>? onDamageTaken;
  final Future<int?> Function(int)? adjustIncomingDamage;
  final List<InventoryItem> inventory;
  final VoidCallback onBeginCombat;
  final VoidCallback? onWholenessOfBody;
  final VoidCallback? onMonkDefense;
  final VoidCallback? onArcaneRecovery;
  final VoidCallback? onMemorizeSpell;
  final VoidCallback? onBardicInspiration;
  final VoidCallback? onPeerlessSkill;
  final bool peerlessSkillAvailable;
  final bool bardicInspirationAvailable;
  final VoidCallback onAddItemFromLibrary;
  final VoidCallback onCreateCustomItem;
  final VoidCallback onRestockItem;
  final ValueChanged<int> onConsumeItem;
  final ValueChanged<int> onEditItem;
  final ValueChanged<SkillCheck> onSkillTap;
  final ValueChanged<RestType> onRestSelected;
  final VoidCallback onAddJournalEntry;
  final ValueChanged<JournalEntry> onJournalEntryTap;
  final ValueChanged<JournalEntry> onJournalEntryLongPress;

  const ExplorationModeView({
    super.key,
    required this.character,
    required this.characterState,
    this.formArmourClass,
    required this.onCharacterStateChanged,
    this.onDamageTaken,
    this.adjustIncomingDamage,
    required this.inventory,
    required this.onBeginCombat,
    this.onWholenessOfBody,
    this.onMonkDefense,
    this.onArcaneRecovery,
    this.onMemorizeSpell,
    this.onBardicInspiration,
    this.onPeerlessSkill,
    this.peerlessSkillAvailable = false,
    this.bardicInspirationAvailable = false,
    required this.onAddItemFromLibrary,
    required this.onCreateCustomItem,
    required this.onRestockItem,
    required this.onConsumeItem,
    required this.onEditItem,
    required this.onSkillTap,
    required this.onRestSelected,
    required this.onAddJournalEntry,
    required this.onJournalEntryTap,
    required this.onJournalEntryLongPress,
  });

  int get totalItemCount {
    return inventory.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalCarryWeight {
    return inventory.fold(0, (sum, item) => sum + item.totalWeight);
  }

  List<InventoryItem> itemsIn(ItemCategory category) {
    return inventory.where((item) => item.category == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Level ${character.level} ${character.characterClass}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          CombatSummary(
            characterState: characterState,
            formArmourClass: formArmourClass,
            additionalResistance: characterState.landResistanceFor(character),
            onChanged: onCharacterStateChanged,
            onDamageTaken: onDamageTaken,
            adjustIncomingDamage: adjustIncomingDamage,
          ),
          const SizedBox(height: 16),
          if (onMonkDefense != null)
            OutlinedButton(
              onPressed: onMonkDefense,
              child: const Text('Monk · Unarmored defense and movement'),
            ),
          if (onWholenessOfBody != null)
            OutlinedButton(
              onPressed: onWholenessOfBody,
              child: const Text('Wholeness of Body'),
            ),
          FilledButton.icon(
            onPressed: onBeginCombat,
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Combat'),
          ),
          if (onMemorizeSpell != null)
            OutlinedButton(
              onPressed: onMemorizeSpell,
              child: const Text('Memorize Spell · After Short Rest'),
            ),
          if (onBardicInspiration != null)
            OutlinedButton(
              onPressed: bardicInspirationAvailable
                  ? onBardicInspiration
                  : null,
              child: const Text('Grant Bardic Inspiration'),
            ),
          if (onPeerlessSkill != null)
            OutlinedButton(
              onPressed: peerlessSkillAvailable ? onPeerlessSkill : null,
              child: const Text('Peerless Skill · Last check or attack'),
            ),
          if (onArcaneRecovery != null)
            OutlinedButton(
              onPressed: onArcaneRecovery,
              child: const Text('Arcane Recovery · After Short Rest'),
            ),
          const SizedBox(height: 24),
          const Text(
            'Skills',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SkillGrid(character: character, onSkillTap: onSkillTap),
          const SizedBox(height: 24),
          const Text(
            'Inventory',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('${inventory.length} unique items'),
          Text('$totalItemCount items carried'),
          Text('${totalCarryWeight.toStringAsFixed(1)} lb total'),
          const SizedBox(height: 12),
          ContentAddButtons(
            libraryKey: 'inventory-library-item',
            customKey: 'inventory-create-item',
            onAddFromLibrary: onAddItemFromLibrary,
            onCreateCustom: onCreateCustomItem,
          ),
          TextButton.icon(
            key: const ValueKey('inventory-restock-item'),
            onPressed: onRestockItem,
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Restock or restore an item'),
          ),
          const SizedBox(height: 16),
          InventorySection(
            icon: Icons.description_outlined,
            title: 'Quest Items',
            items: itemsIn(ItemCategory.quest),
            onConsume: onConsumeItem,
            fullInventory: inventory,
            onEdit: onEditItem,
          ),
          InventorySection(
            icon: Icons.local_drink_outlined,
            title: 'Consumables',
            items: itemsIn(ItemCategory.consumable),
            onConsume: onConsumeItem,
            fullInventory: inventory,
            onEdit: onEditItem,
          ),
          InventorySection(
            icon: Icons.shield_outlined,
            title: 'Equipment',
            items: itemsIn(ItemCategory.equipment),
            onConsume: onConsumeItem,
            fullInventory: inventory,
            onEdit: onEditItem,
          ),
          InventorySection(
            icon: Icons.handyman_outlined,
            title: 'Tools',
            items: itemsIn(ItemCategory.tool),
            onConsume: onConsumeItem,
            fullInventory: inventory,
            onEdit: onEditItem,
          ),
          InventorySection(
            icon: Icons.backpack_outlined,
            title: 'General',
            items: itemsIn(ItemCategory.general),
            onConsume: onConsumeItem,
            fullInventory: inventory,
            onEdit: onEditItem,
          ),
          const SizedBox(height: 20),
          JournalSection(
            entries: character.journalEntries,
            onAdd: onAddJournalEntry,
            onTap: onJournalEntryTap,
            onLongPress: onJournalEntryLongPress,
          ),
          const SizedBox(height: 16),
          RestSection(onRestSelected: onRestSelected),
        ],
      ),
    );
  }
}
