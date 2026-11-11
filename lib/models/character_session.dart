import 'character.dart';
import 'character_state.dart';
import 'inventory_item.dart';
import 'session_event.dart';

enum CombatActionCost {
  action('Action'),
  bonusAction('Bonus Action'),
  reaction('Reaction');

  const CombatActionCost(this.label);
  final String label;
}

class CharacterSession {
  final CharacterState characterState;
  final List<InventoryItem> inventory;
  final List<InventoryItem> archivedInventory;
  final bool isInCombat;
  final int combatRound;
  final int? combatInitiative;
  final Set<CombatActionCost> usedCombatActions;
  final List<SessionEvent> timeline;

  const CharacterSession({
    required this.characterState,
    required this.inventory,
    required this.archivedInventory,
    this.isInCombat = false,
    this.combatRound = 1,
    this.combatInitiative,
    this.usedCombatActions = const {},
    this.timeline = const [],
  });

  factory CharacterSession.fromCharacter(Character character) {
    return CharacterSession(
      characterState: CharacterState.fromCharacter(character),
      inventory: [...character.initialInventory],
      archivedInventory: const [],
      isInCombat: false,
    );
  }

  Map<String, Object> toJson() {
    return {
      'characterState': characterState.toJson(),
      'inventory': inventory.map((item) => item.toJson()).toList(),
      'archivedInventory': archivedInventory
          .map((item) => item.toJson())
          .toList(),
      'isInCombat': isInCombat,
      if (isInCombat) 'combatRound': combatRound,
      if (isInCombat) 'combatInitiative': ?combatInitiative,
      if (isInCombat && usedCombatActions.isNotEmpty)
        'usedCombatActions': usedCombatActions
            .map((cost) => cost.name)
            .toList(),
      'timeline': timeline.map((event) => event.toJson()).toList(),
    };
  }

  factory CharacterSession.fromJson(Map<String, Object?> json) {
    List<InventoryItem> items(String key) {
      return (json[key] as List<Object?>)
          .map((item) => InventoryItem.fromJson(item as Map<String, Object?>))
          .toList();
    }

    return CharacterSession(
      characterState: CharacterState.fromJson(
        json['characterState'] as Map<String, Object?>,
      ),
      inventory: items('inventory'),
      archivedInventory: items('archivedInventory'),
      isInCombat: json['isInCombat'] as bool? ?? false,
      combatRound: ((json['combatRound'] as int?) ?? 1).clamp(1, 999999),
      combatInitiative: json['combatInitiative'] as int?,
      usedCombatActions: {
        for (final cost in CombatActionCost.values)
          if ((json['usedCombatActions'] as List? ?? const []).contains(
            cost.name,
          ))
            cost,
      },
      timeline: ((json['timeline'] as List<Object?>?) ?? const [])
          .map((event) => SessionEvent.fromJson(event as Map<String, Object?>))
          .toList(),
    );
  }
}
