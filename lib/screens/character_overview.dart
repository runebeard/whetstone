import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../content/class_spells.dart';
import '../content/wild_shape_forms.dart';
import '../modes/combat_mode.dart';
import '../modes/exploration_mode.dart';
import '../modes/profile_mode.dart';
import '../modes/spellbook_mode.dart';
import '../models/ability.dart';
import '../models/built_in_class.dart';
import '../widgets/stat_edit_dialog.dart';
import '../models/authored_class.dart';
import '../models/character.dart';
import '../models/character_action.dart';
import '../models/check_roll.dart';
import '../models/cunning_strike.dart';
import '../widgets/sneak_attack_dialog.dart';
import '../models/content_pack.dart';
import '../models/character_resource.dart';
import '../models/character_session.dart';
import '../models/character_mode.dart';
import '../models/character_state.dart';
import '../models/feature.dart';
import '../models/inventory_item.dart';
import '../models/journal_entry.dart';
import '../models/library_content_copy.dart';
import '../models/metamagic.dart';
import '../models/rest.dart';
import '../models/roll_notice.dart';
import '../models/skill.dart';
import '../models/spell.dart';
import '../models/spell_slots.dart';
import '../models/weapon.dart';
import '../models/session_event.dart';
import '../services/session_event_recorder.dart';

import '../widgets/dialogue_action_button.dart';
import '../widgets/empowered_spell_dialog.dart';
import '../widgets/ability_score_editor_dialog.dart';
import '../widgets/action_details_dialog.dart';
import '../widgets/feature_editor_dialog.dart';
import '../widgets/journal_entry_details_dialog.dart';
import '../widgets/journal_entry_editor_dialog.dart';
import '../widgets/library_content_picker.dart';
import '../widgets/resource_adjust_dialog.dart';
import '../widgets/rest_confirmation_dialog.dart';
import '../widgets/roll_notice_stack.dart';
import '../widgets/spell_editor_dialog.dart';
import 'character_advancement.dart';
import 'session_timeline.dart';

part 'character_overview_inventory.dart';

class CharacterOverview extends StatefulWidget {
  final Character character;
  final CharacterSession initialSession;
  final ValueChanged<CharacterSession> onSessionChanged;
  final ValueChanged<Character> onCharacterChanged;
  final DiceRoller? diceRoller;
  final List<ContentPack> contentPacks;

  const CharacterOverview({
    super.key,
    required this.character,
    required this.initialSession,
    required this.onSessionChanged,
    required this.onCharacterChanged,
    this.diceRoller,
    this.contentPacks = const [],
  });

  @override
  State<CharacterOverview> createState() => _CharacterOverviewState();
}

