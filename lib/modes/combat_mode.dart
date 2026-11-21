import 'package:flutter/material.dart';

import '../models/ability.dart';
import '../models/check_roll.dart';
import '../models/character.dart';
import '../models/character_action.dart';
import '../models/character_resource.dart';
import '../models/character_session.dart';
import '../models/character_state.dart';
import '../widgets/action_card.dart';
import '../widgets/combat_summary.dart';
import '../widgets/combat_action_card.dart';
import '../widgets/saving_throw_grid.dart';
import '../widgets/resource_grid.dart';

class CombatModeView extends StatelessWidget {
  final Character character;
  final CharacterState characterState;
  final int? formArmourClass;
  final String? attackActionStatus;
  final ValueChanged<CharacterState> onCharacterStateChanged;
  final ValueChanged<int>? onDamageTaken;
  final CharacterState Function(CharacterState, int)? resolveDamage;
  final Future<int?> Function(int)? adjustIncomingDamage;
  final ValueChanged<CharacterAction> onActionTap;
  final ValueChanged<CharacterAction> onActionDetails;
  final ValueChanged<CharacterAction> onAttackRoll;
  final VoidCallback? onUnarmedStrike;
  final VoidCallback? onFlurry;
  final int flurryAttacksRemaining;
  final bool canStartFlurry;
  final VoidCallback? onMonkMovement;
  final VoidCallback? onBonusUnarmedStrike;
  final String? Function(CharacterAction)? ammunitionLabel;
  final ValueChanged<CharacterAction> onDamageRoll;
  final VoidCallback? onDeathSaveRoll;
  final int combatRound;
  final int? combatInitiative;
  final ValueChanged<int>? onInitiativeRecorded;
  final int Function()? rollD20;
  final Set<CombatActionCost> usedCombatActions;
  final ActionSurgeState? actionSurge;
  final VoidCallback? onActionSurgeSpent;
  final void Function(CombatActionCost, bool)? onCombatActionChanged;
  final VoidCallback? onNextTurn;
  final VoidCallback? onEndRage;
  final VoidCallback? onExtendRage;
  final VoidCallback? onRageEnemySave;
  final String? readiedAction;
  final VoidCallback? onChooseCombatAction;
  final VoidCallback? onCunningAction;
  final VoidCallback? onFastHands;
  final VoidCallback? onSteadyAim;
  final VoidCallback? onSelfRestoration;
  final bool sneakAttackUsedThisTurn;
  final VoidCallback? onNewSneakAttackTurn;
  final VoidCallback? onTriggerReadiedAction;
  final ValueChanged<CharacterAction> onTogglePinned;
  final ValueChanged<SavingThrowCheck> onSavingThrowTap;
  final ValueChanged<CharacterResource> onResourceSpend;
  final ValueChanged<CharacterResource> onResourceManage;

