import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/character_state.dart';
import '../models/spell.dart';
import '../widgets/action_card.dart';
import '../widgets/content_add_buttons.dart';

class SpellbookModeView extends StatelessWidget {
  final Character character;
  final CharacterState characterState;
  final ValueChanged<Spell> onSpellTap;
  final ValueChanged<Spell> onManageSpell;
  final VoidCallback onAddFromLibrary;
  final VoidCallback onCreateCustom;

  const SpellbookModeView({
    super.key,
    required this.character,
    required this.characterState,
    required this.onSpellTap,
    required this.onManageSpell,
    required this.onAddFromLibrary,
    required this.onCreateCustom,
  });

  List<Spell> sorted(Iterable<Spell> spells) {
    return [...spells]..sort((left, right) => left.name.compareTo(right.name));
  }

  Widget buildSection(String title, List<Spell> spells) {
    if (spells.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final spell in spells)
          ActionCard(
            action: spell,
            isPinned: characterState.pinnedActionKeys.contains(spell.actionKey),
            onTap: () => onSpellTap(spell),
            onLongPress: () => onManageSpell(spell),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cantrips = sorted(character.spells.where((spell) => spell.isCantrip));
    final preparedSpells = sorted(
      character.spells.where(
        (spell) =>
            !spell.isCantrip &&
            spell.prepared &&
            !character.isAlwaysPreparedSpell(spell),
      ),
    );
    final alwaysPreparedSpells = sorted(
      character.spells.where(
        (spell) => !spell.isCantrip && character.isAlwaysPreparedSpell(spell),
      ),
    );
    final otherSpells = sorted(
      character.spells.where((spell) => !spell.isCantrip && !spell.prepared),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Long press a spell to edit, pin, or remove it.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ContentAddButtons(
            libraryKey: 'spellbook-library-spell',
            customKey: 'spellbook-create-spell',
            onAddFromLibrary: onAddFromLibrary,
            onCreateCustom: onCreateCustom,
          ),
          const SizedBox(height: 16),
          if (character.subclasses['Druid'] == 'Circle of the Land' &&
              characterState.druidLand != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${characterState.druidLand!.label} Circle Spells'),
              subtitle: Text(
                characterState.druidLand!
                    .spellsAt(character.levelInClass('Druid'))
                    .join(', '),
              ),
            ),
          if (characterState.spellSummons.isNotEmpty) ...[
            Text(
              'Active Summons',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final spell in character.spells)
              if (characterState.spellSummons[spell.id] case final summon?)
                ListTile(
                  title: Text(summon),
                  subtitle: Text(spell.name),
                  onTap: () => onManageSpell(spell),
                ),
            const SizedBox(height: 16),
          ],
          buildSection('Cantrips', cantrips),
          buildSection('Always Prepared', alwaysPreparedSpells),
          buildSection('Prepared Spells', preparedSpells),
          buildSection('Other Spells', otherSpells),
        ],
      ),
    );
  }
}
