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

enum ActionSurgeState { available, spent }

class CharacterSession {
  final CharacterState characterState;
  final List<InventoryItem> inventory;
  final List<InventoryItem> archivedInventory;
  final bool isInCombat;
  final int combatRound;
  final int? combatInitiative;
  final String? readiedAction;
  final String? readiedEffect;
  final Set<CombatActionCost> usedCombatActions;
  final ActionSurgeState? actionSurge;
  final bool wildResurgenceUsedThisTurn;
  final bool primalStrikeUsedThisTurn;
  final bool cleaveUsedThisTurn;
  final bool nickUsedThisTurn;
  final bool sneakAttackUsedThisTurn;
  final bool steadyAimAttackPending;
  final bool selfRestorationUsedThisTurn;
  final bool stunningStrikeUsedThisTurn;
  final bool fleetStepUsedThisTurn;
  final bool stepOfWindUsedThisTurn;
  final bool attackRollMadeThisTurn;
  final bool recklessAttackArmed;
  final bool frenzyUsedThisTurn;
  final bool hurlThroughHellUsedThisTurn;
  final int flurryAttacksRemaining;
  final int attackActionAttacksRemaining;
  final List<SessionEvent> timeline;

  const CharacterSession({
    required this.characterState,
    required this.inventory,
    required this.archivedInventory,
    this.isInCombat = false,
    this.combatRound = 1,
    this.combatInitiative,
    this.readiedAction,
    this.readiedEffect,
    this.usedCombatActions = const {},
    this.actionSurge,
    this.wildResurgenceUsedThisTurn = false,
    this.primalStrikeUsedThisTurn = false,
    this.cleaveUsedThisTurn = false,
    this.nickUsedThisTurn = false,
    this.sneakAttackUsedThisTurn = false,
    this.steadyAimAttackPending = false,
    this.selfRestorationUsedThisTurn = false,
    this.stunningStrikeUsedThisTurn = false,
    this.fleetStepUsedThisTurn = false,
    this.stepOfWindUsedThisTurn = false,
    this.attackRollMadeThisTurn = false,
    this.recklessAttackArmed = false,
    this.frenzyUsedThisTurn = false,
    this.hurlThroughHellUsedThisTurn = false,
    this.flurryAttacksRemaining = 0,
    this.attackActionAttacksRemaining = 0,
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
      if (isInCombat) 'actionSurge': ?actionSurge?.name,
      if (isInCombat && wildResurgenceUsedThisTurn)
        'wildResurgenceUsedThisTurn': true,
      if (isInCombat && primalStrikeUsedThisTurn)
        'primalStrikeUsedThisTurn': true,
      if (isInCombat && cleaveUsedThisTurn) 'cleaveUsedThisTurn': true,
      if (isInCombat && nickUsedThisTurn) 'nickUsedThisTurn': true,
      if (isInCombat && sneakAttackUsedThisTurn)
        'sneakAttackUsedThisTurn': true,
      if (isInCombat && fleetStepUsedThisTurn) 'fleetStepUsedThisTurn': true,
      if (isInCombat && stepOfWindUsedThisTurn) 'stepOfWindUsedThisTurn': true,
      if (isInCombat && attackRollMadeThisTurn) 'attackRollMadeThisTurn': true,
      if (isInCombat && recklessAttackArmed) 'recklessAttackArmed': true,
      if (isInCombat && frenzyUsedThisTurn) 'frenzyUsedThisTurn': true,
      if (isInCombat && hurlThroughHellUsedThisTurn)
        'hurlThroughHellUsedThisTurn': true,
      if (isInCombat && stunningStrikeUsedThisTurn)
        'stunningStrikeUsedThisTurn': true,
      if (isInCombat && selfRestorationUsedThisTurn)
        'selfRestorationUsedThisTurn': true,
      if (isInCombat && steadyAimAttackPending) 'steadyAimAttackPending': true,
      if (isInCombat && flurryAttacksRemaining > 0)
        'flurryAttacksRemaining': flurryAttacksRemaining,
      if (isInCombat && attackActionAttacksRemaining > 0)
        'attackActionAttacksRemaining': attackActionAttacksRemaining,
      if (isInCombat) 'combatInitiative': ?combatInitiative,
      if (isInCombat) 'readiedAction': ?readiedAction,
      if (isInCombat && readiedAction != null) 'readiedEffect': ?readiedEffect,
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
      wildResurgenceUsedThisTurn:
          json['wildResurgenceUsedThisTurn'] as bool? ?? false,
      primalStrikeUsedThisTurn:
          json['primalStrikeUsedThisTurn'] as bool? ?? false,
      cleaveUsedThisTurn: json['cleaveUsedThisTurn'] as bool? ?? false,
      nickUsedThisTurn: json['nickUsedThisTurn'] as bool? ?? false,
      sneakAttackUsedThisTurn:
          json['sneakAttackUsedThisTurn'] as bool? ?? false,
      steadyAimAttackPending: json['steadyAimAttackPending'] as bool? ?? false,
      fleetStepUsedThisTurn: json['fleetStepUsedThisTurn'] as bool? ?? false,
      stepOfWindUsedThisTurn: json['stepOfWindUsedThisTurn'] as bool? ?? false,
      attackRollMadeThisTurn: json['attackRollMadeThisTurn'] as bool? ?? false,
      recklessAttackArmed: json['recklessAttackArmed'] as bool? ?? false,
      frenzyUsedThisTurn: json['frenzyUsedThisTurn'] as bool? ?? false,
      hurlThroughHellUsedThisTurn:
          json['hurlThroughHellUsedThisTurn'] as bool? ?? false,
      stunningStrikeUsedThisTurn:
          json['stunningStrikeUsedThisTurn'] as bool? ?? false,
      selfRestorationUsedThisTurn:
          json['selfRestorationUsedThisTurn'] as bool? ?? false,
      flurryAttacksRemaining: ((json['flurryAttacksRemaining'] as int?) ?? 0)
          .clamp(0, 3),
      attackActionAttacksRemaining:
          ((json['attackActionAttacksRemaining'] as int?) ?? 0).clamp(0, 3),
      actionSurge: ActionSurgeState.values
          .where((state) => state.name == json['actionSurge'])
          .firstOrNull,
      readiedAction: json['readiedAction'] as String?,
      readiedEffect: json['readiedEffect'] as String?,
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
