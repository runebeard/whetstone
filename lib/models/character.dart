class Character {
  final String name;
  final String characterClass;
  final int level;
  final int currentHp;
  final int maxHp;
  final int armourClass;
  final int initiativeModifier;
  final String status;

  Character({
    required this.name,
    required this.characterClass,
    required this.level,
    required this.currentHp,
    required this.maxHp,
    required this.armourClass,
    required this.initiativeModifier,
    required this.status,
    });
}