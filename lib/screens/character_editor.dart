import 'dart:math';

import 'package:flutter/material.dart';
import '../content/class_spells.dart';
import 'package:flutter/services.dart';

import '../models/ability.dart';
import '../models/built_in_class.dart';
import '../models/authored_class.dart';
import '../models/character.dart';
import '../models/character_resource.dart';
import '../models/content_pack.dart';
import '../models/inventory_item.dart';
import '../models/library_content_copy.dart';
import '../models/feature.dart';
import '../models/skill.dart';
import '../models/spell.dart';
import '../models/spell_slots.dart';
import '../models/weapon.dart';
import '../widgets/spell_editor_dialog.dart';
import '../widgets/character_resource_editor_dialog.dart';
import '../widgets/inventory_item_editor_dialog.dart';
import '../widgets/feature_editor_dialog.dart';
import '../widgets/weapon_editor_dialog.dart';
import '../widgets/content_add_buttons.dart';
import '../widgets/library_content_picker.dart';

class CharacterEditor extends StatefulWidget {
  final Character? character;
  final List<ContentPack> contentPacks;

  const CharacterEditor({
    super.key,
    this.character,
    this.contentPacks = const [],
  });

  @override
  State<CharacterEditor> createState() => _CharacterEditorState();
}

class _CharacterEditorState extends State<CharacterEditor> {
  final identityFormKey = GlobalKey<FormState>();
  final abilitiesFormKey = GlobalKey<FormState>();
  final nameFormKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController classController;
  late final TextEditingController levelController;
  late final TextEditingController maxHpController;
  late final TextEditingController armourClassController;
  late final TextEditingController proficiencyBonusController;
  late final Map<Ability, TextEditingController> abilityControllers;
  late final Set<Ability> savingThrowProficiencies;
  late final Map<String, SkillProficiency> skillProficiencies;
  late final List<Weapon> weapons;
  late final List<Spell> spells;
  late final Set<String> pinnedActionKeys;
  late final List<CharacterResource> resources;
  late final List<InventoryItem> inventory;
  late final List<Feature> features;
  int currentStep = 0;
  final stepScrollController = ScrollController();
  final stepTitleKeys = List.generate(9, (_) => GlobalKey());
  AuthoredClass? authoredClass;
  BuiltInClass? builtInClass;
  PrimalOrder? primalOrder;
  DivineOrder? divineOrder;
  bool standardArrayActive = false;
  String? equipmentOptionId;
  late final List<AuthoredClass> authoredClasses = [
    for (final pack in widget.contentPacks)
      if (pack.classPackPayload case final payload?)
        for (final rules
            in (payload['classes'] as List).cast<Map<String, Object?>>())
          AuthoredClass(payload, rules),
  ].where((entry) => entry.supportsFirstLevels).toList();

  bool get isEditing => widget.character != null;

  bool get hasSavedAuthoredClass {
    final character = widget.character;
    return character != null && AuthoredClass.fromCharacter(character) != null;
  }

  @override
  void initState() {
    super.initState();
    final character = widget.character;
    nameController = TextEditingController(text: character?.name ?? '');
    classController = TextEditingController(
      text: character?.characterClass ?? '',
    );
    levelController = TextEditingController(text: '${character?.level ?? 1}');
    maxHpController = TextEditingController(text: '${character?.maxHp ?? 10}');
    armourClassController = TextEditingController(
      text: '${character?.armourClass ?? 10}',
    );
    proficiencyBonusController = TextEditingController(
      text: '${character?.proficiencyBonus ?? 2}',
    );
    abilityControllers = {
      for (final ability in Ability.values)
        ability: TextEditingController(
          text: '${character?.scoreFor(ability) ?? 10}',
        ),
    };
    savingThrowProficiencies = {...?character?.savingThrowProficiencies};
    skillProficiencies = {...?character?.skillProficiencies};
    weapons = [...?character?.weapons];
    spells = [...?character?.spells];
    pinnedActionKeys = {...?character?.initiallyPinnedActionKeys};
    resources = [...?character?.resources];
    inventory = [...?character?.initialInventory];
    features = [...?character?.features];
  }

