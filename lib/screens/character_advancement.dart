import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/built_in_class.dart';
import '../models/ability.dart';
import '../models/character.dart';
import '../models/character_action.dart';
import '../models/character_resource.dart';
import '../models/content_pack.dart';
import '../models/feature.dart';
import '../models/inventory_item.dart';
import '../models/library_content_copy.dart';
import '../models/spell.dart';
import '../models/spell_slots.dart';
import '../models/weapon.dart';
import '../widgets/character_resource_editor_dialog.dart';
import '../widgets/feature_editor_dialog.dart';
import '../widgets/spell_editor_dialog.dart';
import '../widgets/inventory_item_editor_dialog.dart';
import '../widgets/weapon_editor_dialog.dart';
import '../widgets/content_add_buttons.dart';
import '../widgets/library_content_picker.dart';

class CharacterAdvancement extends StatefulWidget {
  final Character character;
  final List<ContentPack> contentPacks;

  const CharacterAdvancement({
    super.key,
    required this.character,
    this.contentPacks = const [],
  });

  @override
  State<CharacterAdvancement> createState() => _CharacterAdvancementState();
}

class _CharacterAdvancementState extends State<CharacterAdvancement> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController levelController;
  late final TextEditingController maxHpController;
  late final TextEditingController proficiencyController;
  late final Map<BuiltInClass, TextEditingController> additionalClasses;
  late final List<Spell> spells;
  late final List<Weapon> weapons;
  late final List<CharacterResource> resources;
  late final List<InventoryItem> inventory;
  late final List<Feature> features;
  late final Set<String> pinnedActionKeys;
  final abilityIncreases = <Ability, int>{};
  late final Map<String, String> subclasses;
  PrimalOrder? primalOrder;
  DivineOrder? divineOrder;
  ElementalFury? elementalFury;
  BlessedStrikes? blessedStrikes;
  bool applyDraconicHpAdjustment = true;

  int? get nextDraconicHpBonus {
    final level = int.tryParse(levelController.text) ?? widget.character.level;
    final candidate = widget.character.copyWith(
      level: level,
      additionalClassLevels: classAllocation,
      subclasses: subclasses,
    );
    final target = candidate.hasDraconicResilience
        ? candidate.levelInClass('Sorcerer')
        : 0;
    if (widget.character.draconicHpBonus != null ||
        (!widget.character.hasDraconicResilience && target > 0)) {
      return target;
    }
    return null;
  }

  int get draconicHpAdjustment => nextDraconicHpBonus == null
      ? 0
      : nextDraconicHpBonus! - (widget.character.draconicHpBonus ?? 0);

  @override
  void initState() {
    super.initState();
    levelController = TextEditingController(text: '${widget.character.level}');
    maxHpController = TextEditingController(text: '${widget.character.maxHp}');
    proficiencyController = TextEditingController(
      text: '${widget.character.proficiencyBonus}',
    );
    final primary = BuiltInClass.named(widget.character.characterClass);
    additionalClasses = {
      if (primary != null)
        for (final entry in BuiltInClass.values)
          if (entry != primary)
            entry: TextEditingController(
              text:
                  '${widget.character.additionalClassLevels[entry.label] ?? 0}',
            ),
    };
    spells = [...widget.character.spells];
    subclasses = {...widget.character.subclasses};
    primalOrder = widget.character.primalOrder;
    divineOrder = widget.character.divineOrder;
    elementalFury = widget.character.elementalFury;
    blessedStrikes = widget.character.blessedStrikes;
    weapons = [...widget.character.weapons];
    resources = [...widget.character.resources];
    inventory = [...widget.character.initialInventory];
    features = [...widget.character.features];
    pinnedActionKeys = {...widget.character.initiallyPinnedActionKeys};
  }

  @override
  void dispose() {
    levelController.dispose();
    maxHpController.dispose();
    proficiencyController.dispose();
    for (final controller in additionalClasses.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? numberBetween(String? value, int minimum, int maximum) {
    final number = int.tryParse(value ?? '');
    return number == null || number < minimum || number > maximum
        ? '$minimum–$maximum'
        : null;
  }

  Map<String, int> get classAllocation => {
    for (final entry in additionalClasses.entries)
      if ((int.tryParse(entry.value.text) ?? 0) > 0)
        entry.key.label: int.parse(entry.value.text),
  };

  int druidLevelAt(int level, Map<String, int> allocation) =>
      BuiltInClass.named(widget.character.characterClass) == BuiltInClass.druid
      ? level - allocation.values.fold<int>(0, (sum, count) => sum + count)
      : allocation['Druid'] ?? 0;

  int clericLevelAt(int level, Map<String, int> allocation) =>
      BuiltInClass.named(widget.character.characterClass) == BuiltInClass.cleric
      ? level - allocation.values.fold<int>(0, (sum, count) => sum + count)
      : allocation['Cleric'] ?? 0;

  Iterable<BuiltInClass> eligibleSubclassClasses(
    int level,
    Map<String, int> allocation,
  ) sync* {
    final primary = BuiltInClass.named(widget.character.characterClass);
    final primaryLevel =
        level - allocation.values.fold<int>(0, (sum, count) => sum + count);
    if (primary != null && primaryLevel >= 3) yield primary;
    for (final entry in allocation.entries) {
      if (entry.value >= 3) yield BuiltInClass.named(entry.key)!;
    }
  }

  int abilityImprovementCount(int level, Map<String, int> allocation) {
    final primary = BuiltInClass.named(widget.character.characterClass);
    if (primary == null || level <= widget.character.level || level > 20) {
      return 0;
    }
    final primaryLevel =
        level - allocation.values.fold<int>(0, (sum, value) => sum + value);
    if (primaryLevel < 1) return 0;
    var count = 0;
    for (final entry in {primary.label: primaryLevel, ...allocation}.entries) {
      final previous = widget.character.levelInClass(entry.key);
      final builtIn = BuiltInClass.named(entry.key)!;
      count += builtIn.abilityImprovementLevels
          .where(
            (milestone) => milestone > previous && milestone <= entry.value,
          )
          .length;
    }
    return count;
  }

  int get assignedAbilityPoints =>
      abilityIncreases.values.fold<int>(0, (sum, value) => sum + value);

  int improvedScore(Ability ability) =>
      widget.character.scoreFor(ability) + (abilityIncreases[ability] ?? 0);

  bool get grantsBodyAndMind =>
      reachesCapstone('Monk', 'whetstone:class:body-and-mind');

  bool get grantsPrimalChampion =>
      reachesCapstone('Barbarian', 'whetstone:class:primal-champion');

  bool reachesCapstone(String className, String marker) {
    if (widget.character.features.any((feature) => feature.id == marker)) {
      return false;
    }
    final target = int.tryParse(levelController.text) ?? 0;
    if (target > 20 || widget.character.levelInClass(className) >= 20) {
      return false;
    }
    final classLevel = widget.character.characterClass == className
        ? target -
              classAllocation.values.fold<int>(0, (sum, value) => sum + value)
        : classAllocation[className] ?? 0;
    return classLevel >= 20;
  }

  int finalScore(Ability ability) {
    final score = improvedScore(ability);
    final granted =
        (grantsBodyAndMind &&
            {Ability.dexterity, Ability.wisdom}.contains(ability)) ||
        (grantsPrimalChampion &&
            {Ability.strength, Ability.constitution}.contains(ability));
    if (!granted || score >= 25) {
      return score;
    }
    return (score + 4).clamp(0, 25);
  }

  int modifierChange(Ability ability) =>
      ((finalScore(ability) - 10) / 2).floor() -
      widget.character.abilityModifierFor(ability);

  Future<void> chooseAbilityImprovement() async {
    final level = int.tryParse(levelController.text) ?? 0;
    if (assignedAbilityPoints >=
        2 * abilityImprovementCount(level, classAllocation)) {
      showProgressionMessage(
        'Enter a level that grants another Ability Score Improvement.',
      );
      return;
    }
    Ability? first;
    Ability? second;
    final picks = await showDialog<(Ability, Ability)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ability Score Improvement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final isFirst in [true, false])
                DropdownButtonFormField<Ability>(
                  decoration: InputDecoration(
                    labelText: isFirst ? 'First +1' : 'Second +1',
                  ),
                  items: [
                    for (final ability in Ability.values)
                      if (improvedScore(ability) < 20)
                        DropdownMenuItem(
                          value: ability,
                          child: Text(
                            '${ability.label} (${improvedScore(ability)})',
                          ),
                        ),
                  ],
                  onChanged: (ability) => setDialogState(() {
                    if (isFirst) {
                      first = ability;
                    } else {
                      second = ability;
                    }
                  }),
                ),
              if (first != null &&
                  first == second &&
                  improvedScore(first!) > 18)
                const Text('An ability score cannot exceed 20.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  first != null &&
                      second != null &&
                      (first != second || improvedScore(first!) <= 18)
                  ? () => Navigator.pop(context, (first!, second!))
                  : null,
              child: const Text('Apply Ability Increase'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || picks == null) return;
    setState(() {
      for (final ability in [picks.$1, picks.$2]) {
        abilityIncreases.update(
          ability,
          (points) => points + 1,
          ifAbsent: () => 1,
        );
      }
    });
  }

  void showProgressionMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void applyLevelUpDefaults(BuiltInClass primary) {
    final current = widget.character;
    final level = int.tryParse(levelController.text);
    if (level == null || level <= current.level || level > 20) {
      showProgressionMessage('Enter a higher level, up to level 20.');
      return;
    }
    final allocation = classAllocation;
    final primaryLevel =
        level - allocation.values.fold<int>(0, (sum, count) => sum + count);
    final nextLevels = {primary.label: primaryLevel, ...allocation};
    final previousLevels = {
      primary.label: current.levelInClass(primary.label),
      ...current.additionalClassLevels,
    };
    if (primaryLevel < 1 ||
        previousLevels.entries.any(
          (entry) => (nextLevels[entry.key] ?? 0) < entry.value,
        )) {
      showProgressionMessage(
        'Keep existing class levels to calculate level-up HP.',
      );
      return;
    }
    final constitution = current.abilityModifierFor(Ability.constitution);
    var maximumHp = current.maxHp;
    for (final entry in nextLevels.entries) {
      final hitDie = BuiltInClass.named(entry.key)!.hitDie;
      final gainedLevels = entry.value - (previousLevels[entry.key] ?? 0);
      final hpPerLevel = (hitDie ~/ 2 + 1 + constitution).clamp(1, 999);
      maximumHp += gainedLevels * hpPerLevel;
    }
    maxHpController.text = '$maximumHp';
    proficiencyController.text = '${2 + (level - 1) ~/ 4}';
  }

  List<CharacterResource> updatedSpellSlotResources(
    int level,
    Map<String, int> allocation,
  ) {
    final wasMulticlass = widget.character.additionalClassLevels.isNotEmpty;
    if (allocation.isEmpty &&
        !wasMulticlass &&
        (level == widget.character.level ||
            !resources.any((resource) => spellSlotLevel(resource) != null))) {
      return [...resources];
    }
    final slots = spellSlotsForClassLevels(
      widget.character.characterClass,
      level,
      allocation,
    );
    if (slots.isEmpty && !wasMulticlass) return [...resources];
    return [
      for (final resource in resources)
        if (spellSlotLevel(resource) == null) resource,
      ...slots,
    ];
  }

  List<CharacterResource> updatedResources(
    int level,
    Map<String, int> allocation,
  ) {
    final primary = BuiltInClass.named(widget.character.characterClass);
    final slotsAndResources = updatedSpellSlotResources(level, allocation);
    if (primary == null) return slotsAndResources;
    final primaryLevel =
        level - allocation.values.fold<int>(0, (sum, value) => sum + value);
    final charisma = ((improvedScore(Ability.charisma) - 10) / 2).floor();
    final wisdom = ((finalScore(Ability.wisdom) - 10) / 2).floor();
    final generated = [
      ...primary.classResources(
        primaryLevel,
        charismaModifier: charisma,
        wisdomModifier: wisdom,
        subclass: subclasses[primary.label],
      ),
      for (final entry in allocation.entries)
        ...BuiltInClass.named(entry.key)!.classResources(
          entry.value,
          charismaModifier: charisma,
          wisdomModifier: wisdom,
          subclass: subclasses[entry.key],
        ),
    ].where((resource) => progressingClassResourceIds.contains(resource.id));
    return [
      for (final resource in slotsAndResources)
        if (!progressingClassResourceIds.contains(resource.id)) resource,
      ...generated,
    ];
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    final level = int.parse(levelController.text);
    final maximumHp =
        int.parse(maxHpController.text) +
        modifierChange(Ability.constitution) * level +
        (applyDraconicHpAdjustment ? draconicHpAdjustment : 0);
    if (maximumHp < 1 || maximumHp > 999) {
      showProgressionMessage(
        'Final maximum HP must be 1–999 after class bonuses.',
      );
      return;
    }
    if (additionalClasses.values.any(
      (controller) => numberBetween(controller.text, 0, 19) != null,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter 0–19 for each additional class.')),
      );
      return;
    }
    final allocation = classAllocation;
    if (assignedAbilityPoints >
        2 * abilityImprovementCount(level, allocation)) {
      showProgressionMessage(
        'Clear ability increases or enter levels that grant them.',
      );
      return;
    }
    if (allocation.values.fold(0, (total, value) => total + value) >= level) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep at least one level in your primary class.'),
        ),
      );
      return;
    }
    final current = widget.character;
    final newClasses = allocation.keys.where(
      (name) => current.levelInClass(name) == 0,
    );
    if (newClasses.isNotEmpty) {
      for (final name in {
        current.characterClass,
        ...current.additionalClassLevels.keys,
        ...newClasses,
      }) {
        final requirement = BuiltInClass.named(
          name,
        )?.unmetMulticlassRequirement(current.scoreFor);
        if (requirement != null) {
          showProgressionMessage(
            'Multiclassing requires $requirement for $name.',
          );
          return;
        }
      }
    }
    Navigator.pop(
      context,
      widget.character.copyWith(
        level: level,
        additionalClassLevels: allocation,
        primalOrder: primalOrder,
        divineOrder: divineOrder,
        elementalFury: elementalFury,
        blessedStrikes: blessedStrikes,
        clearBlessedStrikes: clericLevelAt(level, allocation) < 7,
        clericCantripIds: {
          for (final spell in spells)
            if (spell.isCantrip && current.clericCantripIds.contains(spell.id))
              spell.id,
        },
        sorcererSpellIds: {
          for (final spell in spells)
            if (current.sorcererSpellIds.contains(spell.id)) spell.id,
        },
        clearElementalFury: druidLevelAt(level, allocation) < 7,
        druidCantripIds: {
          for (final spell in spells)
            if (spell.isCantrip && current.druidCantripIds.contains(spell.id))
              spell.id,
        },
        clearPrimalOrder:
            BuiltInClass.named(current.characterClass) != BuiltInClass.druid &&
            !allocation.containsKey('Druid'),
        subclasses: {
          for (final entry in eligibleSubclassClasses(level, allocation))
            entry.label: ?subclasses[entry.label],
        },
        currentHp: widget.character.currentHp.clamp(0, maximumHp),
        maxHp: maximumHp,
        draconicHpBonus: nextDraconicHpBonus,
        abilityScores: {
          ...current.abilityScores,
          for (final ability in Ability.values) ability: finalScore(ability),
        },
        initiativeModifier:
            current.initiativeModifier + modifierChange(Ability.dexterity),
        proficiencyBonus: int.parse(proficiencyController.text),
        spells: [...spells],
        weapons: [...weapons],
        resources: updatedResources(level, allocation),
        initialInventory: [...inventory],
        features: [
          ...features,
          if (grantsBodyAndMind)
            const Feature(
              id: 'whetstone:class:body-and-mind',
              name: 'Body and Mind',
              summary:
                  'Monk level 20: Dexterity and Wisdom increased by 4, capped at 25. The score increases have already been applied.',
            ),
          if (grantsPrimalChampion)
            const Feature(
              id: 'whetstone:class:primal-champion',
              name: 'Primal Champion',
              summary:
                  'Barbarian level 20: Strength and Constitution increased by 4, capped at 25. The scores and Constitution-based maximum HP increases have already been applied.',
            ),
        ],
        initiallyPinnedActionKeys: {...pinnedActionKeys},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = BuiltInClass.named(widget.character.characterClass);
    final eligibleSubclasses = eligibleSubclassClasses(
      int.tryParse(levelController.text) ?? 0,
      classAllocation,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advance Character'),
        actions: [
          TextButton(
            key: const ValueKey('save-advancement'),
            onPressed: save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Update only what changed. Current HP and spent resources are '
              'preserved wherever possible.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Progression',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: numberField(
                            key: 'advancement-level',
                            controller: levelController,
                            label: 'Level',
                            minimum: 1,
                            maximum: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: numberField(
                            key: 'advancement-proficiency',
                            controller: proficiencyController,
                            label: 'Proficiency',
                            minimum: 0,
                            maximum: 10,
                            prefix: '+',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    numberField(
                      key: 'advancement-max-hp',
                      controller: maxHpController,
                      label: 'Maximum HP',
                      minimum: 1,
                      maximum: 999,
                    ),
                    if (draconicHpAdjustment != 0)
                      CheckboxListTile(
                        key: const ValueKey('advancement-draconic-hp'),
                        title: Text(
                          'Draconic Resilience · ${draconicHpAdjustment >= 0 ? '+' : ''}$draconicHpAdjustment maximum HP',
                        ),
                        subtitle: const Text(
                          'Add this adjustment when saving. Uncheck if your entered maximum HP already includes it.',
                        ),
                        value: applyDraconicHpAdjustment,
                        onChanged: (value) => setState(
                          () => applyDraconicHpAdjustment = value ?? true,
                        ),
                      ),
                    if (widget.character.hasDraconicResilience &&
                        widget.character.draconicHpBonus == null)
                      const Text(
                        'Review Draconic Resilience HP from Explore to enable automatic class HP progression.',
                      ),
                    if (additionalClasses.isNotEmpty)
                      ExpansionTile(
                        title: const Text('Additional class levels'),
                        subtitle: const Text(
                          'Used to calculate Hit Dice and spell slots',
                        ),
                        initiallyExpanded:
                            widget.character.additionalClassLevels.isNotEmpty,
                        maintainState: true,
                        children: [
                          for (final entry in additionalClasses.entries)
                            numberField(
                              key: 'advancement-class-${entry.key.name}',
                              controller: entry.value,
                              label: entry.key.label,
                              minimum: 0,
                              maximum: 19,
                            ),
                        ],
                      ),
                    if (primary != null)
                      TextButton(
                        onPressed: () => applyLevelUpDefaults(primary),
                        child: const Text('Apply level-up HP and proficiency'),
                      ),
                    for (final entry in eligibleSubclasses)
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: '${entry.label} subclass',
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: ValueKey('advancement-subclass-${entry.name}'),
                            isExpanded: true,
                            value:
                                subclasses[entry.label] ==
                                    entry.basicRulesSubclass
                                ? entry.basicRulesSubclass
                                : '',
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Choose later'),
                              ),
                              DropdownMenuItem(
                                value: entry.basicRulesSubclass,
                                child: Text(entry.basicRulesSubclass),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              if (value == null || value.isEmpty) {
                                subclasses.remove(entry.label);
                              } else {
                                subclasses[entry.label] = value;
                              }
                            }),
                          ),
                        ),
                      ),
                    if (primary == BuiltInClass.cleric ||
                        classAllocation.containsKey('Cleric')) ...[
                      DropdownButtonFormField<DivineOrder>(
                        decoration: const InputDecoration(
                          labelText: 'Divine Order',
                        ),
                        initialValue: divineOrder,
                        items: [
                          for (final order in DivineOrder.values)
                            DropdownMenuItem(
                              value: order,
                              child: Text(order.label),
                            ),
                        ],
                        onChanged: (order) =>
                            setState(() => divineOrder = order),
                      ),
                      if (divineOrder != null) Text(divineOrder!.guidance),
                    ],
                    if (primary == BuiltInClass.druid ||
                        classAllocation.containsKey('Druid'))
                      DropdownButtonFormField<PrimalOrder>(
                        decoration: const InputDecoration(
                          labelText: 'Primal Order',
                          helperText:
                              'Magician adds a cantrip. Warden grants martial weapons and medium armor.',
                        ),
                        initialValue: primalOrder,
                        items: [
                          for (final order in PrimalOrder.values)
                            DropdownMenuItem(
                              value: order,
                              child: Text(order.label),
                            ),
                        ],
                        onChanged: (order) =>
                            setState(() => primalOrder = order),
                      ),
                    if (primary != null)
                      TextButton(
                        onPressed: chooseAbilityImprovement,
                        child: const Text('Choose Ability Score Improvement'),
                      ),
                    if (druidLevelAt(
                          int.tryParse(levelController.text) ?? 0,
                          classAllocation,
                        ) >=
                        7)
                      DropdownButtonFormField<ElementalFury>(
                        decoration: const InputDecoration(
                          labelText: 'Elemental Fury',
                        ),
                        initialValue: elementalFury,
                        items: [
                          for (final choice in ElementalFury.values)
                            DropdownMenuItem(
                              value: choice,
                              child: Text(choice.label),
                            ),
                        ],
                        onChanged: (choice) =>
                            setState(() => elementalFury = choice),
                      ),
                    if (clericLevelAt(
                          int.tryParse(levelController.text) ?? 0,
                          classAllocation,
                        ) >=
                        7) ...[
                      DropdownButtonFormField<BlessedStrikes>(
                        decoration: const InputDecoration(
                          labelText: 'Blessed Strikes',
                        ),
                        initialValue: blessedStrikes,
                        items: [
                          for (final choice in BlessedStrikes.values)
                            DropdownMenuItem(
                              value: choice,
                              child: Text(choice.label),
                            ),
                        ],
                        validator: (choice) =>
                            choice == null &&
                                widget.character.levelInClass('Cleric') < 7
                            ? 'Choose Blessed Strikes'
                            : null,
                        onChanged: (choice) =>
                            setState(() => blessedStrikes = choice),
                      ),
                      if (blessedStrikes != null)
                        Text(blessedStrikes!.guidance),
                    ],
                    if (grantsBodyAndMind)
                      const Text(
                        'Body and Mind · +4 Dexterity and Wisdom, to a maximum of 25. Applied once when reaching Monk level 20. Recalculate equipment-dependent AC afterward.',
                      ),
                    if (grantsPrimalChampion)
                      const Text(
                        'Primal Champion · +4 Strength and Constitution, to a maximum of 25. Applied once when reaching Barbarian level 20. Constitution adjusts maximum HP across all levels; current HP is preserved. Recalculate equipment-dependent AC afterward.',
                      ),
                    if (abilityIncreases.isNotEmpty) ...[
                      Text(
                        abilityIncreases.entries
                            .map(
                              (entry) => '${entry.key.label} +${entry.value}',
                            )
                            .join(', '),
                      ),
                      if (modifierChange(Ability.constitution) > 0)
                        const Text(
                          'Constitution adds 1 maximum HP per level for each modifier increase.',
                        ),
                      TextButton(
                        onPressed: () => setState(abilityIncreases.clear),
                        child: const Text('Clear ability increases'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            advancementSection(
              title: 'Spells',
              addKey: 'advancement-add-spell',
              libraryKey: 'advancement-library-spell',
              onAdd: addSpell,
              onAddFromLibrary: addSpellFromLibrary,
              emptyMessage: 'No spells added.',
              children: [
                for (var index = 0; index < spells.length; index++)
                  editableTile(
                    icon: isPinned(spells[index])
                        ? Icons.push_pin
                        : Icons.auto_awesome_outlined,
                    title: spells[index].name,
                    subtitle:
                        '${spells[index].levelLabel} • ${spells[index].summary}',
                    editTooltip: 'Edit ${spells[index].name}',
                    removeTooltip: 'Remove ${spells[index].name}',
                    onEdit: () => editSpell(index),
                    onRemove: () => removeSpell(index),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            advancementSection(
              title: 'Weapons',
              addKey: 'advancement-add-weapon',
              libraryKey: 'advancement-library-weapon',
              onAdd: addWeapon,
              onAddFromLibrary: addWeaponFromLibrary,
              emptyMessage: 'No weapons added.',
              children: [
                for (var index = 0; index < weapons.length; index++)
                  editableTile(
                    icon: Icons.gavel_outlined,
                    title: weapons[index].name,
                    subtitle: weapons[index].summary,
                    editTooltip: 'Edit ${weapons[index].name}',
                    removeTooltip: 'Remove ${weapons[index].name}',
                    onEdit: () => editWeapon(index),
                    onRemove: () => removeWeapon(index),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            advancementSection(
              title: 'Resources',
              addKey: 'advancement-add-resource',
              libraryKey: 'advancement-library-resource',
              onAdd: addResource,
              onAddFromLibrary: addResourceFromLibrary,
              emptyMessage: 'No resources added.',
              children: [
                for (var index = 0; index < resources.length; index++)
                  editableTile(
                    icon: Icons.battery_charging_full_outlined,
                    title: resources[index].name,
                    subtitle:
                        '${resources[index].maximum} uses • ${resources[index].rechargePeriod.label}',
                    editTooltip: 'Edit ${resources[index].name}',
                    removeTooltip: 'Remove ${resources[index].name}',
                    onEdit: () => editResource(index),
                    onRemove: () => removeResource(index),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            advancementSection(
              title: 'Inventory',
              addKey: 'advancement-add-item',
              libraryKey: 'advancement-library-item',
              onAdd: addItem,
              onAddFromLibrary: addItemFromLibrary,
              emptyMessage: 'No inventory items added.',
              children: [
                for (var index = 0; index < inventory.length; index++)
                  editableTile(
                    icon: Icons.backpack_outlined,
                    title: inventory[index].name,
                    subtitle:
                        '${inventory[index].quantity} carried • '
                        '${inventory[index].weightPerItem} lb each',
                    editTooltip: 'Edit ${inventory[index].name}',
                    removeTooltip: 'Remove ${inventory[index].name}',
                    onEdit: () => editItem(index),
                    onRemove: () => removeItem(index),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            advancementSection(
              title: 'Features & Traits',
              addKey: 'advancement-add-feature',
              libraryKey: 'advancement-library-feature',
              onAdd: addFeature,
              onAddFromLibrary: addFeatureFromLibrary,
              emptyMessage: 'No features added.',
              children: [
                for (var index = 0; index < features.length; index++)
                  editableTile(
                    icon: isPinned(features[index])
                        ? Icons.push_pin
                        : Icons.bolt_outlined,
                    title: features[index].name,
                    subtitle: features[index].summary,
                    editTooltip: 'Edit ${features[index].name}',
                    removeTooltip: 'Remove ${features[index].name}',
                    onEdit: () => editFeature(index),
                    onRemove: () => removeFeature(index),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.trending_up),
              label: const Text('Save Advancement'),
            ),
          ],
        ),
      ),
    );
  }

  Widget numberField({
    required String key,
    required TextEditingController controller,
    required String label,
    required int minimum,
    required int maximum,
    String? prefix,
  }) {
    return TextFormField(
      key: ValueKey(key),
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, prefixText: prefix),
      validator: (value) => numberBetween(value, minimum, maximum),
      onChanged:
          key == 'advancement-level' || key.startsWith('advancement-class-')
          ? (_) => setState(() {})
          : null,
    );
  }

  Widget advancementSection({
    required String title,
    required String addKey,
    required String libraryKey,
    required VoidCallback onAdd,
    required VoidCallback onAddFromLibrary,
    required String emptyMessage,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(emptyMessage),
              )
            else
              ...children,
            const SizedBox(height: 8),
            ContentAddButtons(
              libraryKey: libraryKey,
              customKey: addKey,
              onAddFromLibrary: onAddFromLibrary,
              onCreateCustom: onAdd,
            ),
          ],
        ),
      ),
    );
  }

  Widget editableTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String editTooltip,
    required String removeTooltip,
    required VoidCallback onEdit,
    required VoidCallback onRemove,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: editTooltip,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: removeTooltip,
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  bool isPinned(CharacterAction action) {
    return pinnedActionKeys.contains(action.actionKey);
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

  bool canSelectMastery(String name, {Weapon? editing}) {
    final level = int.tryParse(levelController.text) ?? widget.character.level;
    final limit =
        BuiltInClass.named(
          widget.character.characterClass,
        )?.weaponMasteryLimit(level) ??
        0;
    return BuiltInClass.named(
              widget.character.characterClass,
            )?.allowsMastery(name) ==
            true &&
        WeaponMastery.hasRoom(
          limit: limit,
          name: name,
          weapons: weapons,
          editing: editing,
        );
  }

  Future<void> addWeapon() async {
    final weapon = await showDialog<Weapon>(
      context: context,
      builder: (context) => WeaponEditorDialog(
        canSelectMastery:
            BuiltInClass.named(
              widget.character.characterClass,
            )?.hasWeaponMastery ??
            false,
        allowsMasteryFor: canSelectMastery,
      ),
    );
    if (!mounted || weapon == null) return;
    setState(() => weapons.add(weapon));
  }

  Future<void> addWeaponFromLibrary() async {
    final selection = await chooseFromLibrary(LibraryContentType.weapon);
    if (!mounted || selection == null) return;
    final weapon = LibraryContentCopy.weapon(
      selection.content as Weapon,
      weapons,
    );
    setState(() => weapons.add(weapon));
  }

  Future<void> editWeapon(int index) async {
    final weapon = await showDialog<Weapon>(
      context: context,
      builder: (context) => WeaponEditorDialog(
        weapon: weapons[index],
        canSelectMastery:
            BuiltInClass.named(
              widget.character.characterClass,
            )?.hasWeaponMastery ??
            false,
        allowsMasteryFor: (name) =>
            canSelectMastery(name, editing: weapons[index]),
      ),
    );
    if (!mounted || weapon == null) return;
    setState(() => weapons[index] = weapon);
  }

  Future<void> removeWeapon(int index) async {
    final weapon = weapons[index];
    if (!await confirmRemoval('Weapon', weapon.name)) return;
    setState(() => weapons.removeAt(index));
  }

  Future<void> addSpell() async {
    final result = await showDialog<SpellEditorResult>(
      context: context,
      builder: (context) => const SpellEditorDialog(),
    );
    if (!mounted || result == null) return;
    setState(() {
      spells.add(result.spell);
      if (result.pinned) pinnedActionKeys.add(result.spell.actionKey);
    });
  }

  Future<void> addSpellFromLibrary() async {
    final selection = await chooseFromLibrary(LibraryContentType.spell);
    if (!mounted || selection == null) return;
    final spell = LibraryContentCopy.spell(selection.content as Spell, spells);
    setState(() => spells.add(spell));
  }

  Future<void> editSpell(int index) async {
    final previous = spells[index];
    final result = await showDialog<SpellEditorResult>(
      context: context,
      builder: (context) => SpellEditorDialog(
        spell: previous,
        initiallyPinned: isPinned(previous),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      pinnedActionKeys.remove(previous.actionKey);
      spells[index] = result.spell;
      if (result.pinned) pinnedActionKeys.add(result.spell.actionKey);
    });
  }

  Future<void> removeSpell(int index) async {
    final spell = spells[index];
    if (!await confirmRemoval('Spell', spell.name)) return;
    setState(() {
      pinnedActionKeys.remove(spell.actionKey);
      spells.removeAt(index);
    });
  }

  Future<void> addResource() async {
    final resource = await showDialog<CharacterResource>(
      context: context,
      builder: (context) => const CharacterResourceEditorDialog(),
    );
    if (!mounted || resource == null) return;
    setState(() => resources.add(resource));
  }

  Future<void> addResourceFromLibrary() async {
    final selection = await chooseFromLibrary(LibraryContentType.resource);
    if (!mounted || selection == null) return;
    final resource = LibraryContentCopy.resource(
      selection.content as CharacterResource,
      resources,
    );
    setState(() => resources.add(resource));
  }

  Future<void> editResource(int index) async {
    final resource = await showDialog<CharacterResource>(
      context: context,
      builder: (context) =>
          CharacterResourceEditorDialog(resource: resources[index]),
    );
    if (!mounted || resource == null) return;
    setState(() => resources[index] = resource);
  }

  Future<void> removeResource(int index) async {
    final resource = resources[index];
    if (!await confirmRemoval('Resource', resource.name)) return;
    setState(() => resources.removeAt(index));
  }

  Future<void> addItem() async {
    final item = await showDialog<InventoryItem>(
      context: context,
      builder: (context) => const InventoryItemEditorDialog(),
    );
    if (!mounted || item == null) return;
    setState(() => inventory.add(item));
  }

  Future<void> addItemFromLibrary() async {
    final selection = await chooseFromLibrary(LibraryContentType.item);
    if (!mounted || selection == null) return;
    final item = LibraryContentCopy.item(selection.content as InventoryItem);
    setState(() => inventory.add(item));
  }

  Future<void> editItem(int index) async {
    final item = await showDialog<InventoryItem>(
      context: context,
      builder: (context) => InventoryItemEditorDialog(item: inventory[index]),
    );
    if (!mounted || item == null) return;
    setState(() => inventory[index] = item);
  }

  Future<void> removeItem(int index) async {
    final item = inventory[index];
    if (!await confirmRemoval('Item', item.name)) return;
    setState(() => inventory.removeAt(index));
  }

  Future<void> addFeature() async {
    final result = await showDialog<FeatureEditorResult>(
      context: context,
      builder: (context) => const FeatureEditorDialog(),
    );
    if (!mounted || result == null) return;
    setState(() {
      features.add(result.feature);
      if (result.pinned) pinnedActionKeys.add(result.feature.actionKey);
    });
  }

  Future<void> addFeatureFromLibrary() async {
    final selection = await chooseFromLibrary(LibraryContentType.feature);
    if (!mounted || selection == null) return;
    final feature = LibraryContentCopy.feature(
      selection.content as Feature,
      features,
    );
    setState(() => features.add(feature));
  }

  Future<void> editFeature(int index) async {
    final previous = features[index];
    final result = await showDialog<FeatureEditorResult>(
      context: context,
      builder: (context) => FeatureEditorDialog(
        feature: previous,
        initiallyPinned: isPinned(previous),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      pinnedActionKeys.remove(previous.actionKey);
      features[index] = result.feature;
      if (result.pinned) pinnedActionKeys.add(result.feature.actionKey);
    });
  }

  Future<void> removeFeature(int index) async {
    final feature = features[index];
    if (!await confirmRemoval('Feature', feature.name)) return;
    setState(() {
      pinnedActionKeys.remove(feature.actionKey);
      features.removeAt(index);
    });
  }

  Future<bool> confirmRemoval(String type, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $type?'),
        content: Text('Remove $name from this character?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return mounted && confirmed == true;
  }
}
