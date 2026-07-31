class Character {
  final String name;
  final String characterClass;
  final int level;
  final int currentHp;
  final int maxHp;
  final int ac;
  final String status;

  Character({
    required this.name,
    required this.characterClass,
    required this.level,
    required this.currentHp,
    required this.maxHp,
    required this.ac,
    required this.status,
  });
}