class _CharacterOverviewState extends State<CharacterOverview>
    with _InventoryActions {
  late CharacterMode currentMode;
  late int combatRound;
  int? combatInitiative;
  String? readiedAction;
  String? readiedEffect;
  late Set<CombatActionCost> usedCombatActions;
  ActionSurgeState? actionSurge;
  final elementalAffinityUsedSpellIds = <String>{};
  bool wildResurgenceUsedThisTurn = false;
  bool primalStrikeUsedThisTurn = false;
  bool cleaveUsedThisTurn = false;
  bool nickUsedThisTurn = false;
  bool sneakAttackUsedThisTurn = false;
  bool steadyAimAttackPending = false;
  bool selfRestorationUsedThisTurn = false;
  bool stunningStrikeUsedThisTurn = false;
  bool fleetStepUsedThisTurn = false;
  bool stepOfWindUsedThisTurn = false;
  bool attackRollMadeThisTurn = false;
  bool recklessAttackArmed = false;
  bool frenzyUsedThisTurn = false;
  bool hurlThroughHellUsedThisTurn = false;
  bool levelledSpellCastThisTurn = false;
  bool quickenedSpellUsedThisTurn = false;
  String? quickeningSpellId;
  String? modifyingSpellId;
  Metamagic? castingMetamagic;
  String? transmutingDamageType;
  SpellSaveEffect? pendingSaveEffect;
  int flurryAttacksRemaining = 0;
  int attackActionAttacksRemaining = 0;
  CheckRoll? tacticalMindCheck;
  CheckRoll? peerlessSkillRoll;
  CheckRoll? darkLuckRoll;
  late final DiceRoller diceRoller;
  String? pendingCriticalActionKey;
  (String, int)? pendingAttackSlot;
  D20Mode nextRollMode = D20Mode.normal;
  late Character character;
  late CharacterState characterState;
  @override
  late List<InventoryItem> inventory;
  @override
  late List<InventoryItem> archivedInventory;
  late List<SessionEvent> timeline;
  final sessionEventRecorder = SessionEventRecorder();
  bool allowExit = false;
  bool exitPromptVisible = false;
  final List<RollNotice> rollNotices = [];
  final Map<int, List<Timer>> rollNoticeTimers = {};
  int nextRollNoticeId = 0;

  @override
  void initState() {
    super.initState();
    character = widget.character;
    elementalAffinityUsedSpellIds.addAll(
      widget.initialSession.elementalAffinityUsedSpellIds,
    );
    final missingMonkResources =
        [
              ...BuiltInClass.sorcerer
                  .classResources(
                    character.levelInClass('Sorcerer'),
                    subclass: character.subclasses['Sorcerer'],
                    charismaModifier: character.abilityModifierFor(
                      Ability.charisma,
                    ),
                  )
                  .where(
                    (resource) =>
                        resource.id == sorceryPointsResourceId ||
                        resource.id == sorcerousRestorationResourceId ||
                        resource.id == innateSorceryResourceId ||
                        resource.id == dragonWingsResourceId ||
                        resource.id == dragonCompanionResourceId,
                  ),
              ...BuiltInClass.warlock
                  .classResources(
                    character.levelInClass('Warlock'),
                    charismaModifier: character.abilityModifierFor(
                      Ability.charisma,
                    ),
                    subclass: character.subclasses['Warlock'],
                  )
                  .where(
                    (resource) =>
                        resource.id == magicalCunningResourceId ||
                        resource.id == darkOnesOwnLuckResourceId ||
                        resource.id == hurlThroughHellResourceId,
                  ),
              ...BuiltInClass.barbarian
                  .classResources(
                    character.levelInClass('Barbarian'),
                    charismaModifier: 0,
                    subclass: character.subclasses['Barbarian'],
                  )
                  .where(
                    (resource) => resource.id == intimidatingPresenceResourceId,
                  ),
              ...BuiltInClass.wizard.classResources(
                character.levelInClass('Wizard'),
                charismaModifier: 0,
              ),
              ...BuiltInClass.bard.classResources(
                character.levelInClass('Bard'),
                charismaModifier: character.abilityModifierFor(
                  Ability.charisma,
                ),
              ),
              ...BuiltInClass.monk.classResources(
                character.levelInClass('Monk'),
                charismaModifier: 0,
                wisdomModifier: character.abilityModifierFor(Ability.wisdom),
                subclass: character.subclasses['Monk'],
              ),
            ]
            .where(
              (resource) =>
                  !character.resources.any((old) => old.id == resource.id),
            )
            .toList();
    if (missingMonkResources.isNotEmpty) {
      character = character.copyWith(
        resources: [...character.resources, ...missingMonkResources],
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCharacterChanged(character);
      });
    }
    diceRoller = widget.diceRoller ?? RandomDiceRoller();
    characterState = widget.initialSession.characterState
        .normalizeDragonCompanion(character)
        .normalizeSpellDamageTypes(character);
    if (!character.hasDragonWings) {
      characterState = characterState.copyWith(
        activeConditions: {...characterState.activeConditions}
          ..remove(dragonWingsCondition),
      );
    }
    if (character.levelInClass('Sorcerer') < 1) {
      characterState = characterState.copyWith(
        activeConditions: {...characterState.activeConditions}
          ..remove(innateSorceryCondition),
      );
    }
    combatRound = widget.initialSession.isInCombat
        ? widget.initialSession.combatRound
        : 1;
    if (widget.initialSession.isInCombat) {
      levelledSpellCastThisTurn =
          widget.initialSession.levelledSpellCastThisTurn;
      quickenedSpellUsedThisTurn =
          widget.initialSession.quickenedSpellUsedThisTurn;
      frenzyUsedThisTurn = widget.initialSession.frenzyUsedThisTurn;
      hurlThroughHellUsedThisTurn =
          widget.initialSession.hurlThroughHellUsedThisTurn;
      attackRollMadeThisTurn =
          widget.initialSession.attackRollMadeThisTurn ||
          widget.initialSession.attackActionAttacksRemaining > 0;
      recklessAttackArmed =
          widget.initialSession.recklessAttackArmed &&
          !attackRollMadeThisTurn &&
          character.levelInClass('Barbarian') >= 2;
      fleetStepUsedThisTurn = widget.initialSession.fleetStepUsedThisTurn;
      stepOfWindUsedThisTurn = widget.initialSession.stepOfWindUsedThisTurn;
      combatInitiative = widget.initialSession.combatInitiative;
      readiedAction = widget.initialSession.readiedAction;
      readiedEffect = widget.initialSession.readiedEffect;
      actionSurge = widget.initialSession.actionSurge;
      wildResurgenceUsedThisTurn =
          widget.initialSession.wildResurgenceUsedThisTurn;
      primalStrikeUsedThisTurn = widget.initialSession.primalStrikeUsedThisTurn;
      cleaveUsedThisTurn = widget.initialSession.cleaveUsedThisTurn;
      nickUsedThisTurn = widget.initialSession.nickUsedThisTurn;
      sneakAttackUsedThisTurn = widget.initialSession.sneakAttackUsedThisTurn;
      stunningStrikeUsedThisTurn =
          widget.initialSession.stunningStrikeUsedThisTurn;
      selfRestorationUsedThisTurn =
          widget.initialSession.selfRestorationUsedThisTurn;
      flurryAttacksRemaining = widget.initialSession.flurryAttacksRemaining
          .clamp(
            0,
            character.levelInClass('Monk') >= 10
                ? 3
                : character.levelInClass('Monk') >= 2
                ? 2
                : 0,
          );
      steadyAimAttackPending =
          widget.initialSession.steadyAimAttackPending &&
          characterState.activeConditions.contains(steadyAimCondition);
      attackActionAttacksRemaining = widget
          .initialSession
          .attackActionAttacksRemaining
          .clamp(0, character.attacksPerAction - 1);
    }
    usedCombatActions = widget.initialSession.isInCombat
        ? {...widget.initialSession.usedCombatActions}
        : {};
    inventory = [...widget.initialSession.inventory];
    archivedInventory = [...widget.initialSession.archivedInventory];
    timeline = [...widget.initialSession.timeline];
    currentMode = widget.initialSession.isInCombat
        ? CharacterMode.combat
        : CharacterMode.exploration;
    final circleSpells = withClassSpells(character, characterState.druidLand);
    if (circleSpells.length != character.spells.length ||
        circleSpells.any(
          (spell) => !character.spells.any(
            (old) =>
                old.id == spell.id &&
                old.prepared == spell.prepared &&
                (!spell.isClassGrant ||
                    (old.summary == spell.summary &&
                        old.name == spell.name &&
                        old.level == spell.level &&
                        old.damageFormula == spell.damageFormula &&
                        old.damageType == spell.damageType &&
                        old.rollModifier == spell.rollModifier &&
                        old.deriveAttackModifier ==
                            spell.deriveAttackModifier &&
                        old.savingThrowAbility == spell.savingThrowAbility &&
                        old.rollEffectOnCast == spell.rollEffectOnCast &&
                        old.castingAbility == spell.castingAbility &&
                        old.concentration == spell.concentration &&
                        old.castingTime == spell.castingTime &&
                        old.range == spell.range &&
                        old.components == spell.components &&
                        old.duration == spell.duration)),
          ),
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          saveSpellChanges(circleSpells, characterState.pinnedActionKeys);
        }
      });
    }
    if (!characterState.canConcentrate ||
        characterState.spellSaveEffects.length !=
            widget.initialSession.characterState.spellSaveEffects.length ||
        characterState.spellDamageTypes.length !=
            widget.initialSession.characterState.spellDamageTypes.length ||
        characterState.dragonCompanionSpellId !=
            widget.initialSession.characterState.dragonCompanionSpellId ||
        characterState.fiendishResistance != null ||
        characterState.fiendishResilienceAvailable ||
        characterState.activeConditions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) updateCharacterState(characterState);
      });
    }
  }

  @override
  void dispose() {
    for (final timers in rollNoticeTimers.values) {
      for (final timer in timers) {
        timer.cancel();
      }
    }
    super.dispose();
  }

  void publishSession() {
    widget.onSessionChanged(
      CharacterSession(
        elementalAffinityUsedSpellIds: {...elementalAffinityUsedSpellIds},
        characterState: characterState,
        inventory: [...inventory],
        archivedInventory: [...archivedInventory],
        isInCombat: currentMode == CharacterMode.combat,
        combatRound: combatRound,
        combatInitiative: combatInitiative,
        readiedAction: readiedAction,
        readiedEffect: readiedEffect,
        usedCombatActions: {...usedCombatActions},
        actionSurge: actionSurge,
        wildResurgenceUsedThisTurn: wildResurgenceUsedThisTurn,
        primalStrikeUsedThisTurn: primalStrikeUsedThisTurn,
        cleaveUsedThisTurn: cleaveUsedThisTurn,
        nickUsedThisTurn: nickUsedThisTurn,
        sneakAttackUsedThisTurn: sneakAttackUsedThisTurn,
        steadyAimAttackPending: steadyAimAttackPending,
        selfRestorationUsedThisTurn: selfRestorationUsedThisTurn,
        stunningStrikeUsedThisTurn: stunningStrikeUsedThisTurn,
        fleetStepUsedThisTurn: fleetStepUsedThisTurn,
        stepOfWindUsedThisTurn: stepOfWindUsedThisTurn,
        attackRollMadeThisTurn: attackRollMadeThisTurn,
        recklessAttackArmed: recklessAttackArmed,
        frenzyUsedThisTurn: frenzyUsedThisTurn,
        hurlThroughHellUsedThisTurn: hurlThroughHellUsedThisTurn,
        levelledSpellCastThisTurn: levelledSpellCastThisTurn,
        quickenedSpellUsedThisTurn: quickenedSpellUsedThisTurn,
        flurryAttacksRemaining: flurryAttacksRemaining,
        attackActionAttacksRemaining: attackActionAttacksRemaining,
        timeline: [...timeline],
      ),
    );
  }

  @override
  void updateInventory(VoidCallback update) {
    setState(update);
    publishSession();
  }

  void updateCharacterState(CharacterState updatedState) {
    updatedState = updatedState.normalizeSpellDamageTypes(character);
    updatedState = updatedState.normalizeDragonCompanion(character);
    if (!character.hasDragonWings &&
        updatedState.activeConditions.contains(dragonWingsCondition)) {
      updatedState = updatedState.copyWith(
        activeConditions: {...updatedState.activeConditions}
          ..remove(dragonWingsCondition),
      );
    }
    if (character.levelInClass('Sorcerer') < 1 &&
        updatedState.activeConditions.contains(innateSorceryCondition)) {
      updatedState = updatedState.copyWith(
        activeConditions: {...updatedState.activeConditions}
          ..remove(innateSorceryCondition),
      );
    }
    if (!character.hasFiendishResilience &&
        (updatedState.fiendishResistance != null ||
            updatedState.fiendishResilienceAvailable)) {
      updatedState = updatedState.copyWith(
        clearFiendishResistance: true,
        fiendishResilienceAvailable: false,
      );
    }
    if (!updatedState.canConcentrate &&
        updatedState.activeConditions.contains(superiorDefenseCondition)) {
      updatedState = updatedState.copyWith(
        activeConditions: {...updatedState.activeConditions}
          ..remove(superiorDefenseCondition),
      );
    }
    if (!updatedState.canConcentrate) flurryAttacksRemaining = 0;
    if (!updatedState.activeConditions.contains(steadyAimCondition)) {
      steadyAimAttackPending = false;
    }
    if (!updatedState.canConcentrate &&
        updatedState.activeConditions.contains(divineSenseCondition)) {
      updatedState = updatedState.copyWith(
        activeConditions: {...updatedState.activeConditions}
          ..remove(divineSenseCondition),
      );
    }
    if (!updatedState.canConcentrate &&
        updatedState.activeConditions.contains(naturesSanctuaryCondition)) {
      updatedState = updatedState.copyWith(
        activeConditions: {...updatedState.activeConditions}
          ..remove(naturesSanctuaryCondition),
      );
    }
    if (landDruidLevel >= 10 &&
        updatedState.activeConditions.contains('Poisoned')) {
      updatedState = updatedState.copyWith(
        activeConditions: {...updatedState.activeConditions}
          ..remove('Poisoned'),
      );
    }
    if (updatedState.wildShapeForm != null && !updatedState.canConcentrate) {
      updatedState = updatedState.copyWith(clearWildShape: true);
    }
    if (updatedState.isRaging &&
        character.subclasses['Barbarian'] == 'Path of the Berserker' &&
        character.levelInClass('Barbarian') >= 6 &&
        updatedState.activeConditions.any(
          const {'Charmed', 'Frightened'}.contains,
        )) {
      updatedState = updatedState.copyWith(
        activeConditions: {...updatedState.activeConditions}
          ..removeAll(const {'Charmed', 'Frightened'}),
      );
    }
    if ((!updatedState.canConcentrate ||
            updatedState.activeConditions.contains('Grappled') ||
            updatedState.activeConditions.contains('Restrained')) &&
        updatedState.activeConditions.contains(dodgingCondition)) {
      updatedState = updatedState.copyWith(
        activeConditions: {...updatedState.activeConditions}
          ..remove(dodgingCondition),
      );
    }
    final rageEnds = hasPersistentRage
        ? updatedState.currentHp <= 0 ||
              updatedState.activeConditions.contains('Unconscious')
        : !updatedState.canConcentrate;
    if (rageEnds) {
      updatedState = updatedState.endRage();
    }
    if (updatedState.isRaging) {
      updatedState = updatedState.copyWith(clearConcentration: true);
    }
    if (updatedState.concentrationSpellId != null &&
        !updatedState.canConcentrate) {
      updatedState = updatedState.copyWith(clearConcentration: true);
    }
    final events = sessionEventRecorder.stateChanges(
      previous: characterState,
      updated: updatedState,
      resources: character.resources,
    );
    setState(() {
      characterState = updatedState;
      timeline.insertAll(0, events);
      trimTimeline();
    });
    publishSession();
  }

  @override
  void recordSessionEvent(
    SessionEventType type,
    String title, {
    String? detail,
  }) {
    setState(() {
      timeline.insert(
        0,
        sessionEventRecorder.create(type, title, detail: detail),
      );
      trimTimeline();
    });
    publishSession();
  }

  void trimTimeline() {
    const maximumEvents = 200;
    if (timeline.length > maximumEvents) {
      timeline.removeRange(maximumEvents, timeline.length);
    }
  }

  bool canUsePrimalKnowledge(SkillCheck check) =>
      character.levelInClass('Barbarian') >= 3 &&
      characterState.isRaging &&
      const {
        'acrobatics',
        'intimidation',
        'perception',
        'stealth',
        'survival',
      }.contains(check.skill.id);

  Future<bool?> choosePrimalKnowledge(SkillCheck check) async {
    if (!canUsePrimalKnowledge(check)) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Primal Knowledge · ${check.skill.name}'),
        content: const Text(
          'While raging, you can use Strength for this skill check. Keep your skill proficiency or Expertise; Rage grants Advantage to the Strength check. No additional action or Rage use is spent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Use ${check.skill.ability.label}'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use Strength'),
          ),
        ],
      ),
    );
    if (!mounted || !canUsePrimalKnowledge(check)) return null;
    return result;
  }

  Future<void> handleSkillTap(SkillCheck check) async {
    final primal = await choosePrimalKnowledge(check);
    if (!mounted || primal == null) return;
    tacticalMindCheck = rollSkillCheck(check, usePrimalKnowledge: primal);
  }

  CheckRoll rollSkillCheck(
    SkillCheck check, {
    String? label,
    String Function(CheckRoll)? describe,
    bool usePrimalKnowledge = false,
  }) {
    final primal = usePrimalKnowledge && canUsePrimalKnowledge(check);
    final effectiveSkill = primal
        ? Skill(
            id: check.skill.id,
            name: check.skill.name,
            ability: Ability.strength,
          )
        : check.skill;
    final modifier = primal
        ? characterForPhysicalChecks.modifierFor(effectiveSkill)
        : check.modifier;
    final reliable =
        character.levelInClass('Rogue') >= 7 &&
        (check.proficiency != SkillProficiency.none ||
            characterForPhysicalChecks.skillModifierMinimums.containsKey(
              check.skill.id,
            ));
    final jackBonus = characterForPhysicalChecks.jackOfAllTradesBonusFor(
      check.skill,
    );
    return rollCheck(
      label ?? check.skill.name,
      modifier,
      peerlessEligible: true,
      checkAbility: effectiveSkill.ability,
      darkLuckEligible: true,
      minimumRoll: reliable ? 10 : null,
      minimumRollReason: reliable ? 'Reliable Talent' : null,
      describe: jackBonus > 0 || primal
          ? (roll) => [
              if (describe != null) describe(roll),
              if (primal) 'Primal Knowledge · Strength',
              if (jackBonus > 0) 'Jack of All Trades +$jackBonus',
            ].join(' · ')
          : describe,
      hasAdvantage:
          (characterState.isRaging &&
              effectiveSkill.ability == Ability.strength) ||
          (character.championLevel >= 3 && check.skill.id == 'athletics'),
    );
  }

  Future<void> handleAbilityLongPress(Ability ability) async {
    HapticFeedback.mediumImpact();
    final score = await showDialog<int>(
      context: context,
      builder: (context) => AbilityScoreEditorDialog(
        ability: ability,
        currentScore: character.scoreFor(ability),
      ),
    );
    if (!mounted || score == null) return;

    final abilityScores = {...character.abilityScores, ability: score};
    final initiativeModifier = ability == Ability.dexterity
        ? ((score - 10) / 2).floor()
        : characterState.initiativeModifier;
    final updatedCharacter = character.copyWith(
      abilityScores: abilityScores,
      initiativeModifier: initiativeModifier,
    );
    setState(() {
      character = updatedCharacter;
      if (ability == Ability.dexterity) {
        characterState = characterState.copyWith(
          initiativeModifier: initiativeModifier,
        );
      }
    });
    widget.onCharacterChanged(updatedCharacter);
    publishSession();
  }

  Future<void> advanceCharacter() async {
    final editableCharacter = character.copyWith(
      currentHp: characterState.currentHp,
      maxHp: characterState.maxHp,
      armourClass: characterState.armourClass,
      initiativeModifier: characterState.initiativeModifier,
      initiallyPinnedActionKeys: characterState.pinnedActionKeys,
      initialInventory: inventory,
    );
    final authored = AuthoredClass.fromCharacter(editableCharacter);
    if (authored != null && editableCharacter.level != 1) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${authored.name} progression'),
          content: SingleChildScrollView(
            child: Text(_authoredProgressionPreview(authored).join('\n')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    final result = authored == null
        ? await Navigator.push<Character>(
            context,
            MaterialPageRoute(
              builder: (context) => CharacterAdvancement(
                character: editableCharacter,
                contentPacks: widget.contentPacks,
              ),
            ),
          )
        : await confirmAuthoredAdvancement(editableCharacter, authored);
    if (!mounted || result == null) return;
    final circleSpells = withClassSpells(result, characterState.druidLand);
    final removedCircleKeys = {
      for (final spell in result.spells)
        if (spell.isClassGrant &&
            !circleSpells.any((entry) => entry.id == spell.id))
          spell.actionKey,
    };
    final updated = result.copyWith(
      spells: circleSpells,
      initiallyPinnedActionKeys: result.initiallyPinnedActionKeys.difference(
        removedCircleKeys,
      ),
    );

    final classResourceIds =
        authored?.resourcesAt(2).map((resource) => resource.id).toSet() ??
        const <String>{};
    final previousResources = {
      for (final resource in editableCharacter.resources) resource.id: resource,
    };
    final resourceValues = <String, int>{};
    if (updated.levelInClass('Sorcerer') >= 2) {
      for (var level = 1; level <= 5; level++) {
        final count = characterState.resourceValues[fontOfMagicSlotId(level)];
        if (count != null) resourceValues[fontOfMagicSlotId(level)] = count;
      }
    }
    final bonusSlot = characterState.resourceValues[wildResurgenceSlot.id];
    if (bonusSlot != null && updated.levelInClass('Druid') >= 5) {
      resourceValues[wildResurgenceSlot.id] = bonusSlot;
    }
    if (updated.levelInClass('Druid') >= 20) {
      for (final slot in natureMagicianSlots) {
        if (characterState.resourceValues[slot.id] case final remaining?) {
          resourceValues[slot.id] = remaining;
        }
      }
    }
    for (final resource in updated.resources) {
      final previous = previousResources[resource.id];
      final remaining = characterState.resourceValues[resource.id];
      if (spellSlotLevel(resource) != null) {
        resourceValues[resource.id] = remainingSpellSlots(
          resource,
          previousResources.values,
          characterState.resourceValues,
        );
      } else if (classResourceIds.contains(resource.id) ||
          (authored == null &&
              progressingClassResourceIds.contains(resource.id))) {
        final spent = previous == null
            ? resource.maximum - resource.initialValue
            : previous.maximum - (remaining ?? previous.initialValue);
        resourceValues[resource.id] = (resource.maximum - spent)
            .clamp(0, resource.maximum)
            .toInt();
      } else {
        resourceValues[resource.id] = (remaining ?? resource.maximum)
            .clamp(0, resource.maximum)
            .toInt();
      }
    }
    final currentHp = characterState.currentHp > updated.maxHp
        ? updated.maxHp
        : characterState.currentHp;
    final updatedState = characterState.copyWith(
      currentHp: currentHp,
      clearConcentration: !updated.spells.any(
        (spell) => spell.id == characterState.concentrationSpellId,
      ),
      spellSummons: {
        for (final spell in updated.spells)
          spell.id: ?characterState.spellSummons[spell.id],
      },
      maxHp: updated.maxHp,
      clearWildShape: updated.levelInClass('Druid') < 2,
      clearWildCompanion: updated.levelInClass('Druid') < 2,
      initiativeModifier: updated.initiativeModifier,
      pinnedActionKeys: updated.initiallyPinnedActionKeys,
      resourceValues: resourceValues,
    );
    setState(() {
      character = updated;
      characterState = updatedState;
      inventory = [...updated.initialInventory];
    });
    widget.onCharacterChanged(updated);
    publishSession();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${updated.name} updated')));
  }

  Iterable<String> _authoredProgressionPreview(AuthoredClass authored) sync* {
    yield 'Levels 3–20 are preview only.';
    var previousMaxima = <String, int>{};
    for (var level = 2; level <= 20; level++) {
      try {
        final resources = authored.resourcesAt(level);
        final names = authored.featureNamesAt(level);
        final changes = [
          ...names,
          for (final resource in resources)
            if (resource.maximum != previousMaxima[resource.id])
              '${resource.name}: maximum ${resource.maximum}',
        ];
        previousMaxima = {
          for (final resource in resources) resource.id: resource.maximum,
        };
        if (level > 2 && changes.isNotEmpty) {
          yield 'Level $level: ${changes.join(', ')}';
        }
      } catch (_) {
        yield 'Level $level: some authored data could not be read.';
      }
    }
  }

  Future<Character?> confirmAuthoredAdvancement(
    Character current,
    AuthoredClass authored,
  ) async {
    final grants = authored.grants(2);
    final classResources = {
      for (final resource in authored.resourcesAt(2)) resource.id: resource,
    };
    final constitution = ((current.scoreFor(Ability.constitution) - 10) / 2)
        .floor();
    final increase = (authored.hitDie ~/ 2 + 1 + constitution)
        .clamp(1, 999)
        .toInt();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Advance to level 2'),
        content: SingleChildScrollView(
          child: Text(
            [
              'Maximum HP increases by $increase.',
              ...grants.map((feature) => feature.name),
              ...classResources.values.map(
                (resource) => '${resource.name}: maximum ${resource.maximum}',
              ),
              '',
              ..._authoredProgressionPreview(authored),
            ].join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Advance'),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    final existingIds = current.features.map((feature) => feature.id).toSet();
    return current.copyWith(
      level: 2,
      maxHp: current.maxHp + increase,
      resources: [
        for (final resource in current.resources)
          if (!classResources.containsKey(resource.id)) resource,
        ...classResources.values,
      ],
      features: [
        ...current.features,
        for (final feature in grants)
          if (existingIds.add(feature.id)) feature,
      ],
    );
  }

  Future<void> addFeature() async {
    HapticFeedback.mediumImpact();
    final result = await showDialog<FeatureEditorResult>(
      context: context,
      builder: (context) => const FeatureEditorDialog(),
    );
    if (!mounted || result == null) return;

    final pinnedActionKeys = {...characterState.pinnedActionKeys};
    if (result.pinned) pinnedActionKeys.add(result.feature.actionKey);
    final updatedCharacter = character.copyWith(
      features: [...character.features, result.feature],
      initiallyPinnedActionKeys: pinnedActionKeys,
    );
    setState(() {
      character = updatedCharacter;
      characterState = characterState.copyWith(
        pinnedActionKeys: pinnedActionKeys,
      );
    });
    widget.onCharacterChanged(updatedCharacter);
    publishSession();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${result.feature.name} added')));
  }

  Future<LibraryContentSelection?> chooseFromLibrary(LibraryContentType type) {
    return Navigator.push<LibraryContentSelection>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LibraryContentPicker(type: type, packs: widget.contentPacks),
      ),
    );
  }

  Future<void> addInventoryItemFromLibrary() async {
    final selection = await chooseFromLibrary(LibraryContentType.item);
    if (!mounted || selection == null) return;
    final item = LibraryContentCopy.item(selection.content as InventoryItem);
    updateInventory(() => inventory.add(item));
    recordSessionEvent(
      SessionEventType.inventory,
      '${item.name} added',
      detail: 'Added from the Content Library',
    );
  }

  Future<void> addSpellFromLibrary() async {
    final selection = await chooseFromLibrary(LibraryContentType.spell);
    if (!mounted || selection == null) return;
    final spell = LibraryContentCopy.spell(
      selection.content as Spell,
      character.spells,
    );
    if (landDruidLevel >= 3 && characterState.druidLand != null) {
      saveSpellChanges([
        ...character.spells,
        spell,
      ], characterState.pinnedActionKeys);
      return;
    }
    final updatedCharacter = character.copyWith(
      spells: [...character.spells, spell],
    );
    setState(() => character = updatedCharacter);
    widget.onCharacterChanged(updatedCharacter);
  }

  Future<void> createCustomSpell() async {
    final result = await showDialog<SpellEditorResult>(
      context: context,
      builder: (context) => const SpellEditorDialog(),
    );
    if (!mounted || result == null) return;

    final pinnedActionKeys = {...characterState.pinnedActionKeys};
    if (result.pinned) pinnedActionKeys.add(result.spell.actionKey);
    if (landDruidLevel >= 3 && characterState.druidLand != null) {
      saveSpellChanges([...character.spells, result.spell], pinnedActionKeys);
      return;
    }
    final updatedCharacter = character.copyWith(
      spells: [...character.spells, result.spell],
      initiallyPinnedActionKeys: pinnedActionKeys,
    );
    setState(() {
      character = updatedCharacter;
      characterState = characterState.copyWith(
        pinnedActionKeys: pinnedActionKeys,
      );
    });
    widget.onCharacterChanged(updatedCharacter);
    publishSession();
  }

  Spell? get activeConcentrationSpell {
    for (final spell in character.spells) {
      if (spell.id == characterState.concentrationSpellId) return spell;
    }
    return null;
  }

  Future<void> showConcentration(Spell spell) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Concentration'),
        content: Text(
          [
            spell.name,
            if (characterState.concentrationTarget case final target?)
              'Target: $target',
            if (characterState.concentrationSlotLevel case final level?)
              'Slot level $level',
            if (characterState.concentrationTurnsRemaining case final turns?)
              'Turns remaining: $turns',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'end'),
            child: const Text('End Concentration'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'duration'),
            child: const Text('Set Turn Limit'),
          ),
          if (characterState.concentrationTarget == null ||
              spell.canMoveConcentrationTarget)
            TextButton(
              onPressed: () => Navigator.pop(context, 'target'),
              child: Text(
                characterState.concentrationTarget == null
                    ? 'Set Target'
                    : 'Move Target',
              ),
            ),
          if (spell.repeatableEffect && spell.damageFormula != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'repeat'),
              child: const Text('Roll Repeat Effect'),
            ),
          if (spell.isClassGrant &&
              spell.savingThrowAbility != null &&
              spell.damageFormula == null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'target-save'),
              child: const Text('Resolve Target Save'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Set Save DC'),
          ),
        ],
      ),
    );
    if (!mounted ||
        action == null ||
        characterState.concentrationSpellId != spell.id) {
      return;
    }
    if (action == 'target') {
      await setConcentrationTarget(spell);
      return;
    }
    if (action == 'target-save') {
      await resolveCircleControlSave(
        spell,
        characterForPhysicalChecks.spellSaveDc(spell),
      );
      return;
    }
    if (action == 'duration') {
      final turns = await showDialog<int>(
        context: context,
        builder: (context) => StatEditDialog(
          title: 'Turns remaining (0 for no limit)',
          initialValue: characterState.concentrationTurnsRemaining ?? 0,
          allowZero: true,
        ),
      );
      if (mounted &&
          turns != null &&
          characterState.concentrationSpellId == spell.id) {
        updateCharacterState(
          characterState.copyWith(concentrationTurnsRemaining: turns),
        );
      }
      return;
    }
    if (action == 'repeat') {
      await rollDamage(spell, repeatingEffect: true);
      return;
    }
    if (action == 'end') {
      updateCharacterState(characterState.copyWith(clearConcentration: true));
      return;
    }
    final dc = await showDialog<int>(
      context: context,
      builder: (context) => const StatEditDialog(initialValue: 10),
    );
    if (!mounted ||
        dc == null ||
        characterState.concentrationSpellId != spell.id) {
      return;
    }
    resolveConcentrationSave(dc);
  }

  Future<void> setConcentrationTarget(Spell spell) async {
    final previousTarget = characterState.concentrationTarget;
    final moving = previousTarget != null;
    if (moving && !spell.canMoveConcentrationTarget) return;
    final costsBonusAction = moving && currentMode == CharacterMode.combat;
    if (costsBonusAction &&
        usedCombatActions.contains(CombatActionCost.bonusAction)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bonus Action already used this turn.')),
      );
      return;
    }
    var target = previousTarget ?? '';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          moving ? 'Move concentration target' : 'Concentration target',
        ),
        contentTextStyle: Theme.of(context).textTheme.bodyMedium,
        content: TextFormField(
          initialValue: target,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Target name'),
          onChanged: (value) => target = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (target.trim().isNotEmpty) {
                Navigator.pop(context, target.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (mounted &&
        selected != null &&
        selected != previousTarget &&
        characterState.concentrationSpellId == spell.id &&
        characterState.concentrationTarget == previousTarget &&
        (!costsBonusAction ||
            !usedCombatActions.contains(CombatActionCost.bonusAction))) {
      if (costsBonusAction) usedCombatActions.add(CombatActionCost.bonusAction);
      updateCharacterState(
        characterState.copyWith(concentrationTarget: selected),
      );
    }
  }

  bool get hasEvasion =>
      characterState.canConcentrate &&
      (character.levelInClass('Rogue') >= 7 ||
          character.levelInClass('Monk') >= 7);

  bool get canUseUncannyDodge =>
      characterState.canConcentrate &&
      character.levelInClass('Rogue') >= 5 &&
      (currentMode != CharacterMode.combat ||
          !usedCombatActions.contains(CombatActionCost.reaction));

  bool get canUseMonkReaction =>
      characterState.canConcentrate &&
      character.levelInClass('Monk') >= 3 &&
      (currentMode != CharacterMode.combat ||
          !usedCombatActions.contains(CombatActionCost.reaction));

  Future<int?> adjustIncomingDamage(int damage) async {
    if (!hasEvasion && !canUseUncannyDodge && !canUseMonkReaction) {
      return damage;
    }
    var save = 'none';
    var dodge = false;
    var monkReduction = 0;
    final selection = await showDialog<(String, bool, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Damage reduction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Incoming damage: $damage. Use the amount before class reductions; '
                  'resistance is applied afterward. Choose no reduction if these features were already applied.',
                ),
                if (hasEvasion)
                  DropdownButtonFormField<String>(
                    key: ValueKey('evasion-$save'),
                    initialValue: save,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Evasion · Dexterity save',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'none',
                        child: Text(
                          'No Evasion / already applied',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'success',
                        child: Text(
                          'Success · half-damage save',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'failure',
                        child: Text(
                          'Failure · half-damage save',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (value) => update(() {
                      save = value ?? 'none';
                      if (save != 'none') monkReduction = 0;
                      if (save == 'success') dodge = false;
                    }),
                  ),
                if (canUseUncannyDodge)
                  CheckboxListTile(
                    title: const Text('Uncanny Dodge'),
                    subtitle: const Text(
                      'An attacker you can see hit you with an attack. Use your Reaction to halve its damage.',
                    ),
                    value: dodge,
                    onChanged: save == 'success'
                        ? null
                        : (value) => update(() {
                            dodge = value ?? false;
                            if (dodge) monkReduction = 0;
                          }),
                  ),
                if (canUseMonkReaction)
                  DropdownButtonFormField<int>(
                    key: ValueKey('monk-reduction-$monkReduction'),
                    initialValue: monkReduction,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Monk · Reaction reduction',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text(
                          'No Monk reduction / already applied',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(
                          character.levelInClass('Monk') >= 13
                              ? 'Deflect Energy · attack hit'
                              : 'Deflect Attacks · hit includes physical damage',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (character.levelInClass('Monk') >= 4)
                        const DropdownMenuItem(
                          value: 2,
                          child: Text(
                            'Slow Fall · falling damage',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => update(() {
                      monkReduction = value ?? 0;
                      if (monkReduction != 0) {
                        save = 'none';
                        dodge = false;
                      }
                    }),
                  ),
                if (canUseMonkReaction)
                  Text(
                    character.levelInClass('Monk') >= 13
                        ? 'Deflect Energy requires an attack hit of any damage type. Slow Fall requires falling damage. Confirm the trigger at the table; each uses one Reaction.'
                        : 'Deflect Attacks requires an attack hit whose damage includes Bludgeoning, Piercing or Slashing. Confirm the trigger at the table; each Monk reduction uses one Reaction.',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, (save, dodge, monkReduction)),
              child: const Text('Apply damage'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return null;
    final (saveResult, useDodge, monkChoice) = selection;
    if ((saveResult != 'none' && !hasEvasion) ||
        (useDodge && !canUseUncannyDodge) ||
        (monkChoice != 0 &&
            (!canUseMonkReaction ||
                (monkChoice == 2 && character.levelInClass('Monk') < 4)))) {
      return null;
    }
    var amount = damage;
    if (monkChoice != 0) {
      final level = character.levelInClass('Monk');
      final roll = monkChoice == 1 ? diceRoller.rollDie(10) : null;
      final dexterity = character.abilityModifierFor(Ability.dexterity);
      final reduction = roll == null ? 5 * level : roll + dexterity + level;
      amount = (damage - reduction).clamp(0, damage);
      if (currentMode == CharacterMode.combat) {
        usedCombatActions.add(CombatActionCost.reaction);
      }
      recordSessionEvent(
        SessionEventType.combat,
        monkChoice == 2
            ? 'Slow Fall'
            : level >= 13
            ? 'Deflect Energy'
            : 'Deflect Attacks',
        detail:
            '$damage → $amount damage · ${roll == null ? '5 × $level = $reduction' : '1d10 ($roll) + $dexterity Dexterity + $level Monk = $reduction'} reduction · Reaction used.',
      );
      if (monkChoice == 1 && amount == 0) await redirectDeflectedAttack();
    }
    if (saveResult != 'none') {
      amount = saveResult == 'success' ? 0 : amount ~/ 2;
      recordSessionEvent(
        SessionEventType.combat,
        'Evasion',
        detail:
            '$damage → $amount damage · Dexterity save ${saveResult == 'success' ? 'succeeded' : 'failed'} against a half-damage effect.',
      );
    }
    if (useDodge && amount > 0) {
      final before = amount;
      amount ~/= 2;
      if (currentMode == CharacterMode.combat) {
        usedCombatActions.add(CombatActionCost.reaction);
      }
      recordSessionEvent(
        SessionEventType.combat,
        'Uncanny Dodge',
        detail: '$before → $amount attack damage · Reaction used.',
      );
    }
    return amount;
  }

  Future<void> redirectDeflectedAttack() async {
    final focus = character.resources
        .where((resource) => resource.id == focusResourceId)
        .firstOrNull;
    if (focus == null || remainingUses(focus) < 1) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redirect deflected attack'),
        content: const Text(
          'Spend 1 Focus Point to redirect the fully deflected attack. For a melee hit, choose a creature you can see within 5 feet. For a ranged hit, choose one you can see within 60 feet without Total Cover. Confirm eligibility and the original damage type at the table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Focus'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Spend 1 Focus · Redirect'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !characterState.canConcentrate ||
        remainingUses(focus) < 1) {
      return;
    }
    final roll = DiceExpression(
      diceCount: 2,
      dieSides: character.martialArtsDieSides,
      modifier: character.abilityModifierFor(Ability.dexterity),
    ).roll('Deflected attack', diceRoller);
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          focus.id: remainingUses(focus) - 1,
        },
      ),
    );
    final dc =
        8 +
        character.proficiencyBonus +
        character.abilityModifierFor(Ability.wisdom);
    recordSessionEvent(
      SessionEventType.combat,
      'Deflected attack redirected',
      detail:
          'Target makes a DC $dc Dexterity save. On failure: ${roll.total.clamp(0, 999999)} damage (${roll.dice.join(' + ')} + ${roll.expression.modifier} Dexterity), of the original attack’s damage type. On success: no damage. Resolve the target save, immunity and damage at the table.',
    );
  }

  Future<void> promptConcentrationAfterDamage(int damage) async {
    final spell = activeConcentrationSpell;
    if (spell == null) return;
    final dc = (damage ~/ 2).clamp(10, 30);
    final roll = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Concentration Save'),
        content: Text('${spell.name} · DC $dc after $damage damage'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Roll Save'),
          ),
        ],
      ),
    );
    if (mounted &&
        roll == true &&
        characterState.concentrationSpellId == spell.id) {
      resolveConcentrationSave(dc);
    }
  }

  Future<void> resolveConcentrationSave(int dc) async {
    final spellId = characterState.concentrationSpellId;
    final save = characterForPhysicalChecks.savingThrowFor(
      Ability.constitution,
    );
    final mode = characterState.extendedConcentration
        ? nextRollMode.withAdvantage()
        : nextRollMode;
    var roll = rollCheck(
      'Concentration Save',
      save.modifier,
      modeOverride: mode,
      describe: (roll) => roll.total >= dc
          ? 'DC $dc · Concentration maintained'
          : character.levelInClass('Monk') >= 14 || hasDarkOnesOwnLuck
          ? 'DC $dc · Failed concentration save'
          : 'DC $dc · Concentration ended',
    );
    if (roll.total < dc) {
      roll = await rerollWithDisciplinedSurvivor(
        roll,
        mode,
        knownFailure: true,
      );
    }
    if (!mounted || characterState.concentrationSpellId != spellId) return;
    roll = await boostFailedSaveWithDarkLuck(roll, dc: dc);
    if (!mounted || characterState.concentrationSpellId != spellId) return;
    if (roll.total < dc) {
      updateCharacterState(characterState.copyWith(clearConcentration: true));
    }
  }

  Future<void> manageSpell(Spell spell) async {
    HapticFeedback.mediumImpact();
    final isPinned = characterState.pinnedActionKeys.contains(spell.actionKey);
    final canPin = spell.isAvailableInCombat || isPinned;
    final isConcentrating = characterState.concentrationSpellId == spell.id;
    final freeCast = freeCastResource(spell);
    final scrolls = inventory.where((item) {
      final name = item.name.trim().toLowerCase();
      final spellName = spell.name.trim().toLowerCase();
      return item.quantity > 0 &&
          (name == 'spell scroll: $spellName' ||
              name == 'spell scroll ($spellName)' ||
              name == '$spellName spell scroll' ||
              name == 'spell scroll (${spell.levelLabel.toLowerCase()})');
    }).toList();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!spell.isClassGrant)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit Spell'),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(isPinned ? 'Unpin from Combat' : 'Pin to Combat'),
                subtitle: canPin
                    ? null
                    : const Text('Prepare this spell before pinning it'),
                onTap: canPin ? () => Navigator.pop(context, 'pin') : null,
              ),
              ListTile(
                leading: const Icon(Icons.center_focus_strong),
                title: Text(
                  isConcentrating ? 'End Concentration' : 'Track Concentration',
                ),
                onTap: isConcentrating || characterState.canConcentrate
                    ? () => Navigator.pop(context, 'concentration')
                    : null,
              ),
              if (!spell.isCantrip && freeCast == null)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Track One Free Cast per Long Rest'),
                  onTap: () => Navigator.pop(context, 'add-free-cast'),
                ),
              if (freeCast != null)
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(
                    freeCast.id == dragonCompanionResourceId
                        ? 'Dragon Companion · Free cast'
                        : 'Use Free Cast',
                  ),
                  subtitle: Text('${remainingUses(freeCast)} remaining'),
                  onTap:
                      remainingUses(freeCast) > 0 &&
                          characterState.canConcentrate
                      ? () => Navigator.pop(context, 'free-cast')
                      : null,
                ),
              if (character.knowsMetamagic(Metamagic.quickened) &&
                  hasActionCastingTime(spell)) ...[
                ListTile(
                  title: const Text('Quickened Spell'),
                  subtitle: const Text(
                    '2 Sorcery Points · Cast as a Bonus Action',
                  ),
                  onTap: quickenedSpellAvailable(spell)
                      ? () => Navigator.pop(context, 'quickened')
                      : null,
                ),
                if (freeCast != null)
                  ListTile(
                    title: const Text('Quickened Spell · Free cast'),
                    subtitle: Text(
                      '2 Sorcery Points · ${remainingUses(freeCast)} free casts remaining',
                    ),
                    onTap:
                        quickenedSpellAvailable(spell) &&
                            remainingUses(freeCast) > 0
                        ? () => Navigator.pop(context, 'quickened-free')
                        : null,
                  ),
              ],
              for (final option in [
                Metamagic.subtle,
                Metamagic.distant,
                Metamagic.extended,
                Metamagic.transmuted,
                Metamagic.twinned,
                Metamagic.careful,
                Metamagic.heightened,
              ])
                if (character.knowsMetamagic(option))
                  ListTile(
                    title: Text(option.label),
                    subtitle: const Text(
                      '1 Sorcery Point · Preview this casting',
                    ),
                    onTap: simpleMetamagicAvailable(spell, option)
                        ? () => Navigator.pop(context, option.name)
                        : null,
                  ),
              if (scrolls.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Cast from Scroll'),
                  subtitle: Text(
                    scrolls.length == 1
                        ? scrolls.single.name
                        : 'Choose a scroll from inventory',
                  ),
                  onTap: () => Navigator.pop(context, 'scroll'),
                ),
              if (characterState.spellSummons[spell.id] case final summon?)
                ListTile(
                  title: const Text('Dismiss Summon'),
                  subtitle: Text(summon),
                  onTap: () => Navigator.pop(context, 'dismiss-summon'),
                )
              else if (!spell.concentration || isConcentrating)
                ListTile(
                  title: const Text('Track Summon'),
                  onTap: () => Navigator.pop(context, 'track-summon'),
                ),
              if (spell.isCantrip &&
                  !spell.isClassGrant &&
                  character.levelInClass('Druid') > 0)
                ListTile(
                  title: Text(
                    character.druidCantripIds.contains(spell.id)
                        ? 'Unmark as Druid Cantrip'
                        : 'Mark as Druid Cantrip',
                  ),
                  onTap: () => Navigator.pop(context, 'druid-cantrip'),
                ),
              if (!spell.isClassGrant)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove Spell'),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
              if (!spell.isClassGrant &&
                  character.levelInClass('Sorcerer') >= 1 &&
                  !character.isDraconicClassSpell(spell))
                ListTile(
                  title: Text(
                    character.sorcererSpellIds.contains(spell.id)
                        ? 'Unmark as Sorcerer Spell'
                        : 'Mark as Sorcerer Spell',
                  ),
                  onTap: () => Navigator.pop(context, 'sorcerer-spell'),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'edit':
        await editSpell(spell);
      case 'pin':
        togglePinnedAction(spell);
      case 'add-free-cast':
        addFreeCast(spell);
      case 'free-cast':
        await castSpell(spell, useFreeCast: true);
      case 'druid-cantrip':
        final ids = {...character.druidCantripIds};
        if (!ids.remove(spell.id)) ids.add(spell.id);
        final updated = character.copyWith(druidCantripIds: ids);
        setState(() => character = updated);
        widget.onCharacterChanged(updated);
      case 'sorcerer-spell':
        final ids = {...character.sorcererSpellIds};
        if (!ids.remove(spell.id)) ids.add(spell.id);
        final updated = character.copyWith(sorcererSpellIds: ids);
        setState(() => character = updated);
        widget.onCharacterChanged(updated);
      case 'scroll':
        final scrollName = scrolls.length == 1
            ? scrolls.single.name
            : await showDialog<String>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Choose a Spell Scroll'),
                  children: [
                    for (final item in scrolls)
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, item.name),
                        child: Text(item.name),
                      ),
                  ],
                ),
              );
        if (mounted && scrollName != null) {
          await castFromScroll(spell, scrollName);
        }
      case 'track-summon':
        await trackSpellSummon(spell);
      case 'dismiss-summon':
        final summons = {...characterState.spellSummons}..remove(spell.id);
        updateCharacterState(
          characterState.dragonCompanionSpellId == spell.id
              ? characterState.endDragonCompanion()
              : characterState.copyWith(spellSummons: summons),
        );
        recordSessionEvent(
          SessionEventType.combat,
          '${spell.name} summon dismissed',
        );
      case 'quickened':
        await castQuickenedSpell(spell);
      case 'quickened-free':
        await castQuickenedSpell(spell, useFreeCast: true);
      case 'subtle':
        await castSimpleMetamagic(spell, Metamagic.subtle);
      case 'distant':
        await castSimpleMetamagic(spell, Metamagic.distant);
      case 'extended':
        await castSimpleMetamagic(spell, Metamagic.extended);
      case 'transmuted':
        await castSimpleMetamagic(spell, Metamagic.transmuted);
      case 'twinned':
        await castSimpleMetamagic(spell, Metamagic.twinned);
      case 'careful':
        await castSimpleMetamagic(spell, Metamagic.careful);
      case 'heightened':
        await castSimpleMetamagic(spell, Metamagic.heightened);
      case 'concentration':
        updateCharacterState(
          characterState.copyWith(
            concentrationSpellId: spell.id,
            clearConcentration: isConcentrating,
          ),
        );
      case 'remove':
        await removeSpell(spell);
    }
  }

  Future<void> castFromScroll(Spell spell, String scrollName) async {
    if (!canSpendSpellAction(spell, fromScroll: true)) return;
    final checkDc = 10 + spell.level;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cast ${spell.name} from a scroll?'),
        content: Text(
          'Confirm that this scroll contains ${spell.name} and that the spell '
          'is on your class list. If it is above the level you can normally '
          'cast, make a DC $checkDc spellcasting ability check. '
          'Scroll save DC ${spell.scrollSaveDc}, attack bonus +${spell.scrollAttackBonus}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'failed'),
            child: const Text('Failed check'),
          ),
          if (!spell.isCantrip)
            TextButton(
              onPressed: () => Navigator.pop(context, 'roll'),
              child: const Text('Roll Ability Check'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'cast'),
            child: const Text('Cast from Scroll'),
          ),
        ],
      ),
    );
    if (!mounted ||
        result == null ||
        !canSpendSpellAction(spell, fromScroll: true)) {
      return;
    }
    var canCast = result == 'cast';
    if (result == 'roll') {
      final ability =
          spell.castingAbility ??
          await showDialog<Ability>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Spellcasting ability'),
              children: [
                for (final ability in [
                  Ability.intelligence,
                  Ability.wisdom,
                  Ability.charisma,
                ])
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, ability),
                    child: Text(ability.label),
                  ),
              ],
            ),
          );
      if (!mounted ||
          ability == null ||
          !canSpendSpellAction(spell, fromScroll: true)) {
        return;
      }
      canCast =
          rollCheck(
            '${spell.name} Scroll Check',
            character.abilityModifierFor(ability),
            describe: (roll) =>
                'DC $checkDc · ${roll.total >= checkDc ? 'Success' : 'Failure'}',
          ).total >=
          checkDc;
    }
    if (canCast) {
      await castSpell(spell, scrollName: scrollName);
    } else if (spendInventoryItem(scrollName)) {
      trackSpellAction(spell, newCast: false);
      recordSessionEvent(
        SessionEventType.combat,
        'Spell scroll failed',
        detail: spell.name,
      );
    }
  }

  Future<void> trackSpellSummon(Spell spell) async {
    var name = '';
    final summon = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Track summon for ${spell.name}'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Creature or group name',
          ),
          maxLength: 80,
          onChanged: (value) => name = value.trim(),
          onSubmitted: (_) {
            if (name.isNotEmpty) Navigator.pop(context, name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.isNotEmpty) Navigator.pop(context, name);
            },
            child: const Text('Track'),
          ),
        ],
      ),
    );
    if (!mounted ||
        summon == null ||
        (spell.concentration &&
            characterState.concentrationSpellId != spell.id)) {
      return;
    }
    updateCharacterState(
      characterState.copyWith(
        spellSummons: {...characterState.spellSummons, spell.id: summon},
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      '${spell.name} summon tracked',
      detail: summon,
    );
  }

  Future<void> editSpell(Spell spell) async {
    final result = await showDialog<SpellEditorResult>(
      context: context,
      builder: (context) => SpellEditorDialog(
        spell: spell,
        initiallyPinned: characterState.pinnedActionKeys.contains(
          spell.actionKey,
        ),
      ),
    );
    if (!mounted || result == null) return;

    final pinnedActionKeys = {...characterState.pinnedActionKeys};
    if (result.pinned) {
      pinnedActionKeys.add(result.spell.actionKey);
    } else {
      pinnedActionKeys.remove(spell.actionKey);
    }
    final updatedSpells = [
      for (final current in character.spells)
        if (current.id == spell.id) result.spell else current,
    ];
    saveSpellChanges(updatedSpells, pinnedActionKeys);
  }

  Future<void> removeSpell(Spell spell) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Spell?'),
        content: Text('Remove ${spell.name} from this character?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-remove-spellbook-spell'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final pinnedActionKeys = {...characterState.pinnedActionKeys}
      ..remove(spell.actionKey);
    saveSpellChanges(
      character.spells.where((current) => current.id != spell.id).toList(),
      pinnedActionKeys,
    );
  }

  void saveSpellChanges(
    List<Spell> requested,
    Set<String> requestedPins, {
    DruidLand? land,
  }) {
    final spells = withClassSpells(
      character.copyWith(spells: requested),
      land ?? characterState.druidLand,
    );
    final removedKeys = {
      for (final spell in character.spells)
        if (!spells.any((entry) => entry.id == spell.id)) spell.actionKey,
    };
    final pinnedActionKeys = requestedPins.difference(removedKeys);
    final removedFreeCastIds = {
      for (final spell in character.spells)
        if (!spells.any((remaining) => remaining.id == spell.id))
          freeCastId(spell),
    };
    final updatedCharacter = character.copyWith(
      resources: [
        for (final resource in character.resources)
          if (!removedFreeCastIds.contains(resource.id)) resource,
      ],
      spells: spells,
      sorcererSpellIds: {
        for (final spell in spells)
          if (character.sorcererSpellIds.contains(spell.id)) spell.id,
      },
      druidCantripIds: {
        for (final spell in spells)
          if (spell.isCantrip && character.druidCantripIds.contains(spell.id))
            spell.id,
      },
      initiallyPinnedActionKeys: pinnedActionKeys,
    );
    final updatedState = characterState.copyWith(
      spellDamageTypes: {
        for (final spell in spells)
          if (character.spells.any(
            (old) => old.id == spell.id && old.damageType == spell.damageType,
          ))
            spell.id: ?characterState.spellDamageTypes[spell.id],
      },
      druidLand: land,
      clearConcentration: !spells.any(
        (spell) => spell.id == characterState.concentrationSpellId,
      ),
      spellSummons: {
        for (final spell in spells)
          spell.id: ?characterState.spellSummons[spell.id],
      },
      resourceValues: {
        for (final entry in characterState.resourceValues.entries)
          if (!removedFreeCastIds.contains(entry.key)) entry.key: entry.value,
      },
      pinnedActionKeys: pinnedActionKeys,
    );
    if (pendingCriticalActionKey?.startsWith('spell:') == true &&
        !spells.any((spell) => spell.actionKey == pendingCriticalActionKey)) {
      pendingCriticalActionKey = null;
    }
    character = updatedCharacter;
    widget.onCharacterChanged(updatedCharacter);
    updateCharacterState(updatedState);
  }

  Future<void> manageFeature(Feature feature) async {
    HapticFeedback.mediumImpact();
    final isPinned = characterState.pinnedActionKeys.contains(
      feature.actionKey,
    );
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Feature'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(isPinned ? 'Unpin from Combat' : 'Pin to Combat'),
              onTap: () => Navigator.pop(context, 'pin'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove Feature'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'edit':
        await editFeature(feature);
      case 'pin':
        togglePinnedAction(feature);
      case 'remove':
        await removeFeature(feature);
    }
  }

  Future<void> editFeature(Feature feature) async {
    final result = await showDialog<FeatureEditorResult>(
      context: context,
      builder: (context) => FeatureEditorDialog(
        feature: feature,
        initiallyPinned: characterState.pinnedActionKeys.contains(
          feature.actionKey,
        ),
      ),
    );
    if (!mounted || result == null) return;

    final pinnedActionKeys = {...characterState.pinnedActionKeys};
    if (result.pinned) {
      pinnedActionKeys.add(result.feature.actionKey);
    } else {
      pinnedActionKeys.remove(result.feature.actionKey);
    }
    final updatedFeatures = [
      for (final current in character.features)
        if (current.id == feature.id) result.feature else current,
    ];
    saveFeatureChanges(updatedFeatures, pinnedActionKeys);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${result.feature.name} updated')));
  }

  Future<void> removeFeature(Feature feature) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Feature?'),
        content: Text('Remove ${feature.name} from this character?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-remove-profile-feature'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final pinnedActionKeys = {...characterState.pinnedActionKeys}
      ..remove(feature.actionKey);
    saveFeatureChanges(
      character.features.where((current) => current.id != feature.id).toList(),
      pinnedActionKeys,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${feature.name} removed')));
  }

  void saveFeatureChanges(
    List<Feature> features,
    Set<String> pinnedActionKeys,
  ) {
    final updatedCharacter = character.copyWith(
      features: features,
      initiallyPinnedActionKeys: pinnedActionKeys,
    );
    setState(() {
      character = updatedCharacter;
      characterState = characterState.copyWith(
        pinnedActionKeys: pinnedActionKeys,
      );
    });
    widget.onCharacterChanged(updatedCharacter);
    publishSession();
  }

  Future<void> addJournalEntry() async {
    HapticFeedback.mediumImpact();
    final entry = await showDialog<JournalEntry>(
      context: context,
      builder: (context) => const JournalEntryEditorDialog(),
    );
    if (!mounted || entry == null) return;

    saveJournalEntries([...character.journalEntries, entry]);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${entry.title} added')));
  }

  void showJournalEntry(JournalEntry entry) {
    HapticFeedback.selectionClick();
    showDialog<void>(
      context: context,
      builder: (context) => JournalEntryDetailsDialog(entry: entry),
    );
  }

  Future<void> manageJournalEntry(JournalEntry entry) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Quest'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: Icon(
                entry.isCompleted
                    ? Icons.flag_outlined
                    : Icons.check_circle_outline,
              ),
              title: Text(
                entry.isCompleted ? 'Mark as Active' : 'Mark as Complete',
              ),
              onTap: () => Navigator.pop(context, 'toggle'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove Quest'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'edit':
        await editJournalEntry(entry);
      case 'toggle':
        toggleJournalEntry(entry);
      case 'remove':
        await removeJournalEntry(entry);
    }
  }

  Future<void> editJournalEntry(JournalEntry entry) async {
    final updated = await showDialog<JournalEntry>(
      context: context,
      builder: (context) => JournalEntryEditorDialog(entry: entry),
    );
    if (!mounted || updated == null) return;

    saveJournalEntries([
      for (final current in character.journalEntries)
        if (current.id == entry.id) updated else current,
    ]);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${updated.title} updated')));
  }

  void toggleJournalEntry(JournalEntry entry) {
    final updated = entry.copyWith(isCompleted: !entry.isCompleted);
    saveJournalEntries([
      for (final current in character.journalEntries)
        if (current.id == entry.id) updated else current,
    ]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.isCompleted
              ? '${updated.title} completed'
              : '${updated.title} returned to active quests',
        ),
      ),
    );
  }

  Future<void> removeJournalEntry(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Quest?'),
        content: Text('Remove ${entry.title} from the journal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-remove-journal-entry'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    saveJournalEntries(
      character.journalEntries
          .where((current) => current.id != entry.id)
          .toList(),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${entry.title} removed')));
  }

  void saveJournalEntries(List<JournalEntry> entries) {
    final updatedCharacter = character.copyWith(journalEntries: entries);
    setState(() => character = updatedCharacter);
    widget.onCharacterChanged(updatedCharacter);
  }

  Future<void> handleSavingThrowTap(SavingThrowCheck check) async {
    final hasDangerSense =
        check.ability == Ability.dexterity &&
        character.levelInClass('Barbarian') >= 2 &&
        characterState.canConcentrate;
    final label = '${check.ability.label} Save';
    final hasAdvantage =
        hasDangerSense ||
        (check.ability == Ability.dexterity &&
            characterState.activeConditions.contains(dodgingCondition)) ||
        (characterState.isRaging && check.ability == Ability.strength);
    final originalMode = hasAdvantage
        ? nextRollMode.withAdvantage()
        : nextRollMode;
    final roll = rollCheck(
      label,
      check.modifier,
      hasAdvantage: hasAdvantage,
      checkAbility: check.ability,
      darkLuckEligible: true,
    );
    if (character.levelInClass('Monk') >= 14) {
      await rerollWithDisciplinedSurvivor(
        roll,
        originalMode,
        tableResolvedSave: true,
      );
      return;
    }
    final fighterLevel = character.levelInClass('Fighter');
    final resource = character.resources
        .where((resource) => resource.id == indomitableResourceId)
        .firstOrNull;
    if (fighterLevel < 9 || resource == null || remainingUses(resource) <= 0) {
      return;
    }
    final reroll = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Indomitable'),
        content: Text(
          '$label total ${roll.total}. If the save failed, you can spend one '
          'use to reroll with a +$fighterLevel bonus and take the new result.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Result'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reroll Failed Save'),
          ),
        ],
      ),
    );
    if (!mounted || reroll != true || !spendCastResource(resource.id)) return;
    rollCheck(
      '$label · Indomitable',
      check.modifier + fighterLevel,
      darkLuckEligible: true,
      checkAbility: check.ability,
      modeOverride: originalMode,
    );
  }

  void handleActionTap(CharacterAction action) {
    HapticFeedback.selectionClick();
    final modifier = character.attackModifierFor(action);
    if (modifier == null || (action is Spell && !action.isAvailableInCombat)) {
      showActionDetails(action);
      return;
    }
    rollAttack(action);
  }

  void showActionDetails(CharacterAction action) {
    HapticFeedback.selectionClick();
    showDialog<void>(
      context: context,
      builder: (context) => ActionDetailsDialog(
        action: action,
        onCastCareful:
            action is Spell &&
                simpleMetamagicAvailable(action, Metamagic.careful)
            ? () {
                Navigator.pop(context);
                castSimpleMetamagic(action, Metamagic.careful);
              }
            : null,
        onCastHeightened:
            action is Spell &&
                simpleMetamagicAvailable(action, Metamagic.heightened)
            ? () {
                Navigator.pop(context);
                castSimpleMetamagic(action, Metamagic.heightened);
              }
            : null,
        onCastTwinned:
            action is Spell &&
                simpleMetamagicAvailable(action, Metamagic.twinned)
            ? () {
                Navigator.pop(context);
                castSimpleMetamagic(action, Metamagic.twinned);
              }
            : null,
        onCastTransmuted:
            action is Spell &&
                simpleMetamagicAvailable(action, Metamagic.transmuted)
            ? () {
                Navigator.pop(context);
                castSimpleMetamagic(action, Metamagic.transmuted);
              }
            : null,
        onCastExtended:
            action is Spell &&
                simpleMetamagicAvailable(action, Metamagic.extended)
            ? () {
                Navigator.pop(context);
                castSimpleMetamagic(action, Metamagic.extended);
              }
            : null,
        onCastSubtle:
            action is Spell &&
                simpleMetamagicAvailable(action, Metamagic.subtle)
            ? () {
                Navigator.pop(context);
                castSimpleMetamagic(action, Metamagic.subtle);
              }
            : null,
        onCastDistant:
            action is Spell &&
                simpleMetamagicAvailable(action, Metamagic.distant)
            ? () {
                Navigator.pop(context);
                castSimpleMetamagic(action, Metamagic.distant);
              }
            : null,
        onCastQuickenedFree:
            action is Spell &&
                quickenedSpellAvailable(action) &&
                freeCastResource(action) != null &&
                remainingUses(freeCastResource(action)!) > 0
            ? () {
                Navigator.pop(context);
                castQuickenedSpell(action, useFreeCast: true);
              }
            : null,
        onCastQuickened: action is Spell && quickenedSpellAvailable(action)
            ? () {
                Navigator.pop(context);
                castQuickenedSpell(action);
              }
            : null,
        spellComponents:
            action is Spell && character.benefitsFromDragonCompanion(action)
            ? 'V, S · Dragon Companion waives the Material component'
            : null,
        spellSaveDc: action is Spell
            ? characterForPhysicalChecks.spellSaveDc(action)
            : null,
        spellRange: action is Spell ? character.rangeForSpell(action) : null,
        spellDamageFormula: action is Spell
            ? character.damageFormulaFor(action)
            : null,
        onRollDamage:
            action is Spell &&
                action.isAvailableInCombat &&
                DiceExpression.tryParse(
                      character.damageFormulaFor(action) ?? '',
                    ) !=
                    null
            ? () {
                Navigator.pop(context);
                rollDamage(action);
              }
            : null,
        onCastRitual:
            action is Spell &&
                action.ritual &&
                currentMode != CharacterMode.combat &&
                characterState.canConcentrate
            ? () {
                Navigator.pop(context);
                castSpell(action, asRitual: true);
              }
            : null,
        onCast:
            action is Spell &&
                action.isAvailableInCombat &&
                characterState.currentHp > 0
            ? () {
                Navigator.pop(context);
                castSpell(action);
              }
            : null,
      ),
    );
  }

  String? effectiveSpellDamageType(Spell spell) =>
      characterState.spellDamageTypes[spell.id] ?? spell.damageType;

  bool simpleMetamagicAvailable(Spell spell, Metamagic option) {
    final points = resourceWithId(sorceryPointsResourceId);
    final cost = spellActionCost(spell);
    return {
          Metamagic.subtle,
          Metamagic.distant,
          Metamagic.extended,
          Metamagic.transmuted,
          Metamagic.twinned,
          Metamagic.careful,
          Metamagic.heightened,
        }.contains(option) &&
        character.knowsMetamagic(option) &&
        spell.isAvailableInCombat &&
        points != null &&
        remainingUses(points) >= option.pointCost &&
        characterState.canConcentrate &&
        !characterState.isRaging &&
        (option != Metamagic.distant ||
            Metamagic.distantRange(character.rangeForSpell(spell)) != null) &&
        (option != Metamagic.extended ||
            Metamagic.extendedTurns(spell.duration) != null) &&
        (option != Metamagic.transmuted ||
            (Metamagic.transmutedType(spell.damageType) != null &&
                !(spell.isCircleGrant && spell.name == 'Ice Storm'))) &&
        (option != Metamagic.twinned || Metamagic.supportsTwinned(spell)) &&
        (!{Metamagic.careful, Metamagic.heightened}.contains(option) ||
            spell.savingThrowAbility != null) &&
        (currentMode != CharacterMode.combat ||
            ((spell.isCantrip || !quickenedSpellUsedThisTurn) &&
                (cost == null || !usedCombatActions.contains(cost))));
  }

  SpellSaveEffect? saveEffectFor(Spell spell, {bool newCast = false}) => newCast
      ? modifyingSpellId == spell.id
            ? pendingSaveEffect
            : null
      : characterState.spellSaveEffects[spell.id];

  Future<SpellSaveEffect?> chooseSpellSaveTargets(Metamagic option) async {
    var text = '';
    final maximum = option == Metamagic.heightened
        ? 1
        : character.abilityModifierFor(Ability.charisma).clamp(1, 10);
    List<String> names() => text
        .split(',')
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    return showDialog<SpellSaveEffect>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('${option.label} targets'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Name ${option == Metamagic.heightened ? 'one target' : 'up to $maximum protected creatures'}. Separate names with commas. Confirm creature eligibility at the table.',
              ),
              TextField(
                key: const ValueKey('metamagic-save-targets'),
                maxLength: 800,
                decoration: const InputDecoration(labelText: 'Target names'),
                onChanged: (value) => update(() => text = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  names().isNotEmpty &&
                      names().length <= maximum &&
                      names().every((n) => n.length <= 80)
                  ? () => Navigator.pop(
                      context,
                      SpellSaveEffect(option, List.unmodifiable(names())),
                    )
                  : null,
              child: const Text('Confirm Targets'),
            ),
          ],
        ),
      ),
    );
  }

  bool extendingSpell(Spell spell) =>
      modifyingSpellId == spell.id && castingMetamagic == Metamagic.extended;

  String metamagicPreview(
    Spell spell,
    Metamagic option, {
    String? damageType,
    SpellSaveEffect? saveEffect,
  }) => {Metamagic.careful, Metamagic.heightened}.contains(option)
      ? (saveEffect ?? pendingSaveEffect)!.guidance
      : option == Metamagic.twinned
      ? 'For Command, Fly or Charm Monster, increase the effective casting level by 1 for an additional target. '
            'Spend the selected slot normally; ninth-level slots are unavailable for this option. '
            'Resolve creature eligibility, target selection, range and saves at the table.'
      : option == Metamagic.transmuted
      ? 'Damage type for this casting: ${damageType ?? transmutingDamageType}. '
            'Track the latest casting of this spell here; resolve overlapping castings at the table.'
      : option == Metamagic.extended
      ? 'Duration for this casting: ${Metamagic.extendedTurns(spell.duration)! ~/ 10} minutes (maximum 24 hours). '
            '${spell.concentration ? 'Concentration saves have Advantage while maintaining this spell.' : 'Track elapsed time at the table.'} '
            '${spell.canMoveConcentrationTarget ? 'Upcast duration is recalculated after slot selection.' : ''}'
            '${character.benefitsFromDragonCompanion(spell) ? ' No-concentration Dragon Companion mode instead lasts 2 minutes.' : ''}'
      : option == Metamagic.distant
      ? 'Range for this casting: ${Metamagic.distantRange(character.rangeForSpell(spell))}. Resolve distance and targets at the table.'
      : 'Verbal and Somatic components waived. Components for this casting: '
            '${character.benefitsFromDragonCompanion(spell) ? 'None (Dragon Companion waives Material)' : Metamagic.subtleComponents(spell)}. '
            'Resolve component use at the table.';

  Future<void> castSimpleMetamagic(Spell spell, Metamagic option) async {
    if (quickeningSpellId != null ||
        modifyingSpellId != null ||
        !simpleMetamagicAvailable(spell, option)) {
      return;
    }
    String? damageType;
    SpellSaveEffect? saveEffect;
    if ({Metamagic.careful, Metamagic.heightened}.contains(option)) {
      saveEffect = await chooseSpellSaveTargets(option);
      if (!mounted ||
          saveEffect == null ||
          !simpleMetamagicAvailable(spell, option)) {
        return;
      }
    }
    if (option == Metamagic.transmuted) {
      damageType = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Transmuted Spell damage type'),
          children: [
            for (final type in Metamagic.transmutedTypes)
              if (type != Metamagic.transmutedType(spell.damageType))
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, type),
                  child: Text(type),
                ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (!mounted ||
          damageType == null ||
          !simpleMetamagicAvailable(spell, option)) {
        return;
      }
    }
    final freeCast = freeCastResource(spell);
    final source = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${option.label} · ${spell.name}'),
        content: Text(
          '${option.pointCost} Sorcery Points. ${metamagicPreview(spell, option, damageType: damageType, saveEffect: saveEffect)}\n\nThe normal casting time still applies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (freeCast != null && remainingUses(freeCast) > 0)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use Free Cast'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cast with Metamagic'),
          ),
        ],
      ),
    );
    if (!mounted ||
        source == null ||
        !simpleMetamagicAvailable(spell, option)) {
      return;
    }
    modifyingSpellId = spell.id;
    castingMetamagic = option;
    transmutingDamageType = damageType;
    pendingSaveEffect = saveEffect;
    try {
      await castSpell(spell, useFreeCast: source);
    } finally {
      modifyingSpellId = null;
      castingMetamagic = null;
      transmutingDamageType = null;
      pendingSaveEffect = null;
    }
  }

  bool hasActionCastingTime(Spell spell) =>
      {'action', '1 action'}.contains(spell.castingTime?.trim().toLowerCase());

  bool quickenedSpellAvailable(Spell spell) {
    final points = resourceWithId(sorceryPointsResourceId);
    return character.knowsMetamagic(Metamagic.quickened) &&
        hasActionCastingTime(spell) &&
        spell.isAvailableInCombat &&
        points != null &&
        remainingUses(points) >= 2 &&
        characterState.canConcentrate &&
        !characterState.isRaging &&
        (currentMode != CharacterMode.combat ||
            (!levelledSpellCastThisTurn &&
                !quickenedSpellUsedThisTurn &&
                !usedCombatActions.contains(CombatActionCost.bonusAction)));
  }

  Future<void> castQuickenedSpell(
    Spell spell, {
    bool useFreeCast = false,
  }) async {
    if (quickeningSpellId != null ||
        modifyingSpellId != null ||
        !quickenedSpellAvailable(spell)) {
      return;
    }
    quickeningSpellId = spell.id;
    try {
      await castSpell(spell, useFreeCast: useFreeCast);
    } finally {
      quickeningSpellId = null;
    }
  }

  CombatActionCost? spellActionCost(Spell spell) {
    if (currentMode != CharacterMode.combat) return null;
    if (quickeningSpellId == spell.id) return CombatActionCost.bonusAction;
    return switch (spell.castingTime?.trim().toLowerCase()) {
      'action' || '1 action' => CombatActionCost.action,
      'bonus action' || '1 bonus action' => CombatActionCost.bonusAction,
      'reaction' || '1 reaction' => CombatActionCost.reaction,
      _ => null,
    };
  }

  bool canSpendSpellAction(Spell spell, {bool fromScroll = false}) {
    if (modifyingSpellId == spell.id &&
        !simpleMetamagicAvailable(spell, castingMetamagic!)) {
      return false;
    }
    if (currentMode == CharacterMode.combat &&
        ((!spell.isCantrip && quickenedSpellUsedThisTurn) ||
            (quickeningSpellId == spell.id && levelledSpellCastThisTurn))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Quickened Spell prevents another level 1+ spell on this turn.',
          ),
        ),
      );
      return false;
    }
    if (quickeningSpellId == spell.id && !quickenedSpellAvailable(spell)) {
      return false;
    }
    final transformed = characterState.wildShapeForm != null;
    final canCastInForm = character.levelInClass('Druid') >= 18;
    if (transformed &&
        (!canCastInForm ||
            (!fromScroll && spell.hasCostlyOrConsumedMaterial))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            canCastInForm
                ? 'Beast Spells cannot use costly or consumed material components.'
                : 'You cannot cast spells while in Wild Shape.',
          ),
        ),
      );
      return false;
    }
    if (characterState.isRaging) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot cast spells while raging.')),
      );
      return false;
    }
    if (!characterState.canConcentrate) return false;
    final cost = spellActionCost(spell);
    if (cost == null || !usedCombatActions.contains(cost)) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${cost.label} already used this turn.')),
    );
    return false;
  }

  void trackSpellAction(Spell spell, {bool newCast = true}) {
    if (newCast) elementalAffinityUsedSpellIds.remove(spell.id);
    final cost = spellActionCost(spell);
    final option = quickeningSpellId == spell.id
        ? Metamagic.quickened
        : modifyingSpellId == spell.id
        ? castingMetamagic
        : null;
    if (newCast &&
        (characterState.spellSaveEffects.containsKey(spell.id) ||
            pendingSaveEffect != null)) {
      final effects = {...characterState.spellSaveEffects}..remove(spell.id);
      if (modifyingSpellId == spell.id && pendingSaveEffect != null) {
        effects[spell.id] = pendingSaveEffect!;
      }
      updateCharacterState(characterState.copyWith(spellSaveEffects: effects));
    }
    if (newCast &&
        (characterState.spellDamageTypes.containsKey(spell.id) ||
            option == Metamagic.transmuted)) {
      final types = {...characterState.spellDamageTypes}..remove(spell.id);
      if (option == Metamagic.transmuted && transmutingDamageType != null) {
        types[spell.id] = transmutingDamageType!;
      }
      updateCharacterState(characterState.copyWith(spellDamageTypes: types));
    }
    if (newCast && option != null) {
      final points = resourceWithId(sorceryPointsResourceId)!;
      updateCharacterState(
        characterState.copyWith(
          resourceValues: {
            ...characterState.resourceValues,
            points.id: remainingUses(points) - option.pointCost,
          },
        ),
      );
      if (option == Metamagic.quickened) {
        quickenedSpellUsedThisTurn = currentMode == CharacterMode.combat;
      }
      recordSessionEvent(
        SessionEventType.combat,
        '${option.label} · ${spell.name}',
        detail: option == Metamagic.quickened
            ? '2 Sorcery Points spent. Cast as a Bonus Action; no further level 1+ spells this turn.'
            : '${option.pointCost} Sorcery Points spent. ${metamagicPreview(spell, option)}',
      );
    }
    if (newCast && !spell.isCantrip && currentMode == CharacterMode.combat) {
      levelledSpellCastThisTurn = true;
    }
    if (cost != null) setCombatActionUsed(cost, true);
    if (cost == null) publishSession();
  }

  String freeCastId(Spell spell) => 'whetstone:free-cast:${spell.id}';

  static const circleFreeCast = CharacterResource(
    id: 'whetstone:class:natural-recovery-cast',
    name: 'Natural Recovery',
    maximum: 1,
    initialValue: 1,
    rechargePeriod: RechargePeriod.longRest,
  );

  CharacterResource? freeCastResource(Spell spell) {
    final companion = character.benefitsFromDragonCompanion(spell)
        ? resourceWithId(dragonCompanionResourceId)
        : null;
    if (companion != null && remainingUses(companion) > 0) return companion;
    CharacterResource? personal;
    for (final resource in character.resources) {
      if (resource.id != freeCastId(spell)) continue;
      if (remainingUses(resource) > 0) return resource;
      personal = resource;
    }
    final eligible =
        landDruidLevel >= 6 &&
        !spell.isCantrip &&
        spell.prepared &&
        (characterState.druidLand
                ?.spellsAt(landDruidLevel)
                .any(
                  (name) =>
                      name.toLowerCase() == spell.name.trim().toLowerCase(),
                ) ??
            false);
    return eligible ? circleFreeCast : personal ?? companion;
  }

  void addFreeCast(Spell spell) {
    if (freeCastResource(spell) != null) return;
    final updated = character.copyWith(
      resources: [
        ...character.resources,
        CharacterResource(
          id: freeCastId(spell),
          name: '${spell.name} Free Cast',
          maximum: 1,
          initialValue: 1,
          rechargePeriod: RechargePeriod.longRest,
        ),
      ],
    );
    setState(() => character = updated);
    widget.onCharacterChanged(updated);
    publishSession();
  }

  bool spendFreeCast(Spell spell) {
    final resource = freeCastResource(spell);
    if (resource == null || remainingUses(resource) <= 0) return false;
    if (resource.id == circleFreeCast.id) {
      updateCharacterState(
        characterState.copyWith(naturalRecoveryCastUsed: true),
      );
      return true;
    }
    return spendCastResource(resource.id);
  }

  bool tracksSlotsFor(Spell spell) =>
      !spell.isCantrip &&
      spell.prepared &&
      castingResources.any((resource) => spellSlotLevel(resource) != null);

  Iterable<CharacterResource> get castingResources sync* {
    yield* character.resources;
    if (character.levelInClass('Sorcerer') >= 2) {
      yield* fontOfMagicSlots(characterState.resourceValues);
    }
    if (character.levelInClass('Druid') >= 5 &&
        characterState.resourceValues.containsKey(wildResurgenceSlot.id)) {
      yield wildResurgenceSlot;
    }
    if (character.levelInClass('Druid') >= 20) {
      yield* natureMagicianSlots.where(
        (slot) => characterState.resourceValues.containsKey(slot.id),
      );
    }
  }

  int remainingUses(CharacterResource resource) =>
      resource.id == circleFreeCast.id
      ? (characterState.naturalRecoveryCastUsed ? 0 : 1)
      : characterState.resourceValues[resource.id] ?? resource.initialValue;

  Future<(int, String)?> chooseTrackedSlot(Spell spell) => chooseAvailableSlot(
    spell.level,
    '${spell.name} slot level',
    maximumLevel:
        modifyingSpellId == spell.id && castingMetamagic == Metamagic.twinned
        ? 8
        : 9,
  );

  Future<(int, String)?> chooseAvailableSlot(
    int minimumLevel,
    String title, {
    int maximumLevel = 9,
  }) {
    final slots = [
      for (final resource in castingResources)
        if (spellSlotLevel(resource) case final level?
            when level >= minimumLevel &&
                level <= maximumLevel &&
                remainingUses(resource) > 0)
          (level, resource),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible spell slots remain.')),
      );
      return Future.value();
    }
    return showDialog<(int, String)>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          for (final (level, resource) in slots)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, (level, resource.id)),
              child: Text(
                'Level $level${resource.id == wildResurgenceSlot.id
                    ? ' Wild Resurgence'
                    : natureMagicianSlots.contains(resource)
                    ? ' Nature Magician'
                    : resource.id.startsWith(fontOfMagicSlotPrefix)
                    ? ' Font of Magic'
                    : resource.rechargePeriod == RechargePeriod.shortRest
                    ? ' Pact Magic'
                    : ''}'
                ' · ${remainingUses(resource)} remaining',
              ),
            ),
        ],
      ),
    );
  }

  bool spendCastResource(String id) {
    for (final resource in castingResources) {
      if (resource.id != id) continue;
      final remaining = remainingUses(resource);
      if (remaining <= 0) return false;
      updateCharacterState(
        characterState.copyWith(
          resourceValues: {
            ...characterState.resourceValues,
            resource.id: remaining - 1,
          },
        ),
      );
      return true;
    }
    return false;
  }

  Future<void> castSpell(
    Spell spell, {
    bool asRitual = false,
    bool useFreeCast = false,
    String? scrollName,
  }) async {
    if (spell.isDraconicGrant &&
        spell.name == 'Legend Lore' &&
        currentMode == CharacterMode.combat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete this 10-minute casting outside combat.'),
        ),
      );
      return;
    }
    if (asRitual && (!spell.ritual || currentMode == CharacterMode.combat)) {
      return;
    }
    if (!canSpendSpellAction(spell, fromScroll: scrollName != null)) return;
    final companionCast =
        scrollName == null &&
        !asRitual &&
        character.benefitsFromDragonCompanion(spell);
    var companionWithoutConcentration = false;
    if (companionCast) {
      final extended = extendingSpell(spell);
      final sameConcentration = characterState.concentrationSpellId == spell.id;
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Summon Dragon · Concentration'),
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Dragon Companion waives the Material component. '
                'Track the latest spirit here; resolve its statistics and attacks at the table.',
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                extended ? 'Concentrate · 2 hours' : 'Concentrate · 1 hour',
              ),
            ),
            SimpleDialogOption(
              onPressed: sameConcentration
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(
                sameConcentration
                    ? 'End concentration on the earlier dragon first'
                    : extended
                    ? 'Dragon Companion · No concentration · 2 minutes'
                    : 'Dragon Companion · No concentration · 1 minute',
              ),
            ),
          ],
        ),
      );
      if (!mounted || choice == null || !canSpendSpellAction(spell)) return;
      companionWithoutConcentration = choice;
    }
    bool? freedomTarget;
    if (spell.isClassGrant && spell.name == 'Freedom of Movement') {
      freedomTarget = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Freedom of Movement target'),
          content: const Text(
            'Choose the willing creature you touch. The protection lasts one hour.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Another creature'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yourself'),
            ),
          ],
        ),
      );
      if (!mounted ||
          freedomTarget == null ||
          !canSpendSpellAction(spell, fromScroll: scrollName != null)) {
        return;
      }
    }
    if (character.attackModifierFor(spell) != null) {
      await rollAttack(
        spell,
        asRitual: asRitual,
        useFreeCast: useFreeCast,
        scrollName: scrollName,
      );
    } else if (spell.rollEffectOnCast && spell.damageFormula != null) {
      await rollDamage(
        spell,
        castingSpell: true,
        asRitual: asRitual,
        useFreeCast: useFreeCast,
        scrollName: scrollName,
      );
    } else {
      int? slotLevel;
      if (scrollName != null && !spendInventoryItem(scrollName)) return;
      if (useFreeCast && !spendFreeCast(spell)) return;
      if (scrollName == null &&
          !useFreeCast &&
          !asRitual &&
          tracksSlotsFor(spell)) {
        final slot = await chooseTrackedSlot(spell);
        slotLevel = slot?.$1;
        if (!mounted ||
            slot == null ||
            !canSpendSpellAction(spell, fromScroll: scrollName != null) ||
            !spendCastResource(slot.$2)) {
          return;
        }
      }
      if (companionCast) {
        updateCharacterState(characterState.endDragonCompanion());
      }
      if (companionWithoutConcentration) {
        updateCharacterState(
          characterState.copyWith(
            dragonCompanionSpellId: spell.id,
            activeConditions: {
              ...characterState.activeConditions,
              dragonCompanionCondition,
            },
            conditionTurns: {
              ...characterState.conditionTurns,
              dragonCompanionCondition: extendingSpell(spell) ? 20 : 10,
            },
            spellSummons: {
              ...characterState.spellSummons,
              spell.id: 'Draconic Spirit · Dragon Companion (no concentration)',
            },
          ),
        );
      } else if (spell.concentration) {
        startSpellConcentration(spell, slotLevel: slotLevel);
      }
      trackSpellAction(spell);
      if (modifyingSpellId == spell.id &&
          castingMetamagic == Metamagic.twinned) {
        final actualLevel = slotLevel ?? spell.level;
        final effectiveLevel = Metamagic.twinnedEffectiveLevel(
          spell,
          actualLevel,
        )!;
        recordSessionEvent(
          SessionEventType.combat,
          'Twinned Spell targets · ${spell.name}',
          detail:
              '${useFreeCast ? 'Free cast' : 'Level $actualLevel slot spent'} · '
              'Effective level $effectiveLevel · ${1 + effectiveLevel - spell.level} targets. Resolve targets at the table.',
        );
      }
      if (companionCast) {
        recordSessionEvent(
          SessionEventType.combat,
          'Dragon Companion cast',
          detail:
              '${useFreeCast ? 'Free cast' : 'Spell slot'} · Material waived · '
              '${companionWithoutConcentration ? 'No concentration · ${extendingSpell(spell) ? '2 minutes' : '1 minute'}' : 'Concentration · ${extendingSpell(spell) ? '2 hours' : '1 hour'}'}. Earlier spirits remain table-managed.',
        );
      }
      if (freedomTarget == true) {
        updateCharacterState(
          characterState.copyWith(
            activeConditions: {
              ...characterState.activeConditions,
              freedomOfMovementCondition,
            },
            conditionTurns: {
              ...characterState.conditionTurns,
              freedomOfMovementCondition: extendingSpell(spell) ? 1200 : 600,
            },
          ),
        );
      }
      if ((spell.isCircleGrant ||
              saveEffectFor(spell) != null ||
              (spell.isDraconicGrant &&
                  {'Command', 'Fear', 'Charm Monster'}.contains(spell.name))) &&
          spell.savingThrowAbility != null) {
        await resolveCircleControlSave(
          spell,
          scrollName == null
              ? characterForPhysicalChecks.spellSaveDc(spell)
              : spell.scrollSaveDc,
        );
      } else if (spell.isClassGrant) {
        recordSessionEvent(
          SessionEventType.combat,
          '${spell.name} cast',
          detail: spell.summary,
        );
      }
    }
  }

  Future<void> resolveCircleControlSave(Spell spell, int? dc) async {
    final ability = spell.savingThrowAbility;
    if (ability == null) return;
    final outcome = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${spell.name} target save'),
        content: Text(
          '${dc == null ? '' : 'DC $dc '}${ability.label} saving throw.\n\n'
          '${spell.summary}\n${saveEffectFor(spell)?.guidance ?? ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Resolve at Table'),
          ),
          if (saveEffectFor(spell)?.option == Metamagic.careful)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Protected target · Automatic save'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Failed save'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Successful save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    recordSessionEvent(
      SessionEventType.combat,
      '${spell.name} target save',
      detail:
          '${outcome == null
              ? 'Resolve at table'
              : outcome
              ? 'Successful save'
              : 'Failed save'}'
          '${dc == null ? '' : ' · DC $dc'} ${ability.label}. ${spell.summary} ${saveEffectFor(spell)?.guidance ?? ''}',
    );
  }

  void startSpellConcentration(Spell spell, {int? slotLevel}) {
    if (!characterState.canConcentrate || characterState.isRaging) return;
    final turns = spell.isDraconicGrant
        ? switch (spell.name) {
            'Alter Self' || 'Arcane Eye' || 'Summon Dragon' => 600,
            "Dragon's Breath" || 'Fear' => 10,
            'Fly' => 100,
            _ => null,
          }
        : spell.isCircleGrant
        ? switch (spell.name) {
            'Blur' ||
            'Hold Person' ||
            'Sleep' ||
            'Sleet Storm' ||
            'Stinking Cloud' ||
            'Tree Stride' => 10,
            'Fog Cloud' || 'Web' || 'Polymorph' => 600,
            'Insect Plague' || 'Wall of Stone' => 100,
            _ => null,
          }
        : null;
    updateCharacterState(
      characterState
          .copyWith(clearConcentration: true)
          .copyWith(
            concentrationSpellId: spell.id,
            extendedConcentration: extendingSpell(spell),
            concentrationSlotLevel:
                modifyingSpellId == spell.id &&
                    castingMetamagic == Metamagic.twinned
                ? Metamagic.twinnedEffectiveLevel(
                    spell,
                    slotLevel ?? spell.level,
                  )
                : slotLevel == 0
                ? null
                : slotLevel,
            concentrationTurnsRemaining: extendingSpell(spell)
                ? Metamagic.extendedSpellTurns(spell, slotLevel: slotLevel)
                : turns,
          ),
    );
  }

  bool matchesAmmunition(InventoryItem item, String name) =>
      item.name.trim().toLowerCase() == name.trim().toLowerCase();

  String? ammunitionLabel(CharacterAction action) {
    if (action is! Weapon || action.ammunitionName == null) return null;
    final name = action.ammunitionName!;
    final total = inventory
        .where((item) => matchesAmmunition(item, name))
        .fold(0, (sum, item) => sum + item.quantity);
    return '$name: $total';
  }

  bool spendInventoryItem(String name) {
    final index = inventory.indexWhere(
      (item) => matchesAmmunition(item, name) && item.quantity > 0,
    );
    if (index < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No $name remaining.')));
      return false;
    }
    final item = inventory[index];
    setState(
      () => inventory[index] = item.copyWith(quantity: item.quantity - 1),
    );
    recordSessionEvent(
      SessionEventType.inventory,
      '${item.name} used',
      detail: '${item.quantity - 1} left in stack',
    );
    return true;
  }

  Future<bool?> choosePackTactics() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Pack Tactics'),
      content: const Text(
        'Is an ally within 5 feet of the target and able to act?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );

  bool get canUseAttackAction =>
      characterState.canConcentrate &&
      (attackActionAttacksRemaining > 0 || canUseNonMagicAction);

  void spendAttackActionAttack() {
    setState(() {
      if (attackActionAttacksRemaining == 0) {
        if (actionSurge == ActionSurgeState.available) {
          actionSurge = ActionSurgeState.spent;
        } else {
          usedCombatActions.add(CombatActionCost.action);
        }
        attackActionAttacksRemaining = character.attacksPerAction;
      }
      attackActionAttacksRemaining--;
    });
    publishSession();
  }

  bool consumeSteadyAimAdvantage() {
    final advantage =
        steadyAimAttackPending &&
        characterState.activeConditions.contains(steadyAimCondition);
    steadyAimAttackPending = false;
    return advantage;
  }

  Future<void> useStunningStrike() async {
    final focus = character.resources
        .where((resource) => resource.id == focusResourceId)
        .firstOrNull;
    bool canUse() =>
        mounted &&
        currentMode == CharacterMode.combat &&
        character.levelInClass('Monk') >= 5 &&
        characterState.canConcentrate &&
        !stunningStrikeUsedThisTurn &&
        focus != null &&
        remainingUses(focus) > 0;
    if (!canUse()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stunning Strike needs an unused turn use and 1 Focus Point.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stunning Strike · Eligible hit'),
        content: const Text(
          'Confirm you just hit a creature with an Unarmed Strike or a Monk weapon: a Simple Melee weapon, or a Light Martial Melee weapon. Spend 1 Focus Point for Stunning Strike. This does not spend another attack or action. Target eligibility is confirmed at the table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eligible hit · Spend 1 Focus'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !canUse()) return;
    stunningStrikeUsedThisTurn = true;
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          focus!.id: remainingUses(focus) - 1,
        },
      ),
    );
    final dc =
        8 +
        character.proficiencyBonus +
        character.abilityModifierFor(Ability.wisdom);
    recordSessionEvent(
      SessionEventType.combat,
      'Stunning Strike attempt',
      detail: 'Target makes a DC $dc Constitution save · 1 Focus Point spent.',
    );
    final failed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stunning Strike · Target save'),
        content: Text(
          'DC $dc Constitution save. On failure: target Stunned until the start of your next turn. On success: target Speed halved until the start of your next turn, and the next attack against it before then has Advantage. Resolve the target roll, immunity and conditions at the table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Resolve later'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Save succeeded'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save failed'),
          ),
        ],
      ),
    );
    if (!mounted || failed == null) return;
    recordSessionEvent(
      SessionEventType.combat,
      'Stunning Strike · ${failed ? 'failed save' : 'successful save'}',
      detail: failed
          ? 'Target Stunned until the start of your next turn.'
          : 'Target Speed halved until the start of your next turn. Next attack against it before then has Advantage.',
    );
  }

  Future<void> useSelfRestoration() async {
    bool canUse() =>
        mounted &&
        currentMode == CharacterMode.combat &&
        character.levelInClass('Monk') >= 10 &&
        !selfRestorationUsedThisTurn;
    if (!canUse()) return;
    final eligible = characterState.activeConditions.intersection({
      'Charmed',
      'Frightened',
      'Poisoned',
    });
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Self-Restoration'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Confirm this is the end of your own turn. Remove one listed condition without spending an action or Focus. You also avoid Exhaustion from forgoing food and drink; track those causes at the table.',
            ),
          ),
          if (eligible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No eligible condition to remove.'),
            ),
          for (final condition in eligible)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, condition),
              child: Text('End turn · Remove $condition'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (choice == null ||
        !canUse() ||
        !characterState.activeConditions.contains(choice)) {
      return;
    }
    selfRestorationUsedThisTurn = true;
    updateCharacterState(
      characterState.copyWith(
        activeConditions: {...characterState.activeConditions}..remove(choice),
        conditionTurns: {...characterState.conditionTurns}..remove(choice),
      ),
    );
    recordSessionEvent(
      SessionEventType.condition,
      'Self-Restoration',
      detail:
          'Removed $choice at the confirmed end of your turn. No action or Focus spent.',
    );
  }

  Future<void> useSteadyAim() async {
    bool canUse() =>
        currentMode == CharacterMode.combat &&
        character.levelInClass('Rogue') >= 3 &&
        characterState.canConcentrate &&
        !usedCombatActions.contains(CombatActionCost.bonusAction);
    if (!canUse()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Steady Aim'),
        content: const Text(
          'Confirm you have not moved this turn. Use a Bonus Action to gain Advantage '
          'on your next attack roll this turn. Your Speed becomes 0 until this turn ends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('No movement · Use Steady Aim'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !canUse()) return;
    usedCombatActions.add(CombatActionCost.bonusAction);
    steadyAimAttackPending = true;
    updateCharacterState(
      characterState.copyWith(
        activeConditions: {
          ...characterState.activeConditions,
          steadyAimCondition,
        },
        conditionTurns: {
          ...characterState.conditionTurns,
          steadyAimCondition: 1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'Steady Aim',
      detail: 'Next attack this turn has Advantage; Speed 0 until turn end.',
    );
  }

  void beginAnotherCreatureTurn() {
    fleetStepUsedThisTurn = true;
    sneakAttackUsedThisTurn = false;
    stunningStrikeUsedThisTurn = false;
    flurryAttacksRemaining = 0;
    steadyAimAttackPending = false;
    updateCharacterState(
      characterState.copyWith(
        activeConditions: {...characterState.activeConditions}
          ..remove(steadyAimCondition),
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'New creature turn confirmed',
      detail:
          'Sneak Attack refreshed and Steady Aim ended. Action, Bonus Action and Reaction are unchanged.',
    );
  }

  Future<void> useSuperiorDefense() async {
    final focus = character.resources
        .where((resource) => resource.id == focusResourceId)
        .firstOrNull;
    bool canUse() =>
        mounted &&
        currentMode == CharacterMode.combat &&
        character.levelInClass('Monk') >= 18 &&
        characterState.canConcentrate &&
        focus != null &&
        remainingUses(focus) >= 3 &&
        !characterState.activeConditions.contains(superiorDefenseCondition);
    if (!canUse()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Superior Defense'),
        content: const Text(
          'Confirm this is the start of your turn. Spend 3 Focus Points for Resistance to all damage except Force for 1 minute or until Incapacitated. No action is spent. Choose a specific damage type when recording damage; unspecified damage is not reduced automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start of turn · Spend 3 Focus'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !canUse()) return;
    updateCharacterState(
      characterState.copyWith(
        activeConditions: {
          ...characterState.activeConditions,
          superiorDefenseCondition,
        },
        conditionTurns: {
          ...characterState.conditionTurns,
          superiorDefenseCondition: 10,
        },
        resourceValues: {
          ...characterState.resourceValues,
          focus!.id: remainingUses(focus) - 3,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'Superior Defense',
      detail:
          '3 Focus Points spent · Resistance to typed damage except Force for 10 combat turns, ending on Incapacitation. Start-of-turn timing confirmed at the table.',
    );
  }

  bool get hasIntimidatingPresence =>
      character.levelInClass('Barbarian') >= 14 &&
      character.subclasses['Barbarian'] == 'Path of the Berserker';

  CharacterResource? resourceWithId(String id) =>
      character.resources.where((resource) => resource.id == id).firstOrNull;

  bool get intimidatingPresenceAvailable {
    final presence = resourceWithId(intimidatingPresenceResourceId);
    final rage = resourceWithId(rageResourceId);
    return currentMode == CharacterMode.combat &&
        hasIntimidatingPresence &&
        characterState.canConcentrate &&
        presence != null &&
        (remainingUses(presence) > 0
            ? !usedCombatActions.contains(CombatActionCost.bonusAction)
            : rage != null && remainingUses(rage) > 0);
  }

  Future<void> useIntimidatingPresence() async {
    if (!intimidatingPresenceAvailable) return;
    final presence = resourceWithId(intimidatingPresenceResourceId)!;
    final restore = remainingUses(presence) == 0;
    final dc =
        8 +
        characterForPhysicalChecks.abilityModifierFor(Ability.strength) +
        character.proficiencyBonus;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          restore
              ? 'Restore Intimidating Presence'
              : 'Intimidating Presence · Confirm targets',
        ),
        content: Text(
          restore
              ? 'Spend one Rage use to restore Intimidating Presence. This costs no action and does not activate or end Rage. Use the feature separately after restoring it.'
              : 'Choose creatures in a 30-foot Emanation from you. Spend your Bonus Action and one Intimidating Presence use. Each chosen creature makes a DC $dc Wisdom saving throw. On failure, it is Frightened for 1 minute, repeating the save at the end of each of its turns to end the effect on success. Resolve eligibility, saves, conditions and expiry at the table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              restore ? 'Spend one Rage · Restore use' : 'Unleash presence',
            ),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !intimidatingPresenceAvailable ||
        (remainingUses(presence) == 0) != restore) {
      return;
    }
    if (restore) {
      final rage = resourceWithId(rageResourceId);
      if (rage == null || remainingUses(rage) <= 0) return;
      updateCharacterState(
        characterState.copyWith(
          resourceValues: {
            ...characterState.resourceValues,
            presence.id: 1,
            rage.id: remainingUses(rage) - 1,
          },
        ),
      );
      recordSessionEvent(
        SessionEventType.resource,
        'Intimidating Presence restored',
        detail: 'One Rage use spent · No action spent.',
      );
    } else {
      usedCombatActions.add(CombatActionCost.bonusAction);
      updateCharacterState(
        characterState.copyWith(
          resourceValues: {
            ...characterState.resourceValues,
            presence.id: remainingUses(presence) - 1,
          },
        ),
      );
      recordSessionEvent(
        SessionEventType.combat,
        'Intimidating Presence',
        detail:
            'Bonus Action and one use spent · Chosen creatures within 30 feet make DC $dc Wisdom saves. Frightened for 1 minute on failure; repeat at the end of each target turn. Resolve target effects at the table.',
      );
    }
  }

  Future<void> useBarbarianDefense() async {
    bool eligible() =>
        character.levelInClass('Barbarian') >= 1 && activeWildShape == null;
    if (!eligible()) return;
    final dexterity = character.abilityModifierFor(Ability.dexterity);
    final constitution = character.abilityModifierFor(Ability.constitution);
    final base = 10 + dexterity + constitution;
    var shield = false;
    final armourClass = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Barbarian · Unarmored Defense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Confirm you are wearing no armor. Base AC: 10 + $dexterity Dexterity + $constitution Constitution = $base. '
                'This replaces your tracked AC and does not stack with another base AC formula. Confirm other bonuses separately. '
                '${character.levelInClass('Barbarian') >= 5 ? 'Fast Movement adds 10 feet to Speed while you are not wearing Heavy armor; resolve movement at the table. ' : ''}'
                'Recalculate when equipment or ability scores change.',
              ),
              CheckboxListTile(
                title: const Text('Wielding a Shield · +2 AC'),
                value: shield,
                onChanged: (value) => update(() => shield = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, base + (shield ? 2 : 0)),
              child: Text('Unarmored · Apply AC ${base + (shield ? 2 : 0)}'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || armourClass == null || !eligible()) return;
    updateCharacterState(characterState.copyWith(armourClass: armourClass));
    recordSessionEvent(
      SessionEventType.condition,
      'Barbarian Unarmored Defense',
      detail:
          'AC set to $armourClass after confirming no armor · ${shield ? 'Shield +2' : 'No Shield'}. '
          'Base 10 + $dexterity Dexterity + $constitution Constitution. Recalculate after equipment or ability changes.',
    );
  }

  Future<void> useDraconicDefense() async {
    bool eligible() =>
        character.hasDraconicResilience && activeWildShape == null;
    if (!eligible()) return;
    final dexterity = character.abilityModifierFor(Ability.dexterity);
    final charisma = character.abilityModifierFor(Ability.charisma);
    final base = 10 + dexterity + charisma;
    var shield = false;
    final ac = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Draconic Resilience · Unarmored AC'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Confirm you are wearing no armor. Base AC: 10 + $dexterity Dexterity + $charisma Charisma = $base. '
                'This replaces your tracked AC and does not stack with another base AC formula. Confirm other AC bonuses separately, and recalculate when equipment or ability scores change.',
              ),
              CheckboxListTile(
                title: const Text('Wielding a Shield · +2 AC'),
                value: shield,
                onChanged: (value) => update(() => shield = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, base + (shield ? 2 : 0)),
              child: Text('Unarmored · Apply AC ${base + (shield ? 2 : 0)}'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || ac == null || !eligible()) return;
    updateCharacterState(characterState.copyWith(armourClass: ac));
    recordSessionEvent(
      SessionEventType.condition,
      'Draconic Resilience AC',
      detail:
          'AC set to $ac after confirming no armor · Base 10 + $dexterity Dexterity + $charisma Charisma${shield ? ' +2 Shield' : ''}. HP, actions and resources unchanged.',
    );
  }

  Future<void> reviewDraconicHp() async {
    if (!character.hasDraconicResilience) return;
    final target = character.levelInClass('Sorcerer');
    final recorded = character.draconicHpBonus;
    final adjustment = target - (recorded ?? 0);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Draconic Resilience · HP'),
        content: Text(
          recorded == target
              ? 'Your +$target Draconic Resilience HP bonus is already recorded. No extra HP will be added. Future advancement tracks changes in Sorcerer levels.'
              : 'At Sorcerer level $target, Draconic Resilience contributes +$target to maximum HP. '
                    '${recorded == null ? 'This recovered character has not yet been reviewed. Choose whether the bonus is already included in your current maximum of ${characterState.maxHp} HP.' : 'The recorded contribution is +$recorded HP. Choose whether to apply the ${adjustment >= 0 ? '+' : ''}$adjustment adjustment or record that your maximum was already adjusted.'} '
                    'Current HP is preserved unless a reduced maximum is lower. This spends no action or resource.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(recorded == target ? 'Done' : 'Cancel'),
          ),
          if (recorded != target) ...[
            TextButton(
              onPressed: () => Navigator.pop(context, 'included'),
              child: Text('HP already includes +$target'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'apply'),
              child: Text(
                'Apply ${adjustment >= 0 ? '+' : ''}$adjustment maximum HP',
              ),
            ),
          ],
        ],
      ),
    );
    if (!mounted ||
        choice == null ||
        !character.hasDraconicResilience ||
        character.draconicHpBonus != recorded ||
        character.levelInClass('Sorcerer') != target) {
      return;
    }
    final maximum = characterState.maxHp + (choice == 'apply' ? adjustment : 0);
    if (maximum < 1 || maximum > 999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maximum HP must remain 1–999. Review your maximum HP before applying this bonus.',
          ),
        ),
      );
      return;
    }
    final hp = characterState.currentHp.clamp(0, maximum);
    final updated = character.copyWith(
      draconicHpBonus: target,
      maxHp: maximum,
      currentHp: hp,
    );
    setState(() => character = updated);
    widget.onCharacterChanged(updated);
    updateCharacterState(
      characterState.copyWith(maxHp: maximum, currentHp: hp),
    );
    recordSessionEvent(
      SessionEventType.condition,
      'Draconic Resilience HP reviewed',
      detail:
          '+$target class HP contribution recorded. ${choice == 'apply' ? 'Maximum HP adjusted by $adjustment to $maximum.' : 'Existing maximum HP $maximum retained.'} No action or resource spent.',
    );
  }

  Future<void> useMonkDefense() async {
    final level = character.levelInClass('Monk');
    if (level < 1 || activeWildShape != null) return;
    final dexterity = character.abilityModifierFor(Ability.dexterity);
    final wisdom = character.abilityModifierFor(Ability.wisdom);
    final ac = 10 + dexterity + wisdom;
    final movement = level >= 18
        ? 30
        : level >= 14
        ? 25
        : level >= 10
        ? 20
        : level >= 6
        ? 15
        : level >= 2
        ? 10
        : 0;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monk · Unarmored defense and movement'),
        content: Text(
          'Confirm you are wearing no armor and wielding no Shield. Base AC: 10 + $dexterity Dexterity + $wisdom Wisdom = $ac. This replaces your tracked AC; confirm any other AC bonuses separately. Unarmored Movement adds $movement feet to Speed. ${level >= 9 ? 'Acrobatic Movement lets you cross liquids and vertical surfaces on your turn without falling during that movement. ' : ''}Movement is resolved at the table. Recalculate when your equipment or ability scores change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Unarmored · Apply AC $ac'),
          ),
        ],
      ),
    );
    if (!mounted || apply != true || activeWildShape != null) return;
    updateCharacterState(characterState.copyWith(armourClass: ac));
    recordSessionEvent(
      SessionEventType.condition,
      'Monk Unarmored Defense',
      detail:
          'AC set to $ac after confirming no armor or Shield · Unarmored Movement +$movement feet. Recalculate after equipment or ability changes.',
    );
  }

  bool get canUseFleetStep =>
      currentMode == CharacterMode.combat &&
      character.levelInClass('Monk') >= 11 &&
      character.subclasses['Monk'] == 'Warrior of the Open Hand' &&
      characterState.canConcentrate &&
      usedCombatActions.contains(CombatActionCost.bonusAction) &&
      !fleetStepUsedThisTurn &&
      !stepOfWindUsedThisTurn;

  Future<void> useMonkMovement({bool asFleetStep = false}) async {
    bool canUse() =>
        mounted &&
        currentMode == CharacterMode.combat &&
        character.levelInClass('Monk') >= 2 &&
        characterState.canConcentrate &&
        (asFleetStep
            ? canUseFleetStep
            : !usedCombatActions.contains(CombatActionCost.bonusAction));
    if (!canUse()) return;
    final focus = character.resources
        .where((resource) => resource.id == focusResourceId)
        .firstOrNull;
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          asFleetStep
              ? 'Fleet Step · Immediate follow-up'
              : 'Monk’s Focus · Movement and defense',
        ),
        children: [
          if (asFleetStep)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Confirm you just completed a Bonus Action other than Step of the Wind on your turn. Use Step of the Wind immediately afterward, without spending another Bonus Action.',
              ),
            ),
          for (final (index, label) in [
            (0, 'Patient Defense · Disengage (free)'),
            (1, 'Patient Defense · Disengage + Dodge (1 Focus)'),
            (2, 'Step of the Wind · Dash (free)'),
            (3, 'Step of the Wind · Dash + Disengage (1 Focus)'),
          ])
            if (!asFleetStep || index >= 2)
              SimpleDialogOption(
                onPressed:
                    index.isOdd && (focus == null || remainingUses(focus) < 1)
                    ? null
                    : () => Navigator.pop(context, index),
                child: Text(label),
              ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (choice == null || !canUse()) return;
    if (choice.isOdd && (focus == null || remainingUses(focus) < 1)) return;
    if (asFleetStep) fleetStepUsedThisTurn = true;
    if (choice >= 2) stepOfWindUsedThisTurn = true;
    final heightened = character.levelInClass('Monk') >= 10;
    final temporaryHp = choice == 1 && heightened
        ? DiceExpression(
            diceCount: 2,
            dieSides: character.martialArtsDieSides,
          ).roll('Heightened Patient Defense', diceRoller)
        : null;
    final effects = <String>{
      if (choice < 2 || choice == 3) disengagingCondition,
      if (choice == 1) dodgingCondition,
      if (choice >= 2) dashingCondition,
    };
    usedCombatActions.add(CombatActionCost.bonusAction);
    updateCharacterState(
      characterState.copyWith(
        temporaryHp:
            temporaryHp == null ||
                temporaryHp.total < characterState.temporaryHp
            ? characterState.temporaryHp
            : temporaryHp.total,
        activeConditions: {...characterState.activeConditions, ...effects},
        conditionTurns: {
          ...characterState.conditionTurns,
          for (final effect in effects) effect: 1,
        },
        resourceValues: {
          ...characterState.resourceValues,
          if (choice.isOdd) focus!.id: remainingUses(focus) - 1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      asFleetStep
          ? 'Fleet Step'
          : choice < 2
          ? 'Patient Defense'
          : 'Step of the Wind',
      detail:
          '${effects.join(' + ')} until your next turn. ${choice == 3 ? 'Jump distance doubled for this turn. ' : ''}'
          '${choice == 1 ? 'Visible attackers have Disadvantage; Dexterity saves have Advantage while Dodge remains eligible. ' : ''}'
          '${temporaryHp == null ? '' : 'Heightened Focus rolled ${temporaryHp.dice.join(' + ')} = ${temporaryHp.total} Temporary HP; keep the larger pool. '}'
          '${choice == 3 && heightened ? 'You may move one willing Large or smaller creature within 5 feet with you this turn, without opportunity attacks against it. ' : ''}'
          '${choice.isOdd ? 'Spent 1 Focus Point.' : 'No Focus Point spent.'} Movement and jumping are resolved at the table.',
    );
  }

  Future<void> useFlurry() async {
    if (flurryAttacksRemaining > 0) {
      await useUnarmedStrike(asFlurry: true);
      return;
    }
    final focus = character.resources
        .where((resource) => resource.id == focusResourceId)
        .firstOrNull;
    bool canUse() =>
        mounted &&
        currentMode == CharacterMode.combat &&
        activeWildShape == null &&
        character.levelInClass('Monk') >= 2 &&
        characterState.canConcentrate &&
        focus != null &&
        remainingUses(focus) > 0 &&
        !usedCombatActions.contains(CombatActionCost.bonusAction);
    if (!canUse()) return;
    final strikes = character.levelInClass('Monk') >= 10 ? 3 : 2;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flurry of Blows'),
        content: Text(
          'Spend 1 Focus Point and your Bonus Action to make $strikes Unarmed Strikes this turn. Resolve each strike separately; your Attack action is preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Spend 1 Focus · Begin Flurry'),
          ),
        ],
      ),
    );
    if (confirmed != true || !canUse()) return;
    flurryAttacksRemaining = strikes;
    usedCombatActions.add(CombatActionCost.bonusAction);
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          focus!.id: remainingUses(focus) - 1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'Flurry of Blows',
      detail:
          '$strikes Unarmed Strikes available this turn · 1 Focus Point and Bonus Action spent.',
    );
  }

  Future<void> resolveOpenHandTechnique() async {
    if (character.levelInClass('Monk') < 3 ||
        character.subclasses['Monk'] != 'Warrior of the Open Hand') {
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Open Hand Technique'),
        children: [
          for (final effect in ['Addle', 'Push', 'Topple'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, effect),
              child: Text(effect),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'Addle') {
      recordSessionEvent(
        SessionEventType.combat,
        'Open Hand · Addle',
        detail:
            'Target cannot make opportunity attacks until the start of its next turn. Apply at the table.',
      );
      return;
    }
    final ability = choice == 'Push' ? 'Strength' : 'Dexterity';
    final dc =
        8 +
        character.proficiencyBonus +
        character.abilityModifierFor(Ability.wisdom);
    final effect = choice == 'Push'
        ? 'Push target up to 15 feet away.'
        : 'Target falls Prone.';
    recordSessionEvent(
      SessionEventType.combat,
      'Open Hand · $choice attempt',
      detail: 'DC $dc $ability save. On failure: $effect',
    );
    final failed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Open Hand · $choice'),
        content: Text(
          'Target makes a DC $dc $ability save. On failure: $effect Target rolls, immunity, movement and conditions are resolved at the table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Resolve later'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Save succeeded'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save failed'),
          ),
        ],
      ),
    );
    if (!mounted || failed == null) return;
    recordSessionEvent(
      SessionEventType.combat,
      'Open Hand · $choice ${failed ? 'failed save' : 'successful save'}',
      detail: failed ? effect : 'Target avoids the effect.',
    );
  }

  Future<void> resolveFrenzy({
    required bool usesStrength,
    required bool critical,
    String? damageType,
  }) async {
    bool eligible() =>
        mounted &&
        currentMode == CharacterMode.combat &&
        character.levelInClass('Barbarian') >= 3 &&
        character.subclasses['Barbarian'] == 'Path of the Berserker' &&
        characterState.canConcentrate &&
        characterState.isRaging &&
        characterState.activeConditions.contains(recklessAttackCondition) &&
        usesStrength &&
        !frenzyUsedThisTurn;
    if (!eligible()) return;
    final count = character.rageDamageBonus * (critical ? 2 : 1);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frenzy · Confirm first Strength hit'),
        content: Text(
          'Confirm this is the first target you hit on your own turn with a Strength-based attack while raging and using Reckless Attack. Add ${count}d6 extra damage${critical ? ' (critical hit dice doubled)' : ''}, of the same type as the triggering attack. No extra action, attack or Rage use is spent. Resolve target damage at the table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Resolve at table'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply Frenzy damage'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !eligible()) return;
    frenzyUsedThisTurn = true;
    final result = DiceExpression(
      diceCount: count,
      dieSides: 6,
    ).roll('Frenzy', diceRoller);
    addRollNotice(
      title: 'Frenzy Damage',
      calculation: '${count}d6 · ${result.dice.join(' + ')} = ${result.total}',
      total: result.total,
      tone: RollNoticeTone.damage,
      detail:
          '${damageType ?? 'Same type as the triggering attack'} · First qualifying hit this turn. No extra action or resource spent.',
    );
  }

  bool get canDeclareRecklessAttack =>
      currentMode == CharacterMode.combat &&
      character.levelInClass('Barbarian') >= 2 &&
      characterState.canConcentrate &&
      !attackRollMadeThisTurn;

  Future<void> declareRecklessAttack() async {
    if (!canDeclareRecklessAttack) return;
    if (recklessAttackArmed) {
      setState(() => recklessAttackArmed = false);
      recordSessionEvent(
        SessionEventType.combat,
        'Reckless Attack declaration cancelled',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prepare Reckless Attack'),
        content: const Text(
          'Confirm the next attack roll is your first on your turn. The declaration activates when that roll is made. Your attacks using Strength gain Advantage until the start of your next turn, and attack rolls against you have Advantage during that time. No action or Rage use is spent. Weapons must be marked as using Strength; Beast attacks without a tracked ability require table resolution. For older mid-turn saves, confirm no earlier attack roll was made.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Prepare first attack'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !canDeclareRecklessAttack) return;
    setState(() => recklessAttackArmed = true);
    recordSessionEvent(
      SessionEventType.combat,
      'Reckless Attack prepared',
      detail:
          'Waiting for the first attack roll on your turn. Tap the declaration control again to cancel before rolling.',
    );
  }

  void recordAttackForReckless({required bool asReaction}) {
    if (currentMode != CharacterMode.combat ||
        character.levelInClass('Barbarian') < 2 ||
        asReaction) {
      return;
    }
    final first = !attackRollMadeThisTurn;
    attackRollMadeThisTurn = true;
    if (first && recklessAttackArmed) {
      recklessAttackArmed = false;
      updateCharacterState(
        characterState.copyWith(
          activeConditions: {
            ...characterState.activeConditions,
            recklessAttackCondition,
          },
          conditionTurns: {
            ...characterState.conditionTurns,
            recklessAttackCondition: 1,
          },
        ),
      );
      recordSessionEvent(
        SessionEventType.combat,
        'Reckless Attack activated',
        detail:
            'Strength attacks have Advantage, and attack rolls against you have Advantage, until the start of your next turn. Resolve incoming attack Advantage at the table.',
      );
    }
  }

  bool get hasRetaliation =>
      character.levelInClass('Barbarian') >= 10 &&
      character.subclasses['Barbarian'] == 'Path of the Berserker';

  bool get canRetaliate =>
      hasRetaliation &&
      (activeWildShape == null ||
          activeWildShape!.combatAttack.range == '5 feet') &&
      currentMode == CharacterMode.combat &&
      characterState.canConcentrate &&
      !usedCombatActions.contains(CombatActionCost.reaction);

  void spendRetaliationReaction() {
    usedCombatActions.add(CombatActionCost.reaction);
    recordSessionEvent(
      SessionEventType.combat,
      'Retaliation',
      detail:
          'Reaction spent after confirming damage from a creature within 5 feet. One melee response; damage already taken and target outcomes are resolved separately.',
    );
  }

  Future<void> useRetaliation() async {
    if (!canRetaliate) return;
    final form = activeWildShape;
    final weapons = characterInCombat.weapons
        .where(
          (weapon) =>
              weapon.isMelee ||
              (form?.combatAttack.id == weapon.id && weapon.range == '5 feet'),
        )
        .toList();
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Retaliation · Confirm triggering damage'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Confirm you just took damage from the creature within 5 feet that you will attack. Enter the incoming damage separately. Spend your Reaction for one melee response against that creature. No Rage use, Action or Bonus Action is spent. '
              '${form == null ? 'Choose a melee weapon or Unarmed Strike.' : 'Confirm your form is physically capable of this response. Only its current melee attack is available.'}',
            ),
          ),
          for (final weapon in weapons)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, weapon.actionKey),
              child: Text('Retaliate with ${weapon.name}'),
            ),
          if (form == null)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'unarmed'),
              child: const Text('Retaliate with Unarmed Strike'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || !canRetaliate) return;
    if (choice == 'unarmed') {
      await useUnarmedStrike(asReaction: true);
    } else {
      final weapon = weapons
          .where((weapon) => weapon.actionKey == choice)
          .firstOrNull;
      if (weapon == null || !characterInCombat.weapons.contains(weapon)) return;
      await rollAttack(weapon, asReaction: true, retaliation: true);
    }
  }

  Future<void> useUnarmedStrike({
    bool asBonusAction = false,
    bool asFlurry = false,
    bool asReaction = false,
  }) async {
    final monk = character.martialArtsDieSides > 0;
    bool canUse() =>
        mounted &&
        currentMode == CharacterMode.combat &&
        activeWildShape == null &&
        characterState.canConcentrate &&
        (asReaction
            ? canRetaliate
            : asFlurry
            ? flurryAttacksRemaining > 0
            : asBonusAction
            ? monk && !usedCombatActions.contains(CombatActionCost.bonusAction)
            : canUseAttackAction);
    if (!canUse()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Attack action attacks remaining.')),
      );
      return;
    }
    var martialArts = false;
    if (monk) {
      final eligible = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Martial Arts eligibility'),
          content: const Text(
            'Confirm you are unarmed or wielding only Monk weapons, wearing no armor and wielding no Shield. '
            'Monk weapons are Simple Melee weapons and Light Martial Melee weapons. Equipment in your pack does not establish what you are wielding.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (!asBonusAction)
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Basic strike'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eligible · Use Martial Arts'),
            ),
          ],
        ),
      );
      if (!mounted || eligible == null || !canUse()) return;
      martialArts = eligible;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Unarmed Strike'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Choose an effect against a target within 5 feet. Grapple needs a free hand. '
              'Grapple and Shove require a target no more than one size larger than you. '
              'Confirm target eligibility at the table. Martial Arts can use Dexterity for attacks, damage and the save DC.',
            ),
          ),
          for (final option in [
            'Damage',
            'Grapple',
            'Shove · Prone',
            'Shove · Push',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option),
              child: Text(option),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || !canUse()) return;
    if (asReaction) {
      spendRetaliationReaction();
    } else if (asFlurry) {
      setState(() => flurryAttacksRemaining--);
      publishSession();
    } else if (asBonusAction) {
      setState(() => usedCombatActions.add(CombatActionCost.bonusAction));
      publishSession();
    } else {
      spendAttackActionAttack();
    }
    if (characterState.isRaging && !asReaction) extendRage();
    final strength = character.abilityModifierFor(Ability.strength);
    final dexterity = character.abilityModifierFor(Ability.dexterity);
    final useDexterity = martialArts && dexterity > strength;
    final modifier = useDexterity ? dexterity : strength;
    final abilityLabel = useDexterity ? 'Dexterity' : 'Strength';
    if (choice == 'Damage') {
      final attack = rollCheck(
        'Unarmed Strike Attack',
        modifier + character.proficiencyBonus,
        strengthAttack: !useDexterity,
        reactionAttack: asReaction,
        peerlessEligible: true,
        attackRoll: true,
        criticalThreshold: character.weaponCriticalThreshold,
        hasAdvantage: consumeSteadyAimAdvantage(),
      );
      if (attack.isNaturalOne) return;
      if (attack.naturalRoll >= character.weaponCriticalThreshold &&
          character.championLevel >= 3) {
        recordSessionEvent(
          SessionEventType.combat,
          'Remarkable Athlete',
          detail:
              'You can move up to half your Speed without provoking opportunity attacks.',
        );
      }
      final hit = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unarmed Strike result'),
          content: Text('Attack total ${attack.total}. Did the strike hit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Miss'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'bludgeoning'),
              child: const Text('Hit · Apply unarmed damage'),
            ),
            if (character.levelInClass('Monk') >= 6)
              FilledButton(
                onPressed: () => Navigator.pop(context, 'force'),
                child: const Text('Hit · Empowered Strike (Force)'),
              ),
          ],
        ),
      );
      if (!mounted || hit == null) return;
      final rage = characterState.isRaging && !useDexterity
          ? character.rageDamageBonus
          : 0;
      final critical = attack.naturalRoll >= character.weaponCriticalThreshold;
      final dice = martialArts
          ? DiceExpression(
              diceCount: critical ? 2 : 1,
              dieSides: character.martialArtsDieSides,
            ).roll('Martial Arts', diceRoller)
          : null;
      final base = dice?.total ?? 1;
      final damage = (base + modifier + rage).clamp(0, 999999);
      addRollNotice(
        title: 'Unarmed Strike Damage',
        calculation:
            '${dice == null ? '1' : '${critical ? 2 : 1}d${character.martialArtsDieSides} (${dice.dice.join(' + ')})'} + $modifier $abilityLabel modifier + $rage Rage = $damage',
        total: damage,
        tone: RollNoticeTone.damage,
        detail: hit,
      );
      rollRadiantStrikes(
        critical: attack.naturalRoll >= character.weaponCriticalThreshold,
      );
      await resolveFrenzy(
        usesStrength: !useDexterity,
        critical: critical,
        damageType: hit,
      );
      if (asFlurry) await resolveOpenHandTechnique();
      return;
    }
    final dc = 8 + modifier + character.proficiencyBonus;
    final effect = choice == 'Grapple'
        ? 'Target Grappled (escape DC $dc).'
        : choice == 'Shove · Prone'
        ? 'Target falls Prone.'
        : 'Push the target 5 feet away.';
    recordSessionEvent(
      SessionEventType.combat,
      '$choice attempt',
      detail:
          'Target chooses a DC $dc Strength or Dexterity save. On failure: $effect',
    );
    final failed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$choice saving throw'),
        content: Text(
          'The target chooses a DC $dc Strength or Dexterity save. '
          'On failure: $effect Resolve target rolls, immunities and conditions at the table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Resolve later'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Save succeeded'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save failed'),
          ),
        ],
      ),
    );
    if (!mounted || failed == null) return;
    recordSessionEvent(
      SessionEventType.combat,
      '$choice · ${failed ? 'failed save' : 'successful save'}',
      detail: failed ? effect : 'The target avoids the effect.',
    );
  }

  Future<void> rollAttack(
    CharacterAction action, {
    bool asRitual = false,
    bool useFreeCast = false,
    String? scrollName,
    bool asReaction = false,
    bool retaliation = false,
    bool? packTacticsChoice,
  }) async {
    if (retaliation && !canRetaliate) return;
    final modifier = scrollName != null && action is Spell
        ? action.scrollAttackBonus
        : character.attackModifierFor(action);
    if (modifier == null) return;
    final beastAttack = action.id.startsWith('wild-shape-');
    final ownWeaponAttack =
        action is Weapon && !asReaction && currentMode == CharacterMode.combat;
    bool canMakeWeaponAttack() => !ownWeaponAttack || canUseAttackAction;
    if (!canMakeWeaponAttack()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No Attack action attacks remaining. Use another available Action or advance the turn.',
          ),
        ),
      );
      return;
    }
    bool canUseBeastAttack() =>
        !beastAttack ||
        (activeWildShape?.combatAttack.id == action.id &&
            characterState.canConcentrate &&
            (currentMode != CharacterMode.combat ||
                asReaction ||
                canMakeWeaponAttack()));
    if (!canUseBeastAttack()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This Beast attack is unavailable or your Action is already spent.',
          ),
        ),
      );
      return;
    }
    var packTactics = packTacticsChoice ?? false;
    if (packTacticsChoice == null &&
        action.id == 'wild-shape-wolf' &&
        activeWildShape?.name == 'Wolf') {
      final advantage = await choosePackTactics();
      if (!mounted || advantage == null || activeWildShape?.name != 'Wolf') {
        return;
      }
      packTactics = advantage;
    }
    if (!canUseBeastAttack()) return;
    int? slotLevel;
    if (action is Spell) {
      if (!canSpendSpellAction(action, fromScroll: scrollName != null)) return;
      if (scrollName != null) {
        if (!spendInventoryItem(scrollName)) return;
        slotLevel = action.level;
      }
      if (useFreeCast && !spendFreeCast(action)) return;
      if (scrollName == null &&
          !useFreeCast &&
          !asRitual &&
          tracksSlotsFor(action)) {
        final slot = await chooseTrackedSlot(action);
        slotLevel = slot?.$1;
        if (!mounted ||
            slot == null ||
            !canSpendSpellAction(action, fromScroll: scrollName != null) ||
            !spendCastResource(slot.$2)) {
          return;
        }
      }
      if (action.concentration) {
        startSpellConcentration(action, slotLevel: slotLevel);
      }
      trackSpellAction(action);
    }
    pendingAttackSlot = slotLevel == null
        ? null
        : (action.actionKey, slotLevel);
    if (retaliation && !canRetaliate) return;
    if (action case Weapon(ammunitionName: final name?)) {
      if (!spendInventoryItem(name)) return;
    }
    if (ownWeaponAttack) {
      if (!canMakeWeaponAttack()) return;
      spendAttackActionAttack();
    }
    if (action is Weapon && characterState.isRaging && !asReaction) {
      extendRage();
    }
    final threshold = action is Weapon ? character.weaponCriticalThreshold : 20;
    final aimed = consumeSteadyAimAdvantage();
    if (retaliation) spendRetaliationReaction();
    var attackMode = D20Mode.normal;
    var attackDice = <int>[];
    var roll = rollCheck(
      '${action.name} Attack',
      modifier,
      strengthAttack: action is Weapon
          ? action.usesStrength
          : action is Spell && action.castingAbility == Ability.strength,
      reactionAttack: asReaction,
      peerlessEligible: true,
      attackRoll: true,
      criticalThreshold: threshold,
      onD20Rolled: (mode, dice) {
        attackMode = mode;
        attackDice = dice;
      },
      hasAdvantage:
          packTactics ||
          aimed ||
          (scrollName == null &&
              action is Spell &&
              characterForPhysicalChecks.benefitsFromInnateSorcery(action)),
    );
    if (action is Spell && scrollName == null) {
      roll = await maybeSeekSpellAttack(action, roll, attackMode, attackDice);
      if (!mounted) return;
    }
    final critical = roll.naturalRoll >= threshold;
    pendingCriticalActionKey =
        critical &&
            DiceExpression.tryParse(character.damageFormulaFor(action) ?? '') !=
                null
        ? action.actionKey
        : null;
    if (critical && character.championLevel >= 3) {
      recordSessionEvent(
        SessionEventType.combat,
        'Remarkable Athlete',
        detail:
            'You can move up to half your Speed without provoking opportunity attacks.',
      );
    }
    if (action case Weapon(mastery: final mastery?)) {
      await resolveWeaponMastery(action, mastery, roll);
    }
    if (action is Weapon && !asReaction) await resolveNick(action);
    if (action.id == 'wild-shape-wolf' && !roll.isNaturalOne) {
      recordSessionEvent(
        SessionEventType.combat,
        'Wolf Bite effect',
        detail: 'On a hit, a Medium or smaller target falls Prone.',
      );
    }
  }

  Future<CheckRoll> maybeSeekSpellAttack(
    Spell spell,
    CheckRoll original,
    D20Mode mode,
    List<int> dice,
  ) async {
    bool available() {
      final points = resourceWithId(sorceryPointsResourceId);
      return character.knowsMetamagic(Metamagic.seeking) &&
          points != null &&
          remainingUses(points) > 0 &&
          characterState.canConcentrate &&
          !original.isNaturalTwenty &&
          dice.isNotEmpty;
    }

    if (!available()) return original;
    final index = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Seeking Spell · ${spell.name}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Attack total ${original.total} · ${mode.label}. Use only if this attack missed. '
              'Spend 1 Sorcery Point to reroll one d20 and keep its new result. '
              'The other die and the original roll mode remain unchanged.',
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Attack'),
          ),
          for (var i = 0; i < dice.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text('Miss · Reroll die ${i + 1} (${dice[i]})'),
            ),
        ],
      ),
    );
    if (!mounted ||
        index == null ||
        index < 0 ||
        index >= dice.length ||
        !available() ||
        !spendCastResource(sorceryPointsResourceId)) {
      return original;
    }
    final rerolled = [...dice];
    rerolled[index] = diceRoller.rollD20();
    final result = CheckRoll(
      label: original.label,
      naturalRoll: mode.select(
        rerolled.first,
        rerolled.length > 1 ? rerolled[1] : null,
      ),
      modifier: original.modifier,
      minimumRoll: original.minimumRoll,
      minimumTotal: original.minimumTotal,
    );
    if (hasPeerlessSkill) {
      peerlessSkillRoll = result.isNaturalOne || result.isNaturalTwenty
          ? null
          : result;
    }
    addRollNotice(
      title: '${spell.name} Attack · Seeking Spell',
      calculation:
          '${mode.label}: ${rerolled.join(', ')} → d20 ${result.naturalRoll} '
          '${result.displayModifier} = ${result.total}',
      total: result.total,
      detail:
          'Miss confirmed · 1 Sorcery Point spent · Die ${index + 1}: '
          '${dice[index]} → ${rerolled[index]}. New result retained.'
          '${result.isNaturalTwenty
              ? ' Natural 20.'
              : result.isNaturalOne
              ? ' Natural 1.'
              : ''}',
      tone: result.isNaturalTwenty
          ? RollNoticeTone.criticalSuccess
          : result.isNaturalOne
          ? RollNoticeTone.criticalFailure
          : RollNoticeTone.normal,
    );
    return result;
  }

  Future<void> resolveWeaponMastery(
    Weapon weapon,
    WeaponMastery mastery,
    CheckRoll roll,
  ) async {
    if (mastery == WeaponMastery.cleave) {
      await resolveCleave(weapon, roll);
      return;
    }
    final ability = weapon.usesStrength ? Ability.strength : Ability.dexterity;
    final modifier = character.abilityModifierFor(ability);
    final grazeDamage = modifier > 0 ? modifier : 0;
    final toppleDc = 8 + modifier + character.proficiencyBonus;
    final effect = switch (mastery) {
      WeaponMastery.graze when grazeDamage > 0 =>
        'The target takes $grazeDamage ${weapon.damageType ?? 'weapon'} damage.',
      WeaponMastery.push =>
        'You can push a Large or smaller target up to 10 feet directly away.',
      WeaponMastery.sap =>
        'The target has Disadvantage on its next attack before your next turn.',
      WeaponMastery.slow =>
        'Reduce the target’s Speed by 10 feet until your next turn. Slow does not stack.',
      WeaponMastery.topple =>
        'The target falls Prone if it fails a DC $toppleDc Constitution save.',
      WeaponMastery.vex =>
        'Your next attack against this target has Advantage before the end of your next turn.',
      _ => null,
    };
    if (effect == null) return;
    final onMiss = mastery == WeaponMastery.graze;
    if (onMiss
        ? roll.naturalRoll >= character.weaponCriticalThreshold
        : roll.isNaturalOne) {
      return;
    }
    final requiresDamage =
        mastery == WeaponMastery.slow || mastery == WeaponMastery.vex;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${weapon.name} · ${mastery.label}'),
        content: Text('Attack total ${roll.total}\n\n$effect'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              onMiss
                  ? 'Attack missed'
                  : mastery == WeaponMastery.topple
                  ? 'Hit and force save'
                  : requiresDamage
                  ? 'Hit and dealt damage'
                  : 'Attack hit',
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (mastery == WeaponMastery.graze) {
      addRollNotice(
        title: '${weapon.name} Graze Damage',
        calculation: '$grazeDamage damage from your attack ability modifier',
        total: grazeDamage,
        tone: RollNoticeTone.damage,
        detail: weapon.damageType,
      );
      return;
    }
    recordSessionEvent(
      SessionEventType.combat,
      '${weapon.name} · ${mastery.label}',
      detail: effect,
    );
    if (mastery == WeaponMastery.topple) {
      final failed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Topple saving throw'),
          content: Text(
            'The target makes a DC $toppleDc Constitution save. '
            'Resolve its roll and any immunities at the table.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Resolve later'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Save succeeded'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save failed · Prone'),
            ),
          ],
        ),
      );
      if (!mounted || failed == null) return;
      recordSessionEvent(
        SessionEventType.combat,
        '${weapon.name} · Topple ${failed ? 'failed save' : 'successful save'}',
        detail: failed
            ? 'The target falls Prone (DC $toppleDc Constitution save).'
            : 'The target stays standing (DC $toppleDc Constitution save).',
      );
    }
  }

  Future<void> resolveNick(Weapon original) async {
    if (!mounted ||
        currentMode != CharacterMode.combat ||
        nickUsedThisTurn ||
        !original.isLight ||
        !characterState.canConcentrate) {
      return;
    }
    final eligible = character.weapons
        .where(
          (weapon) =>
              weapon.id != original.id &&
              weapon.isLight &&
              weapon.mastery == WeaponMastery.nick &&
              weapon.ammunitionName == null,
        )
        .toList();
    if (eligible.isEmpty) return;
    final selected = await showDialog<Weapon>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Nick extra attack'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'If this was an Attack action on your turn, choose a different Light '
              'weapon for the Light property extra attack. Confirm you have not '
              'already used that extra attack this turn. Nick uses no Bonus Action.',
            ),
          ),
          for (final weapon in eligible)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, weapon),
              child: Text('Nick · ${weapon.name}'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (!mounted ||
        selected == null ||
        nickUsedThisTurn ||
        currentMode != CharacterMode.combat ||
        !characterState.canConcentrate) {
      return;
    }
    nickUsedThisTurn = true;
    await rollMasteryExtraAttack(selected, 'Nick');
  }

  Future<void> resolveCleave(Weapon weapon, CheckRoll original) async {
    if (currentMode != CharacterMode.combat ||
        cleaveUsedThisTurn ||
        original.isNaturalOne ||
        !characterState.canConcentrate) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${weapon.name} · Cleave'),
        content: Text(
          'Attack total ${original.total}. If this melee attack hit, '
          'you can attack a second creature within 5 feet of the first '
          'and within your reach.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hit · Make Cleave Attack'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        cleaveUsedThisTurn ||
        currentMode != CharacterMode.combat ||
        !characterState.canConcentrate) {
      return;
    }
    cleaveUsedThisTurn = true;
    await rollMasteryExtraAttack(weapon, 'Cleave');
  }

  Future<void> rollMasteryExtraAttack(Weapon weapon, String mastery) async {
    final attack = rollCheck(
      '${weapon.name} $mastery Attack',
      weapon.attackModifier,
      strengthAttack: weapon.usesStrength,
      peerlessEligible: true,
      attackRoll: true,
      criticalThreshold: character.weaponCriticalThreshold,
      hasAdvantage: consumeSteadyAimAdvantage(),
    );
    publishSession();
    if (attack.isNaturalOne) return;
    final hit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$mastery result'),
        content: Text(
          'Attack total ${attack.total}. Did the second attack hit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Miss'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hit · Roll $mastery Damage'),
          ),
        ],
      ),
    );
    if (!mounted || hit != true) return;
    final formula = character.damageFormulaFor(
      weapon,
      raging: characterState.isRaging,
    );
    var expression = DiceExpression.tryParse(formula ?? '');
    if (expression == null) return;
    final ability = weapon.usesStrength ? Ability.strength : Ability.dexterity;
    final modifier = character.abilityModifierFor(ability);
    if (modifier > 0) expression = expression.withModifierBonus(-modifier);
    if (attack.naturalRoll >= character.weaponCriticalThreshold) {
      expression = expression.withCriticalHitDice();
    }
    final damage = expression.roll(mastery, diceRoller);
    addRollNotice(
      title: '${weapon.name} $mastery Damage',
      calculation:
          '${expression.notation} · ${damage.dice.join(' + ')} = ${damage.total}',
      total: damage.total,
      tone: RollNoticeTone.damage,
      detail: weapon.damageType,
    );
    if (weapon.isMelee) {
      rollRadiantStrikes(
        critical: attack.naturalRoll >= character.weaponCriticalThreshold,
      );
    }
    await resolveSneakAttack(
      weapon,
      critical: attack.naturalRoll >= character.weaponCriticalThreshold,
    );
    await resolveFrenzy(
      usesStrength: weapon.usesStrength,
      critical: attack.naturalRoll >= character.weaponCriticalThreshold,
      damageType: weapon.damageType,
    );
  }

  void rollRadiantStrikes({required bool critical}) {
    if (character.levelInClass('Paladin') < 11) return;
    final expression = DiceExpression(diceCount: critical ? 2 : 1, dieSides: 8);
    final roll = expression.roll('Radiant Strikes', diceRoller);
    addRollNotice(
      title: critical
          ? 'Radiant Strikes Critical Damage'
          : 'Radiant Strikes Damage',
      calculation:
          '${expression.notation}: ${roll.dice.join(' + ')} = ${roll.total}',
      total: roll.total,
      tone: RollNoticeTone.damage,
      detail:
          'Radiant damage. Apply resistance separately from the strike’s other damage.',
    );
  }

  bool get hasPoisonersKit => inventory.any(
    (item) =>
        item.quantity > 0 &&
        item.name.toLowerCase().replaceAll(RegExp('[^a-z]'), '') ==
            'poisonerskit',
  );

  Future<void> resolveCunningStrike(CunningStrike effect) async {
    if (!mounted) return;
    if (effect.save == null) {
      recordSessionEvent(
        SessionEventType.combat,
        'Cunning Strike · ${effect.label}',
        detail: effect.effect,
      );
      return;
    }
    final dc =
        8 +
        characterForPhysicalChecks.abilityModifierFor(Ability.dexterity) +
        character.proficiencyBonus;
    recordSessionEvent(
      SessionEventType.combat,
      'Cunning Strike · ${effect.label}',
      detail: 'DC $dc ${effect.save!.label} save · ${effect.effect}',
    );
    final failed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cunning Strike · ${effect.label}'),
        content: Text(
          'DC $dc ${effect.save!.label} save. ${effect.effect} '
          'Resolve target rolls, eligibility and immunity at the table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Resolve later'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Save succeeded'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save failed'),
          ),
        ],
      ),
    );
    if (!mounted || failed == null) return;
    recordSessionEvent(
      SessionEventType.combat,
      'Cunning Strike · ${effect.label} · ${failed ? 'failed save' : 'successful save'}',
      detail: failed ? effect.effect : 'The target avoids the effect.',
    );
  }

  Future<void> resolveSneakAttack(
    Weapon weapon, {
    required bool critical,
  }) async {
    bool canUse() =>
        currentMode == CharacterMode.combat &&
        characterState.canConcentrate &&
        character.sneakAttackDice > 0 &&
        weapon.sneakAttackEligible &&
        !sneakAttackUsedThisTurn;
    if (!canUse()) return;
    final selection = await showDialog<SneakAttackSelection>(
      context: context,
      builder: (context) => SneakAttackDialog(
        weaponName: weapon.name,
        damageType: weapon.damageType ?? 'weapon',
        rogueLevel: character.levelInClass('Rogue'),
        diceCount: character.sneakAttackDice,
        critical: critical,
        hasPoisonersKit: hasPoisonersKit,
      ),
    );
    if (!mounted ||
        selection == null ||
        !canUse() ||
        !selection.isValid(
          rogueLevel: character.levelInClass('Rogue'),
          sneakDice: character.sneakAttackDice,
          hasPoisonersKit: hasPoisonersKit,
        )) {
      return;
    }
    sneakAttackUsedThisTurn = true;
    final expression = DiceExpression(
      diceCount:
          (character.sneakAttackDice - selection.diceCost) * (critical ? 2 : 1),
      dieSides: 6,
    );
    final roll = expression.roll('Sneak Attack', diceRoller);
    addRollNotice(
      title: critical ? 'Sneak Attack Critical Damage' : 'Sneak Attack Damage',
      calculation: roll.dice.isEmpty
          ? 'All Sneak Attack dice traded for Cunning Strike · 0 damage'
          : '${expression.notation}: ${roll.dice.join(' + ')} = ${roll.total}',
      total: roll.total,
      tone: RollNoticeTone.damage,
      detail:
          'Add to this hit’s ${weapon.damageType ?? 'weapon'} damage before applying resistance.',
    );
    for (final effect in selection.effects) {
      await resolveCunningStrike(effect);
      if (!mounted) return;
    }
  }

  Future<void> confirmNewSneakAttackTurn() async {
    if (currentMode != CharacterMode.combat ||
        (!sneakAttackUsedThisTurn &&
            !stunningStrikeUsedThisTurn &&
            !characterState.activeConditions.contains(steadyAimCondition))) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Another creature’s turn'),
        content: const Text(
          'Confirm that a different creature’s turn has begun. This refreshes Sneak Attack and Stunning Strike, ends Steady Aim, and clears pending Flurry strikes. '
          'It does not restore your Action, Bonus Action, or Reaction.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Different turn confirmed'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        currentMode != CharacterMode.combat ||
        (!sneakAttackUsedThisTurn &&
            !stunningStrikeUsedThisTurn &&
            !characterState.activeConditions.contains(steadyAimCondition))) {
      return;
    }
    beginAnotherCreatureTurn();
  }

  Future<void> rollDamage(
    CharacterAction action, {
    bool repeatingEffect = false,
    bool castingSpell = false,
    bool asRitual = false,
    bool useFreeCast = false,
    String? scrollName,
  }) async {
    var damageType = action is Spell
        ? effectiveSpellDamageType(action)
        : action.damageType;
    final formAttack = activeWildShape;
    if (formAttack?.fixedDamage != null &&
        action.id == formAttack!.combatAttack.id) {
      pendingCriticalActionKey = null;
      addRollNotice(
        title: '${action.name} Damage',
        calculation: '${formAttack.fixedDamage} $damageType damage',
        total: formAttack.fixedDamage!,
        tone: RollNoticeTone.damage,
        detail: '$damageType damage',
      );
      return;
    }
    if (action.id == 'wild-shape-spider' && activeWildShape?.name == 'Spider') {
      final critical = pendingCriticalActionKey == action.actionKey;
      pendingCriticalActionKey = null;
      final expression = DiceExpression(
        diceCount: critical ? 2 : 1,
        dieSides: 4,
      );
      final poison = expression.roll('Spider Bite poison', diceRoller);
      addRollNotice(
        title: critical ? 'Spider Bite Critical Damage' : 'Spider Bite Damage',
        calculation: '1 piercing + ${poison.total} poison',
        total: 1 + poison.total,
        tone: RollNoticeTone.damage,
        detail: 'Apply piercing and poison resistance separately.',
      );
      return;
    }
    int? slotLevel = repeatingEffect
        ? characterState.concentrationSlotLevel
        : null;
    final attackSlot = pendingAttackSlot;
    final useAttackSlot =
        !castingSpell && !repeatingEffect && attackSlot?.$1 == action.actionKey;
    if (useAttackSlot) slotLevel = attackSlot?.$2;
    final spendSlot =
        castingSpell &&
        scrollName == null &&
        !asRitual &&
        !useFreeCast &&
        action is Spell &&
        tracksSlotsFor(action);
    String? chosenSlotId;
    if (spendSlot) {
      final slot = await chooseTrackedSlot(action);
      if (!mounted || slot == null) return;
      (slotLevel, chosenSlotId) = slot;
    } else if (action
        case Spell(additionalDicePerSlotLevel: > 0, level: > 0 && < 9)
        when scrollName == null &&
            !repeatingEffect &&
            !useAttackSlot &&
            !asRitual &&
            !useFreeCast) {
      slotLevel = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('${action.name} slot level'),
          children: [
            for (var level = action.level; level <= 9; level++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, level),
                child: Text(
                  'Level $level · ${character.damageFormulaFor(action, slotLevel: level)}',
                ),
              ),
          ],
        ),
      );
      if (!mounted || slotLevel == null) return;
    }
    var halfDamage = false;
    var noDamage = false;
    var protectedTarget = false;
    if (action case Spell(
      savingThrowAbility: final ability?,
      damageFormula: final formula?,
    ) when formula.isNotEmpty && character.attackModifierFor(action) == null) {
      final dc = scrollName == null
          ? (action.isCircleGrant ||
                    characterForPhysicalChecks.benefitsFromInnateSorcery(action)
                ? characterForPhysicalChecks.spellSaveDc(action)
                : null)
          : action.scrollSaveDc;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(action.name),
          content: Text(
            '${dc == null ? 'Did the target succeed on its ${ability.label} save?' : 'Did the target succeed on its DC $dc ${ability.label} save?'}'
            '\n${saveEffectFor(action, newCast: castingSpell)?.guidance ?? ''}',
          ),
          actions: [
            if (saveEffectFor(action, newCast: castingSpell)?.option ==
                Metamagic.careful)
              TextButton(
                onPressed: () {
                  protectedTarget = true;
                  Navigator.pop(context, true);
                },
                child: const Text('Protected target · Automatic save'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Failed save'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Successful save'),
            ),
          ],
        ),
      );
      if (!mounted || result == null) return;
      halfDamage = result && action.halfDamageOnSave && !protectedTarget;
      noDamage = protectedTarget || (result && !action.halfDamageOnSave);
    }
    var formula = character.damageFormulaFor(
      action,
      slotLevel: slotLevel,
      raging: characterState.isRaging,
      applyPotentSpellcasting: scrollName == null,
    );
    final twoHanded = action is Weapon
        ? character.damageFormulaFor(
            action,
            raging: characterState.isRaging,
            twoHanded: true,
          )
        : null;
    if (twoHanded != null && formula != null) {
      formula = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('${action.name} damage'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, formula),
              child: Text('One-handed · $formula'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, twoHanded),
              child: Text('Two-handed · $twoHanded'),
            ),
          ],
        ),
      );
      if (!mounted || formula == null) return;
    }
    final baseExpression = DiceExpression.tryParse(formula ?? '');
    if (baseExpression == null) return;
    if (repeatingEffect && characterState.concentrationSpellId != action.id) {
      return;
    }
    if (castingSpell &&
        action is Spell &&
        !canSpendSpellAction(action, fromScroll: scrollName != null)) {
      return;
    }
    final critical =
        !castingSpell &&
        !repeatingEffect &&
        pendingCriticalActionKey == action.actionKey;
    if (castingSpell && action is Spell) {
      if (scrollName != null && !spendInventoryItem(scrollName)) return;
      if (useFreeCast && !spendFreeCast(action)) return;
      if (chosenSlotId != null && !spendCastResource(chosenSlotId)) return;
      trackSpellAction(action);
      pendingAttackSlot = null;
      pendingCriticalActionKey = null;
      if (action.concentration) {
        startSpellConcentration(action, slotLevel: slotLevel);
      }
    } else if (!repeatingEffect &&
        slotLevel != null &&
        characterState.concentrationSpellId == action.id &&
        action is Spell) {
      updateCharacterState(
        characterState.copyWith(concentrationSlotLevel: slotLevel),
      );
    }
    if (useAttackSlot) pendingAttackSlot = null;
    if (critical) pendingCriticalActionKey = null;
    damageType = action is Spell
        ? effectiveSpellDamageType(action)
        : action.damageType;
    if (noDamage) {
      addRollNotice(
        title: repeatingEffect
            ? '${action.name} Repeat Effect'
            : '${action.name} Damage',
        calculation: protectedTarget
            ? 'Careful Spell · Protected target · No damage'
            : 'Successful save · No damage',
        total: 0,
        tone: RollNoticeTone.damage,
        detail: damageType == null ? null : '$damageType damage',
      );
      return;
    }
    var expression = critical
        ? baseExpression.withCriticalHitDice()
        : baseExpression;
    final iceStorm =
        action is Spell && action.isCircleGrant && action.name == 'Ice Storm';
    final affinityBonus = action is Spell
        ? await confirmElementalAffinityBonus(
            action,
            iceStorm ? 'cold' : damageType,
          )
        : 0;
    if (!mounted) return;
    if (!iceStorm && affinityBonus != 0) {
      expression = expression.withModifierBonus(affinityBonus);
    }
    HapticFeedback.selectionClick();
    var roll = expression.roll(action.name, diceRoller);
    if (action is Spell && !iceStorm) {
      roll = await maybeEmpowerSpellDamage(action, roll);
      if (!mounted) return;
    }
    if (action is Spell && action.isCircleGrant && action.name == 'Ice Storm') {
      final cold = const DiceExpression(
        diceCount: 4,
        dieSides: 6,
      ).withModifierBonus(affinityBonus).roll('Ice Storm cold', diceRoller);
      final bludgeoningDamage = halfDamage ? roll.total ~/ 2 : roll.total;
      final coldTotal = cold.total.clamp(0, 999999);
      final coldDamage = halfDamage ? coldTotal ~/ 2 : coldTotal;
      addRollNotice(
        title: 'Ice Storm Damage',
        calculation: '$bludgeoningDamage bludgeoning + $coldDamage cold',
        total: bludgeoningDamage + coldDamage,
        detail: 'Apply each damage type’s resistance separately.',
        tone: RollNoticeTone.damage,
      );
      return;
    }
    final adjustedTotal = action is Spell && affinityBonus != 0
        ? roll.total.clamp(0, 999999)
        : roll.total;
    final total = halfDamage
        ? (adjustedTotal < 0 ? 0 : adjustedTotal ~/ 2)
        : adjustedTotal;
    final dice = roll.dice.join(' + ');
    final modifier = expression.modifier;
    final modifierText = modifier == 0
        ? ''
        : modifier > 0
        ? ' + $modifier'
        : ' - ${modifier.abs()}';
    addRollNotice(
      title: repeatingEffect
          ? '${action.name} Repeat Effect'
          : critical
          ? '${action.name} Critical Damage'
          : '${action.name} Damage',
      calculation:
          '${expression.notation}: $dice$modifierText = ${roll.total}'
          '${adjustedTotal != roll.total ? ' → $adjustedTotal minimum damage' : ''}'
          '${halfDamage ? ' → $total after save' : ''}',
      total: total,
      detail: damageType == null ? 'Damage' : '$damageType damage',
      tone: RollNoticeTone.damage,
    );
    if (action is Weapon && action.isMelee) {
      rollRadiantStrikes(critical: critical);
    }
    if (action is Weapon) {
      await resolveSneakAttack(action, critical: critical);
      await resolveFrenzy(
        usesStrength: action.usesStrength,
        critical: critical,
        damageType: damageType,
      );
    }
  }

  Future<void> rollDeathSave() async {
    if (!characterState.canRollDeathSave) return;
    final defyDeath = character.championLevel >= 18;
    final survivor = character.levelInClass('Monk') >= 14;
    int result(CheckRoll roll) => defyDeath && roll.naturalRoll >= 18
        ? 20
        : roll.naturalRoll == 1 || roll.naturalRoll == 20
        ? roll.naturalRoll
        : roll.total >= 10
        ? 10
        : 2;
    var roll = rollCheck(
      'Death Save',
      survivor ? character.proficiencyBonus : 0,
      useSelectedMode: false,
      hasAdvantage: defyDeath,
      criticalThreshold: defyDeath ? 18 : 20,
      describe: (roll) {
        final updated = characterState.applyDeathSave(result(roll));
        return switch (result(roll)) {
          20 => 'Natural ${roll.naturalRoll} · Recovered 1 HP',
          1 when updated.deathSaveFailures == 3 => 'Natural 1 · Dead',
          1 => 'Natural 1 · Two failures',
          _ when updated.deathSaveFailures == 3 => 'Dead',
          _ when updated.deathSaveSuccesses == 3 => 'Stable',
          >= 10 => 'Success · ${updated.deathSaveSuccesses} of 3',
          _ => 'Failure · ${updated.deathSaveFailures} of 3',
        };
      },
    );
    if (result(roll) < 10) {
      roll = await rerollWithDisciplinedSurvivor(
        roll,
        defyDeath ? D20Mode.advantage : D20Mode.normal,
        knownFailure: true,
      );
    }
    if (!mounted || !characterState.canRollDeathSave) return;
    if (result(roll) < 10 && !roll.isNaturalOne) {
      roll = await boostFailedSaveWithDarkLuck(roll, dc: 10);
    }
    if (!mounted || !characterState.canRollDeathSave) return;
    updateCharacterState(characterState.applyDeathSave(result(roll)));
  }

  Future<CheckRoll> rerollWithDisciplinedSurvivor(
    CheckRoll original,
    D20Mode mode, {
    bool knownFailure = false,
    bool tableResolvedSave = false,
  }) async {
    final focus = character.resources
        .where((resource) => resource.id == focusResourceId)
        .firstOrNull;
    if (character.levelInClass('Monk') < 14 ||
        focus == null ||
        remainingUses(focus) < 1) {
      return original;
    }
    final reroll = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disciplined Survivor'),
        content: Text(
          '${original.label} total ${original.total}. ${knownFailure ? 'The save failed.' : 'Confirm that this save failed before rerolling.'} Spend 1 Focus Point to reroll and use the new result, even if lower.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Result'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Spend 1 Focus · Reroll Failed Save'),
          ),
        ],
      ),
    );
    if (!mounted || reroll != true || remainingUses(focus) < 1) return original;
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          focus.id: remainingUses(focus) - 1,
        },
      ),
    );
    return rollCheck(
      '${original.label} · Disciplined Survivor',
      original.modifier,
      modeOverride: mode,
      minimumTotal: original.minimumTotal,
      darkLuckEligible: tableResolvedSave,
    );
  }

  Future<DamageRoll> maybeEmpowerSpellDamage(
    Spell spell,
    DamageRoll roll,
  ) async {
    bool available() {
      final points = resourceWithId(sorceryPointsResourceId);
      return character.knowsMetamagic(Metamagic.empowered) &&
          points != null &&
          remainingUses(points) > 0 &&
          characterState.canConcentrate &&
          roll.dice.isNotEmpty &&
          IncomingDamageType.values.any(
            (type) =>
                type != IncomingDamageType.other &&
                type.label.toLowerCase() ==
                    spell.damageType?.trim().toLowerCase(),
          );
    }

    if (!available()) return roll;
    final maximum = character
        .abilityModifierFor(Ability.charisma)
        .clamp(1, roll.dice.length);
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (context) => EmpoweredSpellDialog(roll: roll, maximum: maximum),
    );
    if (!mounted ||
        selected == null ||
        selected.isEmpty ||
        selected.length > maximum ||
        selected.any((i) => i < 0 || i >= roll.dice.length) ||
        !available() ||
        !spendCastResource(sorceryPointsResourceId)) {
      return roll;
    }
    final dice = [
      for (var i = 0; i < roll.dice.length; i++)
        selected.contains(i)
            ? diceRoller.rollDie(roll.expression.dieSides)
            : roll.dice[i],
    ];
    recordSessionEvent(
      SessionEventType.roll,
      'Empowered Spell · ${spell.name}',
      detail:
          '1 Sorcery Point spent. ${roll.dice.join(', ')} → ${dice.join(', ')}. New results retained; modifiers unchanged.',
    );
    return DamageRoll(
      label: roll.label,
      expression: roll.expression,
      dice: dice,
    );
  }

  CheckRoll rollCheck(
    String label,
    int modifier, {
    bool useSelectedMode = true,
    Ability? checkAbility,
    int? minimumTotal,
    bool peerlessEligible = false,
    bool darkLuckEligible = false,
    bool attackRoll = false,
    bool strengthAttack = false,
    bool reactionAttack = false,
    bool hasAdvantage = false,
    D20Mode? modeOverride,
    int criticalThreshold = 20,
    int? minimumRoll,
    String? minimumRollReason,
    String Function(CheckRoll)? describe,
    void Function(D20Mode, List<int>)? onD20Rolled,
  }) {
    tacticalMindCheck = null;
    peerlessSkillRoll = null;
    darkLuckRoll = null;
    if (attackRoll) {
      recordAttackForReckless(asReaction: reactionAttack);
      hasAdvantage =
          hasAdvantage ||
          (strengthAttack &&
              currentMode == CharacterMode.combat &&
              character.levelInClass('Barbarian') >= 2 &&
              characterState.activeConditions.contains(
                recklessAttackCondition,
              ));
    }
    final selectedMode = useSelectedMode ? nextRollMode : D20Mode.normal;
    final mode =
        modeOverride ??
        (hasAdvantage ? selectedMode.withAdvantage() : selectedMode);
    if (selectedMode != D20Mode.normal) {
      setState(() => nextRollMode = D20Mode.normal);
    }
    final first = diceRoller.rollD20();
    final second = mode == D20Mode.normal ? null : diceRoller.rollD20();
    onD20Rolled?.call(mode, [first, ?second]);
    final roll = CheckRoll(
      label: label,
      naturalRoll: mode.select(first, second),
      modifier: modifier,
      minimumRoll: minimumRoll,
      minimumTotal:
          minimumTotal ??
          (checkAbility == Ability.strength &&
                  character.levelInClass('Barbarian') >= 18
              ? characterForPhysicalChecks.scoreFor(Ability.strength)
              : null),
    );
    final minimumApplied = roll.effectiveRoll != roll.naturalRoll;
    if (darkLuckEligible && hasDarkOnesOwnLuck) darkLuckRoll = roll;
    final totalMinimumApplied = roll.total != roll.unadjustedTotal;
    if (hasPeerlessSkill &&
        peerlessEligible &&
        (!attackRoll ||
            (!roll.isNaturalOne && roll.naturalRoll < criticalThreshold))) {
      peerlessSkillRoll = roll;
    }
    final critical = roll.naturalRoll >= criticalThreshold;
    if (critical) {
      HapticFeedback.heavyImpact();
    } else if (roll.isNaturalOne && !minimumApplied && !totalMinimumApplied) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    final operator = modifier >= 0 ? '+' : '-';
    addRollNotice(
      title: label,
      calculation: [
        if (second != null) '${mode.label}: $first, $second →',
        'd20 ${roll.naturalRoll}${minimumApplied ? ' → ${roll.effectiveRoll}' : ''} $operator ${modifier.abs()} = ${roll.unadjustedTotal}${totalMinimumApplied ? ' → ${roll.total}' : ''}',
      ].join(' '),
      total: roll.total,
      detail: totalMinimumApplied
          ? 'Indomitable Might: use Strength score ${roll.minimumTotal}'
                '${minimumApplied ? ' · ${minimumRollReason ?? 'Minimum roll'}: use ${roll.effectiveRoll}' : ''}'
                '${describe == null ? '' : ' · ${describe(roll)}'}'
          : minimumApplied
          ? '${minimumRollReason ?? 'Minimum roll'}: use ${roll.effectiveRoll}'
                '${describe == null ? '' : ' · ${describe(roll)}'}'
          : describe?.call(roll) ??
                (critical
                    ? roll.isNaturalTwenty
                          ? 'Natural 20'
                          : 'Critical hit · Natural ${roll.naturalRoll}'
                    : roll.isNaturalOne
                    ? 'Natural 1'
                    : null),
      tone: critical
          ? RollNoticeTone.criticalSuccess
          : roll.isNaturalOne && !minimumApplied && !totalMinimumApplied
          ? RollNoticeTone.criticalFailure
          : RollNoticeTone.normal,
    );
    return roll;
  }

  void addRollNotice({
    required String title,
    required String calculation,
    required int total,
    required RollNoticeTone tone,
    String? detail,
  }) {
    final notice = RollNotice(
      id: nextRollNoticeId++,
      title: title,
      calculation: calculation,
      total: total,
      detail: detail,
      tone: tone,
    );
    setState(() {
      rollNotices.insert(0, notice);
      if (rollNotices.length > 5) {
        final removed = rollNotices.removeLast();
        for (final timer in rollNoticeTimers.remove(removed.id) ?? <Timer>[]) {
          timer.cancel();
        }
      }
    });
    recordSessionEvent(
      SessionEventType.roll,
      '$title: $total',
      detail: detail == null ? calculation : '$calculation | $detail',
    );

    rollNoticeTimers[notice.id] = [
      Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        final index = rollNotices.indexWhere((item) => item.id == notice.id);
        if (index == -1) return;
        setState(() {
          rollNotices[index] = rollNotices[index].copyWith(visible: false);
        });
      }),
      Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() {
          rollNotices.removeWhere((item) => item.id == notice.id);
        });
        rollNoticeTimers.remove(notice.id);
      }),
    ];
  }

  void togglePinnedAction(CharacterAction action) {
    final pinnedActionKeys = {...characterState.pinnedActionKeys};
    final wasPinned = pinnedActionKeys.remove(action.actionKey);

    if (!wasPinned) {
      pinnedActionKeys.add(action.actionKey);
    }

    updateCharacterState(
      characterState.copyWith(pinnedActionKeys: pinnedActionKeys),
    );
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasPinned
              ? '${action.name} unpinned from Combat'
              : '${action.name} pinned to Combat',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> adjustResource(CharacterResource resource) async {
    final currentValue =
        characterState.resourceValues[resource.id] ?? resource.initialValue;
    final adjustment = await showDialog<ResourceAdjustment>(
      context: context,
      builder: (context) => ResourceAdjustDialog(
        resource: resource,
        currentValue: currentValue,
        canConvertSlot: canRefillWithSlot(resource),
        canCreateWildResurgenceSlot: canCreateWildResurgenceSlot(resource),
        canUseTacticalMind:
            resource.id == secondWindResourceId &&
            character.levelInClass('Fighter') >= 2 &&
            tacticalMindCheck != null &&
            currentValue > 0,
      ),
    );

    if (!mounted || adjustment == null) {
      return;
    }
    if (adjustment == ResourceAdjustment.tacticalMind) {
      await useTacticalMind(resource);
      return;
    }
    if (adjustment == ResourceAdjustment.createWildResurgenceSlot) {
      if (!canCreateWildResurgenceSlot(resource)) return;
      updateCharacterState(
        characterState.copyWith(
          resourceValues: {
            ...characterState.resourceValues,
            resource.id: remainingUses(resource) - 1,
            wildResurgenceSlot.id: 1,
          },
        ),
      );
      recordSessionEvent(
        SessionEventType.resource,
        'Wild Resurgence · Level 1 spell slot created',
      );
      return;
    }
    if (adjustment == ResourceAdjustment.convertSlot) {
      final wildResurgence = resource.id == wildShapeResourceId;
      final slot = await chooseAvailableSlot(
        1,
        wildResurgence ? 'Wild Resurgence' : 'Font of Inspiration',
      );
      if (!mounted || slot == null || !canRefillWithSlot(resource)) {
        return;
      }
      final pool = castingResources
          .where((entry) => entry.id == slot.$2)
          .firstOrNull;
      if (pool == null || remainingUses(pool) <= 0) return;
      if (wildResurgence && currentMode == CharacterMode.combat) {
        wildResurgenceUsedThisTurn = true;
      }
      updateCharacterState(
        characterState.copyWith(
          resourceValues: {
            ...characterState.resourceValues,
            pool.id: remainingUses(pool) - 1,
            resource.id: remainingUses(resource) + 1,
          },
        ),
      );
      return;
    }

    final updatedValue = switch (adjustment) {
      ResourceAdjustment.spend => currentValue > 0 ? currentValue - 1 : 0,
      ResourceAdjustment.restore =>
        currentValue < resource.maximum ? currentValue + 1 : resource.maximum,
      ResourceAdjustment.refill => resource.maximum,
      ResourceAdjustment.convertSlot => currentValue,
      ResourceAdjustment.tacticalMind => currentValue,
      ResourceAdjustment.createWildResurgenceSlot => currentValue,
    };
    final resourceValues = {...characterState.resourceValues};
    resourceValues[resource.id] = updatedValue;

    updateCharacterState(
      characterState.copyWith(resourceValues: resourceValues),
    );
    HapticFeedback.selectionClick();
  }

  bool canRefillWithSlot(CharacterResource resource) => switch (resource.id) {
    bardicInspirationResourceId =>
      character.levelInClass('Bard') >= 5 &&
          remainingUses(resource) < resource.maximum,
    wildShapeResourceId =>
      character.levelInClass('Druid') >= 5 &&
          remainingUses(resource) == 0 &&
          !wildResurgenceUsedThisTurn,
    _ => false,
  };

  bool canCreateWildResurgenceSlot(CharacterResource resource) =>
      resource.id == wildShapeResourceId &&
      character.levelInClass('Druid') >= 5 &&
      remainingUses(resource) > 0 &&
      !characterState.resourceValues.containsKey(wildResurgenceSlot.id);

  Future<void> useTacticalMind(CharacterResource resource) async {
    final check = tacticalMindCheck;
    if (check == null || !characterState.canConcentrate) return;
    final dc = await showDialog<int>(
      context: context,
      builder: (context) => StatEditDialog(
        title: '${check.label} ${check.total} · Enter the failed check DC',
        initialValue: check.total >= 0 ? check.total + 1 : 1,
      ),
    );
    if (!mounted ||
        dc == null ||
        dc <= check.total ||
        !identical(check, tacticalMindCheck) ||
        remainingUses(resource) <= 0) {
      return;
    }
    tacticalMindCheck = null;
    final bonus = diceRoller.rollDie(10);
    peerlessSkillRoll = null;
    darkLuckRoll = null;
    final total = check.total + bonus;
    final success = total >= dc;
    if (success) spendCastResource(resource.id);
    addRollNotice(
      title: 'Tactical Mind · ${check.label}',
      calculation: '${check.total} + d10 $bonus = $total',
      total: total,
      detail: success ? 'DC $dc · Success' : 'DC $dc · Failed, use retained',
      tone: RollNoticeTone.normal,
    );
  }

  Future<void> useWholenessOfBody(CharacterResource resource) async {
    bool canUse() =>
        mounted &&
        character.levelInClass('Monk') >= 6 &&
        character.subclasses['Monk'] == 'Warrior of the Open Hand' &&
        characterState.canConcentrate &&
        remainingUses(resource) > 0 &&
        (currentMode != CharacterMode.combat ||
            !usedCombatActions.contains(CombatActionCost.bonusAction));
    if (!canUse()) return;
    final wisdom = character.abilityModifierFor(Ability.wisdom);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wholeness of Body'),
        content: Text(
          'Use one Wholeness of Body and ${currentMode == CharacterMode.combat ? 'your Bonus Action' : 'a Bonus Action'} to heal 1d${character.martialArtsDieSides} + $wisdom Wisdom (minimum 1 HP). Uses recover on a Long Rest. Focus Points are not spent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use Wholeness · Heal yourself'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !canUse()) return;
    final die = diceRoller.rollDie(character.martialArtsDieSides);
    final healing = (die + wisdom).clamp(1, 999999);
    final hp = (characterState.currentHp + healing).clamp(
      0,
      characterState.maxHp,
    );
    final gained = hp - characterState.currentHp;
    if (currentMode == CharacterMode.combat) {
      usedCombatActions.add(CombatActionCost.bonusAction);
    }
    updateCharacterState(
      characterState.copyWith(
        currentHp: hp,
        resourceValues: {
          ...characterState.resourceValues,
          resource.id: remainingUses(resource) - 1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'Wholeness of Body',
      detail:
          '1d${character.martialArtsDieSides} ($die) + $wisdom Wisdom = $healing healing · $gained HP recovered. One use spent.',
    );
  }

  Future<void> spendResource(CharacterResource resource) async {
    final currentValue =
        characterState.resourceValues[resource.id] ?? resource.initialValue;
    if (currentValue <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No ${resource.name} remaining'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    final resourceValues = {
      ...characterState.resourceValues,
      resource.id: currentValue - 1,
    };
    if (resource.id == rageResourceId) {
      startRage(resourceValues);
    } else if (resource.id == secondWindResourceId) {
      applySecondWind(resourceValues);
    } else if (resource.id == arcaneRecoveryResourceId) {
      await useArcaneRecovery();
    } else if (resource.id == wholenessOfBodyResourceId) {
      await useWholenessOfBody(resource);
    } else if (resource.id == layOnHandsResourceId) {
      await useLayOnHands(resource);
    } else if (resource.id == paladinChannelDivinityId &&
        character.levelInClass('Paladin') >= 3) {
      await usePaladinChannelDivinity(resource);
    } else if (resource.id == wildShapeResourceId) {
      await useWildShape(resource);
    } else if (resource.id == actionSurgeResourceId) {
      if (currentMode != CharacterMode.combat ||
          !characterState.canConcentrate ||
          character.levelInClass('Fighter') < 2 ||
          actionSurge != null) {
        return;
      }
      actionSurge = ActionSurgeState.available;
      updateCharacterState(
        characterState.copyWith(resourceValues: resourceValues),
      );
      recordSessionEvent(
        SessionEventType.combat,
        'Action Surge used',
        detail: 'One additional action, except the Magic action, this turn.',
      );
    } else {
      updateCharacterState(
        characterState.copyWith(resourceValues: resourceValues),
      );
    }
    HapticFeedback.selectionClick();
  }

  Future<CheckRoll> boostFailedSaveWithDarkLuck(
    CheckRoll original, {
    required int dc,
  }) async {
    final resource = resourceWithId(darkOnesOwnLuckResourceId);
    bool eligible() =>
        mounted &&
        hasDarkOnesOwnLuck &&
        resource != null &&
        remainingUses(resource) > 0 &&
        original.total < dc &&
        !(characterState.currentHp == 0 &&
            characterState.deathSaveFailures >= 3);
    if (!eligible()) return original;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dark One’s Own Luck · Failed save'),
        content: Text(
          '${original.label}: ${original.total} against DC $dc. Spend one use to add 1d10 before the save outcome is applied. Other offered rerolls have already been resolved. The original d20 is unchanged and the use is spent even if the save still fails.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep save result'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Spend use · Boost save'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !eligible() ||
        !spendCastResource(resource!.id)) {
      return original;
    }
    darkLuckRoll = null;
    peerlessSkillRoll = null;
    tacticalMindCheck = null;
    final bonus = diceRoller.rollDie(10);
    final boosted = CheckRoll(
      label: original.label,
      naturalRoll: original.naturalRoll,
      modifier: original.modifier + bonus,
      minimumRoll: original.minimumRoll,
      minimumTotal: original.minimumTotal,
    );
    addRollNotice(
      title: '${original.label} · Dark One’s Own Luck',
      calculation: '${original.total} + 1d10 ($bonus) = ${boosted.total}',
      total: boosted.total,
      tone: RollNoticeTone.normal,
      detail:
          'DC $dc · ${boosted.total >= dc ? 'Success' : 'Failed'} · One use spent. Original d20 ${original.naturalRoll} unchanged.',
    );
    return boosted;
  }

  bool get hasDarkOnesOwnLuck =>
      character.levelInClass('Warlock') >= 6 &&
      character.subclasses['Warlock'] == 'Fiend Patron';

  bool get darkLuckAvailable =>
      hasDarkOnesOwnLuck &&
      darkLuckRoll != null &&
      !(characterState.currentHp == 0 &&
          characterState.deathSaveFailures >= 3) &&
      character.resources.any(
        (resource) =>
            resource.id == darkOnesOwnLuckResourceId &&
            remainingUses(resource) > 0,
      );

  Future<void> useDarkOnesOwnLuck() async {
    if (!darkLuckAvailable) return;
    final original = darkLuckRoll!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dark One’s Own Luck'),
        content: Text(
          '${original.label} total ${original.total}. Confirm no effects of this roll have been resolved yet. Spend one use to add 1d10, with no action cost. Only one use may apply to this roll. Resolve the final check or save at the table; this control excludes attacks, initiative and automatically resolved saves.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Spend use · Add 1d10'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !darkLuckAvailable ||
        !identical(original, darkLuckRoll)) {
      return;
    }
    if (!spendCastResource(darkOnesOwnLuckResourceId)) return;
    darkLuckRoll = null;
    peerlessSkillRoll = null;
    tacticalMindCheck = null;
    final bonus = diceRoller.rollDie(10);
    addRollNotice(
      title: 'Dark One’s Own Luck · ${original.label}',
      calculation:
          '${original.total} + 1d10 ($bonus) = ${original.total + bonus}',
      total: original.total + bonus,
      tone: RollNoticeTone.normal,
      detail:
          'One use spent · Original d20 ${original.naturalRoll} unchanged. Resolve the new total before applying effects.',
    );
  }

  bool get hasPeerlessSkill =>
      character.levelInClass('Bard') >= 14 &&
      character.subclasses['Bard'] == 'College of Lore';

  bool get peerlessSkillAvailable =>
      hasPeerlessSkill &&
      peerlessSkillRoll != null &&
      characterState.canConcentrate &&
      character.resources.any(
        (resource) =>
            resource.id == bardicInspirationResourceId &&
            remainingUses(resource) > 0,
      );

  Future<void> usePeerlessSkill() async {
    if (!peerlessSkillAvailable) return;
    final roll = peerlessSkillRoll!;
    final dc = await showDialog<int>(
      context: context,
      builder: (context) => StatEditDialog(
        title:
            'Peerless Skill · ${roll.label} ${roll.total} · Enter failed DC or AC',
        initialValue: (roll.total + 1).clamp(1, 999),
      ),
    );
    if (!mounted ||
        dc == null ||
        dc <= roll.total ||
        !identical(roll, peerlessSkillRoll) ||
        !peerlessSkillAvailable) {
      return;
    }
    peerlessSkillRoll = null;
    darkLuckRoll = null;
    // A die can be applied only once to this roll, even when the use is retained.
    tacticalMindCheck = null;
    final die = diceRoller.rollDie(character.bardicInspirationDieSides);
    final total = roll.total + die;
    final success = total >= dc;
    if (success) spendCastResource(bardicInspirationResourceId);
    addRollNotice(
      title: 'Peerless Skill · ${roll.label}',
      calculation:
          '${roll.total} + d${character.bardicInspirationDieSides} $die = $total',
      total: total,
      detail:
          'DC/AC $dc · ${success ? 'Success · One Inspiration spent' : 'Failed · Inspiration retained'}. '
          'No extra action spent. Resolve the resulting check or hit at the table.',
      tone: RollNoticeTone.normal,
    );
  }

  bool get bardicInspirationAvailable =>
      character.levelInClass('Bard') >= 1 &&
      characterState.canConcentrate &&
      (currentMode != CharacterMode.combat ||
          !usedCombatActions.contains(CombatActionCost.bonusAction)) &&
      character.resources.any(
        (resource) =>
            resource.id == bardicInspirationResourceId &&
            remainingUses(resource) > 0,
      );

  Future<void> grantBardicInspiration() async {
    if (!bardicInspirationAvailable) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grant Bardic Inspiration'),
        content: Text(
          'Confirm another creature within 60 feet can see or hear you and does not already have a Bardic Inspiration die. '
          'Grant it one d${character.bardicInspirationDieSides} for up to 1 hour. '
          'It can roll the die after failing a D20 Test and add the result, expending the die when rolled. '
          'Spend one Inspiration use${currentMode == CharacterMode.combat ? ' and your Bonus Action' : ''}. '
          'The recipient tracks the die, its expiry and its eventual roll at the table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Grant die'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !bardicInspirationAvailable) return;
    final resource = character.resources.firstWhere(
      (resource) => resource.id == bardicInspirationResourceId,
    );
    if (currentMode == CharacterMode.combat) {
      usedCombatActions.add(CombatActionCost.bonusAction);
    }
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          resource.id: remainingUses(resource) - 1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.resource,
      'Bardic Inspiration granted · d${character.bardicInspirationDieSides}',
      detail:
          'One Inspiration use spent${currentMode == CharacterMode.combat ? ' · Bonus Action spent' : ''}. '
          'Another creature within 60 feet receives the die for up to 1 hour; '
          'one die per recipient. Recipient resolves the failed D20 Test bonus and expiry at the table.',
    );
  }

  Future<void> useCountercharm() async {
    bool canUse() =>
        mounted &&
        currentMode == CharacterMode.combat &&
        character.levelInClass('Bard') >= 7 &&
        characterState.canConcentrate &&
        !usedCombatActions.contains(CombatActionCost.reaction);
    if (!canUse()) return;
    var ability = Ability.wisdom;
    var disadvantage = false;
    final choice = await showDialog<(bool, Ability, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Countercharm · Confirm failed save'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Confirm you or a creature within 30 feet just failed a saving throw against an effect that applies Charmed or Frightened. Spend your Reaction for a reroll with Advantage. No Bardic Inspiration is spent. Resolve the new outcome at the table; existing conditions are not removed automatically.',
                ),
                DropdownButtonFormField<Ability>(
                  initialValue: ability,
                  decoration: const InputDecoration(
                    labelText: 'Your save ability',
                  ),
                  items: [
                    for (final value in Ability.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: (value) =>
                      update(() => ability = value ?? Ability.wisdom),
                ),
                CheckboxListTile(
                  title: const Text('Your save also has Disadvantage'),
                  subtitle: const Text(
                    'Advantage and Disadvantage cancel for your reroll.',
                  ),
                  value: disadvantage,
                  onChanged: (value) =>
                      update(() => disadvantage = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, (false, ability, disadvantage)),
              child: const Text('Help another creature'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, (true, ability, disadvantage)),
              child: const Text('Reroll your failed save'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null || !canUse()) return;
    usedCombatActions.add(CombatActionCost.reaction);
    recordSessionEvent(
      SessionEventType.combat,
      'Countercharm',
      detail: choice.$1
          ? 'Reaction spent · Reroll your failed save against Charmed/Frightened with Advantage.'
          : 'Reaction spent · Another creature within 30 feet rerolls the failed Charmed/Frightened save with Advantage. Resolve its roll and outcome at the table.',
    );
    if (choice.$1) {
      final check = characterInCombat.savingThrowFor(choice.$2);
      rollCheck(
        '${choice.$2.label} Save · Countercharm',
        check.modifier,
        useSelectedMode: false,
        checkAbility: choice.$2,
        darkLuckEligible: true,
        modeOverride: choice.$3 ? D20Mode.normal : D20Mode.advantage,
        describe: (_) => choice.$3
            ? 'Countercharm Advantage cancelled by Disadvantage. Resolve the new save outcome at the table.'
            : 'Countercharm reroll with Advantage. Resolve the new save outcome at the table.',
      );
    }
  }

  bool get hasCuttingWords =>
      character.levelInClass('Bard') >= 3 &&
      character.subclasses['Bard'] == 'College of Lore';

  Future<void> useCuttingWords() async {
    final inspiration = character.resources
        .where((resource) => resource.id == bardicInspirationResourceId)
        .firstOrNull;
    bool canUse() =>
        mounted &&
        currentMode == CharacterMode.combat &&
        hasCuttingWords &&
        characterState.canConcentrate &&
        !usedCombatActions.contains(CombatActionCost.reaction) &&
        inspiration != null &&
        remainingUses(inspiration) > 0;
    if (!canUse()) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Cutting Words · Confirm trigger'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Confirm you can see the creature within 60 feet. It just made a damage roll, or succeeded on an attack roll or ability check. Spend your Reaction and one Bardic Inspiration use to subtract your Inspiration die from that roll. Saving throws are not eligible. Resolve whether the reduced total changes the outcome at the table.',
            ),
          ),
          for (final type in [
            'Successful attack roll',
            'Successful ability check',
            'Damage roll',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, type),
              child: Text(type),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || !canUse()) return;
    final die = diceRoller.rollDie(character.bardicInspirationDieSides);
    usedCombatActions.add(CombatActionCost.reaction);
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          inspiration!.id: remainingUses(inspiration) - 1,
        },
      ),
    );
    addRollNotice(
      title: 'Cutting Words',
      tone: RollNoticeTone.normal,
      calculation: '1d${character.bardicInspirationDieSides} ($die) reduction',
      total: die,
      detail:
          'Subtract $die from the creature’s ${choice.toLowerCase()}. One Bardic Inspiration and Reaction spent. Resolve the reduced total and outcome at the table.',
    );
  }

  Future<void> usePaladinChannelDivinity(CharacterResource resource) async {
    bool canUse(String choice) =>
        characterState.canConcentrate &&
        remainingUses(resource) > 0 &&
        (choice != 'abjure' || character.levelInClass('Paladin') >= 9) &&
        (currentMode != CharacterMode.combat ||
            choice == 'manual' ||
            !usedCombatActions.contains(
              choice == 'sense'
                  ? CombatActionCost.bonusAction
                  : CombatActionCost.action,
            ));
    if (!canUse('manual')) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Paladin Channel Divinity'),
        children: [
          if (canUse('sense'))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'sense'),
              child: const Text('Divine Sense · Bonus Action'),
            ),
          if (canUse('abjure'))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'abjure'),
              child: const Text('Abjure Foes · Magic Action'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'manual'),
            child: const Text(
              'Spend one use · Resolve another effect at the table',
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || !canUse(choice)) return;
    final maximum = character.abilityModifierFor(Ability.charisma).clamp(1, 99);
    var targets = 0;
    if (choice == 'abjure') {
      final count = await showDialog<int>(
        context: context,
        builder: (context) => const StatEditDialog(
          title: 'Visible foes within 60 feet',
          initialValue: 1,
        ),
      );
      if (!mounted || count == null || !canUse(choice)) return;
      if (count < 1 || count > maximum) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Choose 1 to $maximum targets.')),
        );
        return;
      }
      targets = count;
    }
    if (currentMode == CharacterMode.combat && choice != 'manual') {
      usedCombatActions.add(
        choice == 'sense'
            ? CombatActionCost.bonusAction
            : CombatActionCost.action,
      );
    }
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          resource.id: remainingUses(resource) - 1,
        },
        activeConditions: choice == 'sense'
            ? {...characterState.activeConditions, divineSenseCondition}
            : null,
        conditionTurns: choice == 'sense'
            ? {...characterState.conditionTurns, divineSenseCondition: 100}
            : null,
      ),
    );
    if (choice == 'sense') {
      recordSessionEvent(
        SessionEventType.combat,
        'Divine Sense',
        detail:
            'For 10 minutes, detect Celestial, Fiend and Undead locations and types within 60 feet, '
            'plus consecrated or desecrated places and objects. Ends if incapacitated. Resolve detection at the table.',
      );
      return;
    }
    if (choice == 'manual') {
      recordSessionEvent(
        SessionEventType.resource,
        'Paladin Channel Divinity used',
        detail: 'Resolve the chosen effect and its action cost at the table.',
      );
      return;
    }
    if (characterState.isRaging && currentMode == CharacterMode.combat) {
      extendRage();
    }
    final dc =
        8 +
        character.abilityModifierFor(Ability.charisma) +
        character.proficiencyBonus;
    recordSessionEvent(
      SessionEventType.combat,
      'Abjure Foes',
      detail:
          '$targets targets · DC $dc Wisdom save. Failed targets are Frightened for 1 minute or until damaged. '
          'While affected, each can only move, take an action, or take a Bonus Action on its turn. Track targets at the table.',
    );
    final failed = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Abjure Foes saving throws'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '$targets targets · DC $dc Wisdom save. How many failed?',
            ),
          ),
          for (var i = 0; i <= targets; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text('$i failed ${i == 1 ? 'save' : 'saves'}'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Resolve later'),
          ),
        ],
      ),
    );
    if (!mounted || failed == null) return;
    recordSessionEvent(
      SessionEventType.combat,
      'Abjure Foes results',
      detail:
          '$failed of $targets targets Frightened; the others saved. Apply immunity and effects at the table.',
    );
  }

  bool get canUseWildShape =>
      character.levelInClass('Druid') >= 2 &&
      characterState.canConcentrate &&
      (currentMode != CharacterMode.combat ||
          !usedCombatActions.contains(CombatActionCost.bonusAction));

  int get landDruidLevel =>
      character.subclasses['Druid'] == 'Circle of the Land'
      ? character.levelInClass('Druid')
      : 0;

  bool get canUsePrimalStrike =>
      currentMode == CharacterMode.combat &&
      characterState.canConcentrate &&
      !primalStrikeUsedThisTurn &&
      character.levelInClass('Druid') >= 7 &&
      character.elementalFury == ElementalFury.primalStrike;

  Future<void> usePrimalStrike() async {
    if (!canUsePrimalStrike) return;
    var critical = false;
    final type = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => SimpleDialog(
          title: const Text('Primal Strike'),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'After a weapon or Beast attack hits on your turn, choose the extra damage type.',
              ),
            ),
            CheckboxListTile(
              title: const Text('Critical hit'),
              value: critical,
              onChanged: (value) =>
                  setDialogState(() => critical = value ?? false),
            ),
            for (final type in ['Cold', 'Fire', 'Lightning', 'Thunder'])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, type),
                child: Text(type),
              ),
          ],
        ),
      ),
    );
    if (!mounted || type == null || !canUsePrimalStrike) return;
    final dice = character.levelInClass('Druid') >= 15 ? 2 : 1;
    final expression = DiceExpression(
      diceCount: critical ? dice * 2 : dice,
      dieSides: 8,
    );
    final roll = expression.roll('Primal Strike', diceRoller);
    primalStrikeUsedThisTurn = true;
    addRollNotice(
      title: 'Primal Strike',
      calculation:
          '${expression.notation} · ${roll.dice.join(' + ')} = ${roll.total}',
      total: roll.total,
      tone: RollNoticeTone.damage,
      detail: '$type damage',
    );
  }

  bool get canUseNatureMagician {
    final pool = wildShapePool;
    return character.levelInClass('Druid') >= 20 &&
        pool != null &&
        remainingUses(pool) > 0 &&
        !natureMagicianSlots.any(
          (slot) => characterState.resourceValues.containsKey(slot.id),
        );
  }

  Future<void> useNatureMagician() async {
    final pool = wildShapePool;
    if (pool == null || !canUseNatureMagician) return;
    final payment = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Nature Magician'),
        children: [
          for (var uses = 1; uses <= remainingUses(pool).clamp(0, 4); uses++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, uses),
              child: Text('Spend $uses · Create level ${uses * 2} slot'),
            ),
        ],
      ),
    );
    if (!mounted ||
        payment == null ||
        !canUseNatureMagician ||
        remainingUses(pool) < payment) {
      return;
    }
    final slot = natureMagicianSlots[payment - 1];
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          pool.id: remainingUses(pool) - payment,
          slot.id: 1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.resource,
      'Nature Magician',
      detail: 'Created a level ${payment * 2} spell slot.',
    );
  }

  Future<void> chooseDruidLand() async {
    if (landDruidLevel < 3) return;
    final land = await showDialog<DruidLand>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Circle of the Land terrain'),
        children: [
          for (final land in DruidLand.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, land),
              child: Text(land.label),
            ),
        ],
      ),
    );
    if (!mounted || land == null || land == characterState.druidLand) return;
    saveSpellChanges(
      character.spells,
      characterState.pinnedActionKeys,
      land: land,
    );
    recordSessionEvent(
      SessionEventType.resource,
      'Circle of the Land · ${land.label}',
    );
  }

  Future<void> useNaturesSanctuary() async {
    final resistance = characterState.landResistanceFor(character);
    final pool = wildShapePool;
    bool canUse() =>
        landDruidLevel >= 14 &&
        pool != null &&
        remainingUses(pool) > 0 &&
        characterState.canConcentrate &&
        (currentMode != CharacterMode.combat ||
            !usedCombatActions.contains(CombatActionCost.action));
    if (!canUse() || resistance == null) return;
    final detail =
        'Place a 15-foot cube on the ground within 120 feet. '
        'You and allies have half cover inside. Allies inside gain ${resistance.label} resistance. '
        'The sanctuary lasts one minute or until you are incapacitated.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nature’s Sanctuary'),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create Sanctuary'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !canUse()) return;
    if (currentMode == CharacterMode.combat) {
      usedCombatActions.add(CombatActionCost.action);
    }
    updateCharacterState(
      characterState.copyWith(
        activeConditions: {
          ...characterState.activeConditions,
          naturesSanctuaryCondition,
        },
        conditionTurns: {
          ...characterState.conditionTurns,
          naturesSanctuaryCondition: 10,
        },
        resourceValues: {
          ...characterState.resourceValues,
          pool!.id: remainingUses(pool) - 1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'Nature’s Sanctuary',
      detail: detail,
    );
  }

  bool get canMoveNaturesSanctuary =>
      landDruidLevel >= 14 &&
      characterState.canConcentrate &&
      characterState.activeConditions.contains(naturesSanctuaryCondition) &&
      (currentMode != CharacterMode.combat ||
          !usedCombatActions.contains(CombatActionCost.bonusAction));

  Future<void> moveNaturesSanctuary() async {
    if (!canMoveNaturesSanctuary) return;
    final move = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Nature’s Sanctuary'),
        content: const Text(
          'Move the cube up to 60 feet to ground within 120 feet of you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move Sanctuary'),
          ),
        ],
      ),
    );
    if (!mounted || move != true || !canMoveNaturesSanctuary) return;
    if (currentMode == CharacterMode.combat) {
      setCombatActionUsed(CombatActionCost.bonusAction, true);
    }
    recordSessionEvent(
      SessionEventType.combat,
      'Nature’s Sanctuary moved',
      detail:
          'Up to 60 feet, to ground within 120 feet. Resolve placement at the table.',
    );
  }

  CharacterResource? get wildShapePool => character.resources
      .where((resource) => resource.id == wildShapeResourceId)
      .firstOrNull;

  static const wildCompanionSpell = Spell(
    id: 'whetstone:wild-companion',
    name: 'Wild Companion',
    level: 1,
    prepared: true,
    castingTime: 'Action',
    summary: 'Summon a Fey familiar that disappears after a long rest.',
  );

  Future<void> summonWildCompanion() async {
    if (character.levelInClass('Druid') < 2 ||
        !canSpendSpellAction(wildCompanionSpell)) {
      return;
    }
    final pool = wildShapePool;
    var form = '';
    final selection = await showDialog<(String, bool)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wild Companion'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Fey familiar form'),
          maxLength: 60,
          onChanged: (text) => form = text.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (pool != null && remainingUses(pool) > 0)
            TextButton(
              onPressed: () {
                if (form.isNotEmpty) Navigator.pop(context, (form, false));
              },
              child: const Text('Spend Wild Shape'),
            ),
          FilledButton(
            onPressed: () {
              if (form.isNotEmpty) Navigator.pop(context, (form, true));
            },
            child: const Text('Choose Spell Slot'),
          ),
        ],
      ),
    );
    if (!mounted ||
        selection == null ||
        !canSpendSpellAction(wildCompanionSpell)) {
      return;
    }
    final (familiar, useSlot) = selection;
    final slot = useSlot
        ? await chooseAvailableSlot(1, 'Wild Companion spell slot')
        : null;
    if (!mounted || !canSpendSpellAction(wildCompanionSpell)) return;
    final resource = useSlot
        ? castingResources.where((entry) => entry.id == slot?.$2).firstOrNull
        : wildShapePool;
    if (resource == null || remainingUses(resource) <= 0) return;
    if (currentMode == CharacterMode.combat) {
      usedCombatActions.add(CombatActionCost.action);
    }
    updateCharacterState(
      characterState.copyWith(
        wildCompanion: familiar,
        resourceValues: {
          ...characterState.resourceValues,
          resource.id: remainingUses(resource) - 1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'Wild Companion · $familiar',
      detail: 'Fey familiar. Disappears after a long rest.',
    );
  }

  Future<void> useLandsAid() async {
    final pool = wildShapePool;
    bool canUse() =>
        landDruidLevel >= 3 &&
        pool != null &&
        remainingUses(pool) > 0 &&
        characterState.canConcentrate &&
        (currentMode != CharacterMode.combat ||
            !usedCombatActions.contains(CombatActionCost.action));
    if (!canUse()) return;
    final dc =
        8 +
        character.proficiencyBonus +
        character.abilityModifierFor(Ability.wisdom);
    final self = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Land’s Aid'),
        content: Text(
          'Choose a point within 60 feet. Selected creatures in its 10-foot sphere make a DC $dc Constitution save for half damage. Choose one creature in the area to heal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Heal a creature'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Heal yourself'),
          ),
        ],
      ),
    );
    if (!mounted || self == null || !canUse()) return;
    final count = landDruidLevel >= 14
        ? 4
        : landDruidLevel >= 10
        ? 3
        : 2;
    int rollDice() => List.generate(
      count,
      (_) => diceRoller.rollDie(6),
    ).fold(0, (total, die) => total + die);
    final damage = rollDice();
    final healing = rollDice();
    final restored = healing.clamp(
      0,
      characterState.maxHp - characterState.currentHp,
    );
    if (currentMode == CharacterMode.combat) {
      usedCombatActions.add(CombatActionCost.action);
    }
    updateCharacterState(
      characterState.copyWith(
        currentHp: self ? characterState.currentHp + restored : null,
        resourceValues: {
          ...characterState.resourceValues,
          pool!.id: remainingUses(pool) - 1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'Land’s Aid',
      detail:
          'DC $dc Constitution save · $damage Necrotic damage (${damage ~/ 2} on success) · '
          '${self ? '$restored HP recovered' : '$healing HP healing for the chosen creature'}',
    );
  }

  Future<void> useWildShape(CharacterResource resource) async {
    if (!canUseWildShape || remainingUses(resource) <= 0) return;
    final level = character.levelInClass('Druid');
    final maxCr = level >= 8
        ? '1'
        : level >= 4
        ? '½'
        : '¼';
    var otherForm = '';
    final form = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose a Wild Shape form'),
        children: [
          for (final form in suggestedWildShapeForms)
            if (!form.flies || level >= 8)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, form.name),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(form.name),
                  subtitle: Text('AC ${form.armourClass} · ${form.speed}'),
                ),
              ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Another known Beast',
                helperText:
                    'CR $maxCr or lower${level < 8 ? ', no Fly Speed' : ''}',
              ),
              maxLength: 60,
              onChanged: (name) => otherForm = name.trim(),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              if (otherForm.isNotEmpty) Navigator.pop(context, otherForm);
            },
            child: const Text('Use another known form'),
          ),
        ],
      ),
    );
    if (!mounted ||
        form == null ||
        !canUseWildShape ||
        remainingUses(resource) <= 0) {
      return;
    }
    final selectedForm = wildShapeFormNamed(form);
    if (selectedForm?.flies == true && character.levelInClass('Druid') < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flying Wild Shape forms require Druid level 8.'),
        ),
      );
      return;
    }
    if (currentMode == CharacterMode.combat) {
      usedCombatActions.add(CombatActionCost.bonusAction);
    }
    updateCharacterState(
      characterState.copyWith(
        wildShapeForm: form,
        wildShapeTurnsRemaining: (level ~/ 2) * 600,
        temporaryHp: characterState.temporaryHp < level
            ? level
            : characterState.temporaryHp,
        resourceValues: {
          ...characterState.resourceValues,
          resource.id: remainingUses(resource) - 1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'Wild Shape · $form',
      detail:
          'Up to ${level ~/ 2} hours. Apply the Beast’s statistics at the table.',
    );
  }

  void revertWildShape() {
    if (!canUseWildShape || characterState.wildShapeForm == null) return;
    if (currentMode == CharacterMode.combat) {
      usedCombatActions.add(CombatActionCost.bonusAction);
    }
    updateCharacterState(characterState.copyWith(clearWildShape: true));
    recordSessionEvent(SessionEventType.combat, 'Wild Shape ended');
  }

  void showWildShapeForm() {
    final name = characterState.wildShapeForm;
    if (name == null) return;
    final form = wildShapeFormNamed(name);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: form == null
            ? Text(
                'Use the chosen Beast’s statistics at the table.\n'
                '${characterState.wildShapeTurnsRemaining ?? 0} combat turns remaining.',
              )
            : Text(
                'AC ${form.armourClass} · Speed ${form.speed}\n'
                'STR ${form.strength} · DEX ${form.dexterity} · CON ${form.constitution}\n\n'
                '${form.senses.isEmpty ? '' : '${form.senses}\n\n'}'
                '${form.attack}${form.trait == null ? '' : '\n\n${form.trait}'}\n\n'
                '${characterState.wildShapeTurnsRemaining ?? 0} combat turns remaining. '
                'Track elapsed time outside combat at the table.',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> advanceWildShapeTime() async {
    final form = characterState.wildShapeForm;
    if (form == null) return;
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => const StatEditDialog(
        title: 'Minutes elapsed in Wild Shape',
        initialValue: 10,
      ),
    );
    if (!mounted || minutes == null || characterState.wildShapeForm != form) {
      return;
    }
    final remaining =
        characterState.wildShapeTurnsRemaining ??
        (character.levelInClass('Druid') ~/ 2) * 600;
    final next = remaining - minutes * 10;
    updateCharacterState(
      next <= 0
          ? characterState.copyWith(clearWildShape: true)
          : characterState.copyWith(wildShapeTurnsRemaining: next),
    );
    recordSessionEvent(
      SessionEventType.combat,
      next <= 0 ? 'Wild Shape expired' : 'Wild Shape time advanced',
      detail: '$minutes minutes elapsed in $form.',
    );
  }

  Future<void> escapeWithFreedomOfMovement() async {
    if (!characterState.activeConditions.contains(freedomOfMovementCondition)) {
      return;
    }
    final conditions = characterState.activeConditions
        .where(const {'Grappled', 'Restrained'}.contains)
        .toList();
    if (conditions.isEmpty) return;
    final condition = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Escape nonmagical restraints'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Spend 5 feet of movement. Confirm the restraint is nonmagical before removing it.',
            ),
          ),
          for (final condition in conditions)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, condition),
              child: Text('Escape $condition'),
            ),
        ],
      ),
    );
    if (!mounted ||
        condition == null ||
        !characterState.activeConditions.contains(freedomOfMovementCondition)) {
      return;
    }
    updateCharacterState(
      characterState.copyWith(
        activeConditions: {...characterState.activeConditions}
          ..remove(condition),
      ),
    );
    recordSessionEvent(
      SessionEventType.condition,
      'Freedom of Movement escape',
      detail: 'Removed $condition · Spend 5 feet of movement.',
    );
  }

  Future<void> useLayOnHands(CharacterResource resource) async {
    if (character.levelInClass('Paladin') >= 14) {
      await useRestoringTouch(resource);
      return;
    }
    bool canUse() =>
        characterState.canConcentrate &&
        (currentMode != CharacterMode.combat ||
            !usedCombatActions.contains(CombatActionCost.bonusAction));
    if (!canUse()) return;
    final available = remainingUses(resource);
    final missingHp = characterState.maxHp - characterState.currentHp;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Lay on Hands'),
        children: [
          if (missingHp > 0)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'self'),
              child: const Text('Heal yourself'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'ally'),
            child: const Text('Heal an ally'),
          ),
          if (available >= 5 &&
              characterState.activeConditions.contains('Poisoned'))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'self-cleanse'),
              child: const Text('Remove your Poisoned condition (5 points)'),
            ),
          if (available >= 5)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'cleanse'),
              child: const Text(
                'Remove an ally’s Poisoned condition (5 points)',
              ),
            ),
        ],
      ),
    );
    if (!mounted || choice == null || !canUse()) return;
    final self = choice == 'self';
    final selfCleansing = choice == 'self-cleanse';
    final cleansing = selfCleansing || choice == 'cleanse';
    final amount = cleansing
        ? 5
        : await showDialog<int>(
            context: context,
            builder: (context) => StatEditDialog(
              title: 'Healing points to spend',
              initialValue: self ? missingHp.clamp(1, available) : available,
            ),
          );
    if (!mounted || amount == null || !canUse()) return;
    if (amount > remainingUses(resource) ||
        (selfCleansing &&
            !characterState.activeConditions.contains('Poisoned')) ||
        (self && amount > characterState.maxHp - characterState.currentHp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose an amount within the pool and missing HP.'),
        ),
      );
      return;
    }
    if (currentMode == CharacterMode.combat) {
      usedCombatActions.add(CombatActionCost.bonusAction);
    }
    updateCharacterState(
      characterState.copyWith(
        currentHp: self ? characterState.currentHp + amount : null,
        activeConditions: selfCleansing
            ? ({...characterState.activeConditions}..remove('Poisoned'))
            : null,
        resourceValues: {
          ...characterState.resourceValues,
          resource.id: remainingUses(resource) - amount,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'Lay on Hands used',
      detail: selfCleansing
          ? 'Spent 5 points and removed Poisoned.'
          : cleansing
          ? 'Spent 5 points. Apply the removal of Poisoned at the table.'
          : self
          ? 'Recovered $amount HP.'
          : 'Apply $amount healing to the ally.',
    );
  }

  Future<void> useRestoringTouch(CharacterResource resource) async {
    bool canUse() =>
        characterState.canConcentrate &&
        remainingUses(resource) > 0 &&
        (currentMode != CharacterMode.combat ||
            !usedCombatActions.contains(CombatActionCost.bonusAction));
    if (!canUse()) return;
    var self = true;
    var healingText = '';
    final selected = <String>{};
    const conditions = [
      'Poisoned',
      'Blinded',
      'Charmed',
      'Deafened',
      'Frightened',
      'Paralyzed',
      'Stunned',
    ];
    final result = await showDialog<(bool, int, Set<String>)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final healing = int.tryParse(healingText.isEmpty ? '0' : healingText);
          final cost = (healing ?? 0) + selected.length * 5;
          final valid =
              healing != null &&
              healing >= 0 &&
              cost > 0 &&
              cost <= remainingUses(resource) &&
              (!self ||
                  healing <= characterState.maxHp - characterState.currentHp);
          return AlertDialog(
            title: const Text('Lay on Hands · Restoring Touch'),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<bool>(
                      initialValue: true,
                      decoration: const InputDecoration(labelText: 'Target'),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Yourself')),
                        DropdownMenuItem(value: false, child: Text('An ally')),
                      ],
                      onChanged: (value) => update(() {
                        self = value ?? true;
                        selected.clear();
                      }),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'HP to restore',
                        helperText: 'Each condition costs 5 additional points.',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          update(() => healingText = value.trim()),
                    ),
                    for (final condition in conditions)
                      CheckboxListTile(
                        title: Text(condition),
                        subtitle: const Text('5 points'),
                        value: selected.contains(condition),
                        onChanged:
                            self &&
                                !characterState.activeConditions.contains(
                                  condition,
                                )
                            ? null
                            : (checked) => update(() {
                                if (checked == true) {
                                  selected.add(condition);
                                } else {
                                  selected.remove(condition);
                                }
                              }),
                      ),
                    Text('Cost: $cost / ${remainingUses(resource)} points'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: !valid
                    ? null
                    : () => Navigator.pop(context, (
                        self,
                        healing,
                        Set<String>.of(selected),
                      )),
                child: const Text('Apply Lay on Hands'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || result == null || !canUse()) return;
    final (targetSelf, healing, removed) = result;
    final cost = healing + removed.length * 5;
    if (cost <= 0 ||
        cost > remainingUses(resource) ||
        healing < 0 ||
        (targetSelf &&
            (healing > characterState.maxHp - characterState.currentHp ||
                !removed.every(characterState.activeConditions.contains)))) {
      return;
    }
    if (currentMode == CharacterMode.combat) {
      usedCombatActions.add(CombatActionCost.bonusAction);
    }
    updateCharacterState(
      characterState.copyWith(
        currentHp: targetSelf ? characterState.currentHp + healing : null,
        activeConditions: targetSelf
            ? ({...characterState.activeConditions}..removeAll(removed))
            : null,
        resourceValues: {
          ...characterState.resourceValues,
          resource.id: remainingUses(resource) - cost,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'Lay on Hands · Restoring Touch',
      detail:
          'Spent $cost points · $healing HP healing · '
          '${removed.isEmpty
              ? 'No conditions removed.'
              : targetSelf
              ? 'Removed ${removed.join(', ')}.'
              : 'Apply removal of ${removed.join(', ')} to the ally at the table.'}',
    );
  }

  bool get hasPersistentRage => character.levelInClass('Barbarian') >= 15;

  Future<CharacterState> resolveRelentlessRage(
    CharacterState damaged,
    int damage,
  ) async {
    final barbarianLevel = character.levelInClass('Barbarian');
    if (!characterState.isRaging ||
        characterState.currentHp <= 0 ||
        damaged.currentHp != 0 ||
        barbarianLevel < 11 ||
        damage >=
            characterState.temporaryHp +
                characterState.currentHp +
                characterState.maxHp) {
      return damaged;
    }
    final attempts = characterState.relentlessRageAttempts;
    final dc = 10 + 5 * attempts;
    final hp = (2 * barbarianLevel).clamp(1, damaged.maxHp);
    var roll = rollCheck(
      'Relentless Rage',
      characterForPhysicalChecks.savingThrowFor(Ability.constitution).modifier,
      describe: (roll) => roll.total >= dc
          ? 'DC $dc · Remain conscious at $hp HP'
          : 'DC $dc · Failed save',
    );
    roll = await boostFailedSaveWithDarkLuck(roll, dc: dc);
    return damaged.copyWith(
      relentlessRageAttempts: attempts + 1,
      currentHp: roll.total >= dc ? hp : 0,
      // The save decision can spend a resource after damage was calculated.
      resourceValues: characterState.resourceValues,
    );
  }

  void startRage(Map<String, int> resourceValues) {
    if (!characterState.canConcentrate ||
        characterState.isRaging ||
        currentMode != CharacterMode.combat) {
      return;
    }
    if (usedCombatActions.contains(CombatActionCost.bonusAction)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bonus Action already used this turn.')),
      );
      return;
    }
    usedCombatActions.add(CombatActionCost.bonusAction);
    updateCharacterState(
      characterState.copyWith(
        resourceValues: resourceValues,
        rageTurnsElapsed: 0,
        activeConditions: {...characterState.activeConditions, ragingCondition},
        conditionTurns: {
          ...characterState.conditionTurns,
          ragingCondition: hasPersistentRage ? 100 : 2,
        },
        clearConcentration: true,
      ),
    );
  }

  Future<void> recordRageEnemySave() async {
    if (!characterState.isRaging ||
        hasPersistentRage ||
        currentMode != CharacterMode.combat) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record enemy saving throw'),
        content: const Text(
          'Did you force an enemy to make a saving throw on your turn? '
          'Resolve the effect and its costs at the table. This records Rage extension only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enemy forced to save'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !characterState.isRaging ||
        hasPersistentRage ||
        currentMode != CharacterMode.combat) {
      return;
    }
    extendRage();
    recordSessionEvent(
      SessionEventType.combat,
      'Rage extended by enemy save',
      detail: 'An enemy was forced to make a saving throw on your turn.',
    );
  }

  void extendRageWithBonusAction() {
    if (hasPersistentRage ||
        !characterState.isRaging ||
        currentMode != CharacterMode.combat ||
        usedCombatActions.contains(CombatActionCost.bonusAction)) {
      return;
    }
    usedCombatActions.add(CombatActionCost.bonusAction);
    updateCharacterState(
      characterState.copyWith(
        conditionTurns: {...characterState.conditionTurns, ragingCondition: 2},
      ),
    );
  }

  void extendRage() {
    if (hasPersistentRage ||
        characterState.conditionTurns[ragingCondition] == 2) {
      return;
    }
    updateCharacterState(
      characterState.copyWith(
        conditionTurns: {...characterState.conditionTurns, ragingCondition: 2},
      ),
    );
  }

  void applySecondWind(Map<String, int> resourceValues) {
    if (!characterState.canConcentrate) return;
    final inCombat = currentMode == CharacterMode.combat;
    if (inCombat && usedCombatActions.contains(CombatActionCost.bonusAction)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bonus Action already used this turn.')),
      );
      return;
    }
    final roll = diceRoller.rollDie(10);
    final fighterLevel = character.levelInClass('Fighter');
    final bonus = fighterLevel > 0 ? fighterLevel : character.level;
    final hp = (characterState.currentHp + roll + bonus).clamp(
      0,
      characterState.maxHp,
    );
    final recovered = hp - characterState.currentHp;
    if (inCombat) usedCombatActions.add(CombatActionCost.bonusAction);
    updateCharacterState(
      characterState.copyWith(currentHp: hp, resourceValues: resourceValues),
    );
    addRollNotice(
      title: 'Second Wind',
      calculation: '1d10 ($roll) + $bonus = ${roll + bonus}',
      total: recovered,
      detail: fighterLevel >= 5 && inCombat
          ? 'HP recovered · Tactical Shift lets you move up to half your Speed without provoking opportunity attacks.'
          : 'HP recovered',
      tone: RollNoticeTone.normal,
    );
  }

  Map<String, Weapon> masteryWeapons({required bool selected}) {
    final builtIn = BuiltInClass.named(character.characterClass);
    if (builtIn == null || !builtIn.hasWeaponMastery) return {};
    final known = {
      for (final weapon in character.weapons)
        if (weapon.mastery != null) WeaponMastery.weaponType(weapon.name),
    };
    return {
      for (final weapon in character.weapons)
        if (known.contains(WeaponMastery.weaponType(weapon.name)) == selected &&
            (selected || builtIn.allowsMastery(weapon.name)))
          WeaponMastery.weaponType(weapon.name): weapon,
    };
  }

  Future<void> changeMasteryAfterRest() async {
    final known = masteryWeapons(selected: true);
    final choices = masteryWeapons(selected: false);
    final previous = await chooseMasteryWeapon(
      'Replace a Weapon Mastery',
      known,
    );
    if (!mounted || previous == null) return;
    final next = await chooseMasteryWeapon('Choose a Weapon Mastery', choices);
    if (!mounted || next == null) return;
    final updated = character.copyWith(
      weapons: [
        for (final weapon in character.weapons)
          switch (WeaponMastery.weaponType(weapon.name)) {
            final name when name == previous => weapon.withMastery(null),
            final name when name == next => weapon.withMastery(
              WeaponMastery.forWeapon(name),
            ),
            _ => weapon,
          },
      ],
    );
    setState(() => character = updated);
    widget.onCharacterChanged(updated);
    recordSessionEvent(
      SessionEventType.rest,
      'Weapon Mastery changed',
      detail: '${known[previous]!.name} → ${choices[next]!.name}',
    );
  }

  Future<String?> chooseMasteryWeapon(
    String title,
    Map<String, Weapon> weapons,
  ) => showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final entry in weapons.entries)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, entry.key),
            child: Text(entry.value.name),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep current choices'),
        ),
      ],
    ),
  );

  Future<void> takeRest(RestType restType) async {
    final canRecoverSlots =
        restType == RestType.shortRest &&
        landDruidLevel >= 6 &&
        !characterState.naturalRecoveryUsed &&
        naturalRecoverySlots.isNotEmpty;
    final canChangeMastery =
        restType == RestType.longRest &&
        masteryWeapons(selected: true).isNotEmpty &&
        masteryWeapons(selected: false).isNotEmpty;
    final preview = RestPlan.forCharacter(
      type: restType,
      character: character,
      currentState: characterState,
    );
    final canSpend =
        restType == RestType.shortRest &&
        characterState.currentHp > 0 &&
        characterState.currentHp < characterState.maxHp;
    var useSorcerousRestoration = false;
    final counts = await showDialog<Map<int, int>>(
      context: context,
      builder: (context) => RestConfirmationDialog(
        plan: preview,
        sorcerousRestorationAmount: preview.sorcerousRestorationAmount(
          character,
        ),
        onSorcerousRestorationChanged: (value) =>
            useSorcerousRestoration = value,
        canChangeMastery: canChangeMastery,
        canChooseDruidLand:
            restType == RestType.longRest && landDruidLevel >= 3,
        canUseNaturalRecovery: canRecoverSlots,
        availableHitDice: canSpend
            ? RestPlan.availableHitDiceBySize(character, characterState)
            : const {},
      ),
    );
    if (!mounted || counts == null) return;

    var plan =
        RestPlan.forCharacter(
          type: restType,
          character: character,
          currentState: characterState,
        ).spendHitDice(
          character: character,
          countsBySize: counts,
          roller: diceRoller,
        );
    if (useSorcerousRestoration) plan = plan.recoverSorceryPoints(character);
    levelledSpellCastThisTurn = false;
    quickenedSpellUsedThisTurn = false;
    peerlessSkillRoll = null;
    darkLuckRoll = null;
    updateCharacterState(plan.updatedState);
    recordSessionEvent(
      SessionEventType.rest,
      '${restType.label} completed',
      detail: plan.changes.isEmpty
          ? 'No resources needed recovery'
          : plan.changes.join(' | '),
    );
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${restType.label} complete')));
    if (canChangeMastery) await changeMasteryAfterRest();
    if (restType == RestType.longRest && mounted && landDruidLevel >= 3) {
      await chooseDruidLand();
    }
    if (canRecoverSlots && mounted) await useNaturalRecovery();
  }

  List<(int, CharacterResource)> get naturalRecoverySlots => [
    for (final resource in character.resources)
      if (spellSlotLevel(resource) case final level?
          when level <= 5 &&
              resource.rechargePeriod == RechargePeriod.longRest &&
              remainingUses(resource) < resource.maximum)
        (level, resource),
  ];

  List<(int, CharacterResource)> get arcaneRecoverySlots => [
    for (final resource in character.resources)
      for (var level = 1; level <= 5; level++)
        if ((resource.id == spellSlotId(level) ||
                resource.id == 'level_${level}_slots') &&
            resource.rechargePeriod == RechargePeriod.longRest &&
            remainingUses(resource) < resource.maximum)
          (level, resource),
  ];

  Future<void> useMemorizeSpell() async {
    bool canUse() =>
        mounted &&
        currentMode != CharacterMode.combat &&
        character.levelInClass('Wizard') >= 5 &&
        characterState.canConcentrate &&
        characterState.memorizeSpellAvailable;
    if (!canUse()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finish a Short Rest to use Memorize Spell once.'),
        ),
      );
      return;
    }
    bool eligible(Spell spell) =>
        spell.level > 0 &&
        !character.isAlwaysPreparedSpell(spell) &&
        (spell.castingAbility == null ||
            spell.castingAbility == Ability.intelligence);
    Future<Spell?> choose(bool prepared) => showDialog<Spell>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          prepared
              ? 'Memorize Spell · Replace prepared spell'
              : 'Memorize Spell · Prepare from spellbook',
        ),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Choose a level 1+ Wizard spell from your spellbook. Confirm class ownership and any always-prepared feature restrictions at the table.',
            ),
          ),
          for (final spell in character.spells.where(
            (spell) => eligible(spell) && spell.prepared == prepared,
          ))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, spell),
              child: Text('${spell.name} · Level ${spell.level}'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    final previous = await choose(true);
    if (!mounted || previous == null || !canUse()) return;
    final next = await choose(false);
    if (!mounted || next == null || !canUse()) return;
    if (!character.spells.any(
          (spell) => spell.id == previous.id && spell.prepared,
        ) ||
        !character.spells.any(
          (spell) => spell.id == next.id && !spell.prepared,
        )) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Memorize Spell · Confirm swap'),
        content: Text(
          'Replace ${previous.name} with ${next.name} as one prepared Wizard spell after the completed Short Rest. Confirm both are eligible spellbook spells and the old spell is not always prepared by another feature. Spell slots, ongoing concentration and summons are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm eligible Wizard spell swap'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !canUse()) return;
    updateCharacterState(
      characterState.copyWith(memorizeSpellAvailable: false),
    );
    saveSpellChanges([
      for (final spell in character.spells)
        if (spell.id == previous.id)
          spell.withPrepared(false)
        else if (spell.id == next.id)
          spell.withPrepared(true)
        else
          spell,
    ], characterState.pinnedActionKeys);
    recordSessionEvent(
      SessionEventType.rest,
      'Memorize Spell',
      detail:
          '${previous.name} → ${next.name}. One prepared spell replaced after Short Rest.',
    );
  }

  Future<void> useArcaneRecovery() async {
    final resource = character.resources
        .where((r) => r.id == arcaneRecoveryResourceId)
        .firstOrNull;
    final budget = (character.levelInClass('Wizard') + 1) ~/ 2;
    bool canUse() =>
        mounted &&
        currentMode != CharacterMode.combat &&
        budget > 0 &&
        resource != null &&
        remainingUses(resource) > 0 &&
        arcaneRecoverySlots.any((entry) => entry.$1 <= budget);
    if (!canUse()) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arcane Recovery'),
        content: Text(
          'Confirm you just finished a Short Rest studying your spellbook. Recover up to $budget spell slot levels; each slot must be level 5 or lower. Once per Long Rest. Pact Magic and temporary feature-created slots are excluded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Short Rest finished · Choose slots'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true || !canUse()) return;
    await useNaturalRecovery(arcane: true);
  }

  Future<void> chooseFiendishResilience() async {
    bool eligible() =>
        character.hasFiendishResilience &&
        currentMode == CharacterMode.exploration &&
        characterState.canConcentrate &&
        characterState.fiendishResilienceAvailable;
    if (!eligible()) return;
    final choice = await showDialog<IncomingDamageType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Fiendish Resilience · After Rest'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Choose one damage type after finishing a Short or Long Rest. Force cannot be chosen. The resistance lasts until you choose a different type after another rest. Incoming damage must specify its type; resistances do not stack.',
            ),
          ),
          for (final type in IncomingDamageType.values.where(
            (type) =>
                type != IncomingDamageType.force &&
                type != IncomingDamageType.other,
          ))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, type),
              child: Text(type.label),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted ||
        choice == null ||
        !eligible() ||
        choice == IncomingDamageType.force ||
        choice == IncomingDamageType.other) {
      return;
    }
    updateCharacterState(
      characterState.copyWith(
        fiendishResistance: choice,
        fiendishResilienceAvailable: false,
      ),
    );
    recordSessionEvent(
      SessionEventType.condition,
      'Fiendish Resilience',
      detail:
          '${choice.label} Resistance chosen after rest. No action or resource spent; select another type after your next Short or Long Rest.',
    );
  }

  bool get hasDarkOnesBlessing =>
      character.levelInClass('Warlock') >= 3 &&
      character.subclasses['Warlock'] == 'Fiend Patron';

  bool get darkOnesBlessingAvailable =>
      hasDarkOnesBlessing &&
      !(characterState.currentHp == 0 && characterState.deathSaveFailures >= 3);

  Future<void> useDarkOnesBlessing() async {
    if (!darkOnesBlessingAvailable) return;
    final level = character.levelInClass('Warlock');
    final charisma = character.abilityModifierFor(Ability.charisma);
    final grant = (level + charisma).clamp(1, 999999);
    final trigger = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dark One’s Blessing · Confirm enemy'),
        content: Text(
          'Confirm an enemy was just reduced to 0 HP. Gain $grant temporary HP: Warlock $level + Charisma $charisma, minimum 1. '
          'If someone else reduced it to 0 HP, that enemy must be within 10 feet of you. '
          'Temporary HP do not heal or stack; keep a higher existing amount. This spends no action or resource.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, 'You reduced an enemy to 0 HP'),
            child: const Text('Enemy reduced by you'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              'Another creature reduced an enemy within 10 feet to 0 HP',
            ),
            child: const Text('Nearby enemy reduced by another'),
          ),
        ],
      ),
    );
    if (!mounted || trigger == null || !darkOnesBlessingAvailable) return;
    final previous = characterState.temporaryHp;
    final temporary = previous > grant ? previous : grant;
    updateCharacterState(characterState.copyWith(temporaryHp: temporary));
    recordSessionEvent(
      SessionEventType.health,
      'Dark One’s Blessing',
      detail:
          '$trigger · Warlock $level + Charisma $charisma → $grant temporary HP (minimum 1). '
          '${previous > grant ? 'Kept higher existing temporary HP: $previous.' : 'Temporary HP set to $temporary.'} No action or resource spent.',
    );
  }

  CharacterResource? get magicalCunningPactPool {
    final expected = spellSlotsForClass(
      'Warlock',
      character.levelInClass('Warlock'),
    ).firstOrNull;
    if (expected == null) return null;
    final level = spellSlotLevel(expected);
    if (level == null) return null;
    final pact = character.resources
        .where(
          (resource) =>
              resource.id == pactSlotId(level) &&
              resource.rechargePeriod == RechargePeriod.shortRest,
        )
        .firstOrNull;
    return pact ??
        character.resources
            .where(
              (resource) =>
                  resource.id == spellSlotId(level) &&
                  resource.rechargePeriod == RechargePeriod.shortRest &&
                  resource.name.toLowerCase().contains('pact'),
            )
            .firstOrNull;
  }

  bool get hasHurlThroughHell =>
      character.levelInClass('Warlock') >= 14 &&
      character.subclasses['Warlock'] == 'Fiend Patron';

  bool get hurlThroughHellAvailable {
    final use = resourceWithId(hurlThroughHellResourceId);
    return hasHurlThroughHell &&
        currentMode == CharacterMode.combat &&
        characterState.canConcentrate &&
        !hurlThroughHellUsedThisTurn &&
        use != null &&
        remainingUses(use) > 0;
  }

  Future<void> useHurlThroughHell() async {
    if (!hurlThroughHellAvailable) return;
    final dc =
        8 +
        character.proficiencyBonus +
        character.abilityModifierFor(Ability.charisma);
    final outcome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hurl Through Hell · Confirm attack hit'),
        content: Text(
          'Confirm you just hit a creature with an attack roll and have not used this feature this turn. '
          'The target makes a DC $dc Charisma save at the table. One use is spent even on a successful save; no extra action or attack is spent. '
          'On failure, it disappears and is incapacitated until the end of your next turn, then returns to its previous space or the nearest unoccupied space. '
          'A non-Fiend also takes 8d10 Psychic damage. This separate save effect does not double on a critical hit. '
          'Track the target, its return and turns outside the app at the table.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'saved'),
            child: const Text('Target saved'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'fiend'),
            child: const Text('Failed · Fiend target'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'failed'),
            child: const Text('Failed · Roll Psychic damage'),
          ),
        ],
      ),
    );
    if (!mounted || outcome == null || !hurlThroughHellAvailable) return;
    hurlThroughHellUsedThisTurn = true;
    if (!spendCastResource(hurlThroughHellResourceId)) {
      hurlThroughHellUsedThisTurn = false;
      return;
    }
    recordSessionEvent(
      SessionEventType.combat,
      'Hurl Through Hell · ${outcome == 'saved' ? 'Target saved' : 'Target banished'}',
      detail: outcome == 'saved'
          ? 'DC $dc Charisma save succeeded. One use spent; no banishment or extra damage.'
          : 'DC $dc Charisma save failed. Target disappears and is incapacitated until the end of your next turn, then returns to its prior space or the nearest unoccupied space. Resolve at the table. ${outcome == 'fiend' ? 'Fiend target: no Psychic damage.' : 'Non-Fiend: apply the separate Psychic damage roll.'}',
    );
    if (outcome == 'failed') {
      final damage = const DiceExpression(
        diceCount: 8,
        dieSides: 10,
      ).roll('Hurl Through Hell', diceRoller);
      addRollNotice(
        title: 'Hurl Through Hell Damage',
        calculation: '8d10 · ${damage.dice.join(' + ')} = ${damage.total}',
        total: damage.total,
        tone: RollNoticeTone.damage,
        detail:
            'Psychic · Separate failed-save effect; no critical doubling. Apply target damage and defenses at the table.',
      );
    }
  }

  bool get restoreHurlThroughHellAvailable {
    final use = resourceWithId(hurlThroughHellResourceId);
    final pool = magicalCunningPactPool;
    return hasHurlThroughHell &&
        characterState.canConcentrate &&
        use != null &&
        remainingUses(use) == 0 &&
        pool != null &&
        remainingUses(pool) > 0;
  }

  Future<void> restoreHurlThroughHell() async {
    if (!restoreHurlThroughHellAvailable) return;
    final pool = magicalCunningPactPool!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Hurl Through Hell'),
        content: Text(
          'Spend one ${pool.name} slot to restore one use. No action is spent. This does not activate the feature or reset its once-per-turn limit. Ordinary spell slots cannot pay this cost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Spend Pact slot · Restore use'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !restoreHurlThroughHellAvailable ||
        magicalCunningPactPool?.id != pool.id) {
      return;
    }
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          hurlThroughHellResourceId: 1,
          pool.id: remainingUses(pool) - 1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.resource,
      'Hurl Through Hell restored',
      detail:
          'One Pact Magic slot spent; no action. The once-per-turn limit is unchanged.',
    );
  }

  bool get magicalCunningAvailable {
    final use = resourceWithId(magicalCunningResourceId);
    final pool = magicalCunningPactPool;
    return currentMode == CharacterMode.exploration &&
        character.levelInClass('Warlock') >= 2 &&
        characterState.canConcentrate &&
        use != null &&
        remainingUses(use) > 0 &&
        pool != null &&
        remainingUses(pool) < pool.maximum;
  }

  int get sorceryPointCapacity {
    final points = resourceWithId(sorceryPointsResourceId);
    return points == null
        ? 0
        : character.levelInClass('Sorcerer').clamp(0, points.maximum);
  }

  bool get innateSorceryActive =>
      character.levelInClass('Sorcerer') >= 1 &&
      characterState.activeConditions.contains(innateSorceryCondition);

  Future<void> chooseElementalAffinity() async {
    if (!character.hasElementalAffinity) return;
    final current = character.elementalAffinity;
    if (current != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Elemental Affinity · ${current.label}'),
          content: Text(
            'You have ${current.label} Resistance. When casting a spell that deals ${current.label} damage, you may add your Charisma modifier to one damage roll of that cast. Your damage type choice is saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      return;
    }
    final chosen = await showDialog<DraconicAffinity>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Elemental Affinity · Choose damage type'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Choose your permanent Draconic affinity. Gain Resistance to that type and add Charisma to one matching damage roll of a spell you cast. No action or resource is spent.',
            ),
          ),
          for (final type in DraconicAffinity.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, type),
              child: Text(type.label),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted ||
        chosen == null ||
        !character.hasElementalAffinity ||
        character.elementalAffinity != null) {
      return;
    }
    final updated = character.copyWith(elementalAffinity: chosen);
    setState(() => character = updated);
    widget.onCharacterChanged(updated);
    recordSessionEvent(
      SessionEventType.condition,
      'Elemental Affinity chosen',
      detail:
          '${chosen.label} Resistance and matching spell-damage affinity. No action or resource spent.',
    );
  }

  Future<int> confirmElementalAffinityBonus(
    Spell spell,
    String? damageType,
  ) async {
    final affinity = character.elementalAffinity;
    bool eligible() =>
        mounted &&
        character.hasElementalAffinity &&
        affinity != null &&
        damageType?.trim().toLowerCase() == affinity.name &&
        !elementalAffinityUsedSpellIds.contains(spell.id);
    if (!eligible()) return 0;
    final bonus = character.abilityModifierFor(Ability.charisma);
    if (bonus == 0) return 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elemental Affinity · Spell damage'),
        content: Text(
          'Add ${bonus >= 0 ? '+' : ''}$bonus Charisma to this ${affinity!.label} damage roll of ${spell.name}? Confirm this belongs to a spell you cast and that you have not applied this bonus to another damage roll of the same cast. '
          'The flat bonus is not doubled on a critical hit and is included before damage is halved on a save. Concurrent casts of the same spell and manually rolled casts need table confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep for another roll'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply Charisma bonus'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !eligible() ||
        character.elementalAffinity != affinity) {
      return 0;
    }
    elementalAffinityUsedSpellIds.add(spell.id);
    publishSession();
    return bonus;
  }

  bool get dragonWingsActive =>
      character.hasDragonWings &&
      characterState.activeConditions.contains(dragonWingsCondition);

  bool get dragonWingsAvailable {
    if (dragonWingsActive) return true;
    final use = resourceWithId(dragonWingsResourceId);
    return character.hasDragonWings &&
        characterState.canConcentrate &&
        (currentMode != CharacterMode.combat ||
            !usedCombatActions.contains(CombatActionCost.bonusAction)) &&
        use != null &&
        remainingUses(use) > 0;
  }

  Future<void> toggleDragonWings() async {
    if (!dragonWingsAvailable) return;
    final dismissing = dragonWingsActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          dismissing ? 'Dismiss Dragon Wings?' : 'Activate Dragon Wings?',
        ),
        content: Text(
          dismissing
              ? 'Dismiss your wings with no action or resource cost. Resolve your position and any falling at the table.'
              : 'Spend one Dragon Wings use${currentMode == CharacterMode.combat ? ' and your Bonus Action' : ''}. Gain a Fly Speed of 60 feet for 1 hour, until you dismiss the wings. '
                    'Track flight, movement and elapsed time outside combat at the table. The app counts down 600 tracked turns. This is not a spell and does not require concentration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(dismissing ? 'Dismiss wings' : 'Activate wings'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !dragonWingsAvailable ||
        dragonWingsActive != dismissing) {
      return;
    }
    if (dismissing) {
      updateCharacterState(
        characterState.copyWith(
          activeConditions: {...characterState.activeConditions}
            ..remove(dragonWingsCondition),
        ),
      );
      recordSessionEvent(
        SessionEventType.combat,
        'Dragon Wings dismissed',
        detail: 'No action spent. Resolve flight and position at the table.',
      );
      return;
    }
    final use = resourceWithId(dragonWingsResourceId)!;
    if (currentMode == CharacterMode.combat) {
      usedCombatActions.add(CombatActionCost.bonusAction);
    }
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          use.id: remainingUses(use) - 1,
        },
        activeConditions: {
          ...characterState.activeConditions,
          dragonWingsCondition,
        },
        conditionTurns: {
          ...characterState.conditionTurns,
          dragonWingsCondition: 600,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'Dragon Wings activated',
      detail:
          'One use spent · Fly Speed 60 feet for 1 hour. Flight and outside-combat elapsed time are table-managed.',
    );
  }

  bool get restoreDragonWingsAvailable {
    final use = resourceWithId(dragonWingsResourceId);
    final points = resourceWithId(sorceryPointsResourceId);
    return character.hasDragonWings &&
        characterState.canConcentrate &&
        use != null &&
        remainingUses(use) == 0 &&
        points != null &&
        remainingUses(points) >= 3;
  }

  Future<void> restoreDragonWings() async {
    if (!restoreDragonWingsAvailable) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Dragon Wings?'),
        content: const Text(
          'Spend 3 Sorcery Points to restore one Dragon Wings use, with no action cost. This does not activate, dismiss or extend the wings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Spend 3 points · Restore use'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !restoreDragonWingsAvailable) {
      return;
    }
    final points = resourceWithId(sorceryPointsResourceId)!;
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          dragonWingsResourceId: 1,
          points.id: remainingUses(points) - 3,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.resource,
      'Dragon Wings restored',
      detail:
          '3 Sorcery Points spent · No action. Existing wings and their duration are unchanged.',
    );
  }

  bool get innateSorceryAvailable {
    if (innateSorceryActive) return true;
    if (character.levelInClass('Sorcerer') < 1 ||
        !characterState.canConcentrate ||
        (currentMode == CharacterMode.combat &&
            usedCombatActions.contains(CombatActionCost.bonusAction))) {
      return false;
    }
    final use = resourceWithId(innateSorceryResourceId);
    final points = resourceWithId(sorceryPointsResourceId);
    return (use != null && remainingUses(use) > 0) ||
        (character.levelInClass('Sorcerer') >= 7 &&
            points != null &&
            remainingUses(points) >= 2);
  }

  Future<void> toggleInnateSorcery() async {
    if (!innateSorceryAvailable) return;
    final ending = innateSorceryActive;
    final use = resourceWithId(innateSorceryResourceId);
    final pointCost = use == null || remainingUses(use) <= 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          ending ? 'End Innate Sorcery?' : 'Activate Innate Sorcery?',
        ),
        content: Text(
          ending
              ? 'Record that the effect has ended or its minute elapsed at the table. No action or resource is spent.'
              : 'Spend ${pointCost ? '2 Sorcery Points using Sorcery Incarnate' : 'one Innate Sorcery use'}${currentMode == CharacterMode.combat ? ' and your Bonus Action' : ''}. '
                    'For 1 minute, marked Sorcerer spells gain +1 to their save DC and Advantage on attack rolls. Mark eligible spells in their Spellbook menu. '
                    'The effect lasts 10 tracked turns; track elapsed time outside combat at the table. It does not require concentration. '
                    '${character.levelInClass('Sorcerer') >= 7 ? 'While active, Sorcery Incarnate permits two Metamagic options on a spell; resolve those options at the table.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ending ? 'End effect' : 'Activate effect'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !innateSorceryAvailable ||
        innateSorceryActive != ending) {
      return;
    }
    if (ending) {
      updateCharacterState(
        characterState.copyWith(
          activeConditions: {...characterState.activeConditions}
            ..remove(innateSorceryCondition),
        ),
      );
      recordSessionEvent(
        SessionEventType.combat,
        'Innate Sorcery ended',
        detail: 'Effect ended at the table.',
      );
      return;
    }
    final resource = pointCost
        ? resourceWithId(sorceryPointsResourceId)
        : resourceWithId(innateSorceryResourceId);
    final cost = pointCost ? 2 : 1;
    if (resource == null || remainingUses(resource) < cost) return;
    if (currentMode == CharacterMode.combat) {
      usedCombatActions.add(CombatActionCost.bonusAction);
    }
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          resource.id: remainingUses(resource) - cost,
        },
        activeConditions: {
          ...characterState.activeConditions,
          innateSorceryCondition,
        },
        conditionTurns: {
          ...characterState.conditionTurns,
          innateSorceryCondition: 10,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.combat,
      'Innate Sorcery activated',
      detail:
          '${pointCost ? '2 Sorcery Points' : 'One use'} spent · 1 minute. Marked Sorcerer spells: +1 save DC and attack Advantage.',
    );
  }

  List<int> get fontSlotCreationChoices {
    final points = resourceWithId(sorceryPointsResourceId);
    final level = character.levelInClass('Sorcerer');
    if (points == null ||
        level < 2 ||
        !characterState.canConcentrate ||
        (currentMode == CharacterMode.combat &&
            usedCombatActions.contains(CombatActionCost.bonusAction))) {
      return [];
    }
    return [
      for (final entry in fontOfMagicCreationCosts.entries)
        if (level >= entry.value.$2 && remainingUses(points) >= entry.value.$1)
          entry.key,
    ];
  }

  Future<void> createFontOfMagicSlot() async {
    final choices = fontSlotCreationChoices;
    if (choices.isEmpty) return;
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Font of Magic · Create slot'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Spend Sorcery Points to create one extra spell slot. This costs a Bonus Action in combat. Created slots survive Short Rests and vanish on Long Rest.',
            ),
          ),
          for (final level in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, level),
              child: Text(
                'Level $level · ${fontOfMagicCreationCosts[level]!.$1} points',
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted ||
        chosen == null ||
        !fontSlotCreationChoices.contains(chosen)) {
      return;
    }
    final points = resourceWithId(sorceryPointsResourceId)!;
    final cost = fontOfMagicCreationCosts[chosen]!.$1;
    if (currentMode == CharacterMode.combat) {
      usedCombatActions.add(CombatActionCost.bonusAction);
    }
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          points.id: remainingUses(points) - cost,
          fontOfMagicSlotId(chosen):
              (characterState.resourceValues[fontOfMagicSlotId(chosen)] ?? 0) +
              1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.resource,
      'Font of Magic · Slot created',
      detail:
          '$cost Sorcery Points spent · One extra level $chosen slot. Expires on Long Rest.${currentMode == CharacterMode.combat ? ' Bonus Action spent.' : ''}',
    );
  }

  bool get slotToSorceryPointsAvailable {
    final points = resourceWithId(sorceryPointsResourceId);
    return character.levelInClass('Sorcerer') >= 2 &&
        characterState.canConcentrate &&
        points != null &&
        remainingUses(points) < sorceryPointCapacity &&
        castingResources.any(
          (r) => spellSlotLevel(r) != null && remainingUses(r) > 0,
        );
  }

  Future<void> convertSlotToSorceryPoints() async {
    if (!slotToSorceryPointsAvailable) return;
    final choice = await chooseAvailableSlot(1, 'Font of Magic · Choose slot');
    if (!mounted || choice == null || !slotToSorceryPointsAvailable) return;
    final slot = castingResources.where((r) => r.id == choice.$2).firstOrNull;
    final points = resourceWithId(sorceryPointsResourceId)!;
    if (slot == null || remainingUses(slot) <= 0) return;
    final gain = (sorceryPointCapacity - remainingUses(points)).clamp(
      0,
      choice.$1,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert slot to Sorcery Points'),
        content: Text(
          'Spend one level ${choice.$1} slot from ${slot.name} and recover $gain Sorcery Points, capped at $sorceryPointCapacity. '
          '${gain < choice.$1 ? 'Any excess points are lost. ' : ''}No action is spent. This does not cast a spell or recover other resources.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Spend slot · Recover points'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !slotToSorceryPointsAvailable ||
        remainingUses(slot) <= 0) {
      return;
    }
    final current = remainingUses(points);
    final recovered = (sorceryPointCapacity - current).clamp(0, choice.$1);
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          slot.id: remainingUses(slot) - 1,
          points.id: current + recovered,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.resource,
      'Font of Magic · Slot converted',
      detail:
          'One level ${choice.$1} ${slot.name} slot spent · $current → ${current + recovered} Sorcery Points. No action spent.',
    );
  }

  Future<void> useMagicalCunning() async {
    if (!magicalCunningAvailable) return;
    final pool = magicalCunningPactPool!;
    final use = resourceWithId(magicalCunningResourceId)!;
    final master = character.levelInClass('Warlock') >= 20;
    final budget = master ? pool.maximum : (pool.maximum + 1) ~/ 2;
    final recovered = (pool.maximum - remainingUses(pool)).clamp(0, budget);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          master ? 'Eldritch Master · Magical Cunning' : 'Magical Cunning',
        ),
        content: Text(
          'Confirm you completed the uninterrupted 1-minute esoteric rite. Recover $recovered expended Pact Magic slot${recovered == 1 ? '' : 's'} in ${pool.name}. '
          '${master ? 'Eldritch Master recovers all expended Pact Magic slots.' : 'Recover up to half your maximum Pact Magic slots, rounded up.'} '
          'Once per Long Rest. Ordinary spell slots, Mystic Arcanum and temporary slots are not recovered. This does not complete a Short Rest or spend combat actions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rite complete · Recover Pact slots'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !magicalCunningAvailable ||
        magicalCunningPactPool?.id != pool.id) {
      return;
    }
    final current = remainingUses(pool);
    updateCharacterState(
      characterState.copyWith(
        resourceValues: {
          ...characterState.resourceValues,
          pool.id: (current + budget).clamp(0, pool.maximum),
          use.id: remainingUses(use) - 1,
        },
      ),
    );
    recordSessionEvent(
      SessionEventType.resource,
      master ? 'Eldritch Master' : 'Magical Cunning',
      detail:
          '${(current + budget).clamp(0, pool.maximum) - current} Pact Magic slots recovered after a confirmed 1-minute rite · One use spent. Long Rest restores availability.',
    );
  }

  Future<void> useNaturalRecovery({bool arcane = false}) async {
    final resource = character.resources
        .where((r) => r.id == arcaneRecoveryResourceId)
        .firstOrNull;
    bool used() => arcane
        ? resource == null || remainingUses(resource) < 1
        : characterState.naturalRecoveryUsed;
    final recoveryLevel = arcane
        ? character.levelInClass('Wizard')
        : landDruidLevel;
    if (recoveryLevel < (arcane ? 1 : 6) || used()) return;
    var budget = (recoveryLevel + 1) ~/ 2;
    final recovered = <String, int>{};
    while (mounted) {
      final available = [
        for (final (level, resource)
            in (arcane ? arcaneRecoverySlots : naturalRecoverySlots))
          if (level <= budget &&
              remainingUses(resource) + (recovered[resource.id] ?? 0) <
                  resource.maximum)
            (level, resource),
      ];
      if (available.isEmpty) break;
      final choice = await showDialog<(int, String)>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(arcane ? 'Arcane Recovery · Slots' : 'Natural Recovery'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('$budget slot levels remaining'),
            ),
            for (final (level, resource) in available)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, (level, resource.id)),
                child: Text('Recover a level $level slot'),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, (0, '')),
              child: Text(recovered.isEmpty ? 'Skip' : 'Finish Recovery'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null || used()) {
        return;
      }
      if (choice.$1 == 0) break;
      budget -= choice.$1;
      recovered.update(choice.$2, (count) => count + 1, ifAbsent: () => 1);
    }
    if (!mounted || recovered.isEmpty || used()) {
      return;
    }
    updateCharacterState(
      characterState.copyWith(
        naturalRecoveryUsed: arcane ? characterState.naturalRecoveryUsed : true,
        resourceValues: {
          ...characterState.resourceValues,
          if (arcane) resource!.id: remainingUses(resource) - 1,
          for (final resource in character.resources)
            if (recovered.containsKey(resource.id))
              resource.id: (remainingUses(resource) + recovered[resource.id]!)
                  .clamp(0, resource.maximum),
        },
      ),
    );
    if (arcane) {
      recordSessionEvent(
        SessionEventType.rest,
        'Arcane Recovery',
        detail:
            'Recovered ${recovered.values.fold<int>(0, (sum, count) => sum + count)} spell slots after a confirmed Short Rest. Once-per-Long-Rest use spent.',
      );
    }
  }

  // ------------------------------------------------------------
  // CHARACTER MODES
  // ------------------------------------------------------------

  void beginCombat() {
    frenzyUsedThisTurn = false;
    hurlThroughHellUsedThisTurn = false;
    levelledSpellCastThisTurn = false;
    quickenedSpellUsedThisTurn = false;
    attackRollMadeThisTurn = false;
    recklessAttackArmed = false;
    setState(() {
      currentMode = CharacterMode.combat;
      combatRound = 1;
      combatInitiative = null;
      peerlessSkillRoll = null;
      darkLuckRoll = null;
      usedCombatActions.clear();
      actionSurge = null;
      wildResurgenceUsedThisTurn = false;
      primalStrikeUsedThisTurn = false;
      cleaveUsedThisTurn = false;
      nickUsedThisTurn = false;
      sneakAttackUsedThisTurn = false;
      stunningStrikeUsedThisTurn = false;
      flurryAttacksRemaining = 0;
      steadyAimAttackPending = false;
      attackActionAttacksRemaining = 0;
      selfRestorationUsedThisTurn = false;
      fleetStepUsedThisTurn = false;
      stepOfWindUsedThisTurn = false;
      readiedAction = null;
      readiedEffect = null;
    });
    recordSessionEvent(SessionEventType.combat, 'Combat began');
  }

  Future<int?> adjustInitiativeWithDarkLuck(CheckRoll roll) async {
    final resource = resourceWithId(darkOnesOwnLuckResourceId);
    bool eligible() =>
        mounted &&
        currentMode == CharacterMode.combat &&
        hasDarkOnesOwnLuck &&
        resource != null &&
        remainingUses(resource) > 0 &&
        !(characterState.currentHp == 0 &&
            characterState.deathSaveFailures >= 3);
    if (!eligible()) return roll.total;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dark One’s Own Luck · Initiative'),
        content: Text(
          'Initiative total ${roll.total} (d20 ${roll.naturalRoll}, modifier ${roll.displayModifier}). '
          'You can spend one use to add 1d10 before recording the total and resolving initiative effects. No action is spent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel recording'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: const Text('Keep initiative'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'boost'),
            child: const Text('Spend use · Boost initiative'),
          ),
        ],
      ),
    );
    if (!mounted || currentMode != CharacterMode.combat || choice == null) {
      return null;
    }
    if (choice == 'keep') return roll.total;
    if (!eligible() || !spendCastResource(resource!.id)) return null;
    final bonus = diceRoller.rollDie(10);
    addRollNotice(
      title: 'Initiative · Dark One’s Own Luck',
      calculation: '${roll.total} + 1d10 ($bonus) = ${roll.total + bonus}',
      total: roll.total + bonus,
      tone: RollNoticeTone.normal,
      detail: 'One use spent · Original d20 ${roll.naturalRoll} unchanged.',
    );
    return roll.total + bonus;
  }

  Future<void> recordCombatInitiative(int total) async {
    if (currentMode != CharacterMode.combat) return;
    final firstInitiative = combatInitiative == null;
    setState(() => combatInitiative = total);
    recordSessionEvent(
      SessionEventType.combat,
      'Initiative recorded',
      detail: '$total',
    );
    if (firstInitiative) await recoverMonkOnInitiative();
    if (!mounted || currentMode != CharacterMode.combat) return;
    final inspiration = character.resources
        .where((resource) => resource.id == bardicInspirationResourceId)
        .firstOrNull;
    if (firstInitiative &&
        character.levelInClass('Bard') >= 18 &&
        inspiration != null) {
      final target = inspiration.maximum.clamp(0, 2);
      if (remainingUses(inspiration) < target) {
        updateCharacterState(
          characterState.copyWith(
            resourceValues: {
              ...characterState.resourceValues,
              inspiration.id: target,
            },
          ),
        );
      }
    }
    final wildShape = character.resources
        .where((resource) => resource.id == wildShapeResourceId)
        .firstOrNull;
    if (firstInitiative &&
        character.levelInClass('Druid') >= 20 &&
        wildShape != null &&
        remainingUses(wildShape) == 0) {
      updateCharacterState(
        characterState.copyWith(
          resourceValues: {...characterState.resourceValues, wildShape.id: 1},
        ),
      );
    }
    final rage = character.resources
        .where((resource) => resource.id == rageResourceId)
        .firstOrNull;
    if (!hasPersistentRage ||
        characterState.persistentRageRecoveryUsed ||
        rage == null ||
        remainingUses(rage) >= rage.maximum) {
      return;
    }
    final recover = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Persistent Rage'),
        content: const Text(
          'Recover all expended Rage uses? You can do this once per long rest.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recover Rage'),
          ),
        ],
      ),
    );
    if (!mounted ||
        recover != true ||
        currentMode != CharacterMode.combat ||
        characterState.persistentRageRecoveryUsed) {
      return;
    }
    updateCharacterState(
      characterState.copyWith(
        persistentRageRecoveryUsed: true,
        resourceValues: {
          ...characterState.resourceValues,
          rage.id: rage.maximum,
        },
      ),
    );
  }

  Future<void> recoverMonkOnInitiative() async {
    final level = character.levelInClass('Monk');
    final focus = character.resources
        .where((resource) => resource.id == focusResourceId)
        .firstOrNull;
    final metabolism = character.resources
        .where((resource) => resource.id == uncannyMetabolismResourceId)
        .firstOrNull;
    if (level < 2 || focus == null) return;
    if (metabolism != null && remainingUses(metabolism) > 0) {
      final recover = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Uncanny Metabolism'),
          content: Text(
            'Recover all expended Focus Points and heal 1d${character.martialArtsDieSides} + $level HP. Once per Long Rest. ${level >= 15 ? 'If you skip, Perfect Focus restores your Focus to 4 when below 4.' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Recover Focus and HP'),
            ),
          ],
        ),
      );
      if (!mounted || currentMode != CharacterMode.combat) return;
      if (recover == true && remainingUses(metabolism) > 0) {
        final die = diceRoller.rollDie(character.martialArtsDieSides);
        final hp = (characterState.currentHp + level + die).clamp(
          0,
          characterState.maxHp,
        );
        final healed = hp - characterState.currentHp;
        updateCharacterState(
          characterState.copyWith(
            currentHp: hp,
            resourceValues: {
              ...characterState.resourceValues,
              focus.id: focus.maximum,
              metabolism.id: remainingUses(metabolism) - 1,
            },
          ),
        );
        recordSessionEvent(
          SessionEventType.combat,
          'Uncanny Metabolism',
          detail:
              'Focus restored to ${focus.maximum} · 1d${character.martialArtsDieSides} ($die) + $level = ${die + level} healing, $healed HP recovered.',
        );
        return;
      }
    }
    if (level >= 15 && remainingUses(focus) < 4) {
      updateCharacterState(
        characterState.copyWith(
          resourceValues: {...characterState.resourceValues, focus.id: 4},
        ),
      );
      recordSessionEvent(
        SessionEventType.combat,
        'Perfect Focus',
        detail:
            'Focus restored to 4 on initiative; Uncanny Metabolism was not used.',
      );
    }
  }

  bool get canUseNonMagicAction =>
      !usedCombatActions.contains(CombatActionCost.action) ||
      actionSurge == ActionSurgeState.available;

  bool get hasFastHands =>
      character.levelInClass('Rogue') >= 3 &&
      character.subclasses['Rogue'] == 'Thief';

  bool get hasThievesTools => inventory.any(
    (item) =>
        item.quantity > 0 &&
        item.name.toLowerCase().replaceAll(RegExp('[^a-z]'), '') ==
            'thievestools',
  );

  Future<void> chooseCombatAction({
    bool asBonusAction = false,
    bool fastHands = false,
  }) async {
    bool canUse() =>
        characterState.canConcentrate &&
        (asBonusAction
            ? (fastHands
                      ? hasFastHands
                      : character.levelInClass('Rogue') >= 2) &&
                  !usedCombatActions.contains(CombatActionCost.bonusAction)
            : !fastHands && canUseNonMagicAction);
    if (!canUse()) {
      return;
    }
    final prefix = fastHands
        ? 'Fast Hands · '
        : asBonusAction
        ? 'Cunning Action · '
        : '';
    const actions = {
      'Pick a pocket': 'Roll Dexterity (Sleight of Hand).',
      'Pick a lock / disarm trap':
          'Requires carried Thieves’ Tools; roll Dexterity (Sleight of Hand).',
      'Magic Item': 'Take the Magic action to use a qualifying magic item.',
      'Dash': 'Gain extra movement this turn.',
      'Disengage': 'Your movement avoids opportunity attacks this turn.',
      'Dodge': 'Gain defensive benefits until your next turn.',
      'Help': 'Describe who you help and how.',
      'Hide': 'Roll a Dexterity (Stealth) check.',
      'Search': 'Choose a Wisdom skill to check.',
      'Study': 'Choose an Intelligence skill to check.',
      'Influence': 'Choose a social skill if the GM calls for a check.',
      'Utilize': 'Choose an inventory item to use.',
      'Ready': 'Describe the trigger and what you will do when it occurs.',
    };
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          fastHands
              ? 'Fast Hands'
              : asBonusAction
              ? 'Cunning Action'
              : 'Use an Action',
        ),
        children: [
          for (final action in actions.entries)
            if (fastHands
                ? const {
                    'Pick a pocket',
                    'Pick a lock / disarm trap',
                    'Utilize',
                    'Magic Item',
                  }.contains(action.key)
                : asBonusAction
                ? const {'Dash', 'Disengage', 'Hide'}.contains(action.key)
                : !const {
                    'Pick a pocket',
                    'Pick a lock / disarm trap',
                    'Magic Item',
                  }.contains(action.key))
              SimpleDialogOption(
                onPressed:
                    action.key == 'Pick a lock / disarm trap' &&
                        !hasThievesTools
                    ? null
                    : () => Navigator.pop(context, action.key),
                child: ListTile(
                  enabled:
                      action.key != 'Pick a lock / disarm trap' ||
                      hasThievesTools,
                  contentPadding: EdgeInsets.zero,
                  title: Text(action.key),
                  subtitle: Text(action.value),
                ),
              ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || currentMode != CharacterMode.combat) {
      return;
    }
    String? plan;
    String? readyEffect;
    String? actionDetail;
    Skill? actionSkill;
    final applicableSkills = switch (choice) {
      'Pick a pocket' ||
      'Pick a lock / disarm trap' => const {'sleight_of_hand'},
      'Hide' => const {'stealth'},
      'Search' => const {'insight', 'medicine', 'perception', 'survival'},
      'Study' => const {
        'arcana',
        'history',
        'investigation',
        'nature',
        'religion',
      },
      'Influence' => const {
        'animal_handling',
        'deception',
        'intimidation',
        'performance',
        'persuasion',
      },
      _ => const <String>{},
    };
    if (applicableSkills.isNotEmpty) {
      final skills = standardSkills
          .where((skill) => applicableSkills.contains(skill.id))
          .toList();
      if (skills.length == 1) {
        actionSkill = skills.single;
      } else {
        final skillId = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text('$choice check'),
            children: [
              for (final skill in skills)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, skill.id),
                  child: Text(skill.name),
                ),
              if (choice == 'Influence')
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, ''),
                  child: const Text('No check required'),
                ),
            ],
          ),
        );
        if (!mounted || skillId == null) return;
        actionSkill = skills.where((skill) => skill.id == skillId).firstOrNull;
      }
    }
    if (choice == 'Pick a lock / disarm trap' && !hasThievesTools) return;
    if (choice == 'Utilize' || choice == 'Magic Item') {
      final items = inventory.where((item) => item.quantity > 0).toList();
      actionDetail = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(
            choice == 'Magic Item' ? 'Use a magic item' : 'Use an item',
          ),
          children: [
            if (choice == 'Magic Item')
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Confirm the item requires a Magic action. Resolve its requirements, charges and effects at the table.',
                ),
              ),
            for (final item in items)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, item.name),
                child: Text(item.name),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                context,
                choice == 'Magic Item'
                    ? 'Magic item used at the table'
                    : 'Object used at the table',
              ),
              child: const Text('Use another object'),
            ),
          ],
        ),
      );
      if (!mounted || actionDetail == null) return;
    }
    if (choice == 'Help') {
      actionDetail = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('How are you helping?'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                context,
                'Choose one of your skill or tool proficiencies and a nearby '
                'ally you can assist. They gain Advantage on their next check '
                'with it before the start of your next turn.',
              ),
              child: const Text('Assist an ability check'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                context,
                'An ally has Advantage on their next attack against the '
                'enemy you distract within 5 feet, before your next turn.',
              ),
              child: const Text('Distract an enemy'),
            ),
          ],
        ),
      );
      if (!mounted || actionDetail == null) return;
    }
    if (choice == 'Ready') {
      var text = '';
      var effect = '';
      final ready = await showDialog<(String, String)>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ready an Action'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Trigger and action',
                ),
                maxLength: 200,
                onChanged: (value) => text = value,
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Readied effect'),
                initialValue: '',
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Resolve at the table'),
                  ),
                  const DropdownMenuItem(
                    value: 'move',
                    child: Text('Move up to your Speed'),
                  ),
                  for (final weapon in characterInCombat.weapons)
                    DropdownMenuItem(
                      value: weapon.actionKey,
                      child: Text('Attack with ${weapon.name}'),
                    ),
                ],
                onChanged: (value) => effect = value ?? '',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (text.trim().isNotEmpty) {
                  Navigator.pop(context, (text.trim(), effect));
                }
              },
              child: const Text('Ready'),
            ),
          ],
        ),
      );
      if (!mounted || ready == null) return;
      (plan, readyEffect) = ready;
    }
    if (currentMode != CharacterMode.combat || !canUse()) {
      return;
    }
    final primal = actionSkill == null
        ? false
        : await choosePrimalKnowledge(
            characterForPhysicalChecks.checkFor(actionSkill),
          );
    if (!mounted ||
        primal == null ||
        currentMode != CharacterMode.combat ||
        !canUse()) {
      return;
    }
    setState(() {
      if (asBonusAction) {
        usedCombatActions.add(CombatActionCost.bonusAction);
      } else if (actionSurge == ActionSurgeState.available) {
        actionSurge = ActionSurgeState.spent;
      } else {
        usedCombatActions.add(CombatActionCost.action);
      }
      if (plan != null) {
        readiedAction = plan;
        readiedEffect = readyEffect;
      }
    });
    final turnEffect = switch (choice) {
      'Dash' => dashingCondition,
      'Disengage' => disengagingCondition,
      'Dodge' => dodgingCondition,
      _ => null,
    };
    if (choice == 'Dash') {
      actionDetail =
          'Gain extra movement equal to your current Speed this turn.';
    } else if (choice == 'Disengage') {
      actionDetail =
          'Your movement does not provoke opportunity attacks this turn.';
    } else if (choice == 'Dodge') {
      actionDetail =
          'Attacks from creatures you can see have Disadvantage. '
          'Dexterity saves have Advantage. These benefits end at the start '
          'of your next turn, if you are Incapacitated, or if your Speed drops to 0.';
    }
    if (turnEffect != null) {
      updateCharacterState(
        characterState.copyWith(
          activeConditions: {...characterState.activeConditions, turnEffect},
          conditionTurns: {...characterState.conditionTurns, turnEffect: 1},
        ),
      );
    }
    recordSessionEvent(
      SessionEventType.combat,
      asBonusAction ? '$prefix$choice' : '$choice used',
      detail: plan ?? actionDetail,
    );
    if (actionSkill != null) {
      final check = characterForPhysicalChecks.checkFor(actionSkill);
      tacticalMindCheck = rollSkillCheck(
        check,
        usePrimalKnowledge: primal,
        label: '$prefix$choice · ${actionSkill.name}',
        describe: choice == 'Hide'
            ? (roll) => roll.total >= 15
                  ? 'Meets DC 15 · Confirm hiding conditions with the GM'
                  : 'DC 15 · Failed check'
            : null,
      );
    }
  }

  Future<void> triggerReadiedAction() async {
    final plan = readiedAction;
    if (plan == null ||
        !characterState.canConcentrate ||
        usedCombatActions.contains(CombatActionCost.reaction)) {
      return;
    }
    final effect = readiedEffect;
    final weapon = characterInCombat.weapons
        .where((weapon) => weapon.actionKey == effect)
        .firstOrNull;
    if (effect?.startsWith('weapon:') == true && weapon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The readied attack is no longer available.'),
        ),
      );
      return;
    }
    if (weapon != null &&
        characterState.activeConditions.contains(steadyAimCondition)) {
      final sameTurn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Steady Aim · Reaction turn'),
          content: const Text(
            'Is this readied attack on your own current turn? Steady Aim expires when that turn ends.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Another creature’s turn'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Same turn'),
            ),
          ],
        ),
      );
      if (!mounted ||
          sameTurn == null ||
          !characterState.canConcentrate ||
          usedCombatActions.contains(CombatActionCost.reaction)) {
        return;
      }
      if (!sameTurn) beginAnotherCreatureTurn();
    }
    bool? packTactics;
    if (weapon?.id == 'wild-shape-wolf') {
      packTactics = await choosePackTactics();
      if (!mounted ||
          packTactics == null ||
          activeWildShape?.combatAttack.id != weapon!.id ||
          !characterState.canConcentrate ||
          usedCombatActions.contains(CombatActionCost.reaction)) {
        return;
      }
    }
    if (weapon case Weapon(ammunitionName: final name?)) {
      if (!inventory.any(
        (item) => item.quantity > 0 && matchesAmmunition(item, name),
      )) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No $name remaining.')));
        return;
      }
    }
    setState(() {
      usedCombatActions.add(CombatActionCost.reaction);
      readiedAction = null;
      readiedEffect = null;
    });
    recordSessionEvent(
      SessionEventType.combat,
      'Readied action triggered',
      detail: effect == 'move' ? '$plan · Move up to your Speed' : plan,
    );
    if (weapon != null) {
      await rollAttack(
        weapon,
        asReaction: true,
        packTacticsChoice: packTactics,
      );
    }
  }

  void advanceCombatTurn() {
    frenzyUsedThisTurn = false;
    hurlThroughHellUsedThisTurn = false;
    levelledSpellCastThisTurn = false;
    quickenedSpellUsedThisTurn = false;
    attackRollMadeThisTurn = false;
    recklessAttackArmed = false;
    tacticalMindCheck = null;
    peerlessSkillRoll = null;
    darkLuckRoll = null;
    pendingAttackSlot = null;
    pendingCriticalActionKey = null;
    setState(() {
      nextRollMode = D20Mode.normal;
      combatRound++;
      usedCombatActions.clear();
      actionSurge = null;
      wildResurgenceUsedThisTurn = false;
      primalStrikeUsedThisTurn = false;
      cleaveUsedThisTurn = false;
      nickUsedThisTurn = false;
      sneakAttackUsedThisTurn = false;
      stunningStrikeUsedThisTurn = false;
      flurryAttacksRemaining = 0;
      steadyAimAttackPending = false;
      attackActionAttacksRemaining = 0;
      selfRestorationUsedThisTurn = false;
      fleetStepUsedThisTurn = false;
      stepOfWindUsedThisTurn = false;
      readiedAction = null;
      readiedEffect = null;
    });
    var updated = characterState
        .advanceConcentrationTurn()
        .advanceConditionTurn();
    final formTurns = updated.wildShapeTurnsRemaining;
    if (updated.wildShapeForm != null && formTurns != null) {
      updated = formTurns <= 1
          ? updated.copyWith(clearWildShape: true)
          : updated.copyWith(wildShapeTurnsRemaining: formTurns - 1);
    }
    final canRally =
        character.championLevel >= 18 &&
        updated.currentHp > 0 &&
        updated.currentHp * 2 <= updated.maxHp;
    if (canRally) {
      final healing = (5 + character.abilityModifierFor(Ability.constitution))
          .clamp(0, updated.maxHp - updated.currentHp);
      if (healing > 0) {
        updated = updated.copyWith(currentHp: updated.currentHp + healing);
        recordSessionEvent(
          SessionEventType.health,
          'Heroic Rally',
          detail: 'Recovered $healing HP',
        );
      }
    }
    if (!identical(updated, characterState)) updateCharacterState(updated);
    recordSessionEvent(SessionEventType.combat, 'Round $combatRound began');
  }

  void setCombatActionUsed(CombatActionCost cost, bool used) {
    setState(() {
      if (used) {
        usedCombatActions.add(cost);
      } else {
        if (cost == CombatActionCost.action) attackActionAttacksRemaining = 0;
        usedCombatActions.remove(cost);
      }
    });
    publishSession();
  }

  void endCombat() {
    frenzyUsedThisTurn = false;
    hurlThroughHellUsedThisTurn = false;
    levelledSpellCastThisTurn = false;
    quickenedSpellUsedThisTurn = false;
    attackRollMadeThisTurn = false;
    recklessAttackArmed = false;
    var ended = characterState.endRage();
    const turnEffects = {
      recklessAttackCondition,
      dodgingCondition,
      dashingCondition,
      disengagingCondition,
      naturesSanctuaryCondition,
      steadyAimCondition,
    };
    if (ended.activeConditions.any(turnEffects.contains)) {
      ended = ended.copyWith(
        activeConditions: {...ended.activeConditions}..removeAll(turnEffects),
      );
    }
    if (!identical(ended, characterState)) updateCharacterState(ended);
    pendingAttackSlot = null;
    pendingCriticalActionKey = null;
    setState(() {
      currentMode = CharacterMode.exploration;
      combatRound = 1;
      combatInitiative = null;
      peerlessSkillRoll = null;
      darkLuckRoll = null;
      usedCombatActions.clear();
      actionSurge = null;
      wildResurgenceUsedThisTurn = false;
      primalStrikeUsedThisTurn = false;
      cleaveUsedThisTurn = false;
      nickUsedThisTurn = false;
      sneakAttackUsedThisTurn = false;
      stunningStrikeUsedThisTurn = false;
      flurryAttacksRemaining = 0;
      steadyAimAttackPending = false;
      attackActionAttacksRemaining = 0;
      selfRestorationUsedThisTurn = false;
      fleetStepUsedThisTurn = false;
      stepOfWindUsedThisTurn = false;
      readiedAction = null;
      readiedEffect = null;
    });
    recordSessionEvent(SessionEventType.combat, 'Combat ended');
  }

  void openSessionTimeline() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SessionTimeline(events: timeline, onClear: clearSessionTimeline),
      ),
    );
  }

  Future<void> clearSessionTimeline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Session Timeline?'),
        content: const Text(
          'Remove this character\'s recorded session history? This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-clear-session-timeline'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Timeline'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => timeline = []);
    publishSession();
    if (mounted) Navigator.pop(context);
  }

  void selectDestination(int index) {
    setState(() {
      currentMode = switch (index) {
        0 => CharacterMode.exploration,
        1 => CharacterMode.spellbook,
        2 => CharacterMode.profile,
        _ => CharacterMode.exploration,
      };
    });
  }

  int get selectedDestinationIndex => switch (currentMode) {
    CharacterMode.exploration => 0,
    CharacterMode.spellbook => 1,
    CharacterMode.profile => 2,
    CharacterMode.combat => 0,
  };

  Future<void> showBeginCombatPrompt() async {
    final begin = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⚔ Begin Combat?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    style: IconButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.check),
                  ),

                  const SizedBox(width: 24),

                  IconButton.filled(
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    style: IconButton.styleFrom(backgroundColor: Colors.red),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (begin == true) {
      beginCombat();
    }
  }

  Future<void> requestExitCharacter() async {
    if (exitPromptVisible) {
      return;
    }

    exitPromptVisible = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Exit Character?'),
          content: const Text(
            'Return to the Character Vault? Your character is saved '
            'automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
    exitPromptVisible = false;

    if (!mounted || shouldExit != true) {
      return;
    }

    setState(() {
      allowExit = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  // ------------------------------------------------------------
  // MODE VIEWS
  // ------------------------------------------------------------

  WildShapeForm? get activeWildShape =>
      wildShapeFormNamed(characterState.wildShapeForm ?? '');

  Character get characterForPhysicalChecks {
    final form = activeWildShape;
    final aura =
        character.levelInClass('Paladin') >= 6 && characterState.canConcentrate
        ? character.abilityModifierFor(Ability.charisma).clamp(1, 999)
        : 0;
    final base = character.copyWith(
      savingThrowBonus: aura,
      innateSorceryActive: innateSorceryActive,
    );
    if (form == null) return base;
    return base.copyWith(
      skillModifierMinimums: form.skillModifiers,
      saveModifierMinimums: form.saveModifiers,
      abilityScores: {
        ...character.abilityScores,
        Ability.strength: form.strength,
        Ability.dexterity: form.dexterity,
        Ability.constitution: form.constitution,
      },
    );
  }

  Character get characterInCombat {
    final form = activeWildShape;
    final physical = characterForPhysicalChecks;
    return form == null
        ? physical
        : physical.copyWith(weapons: [form.combatAttack]);
  }

  Widget buildExplorationMode() {
    final wholeness = character.resources
        .where((resource) => resource.id == wholenessOfBodyResourceId)
        .firstOrNull;
    return ExplorationModeView(
      character: characterForPhysicalChecks,
      characterState: characterState,
      formArmourClass: activeWildShape?.armourClass,
      onCharacterStateChanged: updateCharacterState,
      onDamageTaken: promptConcentrationAfterDamage,
      adjustIncomingDamage: adjustIncomingDamage,
      inventory: inventory,
      onBeginCombat: showBeginCombatPrompt,
      onMemorizeSpell: character.levelInClass('Wizard') >= 5
          ? useMemorizeSpell
          : null,
      onMagicalCunning: character.levelInClass('Warlock') >= 2
          ? useMagicalCunning
          : null,
      onDarkLuck: hasDarkOnesOwnLuck ? useDarkOnesOwnLuck : null,
      darkLuckAvailable: darkLuckAvailable,
      onFiendishResilience: character.hasFiendishResilience
          ? chooseFiendishResilience
          : null,
      onDarkOnesBlessing: hasDarkOnesBlessing ? useDarkOnesBlessing : null,
      darkOnesBlessingAvailable: darkOnesBlessingAvailable,
      onSlotToSorceryPoints: character.levelInClass('Sorcerer') >= 2
          ? convertSlotToSorceryPoints
          : null,
      slotToSorceryPointsAvailable: slotToSorceryPointsAvailable,
      onInnateSorcery: character.levelInClass('Sorcerer') >= 1
          ? toggleInnateSorcery
          : null,
      innateSorceryAvailable: innateSorceryAvailable,
      onElementalAffinity: character.hasElementalAffinity
          ? chooseElementalAffinity
          : null,
      onDraconicHp: character.hasDraconicResilience ? reviewDraconicHp : null,
      onDraconicDefense:
          character.hasDraconicResilience && activeWildShape == null
          ? useDraconicDefense
          : null,
      onDragonWings: character.hasDragonWings ? toggleDragonWings : null,
      dragonWingsAvailable: dragonWingsAvailable,
      onRestoreDragonWings: character.hasDragonWings
          ? restoreDragonWings
          : null,
      restoreDragonWingsAvailable: restoreDragonWingsAvailable,
      onCreateFontSlot: character.levelInClass('Sorcerer') >= 2
          ? createFontOfMagicSlot
          : null,
      createFontSlotAvailable: fontSlotCreationChoices.isNotEmpty,
      onRestoreHurlThroughHell: hasHurlThroughHell
          ? restoreHurlThroughHell
          : null,
      restoreHurlThroughHellAvailable: restoreHurlThroughHellAvailable,
      magicalCunningAvailable: magicalCunningAvailable,
      onBarbarianDefense:
          character.levelInClass('Barbarian') >= 1 && activeWildShape == null
          ? useBarbarianDefense
          : null,
      onBardicInspiration: character.levelInClass('Bard') >= 1
          ? grantBardicInspiration
          : null,
      bardicInspirationAvailable: bardicInspirationAvailable,
      onPeerlessSkill: hasPeerlessSkill ? usePeerlessSkill : null,
      peerlessSkillAvailable: peerlessSkillAvailable,
      onArcaneRecovery: character.levelInClass('Wizard') > 0
          ? useArcaneRecovery
          : null,
      onMonkDefense:
          character.levelInClass('Monk') >= 1 && activeWildShape == null
          ? useMonkDefense
          : null,
      onWholenessOfBody: wholeness == null
          ? null
          : () => useWholenessOfBody(wholeness),
      onAddItemFromLibrary: addInventoryItemFromLibrary,
      onCreateCustomItem: showNewItemForm,
      onRestockItem: showRestockItems,
      onConsumeItem: consumeItem,
      onEditItem: editItem,
      onSkillTap: handleSkillTap,
      onRestSelected: takeRest,
      onAddJournalEntry: addJournalEntry,
      onJournalEntryTap: showJournalEntry,
      onJournalEntryLongPress: manageJournalEntry,
    );
  }

  Widget buildCombatMode() {
    return CombatModeView(
      character: characterInCombat,
      attackActionStatus:
          'Attack action: ${attackActionAttacksRemaining > 0
              ? '$attackActionAttacksRemaining attacks remaining'
              : canUseNonMagicAction
              ? 'available'
              : 'spent'} · ${character.attacksPerAction} per action',
      characterState: characterState,
      formArmourClass: activeWildShape?.armourClass,
      onCharacterStateChanged: updateCharacterState,
      onDamageTaken: promptConcentrationAfterDamage,
      adjustIncomingDamage: adjustIncomingDamage,
      resolveDamage: resolveRelentlessRage,
      onHurlThroughHell: hasHurlThroughHell ? useHurlThroughHell : null,
      hurlThroughHellAvailable: hurlThroughHellAvailable,
      onActionTap: handleActionTap,
      onActionDetails: showActionDetails,
      onAttackRoll: rollAttack,
      onUnarmedStrike: activeWildShape == null ? useUnarmedStrike : null,
      onCuttingWords: hasCuttingWords ? useCuttingWords : null,
      onDarkLuck: hasDarkOnesOwnLuck ? useDarkOnesOwnLuck : null,
      darkLuckAvailable: darkLuckAvailable,
      onDarkOnesBlessing: hasDarkOnesBlessing ? useDarkOnesBlessing : null,
      darkOnesBlessingAvailable: darkOnesBlessingAvailable,
      onSlotToSorceryPoints: character.levelInClass('Sorcerer') >= 2
          ? convertSlotToSorceryPoints
          : null,
      slotToSorceryPointsAvailable: slotToSorceryPointsAvailable,
      onInnateSorcery: character.levelInClass('Sorcerer') >= 1
          ? toggleInnateSorcery
          : null,
      innateSorceryAvailable: innateSorceryAvailable,
      onElementalAffinity: character.hasElementalAffinity
          ? chooseElementalAffinity
          : null,
      onDraconicHp: character.hasDraconicResilience ? reviewDraconicHp : null,
      onDraconicDefense:
          character.hasDraconicResilience && activeWildShape == null
          ? useDraconicDefense
          : null,
      onDragonWings: character.hasDragonWings ? toggleDragonWings : null,
      dragonWingsAvailable: dragonWingsAvailable,
      onRestoreDragonWings: character.hasDragonWings
          ? restoreDragonWings
          : null,
      restoreDragonWingsAvailable: restoreDragonWingsAvailable,
      onCreateFontSlot: character.levelInClass('Sorcerer') >= 2
          ? createFontOfMagicSlot
          : null,
      createFontSlotAvailable: fontSlotCreationChoices.isNotEmpty,
      onRestoreHurlThroughHell: hasHurlThroughHell
          ? restoreHurlThroughHell
          : null,
      restoreHurlThroughHellAvailable: restoreHurlThroughHellAvailable,
      onRecklessAttack: character.levelInClass('Barbarian') >= 2
          ? declareRecklessAttack
          : null,
      recklessAttackAvailable: canDeclareRecklessAttack,
      recklessAttackArmed: recklessAttackArmed,
      onRetaliation: hasRetaliation ? useRetaliation : null,
      retaliationAvailable: canRetaliate,
      onIntimidatingPresence: hasIntimidatingPresence
          ? useIntimidatingPresence
          : null,
      intimidatingPresenceAvailable: intimidatingPresenceAvailable,
      onBarbarianDefense:
          character.levelInClass('Barbarian') >= 1 && activeWildShape == null
          ? useBarbarianDefense
          : null,
      onPeerlessSkill: hasPeerlessSkill ? usePeerlessSkill : null,
      peerlessSkillAvailable: peerlessSkillAvailable,
      onBardicInspiration: character.levelInClass('Bard') >= 1
          ? grantBardicInspiration
          : null,
      bardicInspirationAvailable: bardicInspirationAvailable,
      onCountercharm: character.levelInClass('Bard') >= 7
          ? useCountercharm
          : null,
      cuttingWordsAvailable: character.resources.any(
        (resource) =>
            resource.id == bardicInspirationResourceId &&
            remainingUses(resource) > 0,
      ),
      onFleetStep:
          character.levelInClass('Monk') >= 11 &&
              character.subclasses['Monk'] == 'Warrior of the Open Hand'
          ? () => useMonkMovement(asFleetStep: true)
          : null,
      canUseFleetStep: canUseFleetStep,
      onSuperiorDefense: character.levelInClass('Monk') >= 18
          ? useSuperiorDefense
          : null,
      onMonkDefense:
          character.levelInClass('Monk') >= 1 && activeWildShape == null
          ? useMonkDefense
          : null,
      onStunningStrike: character.levelInClass('Monk') >= 5
          ? useStunningStrike
          : null,
      stunningStrikeUsedThisTurn: stunningStrikeUsedThisTurn,
      flurryAttacksRemaining: flurryAttacksRemaining,
      canStartFlurry: character.resources.any(
        (resource) =>
            resource.id == focusResourceId && remainingUses(resource) > 0,
      ),
      onFlurry: activeWildShape == null && character.levelInClass('Monk') >= 2
          ? useFlurry
          : null,
      onMonkMovement: character.levelInClass('Monk') >= 2
          ? useMonkMovement
          : null,
      onBonusUnarmedStrike:
          activeWildShape == null && character.martialArtsDieSides > 0
          ? () => useUnarmedStrike(asBonusAction: true)
          : null,
      ammunitionLabel: ammunitionLabel,
      onDamageRoll: rollDamage,
      onDeathSaveRoll: rollDeathSave,
      combatRound: combatRound,
      usedCombatActions: usedCombatActions,
      actionSurge: actionSurge,
      onActionSurgeSpent: () {
        setState(() => actionSurge = ActionSurgeState.spent);
        publishSession();
      },
      onCombatActionChanged: setCombatActionUsed,
      onNextTurn: advanceCombatTurn,
      onRageEnemySave: characterState.isRaging && !hasPersistentRage
          ? recordRageEnemySave
          : null,
      onExtendRage: characterState.isRaging && !hasPersistentRage
          ? extendRageWithBonusAction
          : null,
      onEndRage: characterState.isRaging
          ? () => updateCharacterState(characterState.endRage())
          : null,
      readiedAction: readiedAction,
      onChooseCombatAction: chooseCombatAction,
      sneakAttackUsedThisTurn: sneakAttackUsedThisTurn,
      onNewSneakAttackTurn: confirmNewSneakAttackTurn,
      onSteadyAim: character.levelInClass('Rogue') >= 3 ? useSteadyAim : null,
      onSelfRestoration:
          character.levelInClass('Monk') >= 10 && !selfRestorationUsedThisTurn
          ? useSelfRestoration
          : null,
      onFastHands: hasFastHands
          ? () => chooseCombatAction(asBonusAction: true, fastHands: true)
          : null,
      onCunningAction: character.levelInClass('Rogue') >= 2
          ? () => chooseCombatAction(asBonusAction: true)
          : null,
      onTriggerReadiedAction: triggerReadiedAction,
      combatInitiative: combatInitiative,
      onInitiativeRecorded: recordCombatInitiative,
      beforeInitiativeRecord: hasDarkOnesOwnLuck
          ? adjustInitiativeWithDarkLuck
          : null,
      rollD20: diceRoller.rollD20,
      onInitiativeRollStarted: () => setState(() {
        tacticalMindCheck = null;
        peerlessSkillRoll = null;
        darkLuckRoll = null;
      }),
      onTogglePinned: togglePinnedAction,
      onSavingThrowTap: handleSavingThrowTap,
      onResourceSpend: spendResource,
      onResourceManage: adjustResource,
    );
  }

  Widget buildSpellbookMode() {
    return SpellbookModeView(
      character: characterForPhysicalChecks,
      characterState: characterState,
      onSpellTap: handleActionTap,
      onManageSpell: manageSpell,
      onAddFromLibrary: addSpellFromLibrary,
      onCreateCustom: createCustomSpell,
    );
  }

  int? get pendingBardExpertise {
    for (final milestone in [2, 9]) {
      if (character.levelInClass('Bard') >= milestone &&
          !character.features.any(
            (feature) =>
                feature.id == 'whetstone:class:bard-expertise:$milestone',
          )) {
        return milestone;
      }
    }
    return null;
  }

  bool get pendingLoreProficiencies =>
      character.levelInClass('Bard') >= 3 &&
      character.subclasses['Bard'] == 'College of Lore' &&
      !character.features.any(
        (feature) => feature.id == 'whetstone:class:lore-proficiencies',
      );

  Future<void> chooseBardExpertise({bool loreBonus = false}) async {
    final milestone = loreBonus
        ? (pendingLoreProficiencies ? 3 : null)
        : pendingBardExpertise;
    if (milestone == null) return;
    final count = loreBonus ? 3 : 2;
    final eligible = loreBonus
        ? SkillProficiency.none
        : SkillProficiency.proficient;
    final granted = loreBonus
        ? SkillProficiency.proficient
        : SkillProficiency.expertise;
    final title = loreBonus
        ? 'Lore Bard · Bonus Proficiencies'
        : 'Bard Expertise · Level $milestone';
    final confirm = loreBonus
        ? 'Confirm three proficiencies'
        : 'Confirm two Expertise skills';
    final skills = standardSkills
        .where((skill) => character.proficiencyFor(skill) == eligible)
        .toList();
    final selected = <String>{};
    final choices = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loreBonus
                      ? 'Choose three skills in which you have no proficiency. Existing proficiency and Expertise are preserved. If an older save already includes this grant, review its proficiencies before making another choice.'
                      : 'Choose two skills in which you already have proficiency. Existing Expertise does not stack. If an older save already includes this grant, review its proficiencies before making another choice.',
                ),
                if (skills.length < count)
                  Text(
                    loreBonus
                        ? 'Three eligible untrained skills are required. Review your skill proficiencies first.'
                        : 'Two eligible proficient skills are required. Review your skill proficiencies first.',
                  ),
                for (final skill in skills)
                  CheckboxListTile(
                    title: Text(skill.name),
                    value: selected.contains(skill.id),
                    onChanged:
                        !selected.contains(skill.id) && selected.length == count
                        ? null
                        : (value) => update(() {
                            if (value == true) {
                              selected.add(skill.id);
                            } else {
                              selected.remove(skill.id);
                            }
                          }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.length == count
                  ? () => Navigator.pop(context, {...selected})
                  : null,
              child: Text(confirm),
            ),
          ],
        ),
      ),
    );
    if (!mounted ||
        choices == null ||
        choices.length != count ||
        (loreBonus
            ? !pendingLoreProficiencies
            : pendingBardExpertise != milestone) ||
        !choices.every(
          (id) =>
              character.proficiencyFor(
                standardSkills.singleWhere((skill) => skill.id == id),
              ) ==
              eligible,
        )) {
      return;
    }
    final names = standardSkills
        .where((skill) => choices.contains(skill.id))
        .map((skill) => skill.name)
        .join(', ');
    final updated = character.copyWith(
      skillProficiencies: {
        ...character.skillProficiencies,
        for (final id in choices) id: granted,
      },
      features: [
        ...character.features,
        Feature(
          id: loreBonus
              ? 'whetstone:class:lore-proficiencies'
              : 'whetstone:class:bard-expertise:$milestone',
          name: title,
          summary:
              '${loreBonus ? 'Proficiency' : 'Expertise'} applied to $names. The skill proficiencies have already been updated.',
        ),
      ],
    );
    setState(() => character = updated);
    widget.onCharacterChanged(updated);
    recordSessionEvent(
      SessionEventType.condition,
      loreBonus ? 'Lore Bard proficiencies chosen' : 'Bard Expertise chosen',
      detail: 'Level $milestone · $names',
    );
  }

  bool get pendingPrimalKnowledge =>
      character.levelInClass('Barbarian') >= 3 &&
      !character.features.any(
        (feature) => feature.id == 'whetstone:class:primal-knowledge-skill',
      );

  Future<void> choosePrimalKnowledgeSkill() async {
    if (!pendingPrimalKnowledge) return;
    final skills = standardSkills
        .where(
          (skill) =>
              BuiltInClass.barbarian.allowsSkill(skill.id) &&
              character.proficiencyFor(skill) == SkillProficiency.none,
        )
        .toList();
    final selected = await showDialog<Skill>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Primal Knowledge · Choose proficiency'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Choose one new skill proficiency from the Barbarian list. Existing proficiency and Expertise are preserved. If an older save already includes this grant, review its proficiencies before making another choice.',
            ),
          ),
          if (skills.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No eligible untrained skills remain. Review your proficiencies first.',
              ),
            ),
          for (final skill in skills)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, skill),
              child: Text(skill.name),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted ||
        selected == null ||
        !pendingPrimalKnowledge ||
        !BuiltInClass.barbarian.allowsSkill(selected.id) ||
        character.proficiencyFor(selected) != SkillProficiency.none) {
      return;
    }
    final updated = character.copyWith(
      skillProficiencies: {
        ...character.skillProficiencies,
        selected.id: SkillProficiency.proficient,
      },
      features: [
        ...character.features,
        Feature(
          id: 'whetstone:class:primal-knowledge-skill',
          name: 'Primal Knowledge · Skill proficiency',
          summary:
              '${selected.name} proficiency has already been applied. While raging, Primal Knowledge also allows Strength checks with Acrobatics, Intimidation, Perception, Stealth and Survival.',
        ),
      ],
    );
    setState(() => character = updated);
    widget.onCharacterChanged(updated);
    recordSessionEvent(
      SessionEventType.condition,
      'Primal Knowledge proficiency chosen',
      detail: selected.name,
    );
  }

  Future<void> chooseScholar() async {
    bool canChoose() =>
        mounted &&
        character.levelInClass('Wizard') >= 2 &&
        !character.features.any(
          (feature) =>
              feature.id == 'whetstone:class:scholar' ||
              feature.name.trim().toLowerCase() == 'scholar',
        );
    if (!canChoose()) return;
    const eligibleIds = {
      'arcana',
      'history',
      'investigation',
      'medicine',
      'nature',
      'religion',
    };
    final skills = standardSkills
        .where(
          (skill) =>
              eligibleIds.contains(skill.id) &&
              character.proficiencyFor(skill) == SkillProficiency.proficient,
        )
        .toList();
    final selected = await showDialog<Skill>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Scholar · Choose Expertise'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Choose one listed skill in which you already have proficiency. Scholar grants Expertise; it does not grant a new skill proficiency.',
            ),
          ),
          if (skills.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No eligible proficient skill without Expertise. Review your skill proficiencies before choosing.',
              ),
            ),
          for (final skill in skills)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, skill),
              child: Text('Expertise · ${skill.name}'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null ||
        !canChoose() ||
        character.proficiencyFor(selected) != SkillProficiency.proficient) {
      return;
    }
    final updated = character.copyWith(
      skillProficiencies: {
        ...character.skillProficiencies,
        selected.id: SkillProficiency.expertise,
      },
      features: [
        ...character.features,
        Feature(
          id: 'whetstone:class:scholar',
          name: 'Scholar',
          summary:
              'Expertise in ${selected.name}. The skill proficiency has already been updated.',
        ),
      ],
    );
    setState(() => character = updated);
    widget.onCharacterChanged(updated);
    recordSessionEvent(
      SessionEventType.condition,
      'Scholar chosen',
      detail: 'Expertise in ${selected.name}.',
    );
  }

  Future<void> chooseMetamagic() async {
    final capacity = Metamagic.capacity(character.levelInClass('Sorcerer'));
    if (capacity == 0) return;
    final chosen = {...character.metamagicOptions};
    final result = await showDialog<Set<Metamagic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Known Metamagic'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose up to $capacity options. Recovery corrections are allowed here; confirm level-up replacements at the table.',
                  ),
                  for (final option in Metamagic.values)
                    CheckboxListTile(
                      key: ValueKey('metamagic-${option.name}'),
                      title: Text(option.label),
                      subtitle: Text(
                        '${option.pointCost} Sorcery Points · ${option.usageHint}',
                      ),
                      value: chosen.contains(option),
                      onChanged:
                          chosen.contains(option) || chosen.length < capacity
                          ? (value) => updateDialog(() {
                              if (value == true) {
                                chosen.add(option);
                              } else {
                                chosen.remove(option);
                              }
                            })
                          : null,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: chosen.length <= capacity
                  ? () => Navigator.pop(context, chosen)
                  : null,
              child: const Text('Save Metamagic'),
            ),
          ],
        ),
      ),
    );
    if (!mounted ||
        result == null ||
        result.length >
            Metamagic.capacity(character.levelInClass('Sorcerer'))) {
      return;
    }
    setState(() => character = character.copyWith(metamagicOptions: result));
    widget.onCharacterChanged(character);
    publishSession();
  }

  Widget buildProfileMode() {
    return ProfileModeView(
      character: character,
      characterState: characterState,
      onMetamagic: Metamagic.capacity(character.levelInClass('Sorcerer')) > 0
          ? chooseMetamagic
          : null,
      onFeatureTap: handleActionTap,
      onManageFeature: manageFeature,
      onAddFeature: addFeature,
      onPrimalKnowledge: pendingPrimalKnowledge
          ? choosePrimalKnowledgeSkill
          : null,
      onLoreProficiencies: pendingLoreProficiencies
          ? () => chooseBardExpertise(loreBonus: true)
          : null,
      onBardExpertise: pendingBardExpertise == null
          ? null
          : chooseBardExpertise,
      onScholar:
          character.levelInClass('Wizard') >= 2 &&
              !character.features.any(
                (feature) =>
                    feature.id == 'whetstone:class:scholar' ||
                    feature.name.trim().toLowerCase() == 'scholar',
              )
          ? chooseScholar
          : null,
      onAdvanceCharacter: advanceCharacter,
      onAbilityLongPress: handleAbilityLongPress,
      onExitCharacter: requestExitCharacter,
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: allowExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          requestExitCharacter();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,

          title: Text(switch (currentMode) {
            CharacterMode.exploration => character.name,
            CharacterMode.combat => 'Combat',
            CharacterMode.spellbook => 'Spellbook',
            CharacterMode.profile => 'Profile',
          }),

          actions: [
            if (character.levelInClass('Druid') >= 2)
              PopupMenuButton<String>(
                tooltip: 'Druid features',
                icon: const Icon(Icons.eco_outlined),
                onSelected: (choice) {
                  switch (choice) {
                    case 'companion':
                      summonWildCompanion();
                    case 'dismiss':
                      updateCharacterState(
                        characterState.copyWith(clearWildCompanion: true),
                      );
                    case 'lands-aid':
                      useLandsAid();
                    case 'land':
                      chooseDruidLand();
                    case 'sanctuary':
                      useNaturesSanctuary();
                    case 'move-sanctuary':
                      moveNaturesSanctuary();
                    case 'shape-pool':
                      if (wildShapePool case final pool?) adjustResource(pool);
                    case 'shape-form':
                      showWildShapeForm();
                    case 'shape-time':
                      advanceWildShapeTime();
                    case 'freedom-escape':
                      escapeWithFreedomOfMovement();
                    case 'nature-magician':
                      useNatureMagician();
                    case 'primal-strike':
                      usePrimalStrike();
                  }
                },
                itemBuilder: (context) => [
                  if (characterState.activeConditions.contains(
                        freedomOfMovementCondition,
                      ) &&
                      characterState.activeConditions.any(
                        const {'Grappled', 'Restrained'}.contains,
                      ))
                    const PopupMenuItem(
                      value: 'freedom-escape',
                      child: Text('Escape nonmagical restraints'),
                    ),
                  if (characterState.activeConditions.contains(
                    naturesSanctuaryCondition,
                  ))
                    PopupMenuItem(
                      value: 'move-sanctuary',
                      enabled: canMoveNaturesSanctuary,
                      child: const Text('Move Nature’s Sanctuary'),
                    ),
                  const PopupMenuItem(
                    value: 'companion',
                    child: Text('Wild Companion'),
                  ),
                  if (characterState.wildCompanion case final familiar?)
                    PopupMenuItem(
                      value: 'dismiss',
                      child: Text('Dismiss $familiar'),
                    ),
                  if (landDruidLevel >= 3)
                    const PopupMenuItem(
                      value: 'lands-aid',
                      child: Text('Land’s Aid'),
                    ),
                  if (landDruidLevel >= 3 && characterState.druidLand == null)
                    const PopupMenuItem(
                      value: 'land',
                      child: Text('Choose terrain'),
                    ),
                  if (landDruidLevel >= 14 && characterState.druidLand != null)
                    const PopupMenuItem(
                      value: 'sanctuary',
                      child: Text('Nature’s Sanctuary'),
                    ),
                  if (wildShapePool != null)
                    const PopupMenuItem(
                      value: 'shape-pool',
                      child: Text('Manage Wild Shape'),
                    ),
                  if (characterState.wildShapeForm != null)
                    const PopupMenuItem(
                      value: 'shape-form',
                      child: Text('View Wild Shape form'),
                    ),
                  if (characterState.wildShapeForm != null)
                    const PopupMenuItem(
                      value: 'shape-time',
                      child: Text('Advance Wild Shape time'),
                    ),
                  if (canUseNatureMagician)
                    const PopupMenuItem(
                      value: 'nature-magician',
                      child: Text('Nature Magician'),
                    ),
                  if (canUsePrimalStrike)
                    const PopupMenuItem(
                      value: 'primal-strike',
                      child: Text('Primal Strike'),
                    ),
                ],
              ),
            if (characterState.wildShapeForm case final form?)
              IconButton(
                tooltip: 'Wild Shape: $form · Revert',
                icon: const Icon(Icons.pets),
                onPressed: revertWildShape,
              )
            else if (character.resources
                    .where((resource) => resource.id == wildShapeResourceId)
                    .firstOrNull
                case final wildShape?)
              IconButton(
                tooltip: 'Wild Shape',
                icon: const Icon(Icons.pets_outlined),
                onPressed: () => spendResource(wildShape),
              ),
            if (activeConcentrationSpell case final spell?)
              IconButton(
                tooltip: 'Concentration: ${spell.name}',
                icon: const Icon(Icons.center_focus_strong),
                onPressed: () => showConcentration(spell),
              ),
            PopupMenuButton<D20Mode>(
              tooltip: 'Next d20 roll: ${nextRollMode.label}',
              icon: Icon(
                nextRollMode == D20Mode.normal
                    ? Icons.casino_outlined
                    : Icons.casino,
              ),
              initialValue: nextRollMode,
              onSelected: (mode) => setState(() => nextRollMode = mode),
              itemBuilder: (context) => [
                for (final mode in D20Mode.values)
                  PopupMenuItem(value: mode, child: Text(mode.label)),
              ],
            ),
            IconButton(
              key: const ValueKey('open-session-timeline'),
              tooltip: 'Session Timeline',
              onPressed: openSessionTimeline,
              icon: const Icon(Icons.history),
            ),
            if (currentMode == CharacterMode.combat)
              TextButton(onPressed: endCombat, child: const Text('End Combat')),
          ],
        ),

        body: Stack(
          children: [
            Positioned.fill(
              child: switch (currentMode) {
                CharacterMode.exploration => buildExplorationMode(),
                CharacterMode.combat => buildCombatMode(),
                CharacterMode.spellbook => buildSpellbookMode(),
                CharacterMode.profile => buildProfileMode(),
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: RollNoticeStack(notices: rollNotices),
            ),
          ],
        ),
        bottomNavigationBar: currentMode == CharacterMode.combat
            ? null
            : NavigationBar(
                selectedIndex: selectedDestinationIndex,
                onDestinationSelected: selectDestination,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.explore_outlined),
                    selectedIcon: Icon(Icons.explore),
                    label: 'Explore',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: 'Spellbook',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
      ),
    );
  }
}
