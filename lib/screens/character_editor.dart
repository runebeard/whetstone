import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ability.dart';
import '../models/character.dart';
import '../models/character_resource.dart';
import '../models/content_pack.dart';
import '../models/inventory_item.dart';
import '../models/library_content_copy.dart';
import '../models/feature.dart';
import '../models/skill.dart';
import '../models/spell.dart';
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

  bool get isEditing => widget.character != null;

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

  void continueFromStep() {
    final valid = switch (currentStep) {
      0 => identityFormKey.currentState!.validate(),
      1 => abilitiesFormKey.currentState!.validate(),
      _ => true,
    };
    if (!valid) {
      return;
    }
    setState(() => currentStep += 1);
  }

  void saveCharacter() {
    if (!nameFormKey.currentState!.validate()) {
      return;
    }
    final maximumHp = int.parse(maxHpController.text);
    final abilityScores = {
      for (final entry in abilityControllers.entries)
        entry.key: int.parse(entry.value.text),
    };
    final initiativeModifier = ((abilityScores[Ability.dexterity]! - 10) / 2)
        .floor();
    final character = Character(
      id:
          widget.character?.id ??
          'character-${DateTime.now().microsecondsSinceEpoch}',
      name: nameController.text.trim(),
      characterClass: classController.text.trim(),
      level: int.parse(levelController.text),
      currentHp: isEditing
          ? min(widget.character!.currentHp, maximumHp)
          : maximumHp,
      maxHp: maximumHp,
      armourClass: int.parse(armourClassController.text),
      initiativeModifier: initiativeModifier,
      status: 'Exploring',
      abilityScores: abilityScores,
      proficiencyBonus: int.parse(proficiencyBonusController.text),
      skillProficiencies: {...skillProficiencies},
      savingThrowProficiencies: {...savingThrowProficiencies},
      weapons: [...weapons],
      spells: [...spells],
      initiallyPinnedActionKeys: {...pinnedActionKeys},
      resources: [...resources],
      initialInventory: [...inventory],
      features: [...features],
      journalEntries: [...?widget.character?.journalEntries],
    );
    Navigator.pop(context, character);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Character' : 'Create Character'),
      ),
      body: Stepper(
        currentStep: currentStep,
        onStepTapped: (step) {
          if (step <= currentStep) {
            setState(() => currentStep = step);
          }
        },
        controlsBuilder: (context, details) {
          final isFinalStep = details.stepIndex == 8;
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                FilledButton(
                  key: ValueKey(
                    isFinalStep
                        ? 'creator-save'
                        : 'creator-continue-${details.stepIndex}',
                  ),
                  onPressed: isFinalStep ? saveCharacter : continueFromStep,
                  child: Text(
                    isFinalStep
                        ? (isEditing ? 'Save Changes' : 'Create Character')
                        : 'Continue',
                  ),
                ),
                if (details.stepIndex > 0) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () =>
                        setState(() => currentStep = details.stepIndex - 1),
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Class & Essentials'),
            isActive: currentStep >= 0,
            state: currentStep > 0 ? StepState.complete : StepState.indexed,
            content: identityStep(),
          ),
          Step(
            title: const Text('Ability Scores'),
            isActive: currentStep >= 1,
            state: currentStep > 1 ? StepState.complete : StepState.indexed,
            content: abilitiesStep(),
          ),
          Step(
            title: const Text('Proficiencies'),
            isActive: currentStep >= 2,
            state: currentStep > 2 ? StepState.complete : StepState.indexed,
            content: proficienciesStep(),
          ),
          Step(
            title: const Text('Weapons'),
            isActive: currentStep >= 3,
            state: currentStep > 3 ? StepState.complete : StepState.indexed,
            content: weaponsStep(),
          ),
          Step(
            title: const Text('Spells'),
            isActive: currentStep >= 4,
            state: currentStep > 4 ? StepState.complete : StepState.indexed,
            content: spellsStep(),
          ),
          Step(
            title: const Text('Resources'),
            isActive: currentStep >= 5,
            state: currentStep > 5 ? StepState.complete : StepState.indexed,
            content: resourcesStep(),
          ),
          Step(
            title: Text(isEditing ? 'Inventory' : 'Starting Inventory'),
            isActive: currentStep >= 6,
            state: currentStep > 6 ? StepState.complete : StepState.indexed,
            content: inventoryStep(),
          ),
          Step(
            title: const Text('Features & Actions'),
            isActive: currentStep >= 7,
            state: currentStep > 7 ? StepState.complete : StepState.indexed,
            content: featuresStep(),
          ),
          Step(
            title: const Text('Name & Review'),
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
          TextFormField(
            key: const ValueKey('character-class'),
            controller: classController,
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
              for (final ability in Ability.values)
                SizedBox(
                  width: width,
                  child: numberField(
                    key: 'ability-${ability.name}',
                    controller: abilityControllers[ability]!,
                    label: ability.label,
                    minimum: 1,
                    maximum: 30,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget proficienciesStep() {
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
                onSelected: (selected) {
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
        for (final skill in standardSkills)
          Row(
            children: [
              Expanded(child: Text(skill.name)),
              DropdownButton<SkillProficiency>(
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

  Widget resourcesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Resources track limited-use abilities, spell slots, and other '
          'things that recover during play.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (resources.isEmpty)
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

  Future<void> addWeapon() async {
    final weapon = await showDialog<Weapon>(
      context: context,
      builder: (context) => const WeaponEditorDialog(),
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
      builder: (context) => WeaponEditorDialog(weapon: weapons[index]),
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
  }) {
    return TextFormField(
      key: ValueKey(key),
      controller: controller,
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
