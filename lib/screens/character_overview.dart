import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../modes/combat_mode.dart';
import '../modes/exploration_mode.dart';
import '../modes/profile_mode.dart';
import '../modes/spellbook_mode.dart';
import '../models/ability.dart';
import '../models/character.dart';
import '../models/character_action.dart';
import '../models/check_roll.dart';
import '../models/content_pack.dart';
import '../models/character_resource.dart';
import '../models/character_session.dart';
import '../models/character_mode.dart';
import '../models/character_state.dart';
import '../models/feature.dart';
import '../models/inventory_item.dart';
import '../models/journal_entry.dart';
import '../models/library_content_copy.dart';
import '../models/rest.dart';
import '../models/roll_notice.dart';
import '../models/skill.dart';
import '../models/spell.dart';
import '../models/session_event.dart';
import '../services/session_event_recorder.dart';

import '../widgets/dialogue_action_button.dart';
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
  late final DiceRoller diceRoller;
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
    diceRoller = widget.diceRoller ?? RandomDiceRoller();
    characterState = widget.initialSession.characterState;
    inventory = [...widget.initialSession.inventory];
    archivedInventory = [...widget.initialSession.archivedInventory];
    timeline = [...widget.initialSession.timeline];
    currentMode = widget.initialSession.isInCombat
        ? CharacterMode.combat
        : CharacterMode.exploration;
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
        characterState: characterState,
        inventory: [...inventory],
        archivedInventory: [...archivedInventory],
        isInCombat: currentMode == CharacterMode.combat,
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

  void handleSkillTap(SkillCheck check) {
    rollCheck(check.skill.name, check.modifier);
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
    final updated = await Navigator.push<Character>(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterAdvancement(
          character: editableCharacter,
          contentPacks: widget.contentPacks,
        ),
      ),
    );
    if (!mounted || updated == null) return;

    final resourceValues = {
      for (final resource in updated.resources)
        resource.id: characterState.resourceValues.containsKey(resource.id)
            ? (characterState.resourceValues[resource.id]! > resource.maximum
                  ? resource.maximum
                  : characterState.resourceValues[resource.id]!)
            : resource.maximum,
    };
    final currentHp = characterState.currentHp > updated.maxHp
        ? updated.maxHp
        : characterState.currentHp;
    final updatedState = characterState.copyWith(
      currentHp: currentHp,
      maxHp: updated.maxHp,
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

  Future<void> manageSpell(Spell spell) async {
    HapticFeedback.mediumImpact();
    final isPinned = characterState.pinnedActionKeys.contains(spell.actionKey);
    final canPin = spell.isAvailableInCombat || isPinned;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
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
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove Spell'),
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
        await editSpell(spell);
      case 'pin':
        togglePinnedAction(spell);
      case 'remove':
        await removeSpell(spell);
    }
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

  void saveSpellChanges(List<Spell> spells, Set<String> pinnedActionKeys) {
    final updatedCharacter = character.copyWith(
      spells: spells,
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

  void handleSavingThrowTap(SavingThrowCheck check) {
    rollCheck('${check.ability.label} Save', check.modifier);
  }

  void handleActionTap(CharacterAction action) {
    HapticFeedback.selectionClick();
    final modifier = action.rollModifier;
    if (modifier == null) {
      showActionDetails(action);
      return;
    }
    rollAttack(action);
  }

  void showActionDetails(CharacterAction action) {
    HapticFeedback.selectionClick();
    showDialog<void>(
      context: context,
      builder: (context) => ActionDetailsDialog(action: action),
    );
  }

  void rollAttack(CharacterAction action) {
    final modifier = action.rollModifier;
    if (modifier == null) return;
    rollCheck('${action.name} Attack', modifier);
  }

  void rollDamage(CharacterAction action) {
    final expression = DiceExpression.tryParse(action.damageFormula ?? '');
    if (expression == null) return;
    HapticFeedback.selectionClick();
    final roll = expression.roll(action.name, diceRoller);
    final dice = roll.dice.join(' + ');
    final modifier = expression.modifier;
    final modifierText = modifier == 0
        ? ''
        : modifier > 0
        ? ' + $modifier'
        : ' - ${modifier.abs()}';
    addRollNotice(
      title: '${action.name} Damage',
      calculation: '${expression.notation}: $dice$modifierText = ${roll.total}',
      total: roll.total,
      detail: action.damageType == null
          ? 'Damage'
          : '${action.damageType} damage',
      tone: RollNoticeTone.damage,
    );
  }

  void rollCheck(String label, int modifier) {
    final roll = CheckRoll(
      label: label,
      naturalRoll: diceRoller.rollD20(),
      modifier: modifier,
    );
    if (roll.isNaturalTwenty) {
      HapticFeedback.heavyImpact();
    } else if (roll.isNaturalOne) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    final operator = modifier >= 0 ? '+' : '-';
    addRollNotice(
      title: label,
      calculation:
          'd20 ${roll.naturalRoll} $operator ${modifier.abs()} = ${roll.total}',
      total: roll.total,
      detail: roll.isNaturalTwenty
          ? 'Natural 20'
          : roll.isNaturalOne
          ? 'Natural 1'
          : null,
      tone: roll.isNaturalTwenty
          ? RollNoticeTone.criticalSuccess
          : roll.isNaturalOne
          ? RollNoticeTone.criticalFailure
          : RollNoticeTone.normal,
    );
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
      builder: (context) =>
          ResourceAdjustDialog(resource: resource, currentValue: currentValue),
    );

    if (!mounted || adjustment == null) {
      return;
    }

    final updatedValue = switch (adjustment) {
      ResourceAdjustment.spend => currentValue > 0 ? currentValue - 1 : 0,
      ResourceAdjustment.restore =>
        currentValue < resource.maximum ? currentValue + 1 : resource.maximum,
      ResourceAdjustment.refill => resource.maximum,
    };
    final resourceValues = {...characterState.resourceValues};
    resourceValues[resource.id] = updatedValue;

    updateCharacterState(
      characterState.copyWith(resourceValues: resourceValues),
    );
    HapticFeedback.selectionClick();
  }

  void spendResource(CharacterResource resource) {
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

    final resourceValues = {...characterState.resourceValues};
    resourceValues[resource.id] = currentValue - 1;
    updateCharacterState(
      characterState.copyWith(resourceValues: resourceValues),
    );
    HapticFeedback.selectionClick();
  }

  Future<void> takeRest(RestType restType) async {
    final plan = RestPlan.forCharacter(
      type: restType,
      character: character,
      currentState: characterState,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => RestConfirmationDialog(plan: plan),
    );

    if (!mounted || confirmed != true) {
      return;
    }

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
  }

  // ------------------------------------------------------------
  // CHARACTER MODES
  // ------------------------------------------------------------

  void beginCombat() {
    setState(() {
      currentMode = CharacterMode.combat;
    });
    recordSessionEvent(SessionEventType.combat, 'Combat began');
  }

  void endCombat() {
    setState(() {
      currentMode = CharacterMode.exploration;
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

  Widget buildExplorationMode() {
    return ExplorationModeView(
      character: character,
      characterState: characterState,
      onCharacterStateChanged: updateCharacterState,
      inventory: inventory,
      onBeginCombat: showBeginCombatPrompt,
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
      character: character,
      characterState: characterState,
      onCharacterStateChanged: updateCharacterState,
      onActionTap: handleActionTap,
      onActionDetails: showActionDetails,
      onAttackRoll: rollAttack,
      onDamageRoll: rollDamage,
      onTogglePinned: togglePinnedAction,
      onSavingThrowTap: handleSavingThrowTap,
      onResourceSpend: spendResource,
      onResourceManage: adjustResource,
    );
  }

  Widget buildSpellbookMode() {
    return SpellbookModeView(
      character: character,
      characterState: characterState,
      onSpellTap: handleActionTap,
      onManageSpell: manageSpell,
      onAddFromLibrary: addSpellFromLibrary,
      onCreateCustom: createCustomSpell,
    );
  }

  Widget buildProfileMode() {
    return ProfileModeView(
      character: character,
      characterState: characterState,
      onFeatureTap: handleActionTap,
      onManageFeature: manageFeature,
      onAddFeature: addFeature,
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
