enum Ability {
  strength('Strength', 'STR'),
  dexterity('Dexterity', 'DEX'),
  constitution('Constitution', 'CON'),
  intelligence('Intelligence', 'INT'),
  wisdom('Wisdom', 'WIS'),
  charisma('Charisma', 'CHA');

  final String label;
  final String shortLabel;

  const Ability(this.label, this.shortLabel);
}

class SavingThrowCheck {
  final Ability ability;
  final int modifier;
  final bool proficient;

  const SavingThrowCheck({
    required this.ability,
    required this.modifier,
    required this.proficient,
  });
}
