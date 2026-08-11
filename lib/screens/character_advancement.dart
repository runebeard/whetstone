import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character.dart';
import '../models/character_action.dart';
import '../models/character_resource.dart';
import '../models/content_pack.dart';
import '../models/feature.dart';
import '../models/inventory_item.dart';
import '../models/library_content_copy.dart';
import '../models/spell.dart';
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
  late final List<Spell> spells;
  late final List<Weapon> weapons;
  late final List<CharacterResource> resources;
  late final List<InventoryItem> inventory;
  late final List<Feature> features;
  late final Set<String> pinnedActionKeys;

  @override
  void initState() {
    super.initState();
    levelController = TextEditingController(text: '${widget.character.level}');
    maxHpController = TextEditingController(text: '${widget.character.maxHp}');
    proficiencyController = TextEditingController(
      text: '${widget.character.proficiencyBonus}',
    );
    spells = [...widget.character.spells];
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
    super.dispose();
  }

  String? numberBetween(String? value, int minimum, int maximum) {
    final number = int.tryParse(value ?? '');
    return number == null || number < minimum || number > maximum
        ? '$minimum–$maximum'
        : null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    final maximumHp = int.parse(maxHpController.text);
    Navigator.pop(
      context,
      widget.character.copyWith(
        level: int.parse(levelController.text),
        currentHp: widget.character.currentHp.clamp(0, maximumHp),
        maxHp: maximumHp,
        proficiencyBonus: int.parse(proficiencyController.text),
        spells: [...spells],
        weapons: [...weapons],
        resources: [...resources],
        initialInventory: [...inventory],
        features: [...features],
        initiallyPinnedActionKeys: {...pinnedActionKeys},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