  @override
  void dispose() {
    stepScrollController.dispose();
    nameController.dispose();
    classController.dispose();
    levelController.dispose();
    maxHpController.dispose();
    armourClassController.dispose();
    proficiencyBonusController.dispose();
    for (final controller in abilityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? requiredText(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? numberBetween(String? value, int minimum, int maximum) {
    final number = int.tryParse(value ?? '');
    if (number == null || number < minimum || number > maximum) {
      return '$minimum–$maximum';
    }
    return null;
  }

  bool get builtInSkillsComplete {
    final selectedClass = builtInClass;
    return selectedClass == null ||
        (skillProficiencies.length == selectedClass.skillCount &&
            skillProficiencies.entries.every(
              (entry) =>
                  selectedClass.allowsSkill(entry.key) &&
                  entry.value == SkillProficiency.proficient,
            ));
  }

  void goToStep(int step) {
    FocusScope.of(context).unfocus();
    setState(() => currentStep = step);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || currentStep != step || !stepScrollController.hasClients) {
        return;
      }
      var target = stepTitleKeys[step].currentContext;
      if (target == null) {
        stepScrollController.jumpTo(
          stepScrollController.position.maxScrollExtent,
        );
        WidgetsBinding.instance.scheduleFrame();
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || currentStep != step) return;
        target = stepTitleKeys[step].currentContext;
      }
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  void continueFromStep() {
    final valid = switch (currentStep) {
      0 => identityFormKey.currentState?.validate() ?? false,
      1 => abilitiesFormKey.currentState?.validate() ?? false,
      2 =>
        builtInSkillsComplete &&
            (authoredClass == null ||
                authoredClass!.skills
                        .where(skillProficiencies.containsKey)
                        .length ==
                    authoredClass!.skillCount),
      _ => true,
    };
    if (!valid) {
      goToStep(currentStep);
      if (currentStep == 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Choose ${authoredClass?.skillCount ?? builtInClass!.skillCount} class skills.',
            ),
          ),
        );
      }
      return;
    }
    final hitDie = authoredClass?.hitDie ?? builtInClass?.hitDie;
    if (currentStep == 1 && hitDie != null) {
      final constitution = int.parse(
        abilityControllers[Ability.constitution]!.text,
      );
      final hp = max(1, hitDie + ((constitution - 10) / 2).floor());
      maxHpController.text = '$hp';
    }
    goToStep(currentStep + 1);
  }

  void saveCharacter() {
    final form = nameFormKey.currentState;
    if (form == null) {
      goToStep(8);
      return;
    }
    if (!form.validate() || !builtInSkillsComplete) {
      return;
    }
    final authored = authoredClass;
    if (authored != null &&
        authored.equipmentOptions.length > 1 &&
        equipmentOptionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose starting equipment before saving.'),
        ),
      );
      return;
    }
    final abilityScores = {
      for (final entry in abilityControllers.entries)
        entry.key: int.parse(entry.value.text),
    };
    final selectedSkills = skillProficiencies.entries
        .where((entry) => entry.value != SkillProficiency.none)
        .toList();
    if (authored != null &&
        (selectedSkills.length != authored.skillCount ||
            selectedSkills.any(
              (entry) =>
                  !authored.skills.contains(entry.key) ||
                  entry.value != SkillProficiency.proficient,
            ))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Choose exactly ${authored.skillCount} proficiencies: '
            '${authored.skills.join(', ')}.',
          ),
        ),
      );
      return;
    }
    final constitution = ((abilityScores[Ability.constitution]! - 10) / 2)
        .floor();
    final hitDie = authored?.hitDie ?? builtInClass?.hitDie;
    final maximumHp = hitDie == null
        ? int.parse(maxHpController.text)
        : max(1, hitDie + constitution);
    final initiativeModifier = ((abilityScores[Ability.dexterity]! - 10) / 2)
        .floor();
    final proficiency = authored == null
        ? int.parse(proficiencyBonusController.text)
        : 2;
    final previous = widget.character;
    final className = authored?.name ?? classController.text.trim();
    final previousClass = BuiltInClass.named(previous?.characterClass ?? '');
    final keepClassAllocation =
        previousClass != null &&
        previousClass == BuiltInClass.named(className) &&
        (previous?.additionalClassLevels.isNotEmpty ?? false);
    final keepSubclasses =
        previousClass != null &&
        previousClass == BuiltInClass.named(className) &&
        (previous?.subclasses.isNotEmpty ?? false);
    final savedClass = previous == null
        ? null
        : AuthoredClass.fromCharacter(previous);
    final updatedWeapons = savedClass == null
        ? [
            ...weapons,
            ...?authored?.startingWeapons(
              equipmentOptionId,
              abilityScores,
              proficiency,
            ),
          ]
        : savedClass.refreshStartingWeapons(
            previous!,
            weapons,
            abilityScores,
            proficiency,
          );
    final character = Character(
      id:
          widget.character?.id ??
          'character-${DateTime.now().microsecondsSinceEpoch}',
      name: nameController.text.trim(),
      characterClass: className,
      savedClassRules: authored?.snapshot ?? widget.character?.savedClassRules,
      additionalClassLevels: keepClassAllocation
          ? previous!.additionalClassLevels
          : const {},
      subclasses: keepSubclasses ? previous!.subclasses : const {},
      draconicHpBonus: previous?.draconicHpBonus,
      metamagicOptions: previous?.metamagicOptions ?? const {},
      elementalAffinity: previous?.elementalAffinity,
      blessedStrikes: previousClass == BuiltInClass.named(className)
          ? previous?.blessedStrikes
          : null,
      clericCantripIds: previousClass == BuiltInClass.named(className)
          ? {
              for (final spell in spells)
                if (spell.isCantrip &&
                    (previous?.clericCantripIds.contains(spell.id) ?? false))
                  spell.id,
            }
          : const {},
      elementalFury: previousClass == BuiltInClass.named(className)
          ? previous?.elementalFury
          : null,
      sorcererSpellIds: previousClass == BuiltInClass.named(className)
          ? {
              for (final spell in spells)
                if (previous?.sorcererSpellIds.contains(spell.id) ?? false)
                  spell.id,
            }
          : const {},
      druidCantripIds: previousClass == BuiltInClass.named(className)
          ? {
              for (final spell in spells)
                if (spell.isCantrip &&
                    (previous?.druidCantripIds.contains(spell.id) ?? false))
                  spell.id,
            }
          : const {},
      primalOrder: builtInClass == BuiltInClass.druid
          ? primalOrder
          : (previousClass == BuiltInClass.named(className)
                ? previous?.primalOrder
                : null),
      divineOrder: builtInClass == BuiltInClass.cleric
          ? divineOrder
          : (previousClass == BuiltInClass.named(className)
                ? previous?.divineOrder
                : null),
      level: hasSavedAuthoredClass || keepClassAllocation || keepSubclasses
          ? widget.character!.level
          : authored == null && builtInClass == null
          ? int.parse(levelController.text)
          : 1,
      currentHp: isEditing
          ? min(widget.character!.currentHp, maximumHp)
          : maximumHp,
      maxHp: maximumHp,
      armourClass: int.parse(armourClassController.text),
      initiativeModifier: initiativeModifier,
      status: 'Exploring',
      abilityScores: abilityScores,
      proficiencyBonus: proficiency,
      skillProficiencies: {...skillProficiencies},
      savingThrowProficiencies:
          authored?.saves ??
          builtInClass?.saves ??
          {...savingThrowProficiencies},
      weapons: updatedWeapons,
      spells: [...spells],
      initiallyPinnedActionKeys: {...pinnedActionKeys},
      resources: [
        ...resources,
        ...unlistedStartingResources,
        ...?authored?.resourcesAt(1),
      ],
      initialInventory: [
        ...inventory,
        ...?authored?.startingEquipment(equipmentOptionId),
      ],
      features: [...features, ...?authored?.grants(1)],
      journalEntries: [...?widget.character?.journalEntries],
    );
    Navigator.pop(context, withBuiltInSpellGrants(character));
  }

  @override
  Widget build(BuildContext context) {
    final isFinalStep = currentStep == 8;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Character' : 'Create Character'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton(
                key: ValueKey(
                  isFinalStep
                      ? 'creator-save'
                      : 'creator-continue-$currentStep',
                ),
                onPressed: isFinalStep ? saveCharacter : continueFromStep,
                child: Text(
                  isFinalStep
                      ? (isEditing ? 'Save Changes' : 'Create Character')
                      : 'Continue',
                ),
              ),
              if (currentStep > 0)
                TextButton(
                  onPressed: () => goToStep(currentStep - 1),
                  child: const Text('Back'),
                ),
            ],
          ),
        ),
      ),
      body: Stepper(
        controller: stepScrollController,
        currentStep: currentStep,
        onStepTapped: (step) {
          if (step <= currentStep) {
            goToStep(step);
          }
        },
        controlsBuilder: (context, details) => const SizedBox.shrink(),
        steps: [
          Step(
            title: Text('Class & Essentials', key: stepTitleKeys[0]),
            isActive: currentStep >= 0,
            state: currentStep > 0 ? StepState.complete : StepState.indexed,
            content: identityStep(),
          ),
          Step(
            title: Text('Ability Scores', key: stepTitleKeys[1]),
            isActive: currentStep >= 1,
            state: currentStep > 1 ? StepState.complete : StepState.indexed,
            content: abilitiesStep(),
          ),
          Step(
            title: Text('Proficiencies', key: stepTitleKeys[2]),
            isActive: currentStep >= 2,
            state: currentStep > 2 ? StepState.complete : StepState.indexed,
            content: proficienciesStep(),
          ),
          Step(
            title: Text('Weapons', key: stepTitleKeys[3]),
            isActive: currentStep >= 3,
            state: currentStep > 3 ? StepState.complete : StepState.indexed,
            content: weaponsStep(),
          ),
          Step(
            title: Text('Spells', key: stepTitleKeys[4]),
            isActive: currentStep >= 4,
            state: currentStep > 4 ? StepState.complete : StepState.indexed,
            content: spellsStep(),
          ),
          Step(
            title: Text('Resources', key: stepTitleKeys[5]),
            isActive: currentStep >= 5,
            state: currentStep > 5 ? StepState.complete : StepState.indexed,
            content: resourcesStep(),
          ),
          Step(
            title: Text(
              isEditing ? 'Inventory' : 'Starting Inventory',
              key: stepTitleKeys[6],
            ),
            isActive: currentStep >= 6,
            state: currentStep > 6 ? StepState.complete : StepState.indexed,
            content: inventoryStep(),
          ),
          Step(
            title: Text('Features & Actions', key: stepTitleKeys[7]),
            isActive: currentStep >= 7,
            state: currentStep > 7 ? StepState.complete : StepState.indexed,
            content: featuresStep(),
          ),
          Step(
            title: Text('Name & Review', key: stepTitleKeys[8]),
            isActive: currentStep >= 8,
            content: reviewStep(),
          ),
        ],
      ),
    );
  }

  Widget identityStep() {
    return Form(
      key: identityFormKey,
      child: Column(
        children: [
          if (!isEditing && authoredClasses.isNotEmpty)
            DropdownButtonFormField<AuthoredClass>(
              decoration: const InputDecoration(labelText: 'Pack class'),
              items: [
                const DropdownMenuItem(child: Text('Manual class')),
                for (final entry in authoredClasses)
                  DropdownMenuItem(value: entry, child: Text(entry.name)),
              ],
              onChanged: (entry) => setState(() {
                authoredClass = entry;
                builtInClass = null;
                if (entry != null) skillProficiencies.clear();
                equipmentOptionId = null;
                classController.text = entry?.name ?? '';
                if (entry != null) {
                  levelController.text = '1';
                  maxHpController.text = '${entry.hitDie}';
                  proficiencyBonusController.text = '2';
                }
              }),
            ),
          if (!isEditing && authoredClass == null)
            DropdownButtonFormField<BuiltInClass>(
              key: const ValueKey('built-in-class-picker'),
              decoration: const InputDecoration(labelText: 'Built-in class'),
              initialValue: builtInClass,
              items: [
                const DropdownMenuItem(child: Text('Manual')),
                for (final entry in BuiltInClass.values)
                  DropdownMenuItem(value: entry, child: Text(entry.label)),
              ],
              onChanged: (entry) => setState(() {
                if (builtInClass != null) savingThrowProficiencies.clear();
                if (builtInClass != entry) skillProficiencies.clear();
                builtInClass = entry;
                if (entry != null) {
                  savingThrowProficiencies
                    ..clear()
                    ..addAll(entry.saves);
                }
                classController.text = entry?.label ?? '';
                if (entry != null) {
                  levelController.text = '1';
                  proficiencyBonusController.text = '2';
                  maxHpController.text = '${entry.hitDie}';
                }
              }),
            ),
          if (builtInClass == BuiltInClass.cleric) ...[
            DropdownButtonFormField<DivineOrder>(
              decoration: const InputDecoration(labelText: 'Divine Order'),
              initialValue: divineOrder,
              items: [
                for (final order in DivineOrder.values)
                  DropdownMenuItem(value: order, child: Text(order.label)),
              ],
              onChanged: (order) => setState(() => divineOrder = order),
              validator: (order) =>
                  order == null ? 'Choose a Divine Order' : null,
            ),
            if (divineOrder != null) Text(divineOrder!.guidance),
          ],
          if (builtInClass == BuiltInClass.druid)
            DropdownButtonFormField<PrimalOrder>(
              decoration: const InputDecoration(labelText: 'Primal Order'),
              initialValue: primalOrder,
              items: [
                for (final order in PrimalOrder.values)
                  DropdownMenuItem(value: order, child: Text(order.label)),
              ],
              onChanged: (order) => setState(() => primalOrder = order),
              validator: (order) =>
                  order == null ? 'Choose a Primal Order' : null,
            ),
          if ((authoredClass?.equipmentOptions.length ?? 0) > 1)
            DropdownButtonFormField<String>(
              key: ObjectKey(authoredClass),
              decoration: const InputDecoration(
                labelText: 'Starting equipment',
              ),
              items: [
                for (final option in authoredClass!.equipmentOptions)
                  DropdownMenuItem(
                    value: option['id'] as String,
                    child: Text(option['label'] as String),
                  ),
              ],
              validator: requiredText,
              onChanged: (value) => setState(() => equipmentOptionId = value),
            ),
          TextFormField(
            key: const ValueKey('character-class'),
            controller: classController,
            readOnly:
                authoredClass != null ||
                builtInClass != null ||
                hasSavedAuthoredClass,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Class'),
            validator: requiredText,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: numberField(
                  key: 'character-level',
                  readOnly:
                      authoredClass != null ||
                      builtInClass != null ||
                      hasSavedAuthoredClass,
                  controller: levelController,
                  label: 'Level',
                  minimum: 1,
                  maximum: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: numberField(
                  key: 'proficiency-bonus',
                  readOnly: authoredClass != null || builtInClass != null,
                  controller: proficiencyBonusController,
                  label: 'Proficiency',
                  minimum: 0,
                  maximum: 10,
                  prefix: '+',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: numberField(
                  key: 'maximum-hp',
                  readOnly: authoredClass != null || builtInClass != null,
                  controller: maxHpController,
                  label: 'Maximum HP',
                  minimum: 1,
                  maximum: 999,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: numberField(
                  key: 'armour-class',
                  controller: armourClassController,
                  label: 'Armour Class',
                  minimum: 0,
                  maximum: 99,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void generateAbilityScores({required bool rolled}) {
    setState(() => standardArrayActive = !rolled);
    final random = Random();
    final scores = rolled
        ? List.generate(6, (_) {
            final dice = List.generate(4, (_) => random.nextInt(6) + 1)..sort();
            return dice.skip(1).reduce((left, right) => left + right);
          })
        : const [15, 14, 13, 12, 10, 8];
    for (final (index, ability) in Ability.values.indexed) {
      abilityControllers[ability]!.text = scores[index].toString();
    }
  }

  Future<void> buyAbilityScores() async {
    const costs = [0, 1, 2, 3, 4, 5, 7, 9];
    final scores = {for (final ability in Ability.values) ability: 8};
    final selection = await showDialog<Map<Ability, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final remaining =
              27 -
              scores.values.fold<int>(
                0,
                (total, score) => total + costs[score - 8],
              );
          return AlertDialog(
            title: Text('Point Buy · $remaining points left'),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final ability in Ability.values)
                  Row(
                    children: [
                      Expanded(child: Text(ability.label)),
                      IconButton(
                        tooltip: 'Lower ${ability.label}',
                        onPressed: scores[ability]! == 8
                            ? null
                            : () => setDialogState(
                                () => scores[ability] = scores[ability]! - 1,
                              ),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('${scores[ability]}'),
                      IconButton(
                        tooltip: 'Raise ${ability.label}',
                        onPressed:
                            scores[ability]! == 15 ||
                                costs[scores[ability]! - 7] -
                                        costs[scores[ability]! - 8] >
                                    remaining
                            ? null
                            : () => setDialogState(
                                () => scores[ability] = scores[ability]! + 1,
                              ),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, scores),
                child: const Text('Apply Scores'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || selection == null) return;
    setState(() => standardArrayActive = false);
    for (final entry in selection.entries) {
      abilityControllers[entry.key]!.text = entry.value.toString();
    }
  }

  Widget abilitiesStep() {
    return Form(
      key: abilitiesFormKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!isEditing)
                SizedBox(
                  width: constraints.maxWidth,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => generateAbilityScores(rolled: false),
                        child: const Text('Use Standard Array'),
                      ),
                      OutlinedButton(
                        onPressed: buyAbilityScores,
                        child: const Text('Point Buy'),
                      ),
                      OutlinedButton(
                        onPressed: () => generateAbilityScores(rolled: true),
                        child: const Text('Roll Ability Scores'),
                      ),
                      if (standardArrayActive)
                        TextButton(
                          onPressed: () =>
                              setState(() => standardArrayActive = false),
                          child: const Text('Edit Scores Manually'),
                        ),
                    ],
                  ),
                ),
              for (final ability in Ability.values)
                SizedBox(
                  width: width,
                  child: Row(
                    children: [
                      Expanded(
                        child: numberField(
                          key: 'ability-${ability.name}',
                          controller: abilityControllers[ability]!,
                          label: ability.label,
                          minimum: 1,
                          maximum: 30,
                          readOnly: standardArrayActive,
                        ),
                      ),
                      if (standardArrayActive)
                        PopupMenuButton<Ability>(
                          tooltip: 'Swap ${ability.label} score',
                          icon: const Icon(Icons.swap_horiz),
                          onSelected: (other) => setState(() {
                            final current = abilityControllers[ability]!;
                            final swap = abilityControllers[other]!;
                            final score = current.text;
                            current.text = swap.text;
                            swap.text = score;
                          }),
                          itemBuilder: (context) => [
                            for (final other in Ability.values)
                              if (other != ability)
                                PopupMenuItem(
                                  value: other,
                                  child: Text(
                                    '${other.label} (${abilityControllers[other]!.text})',
                                  ),
                                ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget proficienciesStep() {
    final authored = authoredClass;
    if (authored != null) return authoredProficiencies(authored);
    final selectedClass = builtInClass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saving Throws',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final ability in Ability.values)
              FilterChip(
                label: Text(ability.shortLabel),
                selected: savingThrowProficiencies.contains(ability),
                onSelected: builtInClass != null
                    ? null
                    : (selected) {
                        setState(() {
                          selected
                              ? savingThrowProficiencies.add(ability)
                              : savingThrowProficiencies.remove(ability);
                        });
                      },
              ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Skills',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        if (selectedClass != null)
          ...classSkillOptions(
            selectedClass.skillCount,
            selectedClass.allowsSkill,
          )
        else
          for (final skill in standardSkills)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(skill.name),
                DropdownButton<SkillProficiency>(
                  isExpanded: true,
                  value: skillProficiencies[skill.id] ?? SkillProficiency.none,
                  items: const [
                    DropdownMenuItem(
                      value: SkillProficiency.none,
                      child: Text('None'),
                    ),
                    DropdownMenuItem(
                      value: SkillProficiency.proficient,
                      child: Text('Proficient'),
                    ),
                    DropdownMenuItem(
                      value: SkillProficiency.expertise,
                      child: Text('Expertise'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      if (value == SkillProficiency.none) {
                        skillProficiencies.remove(skill.id);
                      } else {
                        skillProficiencies[skill.id] = value;
                      }
                    });
                  },
                ),
              ],
            ),
      ],
    );
  }

  Iterable<Widget> classSkillOptions(
    int limit,
    bool Function(String) allowsSkill,
  ) sync* {
    final selected = skillProficiencies.keys.where(allowsSkill).length;
    yield Text('Choose $limit class skills ($selected selected)');
    for (final skill in standardSkills.where(
      (skill) => allowsSkill(skill.id),
    )) {
      final checked = skillProficiencies.containsKey(skill.id);
      yield CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(skill.name),
        value: checked,
        onChanged: !checked && selected >= limit
            ? null
            : (value) => setState(() {
                if (value == true) {
                  skillProficiencies[skill.id] = SkillProficiency.proficient;
                } else {
                  skillProficiencies.remove(skill.id);
                }
              }),
      );
    }
  }

  Widget authoredProficiencies(AuthoredClass authored) {
    final selected = authored.skills
        .where(skillProficiencies.containsKey)
        .length;
    final training = authored.initialTraining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saving throws: ${authored.saves.map((save) => save.label).join(', ')}',
        ),
        for (final entry in training.entries)
          if (entry.value.isNotEmpty)
            Text('${entry.key}: ${entry.value.join(', ')}'),
        const SizedBox(height: 12),
        Text('Choose ${authored.skillCount} class skills ($selected selected)'),
        for (final skill in standardSkills)
          if (authored.skills.contains(skill.id))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(skill.name),
              value: skillProficiencies.containsKey(skill.id),
              onChanged:
                  selected >= authored.skillCount &&
                      !skillProficiencies.containsKey(skill.id)
                  ? null
                  : (checked) => setState(() {
                      if (checked == true) {
                        skillProficiencies[skill.id] =
                            SkillProficiency.proficient;
                      } else {
                        skillProficiencies.remove(skill.id);
                      }
                    }),
            ),
      ],
    );
  }

  Widget reviewStep() {
    final skilled = skillProficiencies.values
        .where((value) => value != SkillProficiency.none)
        .length;
    return Form(
      key: nameFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your character is ready. What is their name?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const ValueKey('character-name'),
            controller: nameController,
            autofocus: !isEditing,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Character name'),
            validator: requiredText,
          ),
          const SizedBox(height: 18),
          Text('Level ${levelController.text} ${classController.text.trim()}'),
          const SizedBox(height: 16),
          Text('Maximum HP ${maxHpController.text}'),
          Text('AC ${armourClassController.text}'),
          Text('Initiative ${signedModifier(dexterityModifier)} from DEX'),
          Text('Proficiency +${proficiencyBonusController.text}'),
          const SizedBox(height: 16),
          Text(
            Ability.values
                .map(
                  (ability) =>
                      '${ability.shortLabel} ${abilityControllers[ability]!.text}',
                )
                .join('  •  '),
          ),
          const SizedBox(height: 16),
          Text('${savingThrowProficiencies.length} proficient saving throws'),
          Text('$skilled trained skills'),
          Text('${weapons.length} weapons'),
          Text(
            '${spells.length} spells • '
            '${spells.where((spell) => spell.prepared).length} prepared • '
            '${spells.where(isSpellPinned).length} pinned',
          ),
          Text('${resources.length} resources'),
          Text(
            '${inventory.fold<int>(0, (sum, item) => sum + item.quantity)} '
            'inventory items • '
            '${inventory.fold<double>(0, (sum, item) => sum + item.totalWeight).toStringAsFixed(1)} lb',
          ),
          Text(
            '${features.length} features • '
            '${features.where(isFeaturePinned).length} pinned',
          ),
        ],
      ),
    );
  }

  Widget weaponsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Weapons are optional. Add the attacks this character should have '
          'ready in Combat.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (weapons.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No weapons added yet.'),
          ),
        for (var index = 0; index < weapons.length; index++)
          Card(
            child: ListTile(
              title: Text(weapons[index].name),
              subtitle: Text(weapons[index].summary),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit ${weapons[index].name}',
                    onPressed: () => editWeapon(index),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove ${weapons[index].name}',
                    onPressed: () => removeWeapon(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        ContentAddButtons(
          libraryKey: 'library-weapon',
          customKey: 'add-weapon',
          onAddFromLibrary: addWeaponFromLibrary,
          onCreateCustom: addWeapon,
        ),
      ],
    );
  }

  Widget spellsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Spells are optional. Prepared spells appear in Combat, while '
          'pinned spells are kept close to attacks.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (spells.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No spells added yet.'),
          ),
        for (var index = 0; index < spells.length; index++)
          Card(
            child: ListTile(
              title: Text(spells[index].name),
              subtitle: Text(
                '${spells[index].levelLabel} • ${spells[index].summary}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              leading: isSpellPinned(spells[index])
                  ? const Icon(Icons.push_pin, size: 18)
                  : const Icon(Icons.auto_awesome_outlined),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit ${spells[index].name}',
                    onPressed: () => editSpell(index),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove ${spells[index].name}',
                    onPressed: () => removeSpell(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        ContentAddButtons(
          libraryKey: 'library-spell',
          customKey: 'add-spell',
          onAddFromLibrary: addSpellFromLibrary,
          onCreateCustom: addSpell,
        ),
      ],
    );
  }

  bool isSpellPinned(Spell spell) {
    return pinnedActionKeys.contains(spell.actionKey);
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

  Future<void> addSpellFromLibrary() async {
    final selection = await chooseFromLibrary(LibraryContentType.spell);
    if (!mounted || selection == null) return;
    final spell = LibraryContentCopy.spell(selection.content as Spell, spells);
    setState(() => spells.add(spell));
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

  Future<void> editSpell(int index) async {
    final previous = spells[index];
    final result = await showDialog<SpellEditorResult>(
      context: context,
      builder: (context) => SpellEditorDialog(
        spell: previous,
        initiallyPinned: isSpellPinned(previous),
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      pinnedActionKeys.remove(spell.actionKey);
      spells.removeAt(index);
    });
  }

  Iterable<CharacterResource> get unlistedStartingResources {
    final selectedClass = builtInClass;
    if (selectedClass == null) return const [];
    final charisma =
        int.tryParse(abilityControllers[Ability.charisma]!.text) ?? 10;
    final existingIds = resources.map((resource) => resource.id).toSet();
    return selectedClass
        .startingResources(charismaModifier: ((charisma - 10) / 2).floor())
        .where((resource) => !existingIds.contains(resource.id));
  }

  void setClassSpellSlots() {
    final slots = spellSlotsForClassLevels(
      classController.text,
      int.tryParse(levelController.text) ?? 0,
      widget.character?.additionalClassLevels ?? const {},
    );
    if (slots.isEmpty) return;
    setState(() {
      resources.removeWhere((resource) => spellSlotLevel(resource) != null);
      resources.addAll(slots);
    });
  }

  Widget resourcesStep() {
    final canGenerateSlots = spellSlotsForClassLevels(
      classController.text,
      int.tryParse(levelController.text) ?? 0,
      widget.character?.additionalClassLevels ?? const {},
    ).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Resources track limited-use abilities, spell slots, and other '
          'things that recover during play.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (canGenerateSlots && builtInClass == null)
          OutlinedButton(
            onPressed: setClassSpellSlots,
            child: const Text('Set Spell Slots from Class Level'),
          ),
        for (final resource in unlistedStartingResources)
          ListTile(
            title: Text(resource.name),
            subtitle: Text(
              '${resource.maximum} uses • ${resource.rechargePeriod.label}',
            ),
          ),
        if (resources.isEmpty && unlistedStartingResources.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No resources added yet.'),
          ),
        for (var index = 0; index < resources.length; index++)
          Card(
            child: ListTile(
              title: Text(resources[index].name),
              subtitle: Text(
                '${resources[index].maximum} uses • '
                '${resources[index].rechargePeriod.label}',
              ),
              leading: const Icon(Icons.battery_charging_full_outlined),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit ${resources[index].name}',
                    onPressed: () => editResource(index),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove ${resources[index].name}',
                    onPressed: () => removeResource(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        ContentAddButtons(
          libraryKey: 'library-resource',
          customKey: 'add-resource',
          onAddFromLibrary: addResourceFromLibrary,
          onCreateCustom: addResource,
        ),
      ],
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Resource?'),
        content: Text('Remove ${resource.name} from this character?'),
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
    if (!mounted || confirmed != true) return;
    setState(() => resources.removeAt(index));
  }

  Widget inventoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isEditing
              ? 'This is the character’s current active inventory. Archived '
                    'items remain safely archived.'
              : 'Inventory is optional. Add anything the character begins '
                    'their adventure carrying.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (inventory.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No inventory items added yet.'),
          ),
        for (var index = 0; index < inventory.length; index++)
          Card(
            child: ListTile(
              title: Text(inventory[index].name),
              subtitle: Text(
                '${categoryLabel(inventory[index].category)} • '
                '${inventory[index].quantity} × '
                '${inventory[index].weightPerItem} lb',
              ),
              leading: const Icon(Icons.backpack_outlined),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit ${inventory[index].name}',
                    onPressed: () => editInventoryItem(index),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove ${inventory[index].name}',
                    onPressed: () => removeInventoryItem(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        ContentAddButtons(
          libraryKey: 'library-inventory-item',
          customKey: 'add-inventory-item',
          onAddFromLibrary: addItemFromLibrary,
          onCreateCustom: addInventoryItem,
        ),
      ],
    );
  }

  String categoryLabel(ItemCategory value) {
    return switch (value) {
      ItemCategory.consumable => 'Consumable',
      ItemCategory.equipment => 'Equipment',
      ItemCategory.tool => 'Tool',
      ItemCategory.quest => 'Quest Item',
      ItemCategory.general => 'General',
    };
  }

  Future<void> addInventoryItem() async {
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

  Future<void> editInventoryItem(int index) async {
    final item = await showDialog<InventoryItem>(
      context: context,
      builder: (context) => InventoryItemEditorDialog(item: inventory[index]),
    );
    if (!mounted || item == null) return;
    setState(() => inventory[index] = item);
  }

  Future<void> removeInventoryItem(int index) async {
    final item = inventory[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item?'),
        content: Text('Remove ${item.name} from this character?'),
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
    if (!mounted || confirmed != true) return;
    setState(() => inventory.removeAt(index));
  }

  Widget featuresStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Features are system-agnostic abilities and traits. Pin anything '
          'the character may need during Combat.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (features.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No features added yet.'),
          ),
        for (var index = 0; index < features.length; index++)
          Card(
            child: ListTile(
              title: Text(features[index].name),
              subtitle: Text(
                features[index].summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              leading: isFeaturePinned(features[index])
                  ? const Icon(Icons.push_pin, size: 18)
                  : const Icon(Icons.bolt_outlined),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit ${features[index].name}',
                    onPressed: () => editFeature(index),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove ${features[index].name}',
                    onPressed: () => removeFeature(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        ContentAddButtons(
          libraryKey: 'library-feature',
          customKey: 'add-feature',
          onAddFromLibrary: addFeatureFromLibrary,
          onCreateCustom: addFeature,
        ),
      ],
    );
  }

  bool isFeaturePinned(Feature feature) {
    return pinnedActionKeys.contains(feature.actionKey);
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
        initiallyPinned: isFeaturePinned(previous),
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      pinnedActionKeys.remove(feature.actionKey);
      features.removeAt(index);
    });
  }

  bool canSelectWeaponMastery(String name, {Weapon? editing}) {
    final level = int.tryParse(levelController.text) ?? 1;
    final limit =
        BuiltInClass.named(classController.text)?.weaponMasteryLimit(level) ??
        0;
    return BuiltInClass.named(classController.text)?.allowsMastery(name) ==
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
            BuiltInClass.named(classController.text)?.hasWeaponMastery ?? false,
        allowsMasteryFor: canSelectWeaponMastery,
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
            BuiltInClass.named(classController.text)?.hasWeaponMastery ?? false,
        allowsMasteryFor: (name) =>
            canSelectWeaponMastery(name, editing: weapons[index]),
      ),
    );
    if (!mounted || weapon == null) return;
    setState(() => weapons[index] = weapon);
  }

  Future<void> removeWeapon(int index) async {
    final weapon = weapons[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Weapon?'),
        content: Text('Remove ${weapon.name} from this character?'),
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
    if (!mounted || confirmed != true) return;
    setState(() => weapons.removeAt(index));
  }

  Widget numberField({
    required String key,
    required TextEditingController controller,
    required String label,
    required int minimum,
    required int maximum,
    String? prefix,
    bool readOnly = false,
  }) {
    return TextFormField(
      key: ValueKey(key),
      controller: controller,
      readOnly: readOnly,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, prefixText: prefix),
      validator: (value) => numberBetween(value, minimum, maximum),
    );
  }

  int get dexterityModifier {
    final score =
        int.tryParse(abilityControllers[Ability.dexterity]!.text) ?? 10;
    return ((score - 10) / 2).floor();
  }

  String signedModifier(int modifier) {
    return modifier >= 0 ? '+$modifier' : '$modifier';
  }
}