  const CombatModeView({
    super.key,
    required this.character,
    required this.characterState,
    this.formArmourClass,
    this.attackActionStatus,
    required this.onCharacterStateChanged,
    this.onDamageTaken,
    this.resolveDamage,
    this.adjustIncomingDamage,
    required this.onActionTap,
    required this.onActionDetails,
    required this.onAttackRoll,
    this.onUnarmedStrike,
    this.onFlurry,
    this.flurryAttacksRemaining = 0,
    this.canStartFlurry = false,
    this.onMonkMovement,
    this.onBonusUnarmedStrike,
    this.ammunitionLabel,
    required this.onDamageRoll,
    this.onDeathSaveRoll,
    this.combatRound = 1,
    this.combatInitiative,
    this.onInitiativeRecorded,
    this.rollD20,
    this.usedCombatActions = const {},
    this.actionSurge,
    this.onActionSurgeSpent,
    this.onCombatActionChanged,
    this.onNextTurn,
    this.onEndRage,
    this.onExtendRage,
    this.onRageEnemySave,
    this.readiedAction,
    this.onChooseCombatAction,
    this.onCunningAction,
    this.onFastHands,
    this.onSteadyAim,
    this.onSelfRestoration,
    this.sneakAttackUsedThisTurn = false,
    this.onNewSneakAttackTurn,
    this.onTriggerReadiedAction,
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
    if (actions.isEmpty && (title != 'Attacks' || onUnarmedStrike == null)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (title == 'Attacks' && onUnarmedStrike != null)
          OutlinedButton(
            onPressed: onUnarmedStrike,
            child: const Text('Unarmed Strike'),
          ),
        if (title == 'Attacks' && onSelfRestoration != null)
          OutlinedButton(
            onPressed: onSelfRestoration,
            child: const Text('Self-Restoration · End of turn'),
          ),
        if (title == 'Attacks' && onBonusUnarmedStrike != null)
          OutlinedButton(
            onPressed:
                !characterState.canConcentrate ||
                    usedCombatActions.contains(CombatActionCost.bonusAction)
                ? null
                : onBonusUnarmedStrike,
            child: const Text('Martial Arts · Bonus Unarmed Strike'),
          ),
        if (title == 'Attacks' && onFlurry != null)
          OutlinedButton(
            onPressed:
                !characterState.canConcentrate ||
                    (flurryAttacksRemaining == 0 &&
                        (!canStartFlurry ||
                            usedCombatActions.contains(
                              CombatActionCost.bonusAction,
                            )))
                ? null
                : onFlurry,
            child: Text(
              flurryAttacksRemaining > 0
                  ? 'Flurry of Blows · $flurryAttacksRemaining strikes remaining'
                  : 'Flurry of Blows (1 Focus)',
            ),
          ),
        if (title == 'Attacks' && onMonkMovement != null)
          OutlinedButton(
            onPressed:
                !characterState.canConcentrate ||
                    usedCombatActions.contains(CombatActionCost.bonusAction)
                ? null
                : onMonkMovement,
            child: const Text('Monk’s Focus · Movement and defense'),
          ),
        if (title == 'Attacks' && attackActionStatus != null)
          Text(attackActionStatus!),
        const SizedBox(height: 8),
        for (final action in actions)
          if (showRollControls &&
              (character.attackModifierFor(action) != null ||
                  action.damageFormula != null))
            CombatActionCard(
              action: action,
              controlKeyPrefix: title.toLowerCase().replaceAll(' ', '-'),
              isPinned: isPinned(action),
              onDetails: () => onActionDetails(action),
              attackModifier: character.attackModifierFor(action),
              ammunitionLabel: ammunitionLabel?.call(action),
              damageFormula: character.damageFormulaFor(
                action,
                raging: characterState.isRaging,
              ),
              onAttack: character.attackModifierFor(action) == null
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
            formArmourClass: formArmourClass,
            additionalResistance: characterState.landResistanceFor(character),
            onChanged: onCharacterStateChanged,
            onDamageTaken: onDamageTaken,
            resolveDamage: resolveDamage,
            adjustIncomingDamage: adjustIncomingDamage,
            onDeathSaveRoll: onDeathSaveRoll,
            onInitiativeRecorded: onInitiativeRecorded,
            rollD20: rollD20,
            initiativeMode:
                character.levelInClass('Barbarian') >= 7 ||
                    character.championLevel >= 3
                ? D20Mode.advantage
                : D20Mode.normal,
          ),
          if (character.savingThrowBonus > 0)
            Text(
              'Aura of Protection +${character.savingThrowBonus} to saves · ${character.levelInClass('Paladin') >= 18 ? 30 : 10}-foot Emanation. Track allies at the table.',
            ),
          const SizedBox(height: 20),
          if (onNextTurn != null) ...[
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Round $combatRound'),
                if (combatInitiative case final initiative?)
                  Text('Initiative $initiative'),
                OutlinedButton(
                  onPressed: onNextTurn,
                  child: const Text('Next Turn'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final cost in CombatActionCost.values)
                  FilterChip(
                    label: Text(cost.label),
                    selected: usedCombatActions.contains(cost),
                    onSelected: (used) =>
                        onCombatActionChanged?.call(cost, used),
                  ),
                if (actionSurge != null)
                  FilterChip(
                    label: const Text('Action Surge action'),
                    selected: actionSurge == ActionSurgeState.spent,
                    onSelected: actionSurge == ActionSurgeState.available
                        ? (_) => onActionSurgeSpent?.call()
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (onExtendRage != null)
            OutlinedButton(
              onPressed:
                  usedCombatActions.contains(CombatActionCost.bonusAction)
                  ? null
                  : onExtendRage,
              child: const Text('Extend Rage'),
            ),
          if (onRageEnemySave != null)
            OutlinedButton(
              onPressed: onRageEnemySave,
              child: const Text('Record enemy save'),
            ),
          if (onEndRage != null)
            OutlinedButton(onPressed: onEndRage, child: const Text('End Rage')),
          if (onChooseCombatAction != null)
            OutlinedButton(
              onPressed:
                  usedCombatActions.contains(CombatActionCost.action) &&
                      actionSurge != ActionSurgeState.available
                  ? null
                  : onChooseCombatAction,
              child: const Text('Use an Action'),
            ),
          if (character.sneakAttackDice > 0) ...[
            Text(
              'Sneak Attack: ${character.sneakAttackDice}d6 · ${sneakAttackUsedThisTurn ? 'used this turn' : 'available after an eligible hit'}',
            ),
            if ((sneakAttackUsedThisTurn ||
                    characterState.activeConditions.contains(
                      steadyAimCondition,
                    )) &&
                onNewSneakAttackTurn != null)
              OutlinedButton(
                onPressed: onNewSneakAttackTurn,
                child: const Text('Track another creature’s turn'),
              ),
          ],
          if (onCunningAction != null)
            OutlinedButton(
              onPressed:
                  !characterState.canConcentrate ||
                      usedCombatActions.contains(CombatActionCost.bonusAction)
                  ? null
                  : onCunningAction,
              child: const Text('Cunning Action'),
            ),
          if (onSteadyAim != null)
            OutlinedButton(
              onPressed:
                  !characterState.canConcentrate ||
                      usedCombatActions.contains(CombatActionCost.bonusAction)
                  ? null
                  : onSteadyAim,
              child: const Text('Steady Aim'),
            ),
          if (characterState.activeConditions.contains(steadyAimCondition))
            const Text('Steady Aim · Speed 0 until this turn ends'),
          if (onFastHands != null)
            OutlinedButton(
              onPressed:
                  !characterState.canConcentrate ||
                      usedCombatActions.contains(CombatActionCost.bonusAction)
                  ? null
                  : onFastHands,
              child: const Text('Fast Hands'),
            ),
          if (readiedAction case final plan?)
            ListTile(
              title: const Text('Readied Action'),
              subtitle: Text(plan),
              trailing: TextButton(
                onPressed: usedCombatActions.contains(CombatActionCost.reaction)
                    ? null
                    : onTriggerReadiedAction,
                child: const Text('Trigger'),
              ),
            ),
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
