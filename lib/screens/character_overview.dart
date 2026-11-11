import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../modes/combat_mode.dart';
import '../modes/exploration_mode.dart';
import '../modes/profile_mode.dart';
import '../modes/spellbook_mode.dart';
import '../models/ability.dart';
import '../widgets/stat_edit_dialog.dart';
import '../models/authored_class.dart';
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
  late int combatRound;
  int? combatInitiative;
  late Set<CombatActionCost> usedCombatActions;
  late final DiceRoller diceRoller;
  String? pendingCriticalActionKey;
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
    diceRoller = widget.diceRoller ?? RandomDiceRoller();
    characterState = widget.initialSession.characterState;
    combatRound = widget.initialSession.isInCombat
        ? widget.initialSession.combatRound
        : 1;
    if (widget.initialSession.isInCombat) {
      combatInitiative = widget.initialSession.combatInitiative;
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
        combatRound: combatRound,
        combatInitiative: combatInitiative,
        usedCombatActions: {...usedCombatActions},
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
    final updated = authored == null
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
    if (!mounted || updated == null) return;

    final classResourceIds =
        authored?.resourcesAt(2).map((resource) => resource.id).toSet() ??
        const <String>{};
    final previousResources = {
      for (final resource in editableCharacter.resources) resource.id: resource,
    };
    final resourceValues = <String, int>{};
    for (final resource in updated.resources) {
      final previous = previousResources[resource.id];
      final remaining = characterState.resourceValues[resource.id];
      if (classResourceIds.contains(resource.id)) {
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
          if (spell.repeatableEffect && spell.damageFormula != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'repeat'),
              child: const Text('Roll Repeat Effect'),
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

  void resolveConcentrationSave(int dc) {
    final save = character.savingThrowFor(Ability.constitution);
    final roll = rollCheck(
      'Concentration Save',
      save.modifier,
      describe: (roll) => roll.total >= dc
          ? 'DC $dc · Concentration maintained'
          : 'DC $dc · Concentration ended',
    );
    if (roll.total < dc) {
      updateCharacterState(characterState.copyWith(clearConcentration: true));
    }
  }

  Future<void> manageSpell(Spell spell) async {
    HapticFeedback.mediumImpact();
    final isPinned = characterState.pinnedActionKeys.contains(spell.actionKey);
    final canPin = spell.isAvailableInCombat || isPinned;
    final isConcentrating = characterState.concentrationSpellId == spell.id;
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
              leading: const Icon(Icons.center_focus_strong),
              title: Text(
                isConcentrating ? 'End Concentration' : 'Track Concentration',
              ),
              onTap: isConcentrating || characterState.canConcentrate
                  ? () => Navigator.pop(context, 'concentration')
                  : null,
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
    final updatedState = characterState.copyWith(
      clearConcentration: !spells.any(
        (spell) => spell.id == characterState.concentrationSpellId,
      ),
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

  void handleSavingThrowTap(SavingThrowCheck check) {
    rollCheck('${check.ability.label} Save', check.modifier);
  }

  void handleActionTap(CharacterAction action) {
    HapticFeedback.selectionClick();
    final modifier = character.attackModifierFor(action);
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
      builder: (context) => ActionDetailsDialog(
        action: action,
        spellSaveDc: action is Spell ? character.spellSaveDc(action) : null,
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
        onCast:
            action is Spell &&
                (action.concentration || action.rollEffectOnCast) &&
                characterState.currentHp > 0
            ? () {
                Navigator.pop(context);
                castSpell(action);
              }
            : null,
      ),
    );
  }

  void trackSpellAction(Spell spell) {
    if (currentMode != CharacterMode.combat) return;
    final cost = switch (spell.castingTime?.trim().toLowerCase()) {
      'action' || '1 action' => CombatActionCost.action,
      'bonus action' || '1 bonus action' => CombatActionCost.bonusAction,
      'reaction' || '1 reaction' => CombatActionCost.reaction,
      _ => null,
    };
    if (cost != null && !usedCombatActions.contains(cost)) {
      setCombatActionUsed(cost, true);
    }
  }

  void castSpell(Spell spell) {
    if (characterState.currentHp <= 0) return;
    if (character.attackModifierFor(spell) != null) {
      rollAttack(spell);
    } else if (spell.rollEffectOnCast && spell.damageFormula != null) {
      rollDamage(spell, castingSpell: true);
    } else if (spell.concentration) {
      startSpellConcentration(spell);
      trackSpellAction(spell);
    }
  }

  void startSpellConcentration(Spell spell, {int? slotLevel}) {
    if (!characterState.canConcentrate) return;
    updateCharacterState(
      characterState
          .copyWith(clearConcentration: true)
          .copyWith(
            concentrationSpellId: spell.id,
            concentrationSlotLevel: slotLevel,
          ),
    );
  }

  void rollAttack(CharacterAction action) {
    final modifier = character.attackModifierFor(action);
    if (modifier == null) return;
    if (action is Spell && characterState.currentHp > 0) {
      if (action.concentration) startSpellConcentration(action);
      trackSpellAction(action);
    }
    final roll = rollCheck('${action.name} Attack', modifier);
    pendingCriticalActionKey =
        roll.isNaturalTwenty &&
            DiceExpression.tryParse(character.damageFormulaFor(action) ?? '') !=
                null
        ? action.actionKey
        : null;
  }

  Future<void> rollDamage(
    CharacterAction action, {
    bool repeatingEffect = false,
    bool castingSpell = false,
  }) async {
    int? slotLevel = repeatingEffect
        ? characterState.concentrationSlotLevel
        : null;
    if (action case Spell(
      additionalDicePerSlotLevel: > 0,
      level: > 0 && < 9,
    ) when !repeatingEffect) {
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
    if (action case Spell(
      halfDamageOnSave: true,
      savingThrowAbility: final ability?,
    )) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(action.name),
          content: Text('Did the target succeed on its ${ability.label} save?'),
          actions: [
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
      halfDamage = result;
    }
    final baseExpression = DiceExpression.tryParse(
      character.damageFormulaFor(action, slotLevel: slotLevel) ?? '',
    );
    if (baseExpression == null) return;
    if (repeatingEffect && characterState.concentrationSpellId != action.id) {
      return;
    }
    if (castingSpell && characterState.currentHp <= 0) return;
    final critical =
        !castingSpell &&
        !repeatingEffect &&
        pendingCriticalActionKey == action.actionKey;
    if (castingSpell && action is Spell) {
      trackSpellAction(action);
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
    if (critical) pendingCriticalActionKey = null;
    final expression = critical
        ? baseExpression.withCriticalHitDice()
        : baseExpression;
    HapticFeedback.selectionClick();
    final roll = expression.roll(action.name, diceRoller);
    final total = halfDamage
        ? (roll.total < 0 ? 0 : roll.total ~/ 2)
        : roll.total;
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
          '${halfDamage ? ' → $total after save' : ''}',
      total: total,
      detail: action.damageType == null
          ? 'Damage'
          : '${action.damageType} damage',
      tone: RollNoticeTone.damage,
    );
  }

  void rollDeathSave() {
    if (!characterState.canRollDeathSave) return;
    final roll = rollCheck(
      'Death Save',
      0,
      useSelectedMode: false,
      describe: (roll) {
        final updated = characterState.applyDeathSave(roll.naturalRoll);
        return switch (roll.naturalRoll) {
          20 => 'Natural 20 · Recovered 1 HP',
          1 when updated.deathSaveFailures == 3 => 'Natural 1 · Dead',
          1 => 'Natural 1 · Two failures',
          _ when updated.deathSaveFailures == 3 => 'Dead',
          _ when updated.deathSaveSuccesses == 3 => 'Stable',
          >= 10 => 'Success · ${updated.deathSaveSuccesses} of 3',
          _ => 'Failure · ${updated.deathSaveFailures} of 3',
        };
      },
    );
    updateCharacterState(characterState.applyDeathSave(roll.naturalRoll));
  }

  CheckRoll rollCheck(
    String label,
    int modifier, {
    bool useSelectedMode = true,
    String Function(CheckRoll)? describe,
  }) {
    final mode = useSelectedMode ? nextRollMode : D20Mode.normal;
    if (mode != D20Mode.normal) {
      setState(() => nextRollMode = D20Mode.normal);
    }
    final first = diceRoller.rollD20();
    final second = mode == D20Mode.normal ? null : diceRoller.rollD20();
    final roll = CheckRoll(
      label: label,
      naturalRoll: mode.select(first, second),
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
      calculation: [
        if (second != null) '${mode.label}: $first, $second →',
        'd20 ${roll.naturalRoll} $operator ${modifier.abs()} = ${roll.total}',
      ].join(' '),
      total: roll.total,
      detail:
          describe?.call(roll) ??
          (roll.isNaturalTwenty
              ? 'Natural 20'
              : roll.isNaturalOne
              ? 'Natural 1'
              : null),
      tone: roll.isNaturalTwenty
          ? RollNoticeTone.criticalSuccess
          : roll.isNaturalOne
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
    final preview = RestPlan.forCharacter(
      type: restType,
      character: character,
      currentState: characterState,
    );
    final canSpend =
        restType == RestType.shortRest &&
        characterState.currentHp > 0 &&
        characterState.currentHp < characterState.maxHp;
    final count = await showDialog<int>(
      context: context,
      builder: (context) => RestConfirmationDialog(
        plan: preview,
        availableHitDice: canSpend
            ? RestPlan.availableHitDice(character, characterState)
            : 0,
        hitDie: RestPlan.hitDieFor(character),
      ),
    );
    if (!mounted || count == null) return;

    final plan = RestPlan.forCharacter(
      type: restType,
      character: character,
      currentState: characterState,
    ).spendHitDice(character: character, count: count, roller: diceRoller);
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
      combatRound = 1;
      combatInitiative = null;
      usedCombatActions.clear();
    });
    recordSessionEvent(SessionEventType.combat, 'Combat began');
  }

  void recordCombatInitiative(int total) {
    if (currentMode != CharacterMode.combat) return;
    setState(() => combatInitiative = total);
    recordSessionEvent(
      SessionEventType.combat,
      'Initiative recorded',
      detail: '$total',
    );
  }

  void advanceCombatTurn() {
    pendingCriticalActionKey = null;
    setState(() {
      nextRollMode = D20Mode.normal;
      combatRound++;
      usedCombatActions.clear();
    });
    final updated = characterState
        .advanceConcentrationTurn()
        .advanceConditionTurn();
    if (!identical(updated, characterState)) updateCharacterState(updated);
    recordSessionEvent(SessionEventType.combat, 'Round $combatRound began');
  }

  void setCombatActionUsed(CombatActionCost cost, bool used) {
    setState(() {
      if (used) {
        usedCombatActions.add(cost);
      } else {
        usedCombatActions.remove(cost);
      }
    });
    publishSession();
  }

  void endCombat() {
    pendingCriticalActionKey = null;
    setState(() {
      currentMode = CharacterMode.exploration;
      combatRound = 1;
      combatInitiative = null;
      usedCombatActions.clear();
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
      onDamageTaken: promptConcentrationAfterDamage,
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
      onDamageTaken: promptConcentrationAfterDamage,
      onActionTap: handleActionTap,
      onActionDetails: showActionDetails,
      onAttackRoll: rollAttack,
      onDamageRoll: rollDamage,
      onDeathSaveRoll: rollDeathSave,
      combatRound: combatRound,
      usedCombatActions: usedCombatActions,
      onCombatActionChanged: setCombatActionUsed,
      onNextTurn: advanceCombatTurn,
      combatInitiative: combatInitiative,
      onInitiativeRecorded: recordCombatInitiative,
      rollD20: diceRoller.rollD20,
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
