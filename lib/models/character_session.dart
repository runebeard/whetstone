import 'character.dart';
import 'character_state.dart';
import 'inventory_item.dart';
import 'session_event.dart';

class CharacterSession {
  final CharacterState characterState;
  final List<InventoryItem> inventory;
  final List<InventoryItem> archivedInventory;
  final bool isInCombat;
  final List<SessionEvent> timeline;

  const CharacterSession({
    required this.characterState,
    required this.inventory,
    required this.archivedInventory,
    this.isInCombat = false,
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
      timeline: ((json['timeline'] as List<Object?>?) ?? const [])
          .map((event) => SessionEvent.fromJson(event as Map<String, Object?>))
          .toList(),
    );
  }
}
